import AVFoundation
import os

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
        .vulcanFire: 0.06
    ]

    // Phase Laser real-time synthesis
    private var laserNode: AVAudioSourceNode?
    private let laserFrequency = OSAllocatedUnfairLock(initialState: Float(120.0))
    private let laserAmplitude = OSAllocatedUnfairLock(initialState: Float(0.0))
    private var laserPhase: Float = 0
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

        laserFrequency.withLock { $0 = 120.0 }
        laserAmplitude.withLock { $0 = 0.3 }
        laserPhase = 0

        let sRate = Float(sampleRate)

        let node = AVAudioSourceNode(format: format) { [weak self] _, _, frameCount, bufferList -> OSStatus in
            guard let self else { return noErr }
            let ablPointer = UnsafeMutableAudioBufferListPointer(bufferList)
            let buffer = ablPointer[0]
            let samples = buffer.mData!.assumingMemoryBound(to: Float.self)

            let freq = self.laserFrequency.withLock { $0 }
            let amp = self.laserAmplitude.withLock { $0 }

            for i in 0..<Int(frameCount) {
                let t = self.laserPhase / sRate
                // Sawtooth + sine blend with slow LFO wobble
                let lfo = sin(2.0 * .pi * 3.0 * t) * 8.0 // 3Hz wobble, ±8Hz
                let currentFreq = freq + lfo
                let saw = 2.0 * ((currentFreq * t).truncatingRemainder(dividingBy: 1.0)) - 1.0
                let sine = sin(2.0 * .pi * currentFreq * t)
                samples[i] = (saw * 0.6 + sine * 0.4) * amp
                self.laserPhase += 1
            }

            return noErr
        }

        audioEngine.attach(node)
        audioEngine.connect(node, to: audioEngine.mainMixerNode, format: format)
        laserNode = node
    }

    public func stopLaser() {
        guard isLaserActive else { return }
        isLaserActive = false

        laserAmplitude.withLock { $0 = 0 }

        if let node = laserNode {
            audioEngine.detach(node)
            laserNode = nil
        }
        laserPhase = 0
    }

    public func setLaserHeat(_ heat: Float) {
        let clamped = max(0, min(1, heat))
        // Map heat 0→1 to frequency 120Hz→180Hz
        laserFrequency.withLock { $0 = 120.0 + clamped * 60.0 }
        // Map heat 0→1 to amplitude 0.3→0.5
        laserAmplitude.withLock { $0 = 0.3 + clamped * 0.2 }
    }
}
