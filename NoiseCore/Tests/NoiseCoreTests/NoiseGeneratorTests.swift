import XCTest
@testable import NoiseCore

final class NoiseGeneratorTests: XCTestCase {
    func samples(_ kind: SoundKind, count: Int = 48_000) -> [Float] {
        var g = NoiseGenerator(kind: kind, sampleRate: 48_000, seed: 42)
        return (0..<count).map { _ in g.nextSample() }
    }

    func testEveryKindProducesBoundedNonSilentAudio() {
        for kind in SoundKind.allCases {
            let s = samples(kind)
            let peak = SignalStats.peak(s)
            let rms = SignalStats.rms(s)
            XCTAssertGreaterThan(rms, 0.01, "\(kind) is silent")
            XCTAssertLessThanOrEqual(peak, 1.0, "\(kind) clips (peak \(peak))")
            XCTAssertFalse(s.contains { $0.isNaN || $0.isInfinite }, "\(kind) produced NaN/inf")
        }
    }

    /// Brown noise has far less high-frequency energy than white. The RMS of
    /// sample-to-sample differences is a cheap proxy for high-frequency content.
    func testSpectralOrdering() {
        func diffRMS(_ s: [Float]) -> Float {
            let d = zip(s.dropFirst(), s).map { $0 - $1 }
            return SignalStats.rms(d) / max(SignalStats.rms(s), 1e-6)
        }
        let white = diffRMS(samples(.white))
        let pink = diffRMS(samples(.pink))
        let brown = diffRMS(samples(.brown))
        let fan = diffRMS(samples(.fan))
        XCTAssertGreaterThan(white, pink)
        XCTAssertGreaterThan(pink, brown)
        XCTAssertLessThan(fan, white)
    }

    func testDeterministicForSameSeed() {
        var a = NoiseGenerator(kind: .pink, sampleRate: 48_000, seed: 7)
        var b = NoiseGenerator(kind: .pink, sampleRate: 48_000, seed: 7)
        for _ in 0..<1000 { XCTAssertEqual(a.nextSample(), b.nextSample()) }
    }

    func testDifferentSeedsDiffer() {
        var a = NoiseGenerator(kind: .white, sampleRate: 48_000, seed: 1)
        var b = NoiseGenerator(kind: .white, sampleRate: 48_000, seed: 2)
        let same = (0..<100).filter { _ in a.nextSample() == b.nextSample() }.count
        XCTAssertLessThan(same, 5)
    }

    func testRenderAppliesGain() {
        var g = NoiseGenerator(kind: .white, sampleRate: 48_000, seed: 3)
        let buffer = UnsafeMutablePointer<Float>.allocate(capacity: 256)
        defer { buffer.deallocate() }
        g.render(into: buffer, count: 256, gain: 0)
        XCTAssertTrue((0..<256).allSatisfy { buffer[$0] == 0 })
    }

    func testOceanActuallySwells() {
        // Over 20 seconds the ocean's loudness envelope must vary noticeably.
        let s = samples(.ocean, count: 48_000 * 20)
        let chunk = 48_000
        let levels = stride(from: 0, to: s.count, by: chunk).map { SignalStats.rms(Array(s[$0..<min($0 + chunk, s.count)])) }
        XCTAssertGreaterThan(levels.max()! / levels.min()!, 1.5)
    }
}
