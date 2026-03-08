import AVFoundation

@MainActor
public protocol AudioProvider: AnyObject {
    func playEffect(_ name: String)
    func playMusic(_ name: String)
    func stopAll()
}

@MainActor
public final class AVAudioManager: AudioProvider {
    private let engine = AVAudioEngine()
    private let musicNode = AVAudioPlayerNode()
    private var effectNodes: [AVAudioPlayerNode] = []
    private var bufferCache: [String: AVAudioPCMBuffer] = [:]
    private let effectPoolSize = 8

    public private(set) var masterVolume: Float = 1.0

    public init() {
        engine.attach(musicNode)
        engine.connect(musicNode, to: engine.mainMixerNode, format: nil)

        for _ in 0..<effectPoolSize {
            let node = AVAudioPlayerNode()
            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: nil)
            effectNodes.append(node)
        }

        do {
            try engine.start()
        } catch {
            print("AVAudioEngine failed to start: \(error)")
        }
    }

    public func setMasterVolume(_ volume: Float) {
        masterVolume = max(0, min(1, volume))
        engine.mainMixerNode.outputVolume = masterVolume
    }

    public func playMusic(_ name: String) {
        guard let buffer = loadBuffer(named: name) else { return }
        musicNode.stop()
        musicNode.scheduleBuffer(buffer, at: nil, options: .loops)
        musicNode.play()
    }

    public func playEffect(_ name: String) {
        guard let buffer = loadBuffer(named: name) else { return }

        // Find an idle effect node
        guard let node = effectNodes.first(where: { !$0.isPlaying }) ?? effectNodes.first else { return }
        node.stop()
        node.scheduleBuffer(buffer, at: nil, options: [])
        node.play()
    }

    public func stopAll() {
        musicNode.stop()
        for node in effectNodes {
            node.stop()
        }
    }

    public func shutdown() {
        stopAll()
        engine.stop()
    }

    private func loadBuffer(named name: String) -> AVAudioPCMBuffer? {
        if let cached = bufferCache[name] { return cached }

        guard let url = Bundle.module.url(forResource: name, withExtension: nil) ??
                        Bundle.module.url(forResource: name, withExtension: "caf") ??
                        Bundle.module.url(forResource: name, withExtension: "m4a") else {
            return nil
        }

        do {
            let file = try AVAudioFile(forReading: url)
            let format = file.processingFormat
            let frameCount = AVAudioFrameCount(file.length)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return nil }
            try file.read(into: buffer)
            bufferCache[name] = buffer
            return buffer
        } catch {
            print("Failed to load audio: \(name) — \(error)")
            return nil
        }
    }
}
