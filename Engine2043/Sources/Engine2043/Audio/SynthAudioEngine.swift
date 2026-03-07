import AVFoundation
import Synchronization

/// Thread-safe shared state for the Phase Laser, accessible from both main and audio threads.
final class LaserState: Sendable {
    let frequency = Mutex<Float>(120.0)
    let amplitude = Mutex<Float>(0.0)
    let phase = Mutex<Float>(0)

    /// Creates an AVAudioSourceNode with a render closure that runs on the audio thread.
    /// Must be defined here (outside @MainActor) so the closure doesn't inherit main-actor isolation.
    func makeSourceNode(format: AVAudioFormat, sampleRate: Float) -> AVAudioSourceNode {
        let state = self
        return AVAudioSourceNode(format: format) { _, _, frameCount, bufferList -> OSStatus in
            let ablPointer = UnsafeMutableAudioBufferListPointer(bufferList)
            let buffer = ablPointer[0]
            let samples = buffer.mData!.assumingMemoryBound(to: Float.self)

            let freq = state.frequency.withLock { $0 }
            let amp = state.amplitude.withLock { $0 }

            state.phase.withLock { phase in
                for i in 0..<Int(frameCount) {
                    let t = phase / sampleRate
                    let lfo = sin(2.0 * .pi * 3.0 * t) * 8.0
                    let currentFreq = freq + lfo
                    let saw = 2.0 * ((currentFreq * t).truncatingRemainder(dividingBy: 1.0)) - 1.0
                    let sine = sin(2.0 * .pi * currentFreq * t)
                    samples[i] = (saw * 0.6 + sine * 0.4) * amp
                    phase += 1
                }
            }

            return noErr
        }
    }
}

@MainActor
public final class SynthAudioEngine {
    private let audioEngine = AVAudioEngine()
    private var playerNodes: [AVAudioPlayerNode] = []
    private var buffers: [SFXType: AVAudioPCMBuffer] = [:]
    private let poolSize = 8
    private let sampleRate: Double = 44100

    // Rate limiting: last play time per SFX type
    private var lastPlayTime: [SFXType: CFTimeInterval] = [:]
    private var cooldowns: [SFXType: CFTimeInterval] = [
        .vulcanFire: 0.06,
        .bossShieldDeflect: 0.08
    ]

    // Phase Laser real-time synthesis
    private var laserNode: AVAudioSourceNode?
    private let laser = LaserState()
    private var isLaserActive = false

    public var volume: Float = 0.8 {
        didSet { volume = max(0, min(1, volume)); audioEngine.mainMixerNode.outputVolume = volume }
    }

    private lazy var format: AVAudioFormat = {
        AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
    }()

    public init() {
        for _ in 0..<poolSize {
            let node = AVAudioPlayerNode()
            audioEngine.attach(node)
            audioEngine.connect(node, to: audioEngine.mainMixerNode, format: format)
            playerNodes.append(node)
        }

        audioEngine.mainMixerNode.outputVolume = volume

        do {
            try audioEngine.start()
        } catch {
            print("SynthAudioEngine failed to start: \(error)")
        }

        synthesizeAllBuffers()
    }

    public func play(_ effect: SFXType) {
        // Rate limiting
        let now = CACurrentMediaTime()
        if let cooldown = cooldowns[effect],
           let last = lastPlayTime[effect],
           now - last < cooldown {
            return
        }
        lastPlayTime[effect] = now

        guard let buffer = buffers[effect] else { return }

        // Find idle node or steal the first
        guard let node = playerNodes.first(where: { !$0.isPlaying }) ?? playerNodes.first else { return }
        node.stop()
        node.scheduleBuffer(buffer, at: nil, options: [])
        node.play()
    }

    // MARK: - Synthesis

    private func synthesizeAllBuffers() {
        buffers[.doubleCannonFire] = synthesize(duration: 0.08, generator: squareSweep(from: 440, to: 220))
        buffers[.triSpreadFire] = synthesize(duration: 0.10, generator: mixedSweep(square: (330, 165), noiseMix: 0.3))
        buffers[.vulcanFire] = synthesize(duration: 0.04, generator: sawtoothSweep(from: 880, to: 660))
        buffers[.enemyHit] = synthesize(duration: 0.03, generator: noiseBurst())
        buffers[.enemyDestroyed] = synthesize(duration: 0.20, generator: explosion(squareFrom: 200, squareTo: 50))
        buffers[.playerDamaged] = synthesize(duration: 0.15, generator: squareSweep(from: 100, to: 60))
        buffers[.itemSpawn] = synthesize(duration: 0.12, generator: sineSweep(from: 660, to: 880))
        buffers[.itemCycle] = synthesize(duration: 0.06, generator: sineSweep(from: 440, to: 550))
        buffers[.itemPickup] = synthesize(duration: 0.20, generator: sineChord(freqs: [440, 660, 880]))
        buffers[.gravBombLaunch] = synthesize(duration: 0.10, generator: sineSweep(from: 300, to: 100))
        buffers[.gravBombDetonate] = synthesize(duration: 0.30, generator: explosion(squareFrom: 150, squareTo: 30))
        buffers[.empSweep] = synthesize(duration: 0.25, generator: empZap())
        buffers[.overchargeActivate] = synthesize(duration: 0.15, generator: sineChord(freqs: [330, 440, 660]))
        buffers[.bossShieldDeflect] = synthesize(duration: 0.04, generator: squareSweep(from: 1200, to: 1400))
        buffers[.playerDeath] = synthesize(duration: 0.50, generator: deathGroan())
        buffers[.victory] = synthesize(duration: 1.0, generator: victoryFanfare())
    }

    private func synthesize(duration: Double, generator: (Float, Float) -> Float) -> AVAudioPCMBuffer {
        let frameCount = AVAudioFrameCount(duration * sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        let samples = buffer.floatChannelData![0]

        let attackFrames = max(1, Int(Float(frameCount) * 0.08))

        for i in 0..<Int(frameCount) {
            let t = Float(i) / Float(sampleRate)
            let progress = Float(i) / Float(frameCount)

            var sample = generator(t, progress)

            // AD envelope
            let envelope: Float
            if i < attackFrames {
                envelope = Float(i) / Float(attackFrames)
            } else {
                envelope = 1.0 - (Float(i - attackFrames) / Float(Int(frameCount) - attackFrames))
            }

            sample *= envelope * 0.4 // master gain to prevent clipping
            samples[i] = sample
        }

        return buffer
    }

    // MARK: - Waveform Generators

    private func squareSweep(from startFreq: Float, to endFreq: Float) -> (Float, Float) -> Float {
        { t, progress in
            let freq = startFreq + (endFreq - startFreq) * progress
            return sign(sin(2.0 * .pi * freq * t))
        }
    }

    private func sawtoothSweep(from startFreq: Float, to endFreq: Float) -> (Float, Float) -> Float {
        { t, progress in
            let freq = startFreq + (endFreq - startFreq) * progress
            let phase = freq * t
            return 2.0 * (phase - Float(Int(phase))) - 1.0
        }
    }

    private func sineSweep(from startFreq: Float, to endFreq: Float) -> (Float, Float) -> Float {
        { t, progress in
            let freq = startFreq + (endFreq - startFreq) * progress
            return sin(2.0 * .pi * freq * t)
        }
    }

    private func noiseBurst() -> (Float, Float) -> Float {
        { _, _ in
            Float.random(in: -1...1)
        }
    }

    private func mixedSweep(square: (Float, Float), noiseMix: Float) -> (Float, Float) -> Float {
        let sq = squareSweep(from: square.0, to: square.1)
        let noise = noiseBurst()
        return { t, progress in
            sq(t, progress) * (1.0 - noiseMix) + noise(t, progress) * noiseMix
        }
    }

    private func explosion(squareFrom: Float, squareTo: Float) -> (Float, Float) -> Float {
        let sq = squareSweep(from: squareFrom, to: squareTo)
        let noise = noiseBurst()
        return { t, progress in
            sq(t, progress) * 0.4 + noise(t, progress) * 0.6
        }
    }

    private func empZap() -> (Float, Float) -> Float {
        let sweep = sineSweep(from: 200, to: 2000)
        let noise = noiseBurst()
        return { t, progress in
            sweep(t, progress) * 0.6 + noise(t, progress) * 0.4
        }
    }

    private func victoryFanfare() -> (Float, Float) -> Float {
        // Ascending 4-note arpeggio: C5 → E5 → G5 → C6
        // Each note has its own envelope; compensate for global AD decay
        let notes: [(freq: Float, onset: Float)] = [
            (523.25, 0.0), (659.25, 0.15), (783.99, 0.30), (1046.50, 0.50)
        ]
        return { t, progress in
            // Compensate for global AD envelope decay (linear from 1→0 after 8% attack)
            let compensation: Float = progress > 0.08 ? 1.0 / max(0.15, 1.0 - progress) : 1.0

            var sum: Float = 0
            for note in notes {
                guard progress >= note.onset else { continue }
                let localT = t - note.onset * 1.0
                let noteAge = progress - note.onset
                let noteEnv = max(0, 1.0 - noteAge * 1.2)
                let sine = sin(2.0 * .pi * note.freq * localT)
                let square = sign(sin(2.0 * .pi * note.freq * localT))
                sum += (sine * 0.7 + square * 0.3) * noteEnv
            }
            return (sum / 2.0) * min(compensation, 3.0)
        }
    }

    private func deathGroan() -> (Float, Float) -> Float {
        let sq = squareSweep(from: 200, to: 40)
        let noise = noiseBurst()
        return { t, progress in
            sq(t, progress) * 0.5 + noise(t, progress) * 0.5
        }
    }

    private func sineChord(freqs: [Float]) -> (Float, Float) -> Float {
        { t, progress in
            var sum: Float = 0
            for (i, freq) in freqs.enumerated() {
                let offset = Float(i) * 0.03 // stagger for arpeggio effect
                let adjustedT = max(0, t - offset)
                sum += sin(2.0 * .pi * freq * adjustedT)
            }
            return sum / Float(freqs.count)
        }
    }

    // MARK: - Phase Laser

    public func startLaser() {
        guard !isLaserActive else { return }
        isLaserActive = true

        laser.frequency.withLock { $0 = 120.0 }
        laser.amplitude.withLock { $0 = 0.3 }
        laser.phase.withLock { $0 = 0 }

        let node = laser.makeSourceNode(format: format, sampleRate: Float(sampleRate))

        audioEngine.attach(node)
        audioEngine.connect(node, to: audioEngine.mainMixerNode, format: format)
        laserNode = node
    }

    public func stopLaser() {
        guard isLaserActive else { return }
        isLaserActive = false

        laser.amplitude.withLock { $0 = 0 }

        if let node = laserNode {
            audioEngine.detach(node)
            laserNode = nil
        }
        laser.phase.withLock { $0 = 0 }
    }

    public func setLaserHeat(_ heat: Float) {
        let clamped = max(0, min(1, heat))
        // Map heat 0→1 to frequency 120Hz→180Hz
        laser.frequency.withLock { $0 = 120.0 + clamped * 60.0 }
        // Map heat 0→1 to amplitude 0.3→0.5
        laser.amplitude.withLock { $0 = 0.3 + clamped * 0.2 }
    }
}
