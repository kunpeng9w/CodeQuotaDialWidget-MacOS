import Testing

@testable import UsagePanelSupport

@Test func gaugeFractionClampsToUnitRange() {
    #expect(QuotaGaugeLogic.fraction(remainingPercent: nil) == 0)
    #expect(QuotaGaugeLogic.fraction(remainingPercent: -5) == 0)
    #expect(QuotaGaugeLogic.fraction(remainingPercent: 0) == 0)
    #expect(QuotaGaugeLogic.fraction(remainingPercent: 62) == 0.62)
    #expect(QuotaGaugeLogic.fraction(remainingPercent: 100) == 1)
    #expect(QuotaGaugeLogic.fraction(remainingPercent: 150) == 1)
}

@Test func gaugeToneThresholdsMatchQuotaToneTiers() {
    #expect(QuotaGaugeLogic.tone(remainingPercent: nil) == .unknown)
    #expect(QuotaGaugeLogic.tone(remainingPercent: 100) == .healthy)
    #expect(QuotaGaugeLogic.tone(remainingPercent: 50) == .healthy)
    #expect(QuotaGaugeLogic.tone(remainingPercent: 49) == .low)
    #expect(QuotaGaugeLogic.tone(remainingPercent: 20) == .low)
    #expect(QuotaGaugeLogic.tone(remainingPercent: 19) == .critical)
    #expect(QuotaGaugeLogic.tone(remainingPercent: 0) == .critical)
}
