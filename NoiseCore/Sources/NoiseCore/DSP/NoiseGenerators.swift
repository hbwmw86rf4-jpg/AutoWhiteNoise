import Foundation

/// A deterministic, fast pseudo-random source (xorshift128+). We do not want
/// cryptographic randomness here; we want millions of samples per second with
/// no allocation. Seeded differently per channel so stereo sounds wide.
public struct NoiseRNG: Sendable {
    private var s0: UInt64
    private var s1: UInt64

    public init(seed: UInt64) {
        // SplitMix64 to spread a small seed into two good state words.
        var z = seed &+ 0x9E3779B97F4A7C15
        func mix(_ v: inout UInt64) -> UInt64 {
            v = (v ^ (v >> 30)) &* 0xBF58476D1CE4E5B9
            v = (v ^ (v >> 27)) &* 0x94D049BB133111EB
            return v ^ (v >> 31)
        }
        s0 = mix(&z)
        z = z &+ 0x9E3779B97F4A7C15
        s1 = mix(&z)
        if s0 == 0 && s1 == 0 { s1 = 1 }
    }

    @inline(__always)
    public mutating func next() -> UInt64 {
        var x = s0
        let y = s1
        s0 = y
        x ^= x << 23
        s1 = x ^ y ^ (x >> 17) ^ (y >> 26)
        return s1 &+ y
    }

    /// Uniform in [-1, 1).
    @inline(__always)
    public mutating func nextSample() -> Float {
        // Take the top 24 bits so Float gets a full mantissa of randomness.
        let bits = next() >> 40
        return Float(bits) * (2.0 / 16_777_216.0) - 1.0
    }
}

/// One channel of one sound. Call `nextSample()` once per output sample.
/// Everything here is a plain value type with no allocation so it can run
/// inside the real-time audio thread.
public struct NoiseGenerator: Sendable {
    public let kind: SoundKind
    public let sampleRate: Float
    private var rng: NoiseRNG

    // Pink noise state (Paul Kellet's refined filter).
    private var b0: Float = 0, b1: Float = 0, b2: Float = 0, b3: Float = 0, b4: Float = 0, b5: Float = 0, b6: Float = 0
    // Brown noise integrator.
    private var brown: Float = 0
    // One-pole filters.
    private var lp1: Float = 0, lp2: Float = 0, hp: Float = 0, hpPrevIn: Float = 0
    // Slow modulation phases (ocean swell, rain gusts).
    private var phaseA: Float = 0, phaseB: Float = 0

    public init(kind: SoundKind, sampleRate: Float, seed: UInt64) {
        self.kind = kind
        self.sampleRate = sampleRate
        self.rng = NoiseRNG(seed: seed)
    }

    @inline(__always)
    private mutating func white() -> Float { rng.nextSample() }

    @inline(__always)
    private mutating func pink() -> Float {
        let w = white()
        b0 = 0.99886 * b0 + w * 0.0555179
        b1 = 0.99332 * b1 + w * 0.0750759
        b2 = 0.96900 * b2 + w * 0.1538520
        b3 = 0.86650 * b3 + w * 0.3104856
        b4 = 0.55000 * b4 + w * 0.5329522
        b5 = -0.7616 * b5 - w * 0.0168980
        let out = b0 + b1 + b2 + b3 + b4 + b5 + b6 + w * 0.5362
        b6 = w * 0.115926
        return out * 0.11
    }

    @inline(__always)
    private mutating func brownSample() -> Float {
        let w = white()
        brown = (brown + 0.02 * w) / 1.02
        return brown * 3.5
    }

    /// A one-pole low-pass. `coeff` is between 0 (no filtering) and 1 (frozen).
    @inline(__always)
    private static func lowPassCoefficient(cutoffHz: Float, sampleRate: Float) -> Float {
        let x = exp(-2 * Float.pi * cutoffHz / sampleRate)
        return x
    }

    public mutating func nextSample() -> Float {
        switch kind {
        case .white:
            return white() * 0.5

        case .pink:
            return pink()

        case .brown:
            return brownSample()

        case .fan:
            // Pink noise through two gentle low-passes gives the smooth, bass-heavy
            // whoosh of a box fan or an air purifier on medium.
            let c = NoiseGenerator.lowPassCoefficient(cutoffHz: 900, sampleRate: sampleRate)
            let p = pink()
            lp1 = c * lp1 + (1 - c) * p
            lp2 = c * lp2 + (1 - c) * lp1
            return lp2 * 1.6

        case .ocean:
            // Brown noise whose loudness rises and falls on two slow, slightly
            // mismatched cycles, so the "waves" never repeat exactly.
            let inc1 = 2 * Float.pi * 0.09 / sampleRate
            let inc2 = 2 * Float.pi * 0.023 / sampleRate
            phaseA += inc1; if phaseA > 2 * Float.pi { phaseA -= 2 * Float.pi }
            phaseB += inc2; if phaseB > 2 * Float.pi { phaseB -= 2 * Float.pi }
            let swell = 0.55 + 0.30 * sin(phaseA) + 0.15 * sin(phaseB)
            return brownSample() * swell

        case .rain:
            // Bright, high-passed white noise (the patter) over a soft pink bed,
            // with a slow gust cycle so it breathes a little.
            let w = white()
            // One-pole high-pass around 1.5 kHz.
            let c = NoiseGenerator.lowPassCoefficient(cutoffHz: 1500, sampleRate: sampleRate)
            hp = c * (hp + w - hpPrevIn)
            hpPrevIn = w
            let inc = 2 * Float.pi * 0.05 / sampleRate
            phaseA += inc; if phaseA > 2 * Float.pi { phaseA -= 2 * Float.pi }
            let gust = 0.8 + 0.2 * sin(phaseA)
            return (hp * 0.35 * gust) + pink() * 0.5
        }
    }

    /// Fills `buffer` with `count` samples multiplied by `gain`. Used by the
    /// audio engine; also handy in tests.
    public mutating func render(into buffer: UnsafeMutablePointer<Float>, count: Int, gain: Float) {
        for i in 0..<count {
            buffer[i] = nextSample() * gain
        }
    }
}

/// Quick statistics used by tests and by the "level meter" in the UI.
public enum SignalStats {
    public static func rms(_ samples: [Float]) -> Float {
        guard !samples.isEmpty else { return 0 }
        var acc: Float = 0
        for s in samples { acc += s * s }
        return (acc / Float(samples.count)).squareRoot()
    }

    public static func peak(_ samples: [Float]) -> Float {
        samples.reduce(0) { max($0, abs($1)) }
    }
}
