import Foundation

public struct CodexQuotaCollector: Sendable {
    private let paths: CodexPaths

    public init(paths: CodexPaths = CodexPaths()) {
        self.paths = paths
    }

    public func collect(now: Date = Date()) -> CodexQuotaSnapshot {
        do {
            let stdout = try readRateLimitsFromAppServer()
            var snapshot = try Self.parseRateLimitsResponse(stdout)
            snapshot.generatedAt = now
            return snapshot
        } catch {
            return CodexQuotaSnapshot(generatedAt: now, error: error.localizedDescription)
        }
    }

    private func readRateLimitsFromAppServer() throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: paths.codexBinaryPath)
        process.arguments = ["app-server", "--listen", "stdio://"]

        let inputPipe = Pipe()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        let outputBuffer = LockedBuffer()
        let errorBuffer = LockedBuffer()
        let initialized = DispatchSemaphore(value: 0)
        let completed = DispatchSemaphore(value: 0)

        outputPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            let output = outputBuffer.appendAndString(data)
            if output.contains(#""id":1"#), output.contains(#""result""#) {
                initialized.signal()
            }
            if output.contains(#""id":2"#), output.contains(#""rateLimits""#) {
                completed.signal()
            }
        }

        errorPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            errorBuffer.append(data)
        }

        do {
            try process.run()
        } catch {
            throw CodexQuotaError.noResponse("Could not launch app-server: \(error.localizedDescription)")
        }

        func send(_ object: String) {
            inputPipe.fileHandleForWriting.write(Data((object + "\n").utf8))
        }

        send(#"{"id":1,"method":"initialize","params":{"clientInfo":{"name":"codex-quota-dial-widget","title":"Codex Quota Dial Widget","version":"0.1.0"},"capabilities":{"experimentalApi":true,"requestAttestation":false,"optOutNotificationMethods":[]}}}"#)

        guard initialized.wait(timeout: .now() + .seconds(60)) == .success else {
            close(process: process, inputPipe: inputPipe, outputPipe: outputPipe, errorPipe: errorPipe)
            throw CodexQuotaError.noResponse(Self.errorMessage(from: errorBuffer.string(), fallback: "app-server initialize did not return within 60 seconds"))
        }

        send(#"{"method":"initialized"}"#)
        send(#"{"id":2,"method":"account/rateLimits/read"}"#)

        guard completed.wait(timeout: .now() + .seconds(60)) == .success else {
            close(process: process, inputPipe: inputPipe, outputPipe: outputPipe, errorPipe: errorPipe)
            throw CodexQuotaError.noResponse(Self.errorMessage(from: errorBuffer.string(), fallback: "account/rateLimits/read did not return within 60 seconds"))
        }

        close(process: process, inputPipe: inputPipe, outputPipe: outputPipe, errorPipe: errorPipe)
        return outputBuffer.string()
    }

    public static func parseRateLimitsResponse(_ stdout: String) throws -> CodexQuotaSnapshot {
        guard let data = stdout
            .split(separator: "\n")
            .compactMap({ line -> Data? in
                line.contains(#""rateLimits""#) ? Data(line.utf8) : nil
            })
            .first else {
            return CodexQuotaSnapshot(generatedAt: Date(), error: "rateLimits response not found")
        }

        let envelope = try JSONDecoder().decode(RateLimitEnvelope.self, from: data)
        let keyedSnapshots = envelope.result.rateLimitsByLimitId.map { Array($0.values) } ?? []
        let snapshots = keyedSnapshots + [envelope.result.rateLimits]
        var fiveHour: CodexQuotaWindow?
        var weekly: CodexQuotaWindow?

        for snapshot in snapshots {
            for window in [snapshot.primary, snapshot.secondary].compactMap({ $0 }) {
                let normalized = CodexQuotaWindow(
                    remainingPercent: max(0, min(100, 100 - window.usedPercent)),
                    usedPercent: window.usedPercent,
                    resetsAt: window.resetsAt.map { Date(timeIntervalSince1970: TimeInterval($0)) },
                    windowDurationMins: window.windowDurationMins
                )

                if let duration = window.windowDurationMins, abs(duration - 300) <= 30 {
                    fiveHour = normalized
                } else if let duration = window.windowDurationMins, abs(duration - 10_080) <= 120 {
                    weekly = normalized
                }
            }
        }

        return CodexQuotaSnapshot(generatedAt: Date(), fiveHour: fiveHour, weekly: weekly)
    }

    private func close(process: Process, inputPipe: Pipe, outputPipe: Pipe, errorPipe: Pipe) {
        outputPipe.fileHandleForReading.readabilityHandler = nil
        errorPipe.fileHandleForReading.readabilityHandler = nil
        inputPipe.fileHandleForWriting.closeFile()
        if process.isRunning {
            process.terminate()
        }
    }

    private static func errorMessage(from stderr: String, fallback: String) -> String {
        let trimmed = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return fallback
        }

        if trimmed.contains("remote installed plugin bundle sync failed")
            || trimmed.contains("failed to warm featured plugin ids cache")
            || trimmed.contains("failed to refresh remote installed plugins cache")
            || trimmed.contains("/backend-api/plugins/featured")
            || trimmed.contains("/backend-api/ps/plugins/installed") {
            return "Codex app-server 启动时同步远程插件失败，额度接口本次未及时返回"
        }

        return trimmed
    }
}

private final class LockedBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()

    func append(_ newData: Data) {
        lock.lock()
        data.append(newData)
        lock.unlock()
    }

    func appendAndString(_ newData: Data) -> String {
        lock.lock()
        data.append(newData)
        let output = String(data: data, encoding: .utf8) ?? ""
        lock.unlock()
        return output
    }

    func string() -> String {
        lock.lock()
        let output = String(data: data, encoding: .utf8) ?? ""
        lock.unlock()
        return output
    }
}

private enum CodexQuotaError: Error, LocalizedError {
    case noResponse(String)

    var errorDescription: String? {
        switch self {
        case .noResponse(let message):
            return message
        }
    }
}

private struct RateLimitEnvelope: Decodable {
    var result: RateLimitReadResult
}

private struct RateLimitReadResult: Decodable {
    var rateLimits: RateLimitSnapshotPayload
    var rateLimitsByLimitId: [String: RateLimitSnapshotPayload]?
}

private struct RateLimitSnapshotPayload: Decodable {
    var primary: RateLimitWindowPayload?
    var secondary: RateLimitWindowPayload?
}

private struct RateLimitWindowPayload: Decodable {
    var usedPercent: Int
    var resetsAt: Int?
    var windowDurationMins: Int?
}
