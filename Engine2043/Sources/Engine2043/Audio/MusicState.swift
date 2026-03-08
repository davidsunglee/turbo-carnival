import AVFoundation
import Synchronization

/// Thread-safe shared state for background music, accessible from both main and audio threads.
final class MusicState: Sendable {
    let amplitude = Mutex<Float>(0.0)
    let track = Mutex<MusicTrack>(.gameplay)
    let samplePosition = Mutex<Int>(0)

    /// Creates an AVAudioSourceNode that synthesizes music on the audio thread.
    func makeSourceNode(format: AVAudioFormat, sampleRate: Float) -> AVAudioSourceNode {
        let state = self
        return AVAudioSourceNode(format: format) { _, _, frameCount, bufferList -> OSStatus in
            let ablPointer = UnsafeMutableAudioBufferListPointer(bufferList)
            let buffer = ablPointer[0]
            let samples = buffer.mData!.assumingMemoryBound(to: Float.self)

            let amp = state.amplitude.withLock { $0 }
            let currentTrack = state.track.withLock { $0 }

            state.samplePosition.withLock { position in
                for i in 0..<Int(frameCount) {
                    let t = Float(position) / sampleRate
                    let sample = MusicSynthesizer.synthesize(track: currentTrack, time: t, sampleRate: sampleRate)
                    samples[i] = sample * amp
                    position += 1
                }
            }

            return noErr
        }
    }
}
