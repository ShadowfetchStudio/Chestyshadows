import AppKit
import Foundation

/// Synthesizes tactile acoustic chess sound effects in-memory without external audio files.
@MainActor
public final class SoundEffects {
    public static let shared = SoundEffects()

    public var isMuted: Bool = false

    public enum Cue: CaseIterable {
        case move
        case capture
        case castle
        case check
        case victory
        case defeat
    }

    private var cachedData: [Cue: Data] = [:]
    private var activeSounds: [NSSound] = []

    private init() {
        for cue in Cue.allCases {
            cachedData[cue] = Self.generateWAVData(for: cue)
        }
    }

    public func play(_ cue: Cue) {
        guard !isMuted, let data = cachedData[cue], let sound = NSSound(data: data) else { return }
        activeSounds.removeAll { !$0.isPlaying }
        sound.volume = 0.45
        activeSounds.append(sound)
        sound.play()
    }

    private static func generateWAVData(for cue: Cue) -> Data {
        let sampleRate = 44100.0
        let duration: Double
        switch cue {
        case .move: duration = 0.095
        case .capture: duration = 0.125
        case .castle: duration = 0.19
        case .check: duration = 0.28
        case .victory: duration = 0.52
        case .defeat: duration = 0.48
        }

        let numSamples = Int(sampleRate * duration)
        var samples = [Int16](repeating: 0, count: numSamples)

        for i in 0..<numSamples {
            let t = Double(i) / sampleRate
            let signal: Double
            switch cue {
            case .move:
                // Warm wooden board thock: low pitch sweep + subtle click transient
                let env = exp(-t * 46.0)
                let click = exp(-t * 210.0) * sin(2.0 * .pi * 920.0 * t) * 0.25
                let bodyFreq = 148.0 - 42.0 * min(1.0, t * 18.0)
                let body = sin(2.0 * .pi * bodyFreq * t) + 0.35 * sin(2.0 * .pi * bodyFreq * 2.1 * t)
                signal = (body * env * 0.65 + click)
            case .capture:
                // Crisp weighted snap + deeper resonant thump
                let env = exp(-t * 36.0)
                let snap = exp(-t * 140.0) * (sin(2.0 * .pi * 1340.0 * t) + 0.5 * sin(2.0 * .pi * 780.0 * t)) * 0.38
                let thump = sin(2.0 * .pi * 124.0 * t) * env * 0.72
                signal = thump + snap
            case .castle:
                // Double wooden thock (King + Rook)
                let t1 = t
                let env1 = exp(-t1 * 48.0)
                let hit1 = sin(2.0 * .pi * 150.0 * t1) * env1 * 0.6
                var hit2 = 0.0
                if t >= 0.075 {
                    let t2 = t - 0.075
                    let env2 = exp(-t2 * 45.0)
                    hit2 = sin(2.0 * .pi * 172.0 * t2) * env2 * 0.65
                }
                signal = hit1 + hit2
            case .check:
                // Clear crystalline alert harmonic
                let env = exp(-t * 11.5)
                let f1 = 587.33 // D5
                let f2 = 880.00 // A5
                signal = (0.55 * sin(2.0 * .pi * f1 * t) + 0.45 * sin(2.0 * .pi * f2 * t)) * env * 0.55
            case .victory:
                // Warm major triad arpeggio chime (D5 - F#5 - A5)
                let f1 = 587.33
                let f2 = 739.99
                let f3 = 880.00
                let n1 = sin(2.0 * .pi * f1 * t) * exp(-t * 6.5) * 0.4
                let n2 = t >= 0.08 ? sin(2.0 * .pi * f2 * (t - 0.08)) * exp(-(t - 0.08) * 6.5) * 0.4 : 0.0
                let n3 = t >= 0.16 ? sin(2.0 * .pi * f3 * (t - 0.16)) * exp(-(t - 0.16) * 5.2) * 0.48 : 0.0
                signal = n1 + n2 + n3
            case .defeat:
                // Subtle descending minor interval
                let f1 = 440.0
                let f2 = 349.23
                let n1 = sin(2.0 * .pi * f1 * t) * exp(-t * 7.5) * 0.42
                let n2 = t >= 0.12 ? sin(2.0 * .pi * f2 * (t - 0.12)) * exp(-(t - 0.12) * 5.8) * 0.45 : 0.0
                signal = n1 + n2
            }

            let clamped = max(-0.98, min(0.98, signal))
            samples[i] = Int16(clamped * Double(Int16.max))
        }

        return encodePCM16WAV(samples: samples, sampleRate: UInt32(sampleRate))
    }

    private static func encodePCM16WAV(samples: [Int16], sampleRate: UInt32) -> Data {
        let numChannels: UInt16 = 1
        let bitsPerSample: UInt16 = 16
        let byteRate = sampleRate * UInt32(numChannels) * UInt32(bitsPerSample / 8)
        let blockAlign = numChannels * (bitsPerSample / 8)
        let dataSize = UInt32(samples.count * MemoryLayout<Int16>.size)
        let chunkSize = 36 + dataSize

        var data = Data()
        data.append(contentsOf: "RIFF".utf8)
        data.append(littleEndianBytes(chunkSize))
        data.append(contentsOf: "WAVE".utf8)
        data.append(contentsOf: "fmt ".utf8)
        data.append(littleEndianBytes(UInt32(16)))
        data.append(littleEndianBytes(UInt16(1))) // PCM
        data.append(littleEndianBytes(numChannels))
        data.append(littleEndianBytes(sampleRate))
        data.append(littleEndianBytes(byteRate))
        data.append(littleEndianBytes(blockAlign))
        data.append(littleEndianBytes(bitsPerSample))
        data.append(contentsOf: "data".utf8)
        data.append(littleEndianBytes(dataSize))

        for sample in samples {
            data.append(littleEndianBytes(sample))
        }
        return data
    }

    private static func littleEndianBytes<T: FixedWidthInteger>(_ value: T) -> Data {
        var le = value.littleEndian
        return withUnsafeBytes(of: &le) { Data($0) }
    }
}
