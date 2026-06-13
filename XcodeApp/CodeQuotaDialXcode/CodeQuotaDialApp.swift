import SwiftUI

@main
struct CodeQuotaDialApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(width: 580, height: 440)
        }
        .windowResizability(.contentSize)
    }
}
