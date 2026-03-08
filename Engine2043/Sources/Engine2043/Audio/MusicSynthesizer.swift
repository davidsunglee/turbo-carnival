import Foundation
import simd

/// Pure synthesis functions for procedural background music.
/// Called from the audio thread — must be lock-free and deterministic.
enum MusicSynthesizer {

    // MARK: - Track Definitions

    // Gameplay: C minor, 120 BPM, Cm -> Ab -> Bb -> G
    // Boss: E minor, 120 BPM, Em -> C -> D -> B

    private static let bpm: Float = 120.0
    private static let beatDuration: Float = 60.0 / bpm  // 0.5s

    // Chord root frequencies (Hz)
    // Gameplay: Cm(C3=130.81) Ab(Ab2=103.83) Bb(Bb2=116.54) G(G2=98.00)
    private static let gameplayChords: [(root: Float, third: Float, fifth: Float)] = [
        (130.81, 155.56, 196.00),  // Cm:  C3, Eb3, G3
        (103.83, 130.81, 155.56),  // Ab:  Ab2, C3, Eb3
        (116.54, 146.83, 174.61),  // Bb:  Bb2, D3, F3
        (98.00,  123.47, 146.83),  // G:   G2, B2, D3
    ]

    // Boss: Em(E3=164.81) C(C3=130.81) D(D3=146.83) B(B2=123.47)
    private static let bossChords: [(root: Float, third: Float, fifth: Float)] = [
        (164.81, 196.00, 246.94),  // Em:  E3, G3, B3
        (130.81, 164.81, 196.00),  // C:   C3, E3, G3
        (146.83, 185.00, 220.00),  // D:   D3, F#3, A3
        (123.47, 155.56, 185.00),  // B:   B2, D#3, F#3
    ]

    // MARK: - Main Entry Point

    static func synthesize(track: MusicTrack, time: Float, sampleRate: Float) -> Float {
        let chords: [(root: Float, third: Float, fifth: Float)]
        switch track {
        case .gameplay: chords = gameplayChords
        case .boss:     chords = bossChords
        }

        // Each chord lasts 4 beats (2 seconds at 120 BPM), 4 chords = 8 seconds loop
        let loopDuration = beatDuration * 16.0  // 4 chords x 4 beats
        let loopTime = time.truncatingRemainder(dividingBy: loopDuration)
        let chordIndex = Int(loopTime / (beatDuration * 4.0)) % chords.count
        let chord = chords[chordIndex]

        // Beat position within the loop
        let beatInLoop = loopTime / beatDuration
        let beatFraction = beatInLoop.truncatingRemainder(dividingBy: 1.0)

        let bass = synthBass(root: chord.root, time: time, beatFraction: beatFraction, track: track)
        let arp = synthArpeggio(chord: chord, time: time, beatInLoop: beatInLoop, track: track)
        let drums = synthDrums(beatInLoop: beatInLoop, beatFraction: beatFraction, track: track, sampleRate: sampleRate)
        let pad = synthPad(chord: chord, time: time)

        // Mix levels — keep total under ~0.4 to leave headroom
        let mix: Float
        switch track {
        case .gameplay:
            mix = bass * 0.12 + arp * 0.08 + drums * 0.10 + pad * 0.05
        case .boss:
            mix = bass * 0.14 + arp * 0.09 + drums * 0.12 + pad * 0.04
        }

        return mix
    }

    // MARK: - Bass Layer

    private static func synthBass(root: Float, time: Float, beatFraction: Float, track: MusicTrack) -> Float {
        let freq = root * 0.5  // One octave down
        let saw = 2.0 * ((freq * time).truncatingRemainder(dividingBy: 1.0)) - 1.0
        let square = sign(sin(2.0 * .pi * freq * time))
        let wave: Float
        switch track {
        case .gameplay:
            wave = saw * 0.6 + square * 0.4
        case .boss:
            // Distorted: clip the sawtooth
            let clipped = max(-0.7, min(0.7, saw * 1.5))
            wave = clipped * 0.7 + square * 0.3
        }
        // Eighth-note envelope (gate on each eighth)
        let eighthFrac = (beatFraction * 2.0).truncatingRemainder(dividingBy: 1.0)
        let envelope = max(0, 1.0 - eighthFrac * 1.5)
        return wave * envelope
    }

    // MARK: - Arpeggio Layer

    private static func synthArpeggio(chord: (root: Float, third: Float, fifth: Float), time: Float, beatInLoop: Float, track: MusicTrack) -> Float {
        // Cycle through chord tones as sixteenth notes
        let sixteenthIndex = Int(beatInLoop * 4.0) % 4
        let tones = [chord.root * 2, chord.third * 2, chord.fifth * 2, chord.third * 2]  // Up one octave
        let freq = tones[sixteenthIndex]

        let wave: Float
        switch track {
        case .gameplay:
            wave = sin(2.0 * .pi * freq * time)
        case .boss:
            // Pulse wave for more aggressive feel
            let phase = (freq * time).truncatingRemainder(dividingBy: 1.0)
            wave = phase < 0.3 ? 1.0 : -1.0
        }

        // Sixteenth-note envelope
        let sixteenthFrac = (beatInLoop * 4.0).truncatingRemainder(dividingBy: 1.0)
        let envelope = max(0, 1.0 - sixteenthFrac * 2.0)
        return wave * envelope
    }

    // MARK: - Drums Layer

    private static func synthDrums(beatInLoop: Float, beatFraction: Float, track: MusicTrack, sampleRate: Float) -> Float {
        let beatIndex = Int(beatInLoop) % 16  // 16 beats in loop

        var drum: Float = 0

        // Kick: beats 0, 4, 8, 12 (quarter notes)
        let kickBeats = [0, 4, 8, 12]
        if kickBeats.contains(beatIndex) && beatFraction < 0.3 {
            let kickProgress = beatFraction / 0.3
            let kickFreq = 150.0 - 100.0 * kickProgress  // Sweep from 150 to 50 Hz
            drum += sin(2.0 * .pi * kickFreq * beatFraction * beatDuration) * (1.0 - kickProgress)
        }

        // Boss gets extra kick on off-beats
        if track == .boss && [2, 6, 10, 14].contains(beatIndex) && beatFraction < 0.2 {
            let kickProgress = beatFraction / 0.2
            let kickFreq = 120.0 - 70.0 * kickProgress
            drum += sin(2.0 * .pi * kickFreq * beatFraction * beatDuration) * (1.0 - kickProgress) * 0.6
        }

        // Snare: beats 4, 12
        let snareBeats = [4, 12]
        if snareBeats.contains(beatIndex) && beatFraction < 0.2 {
            let snareProgress = beatFraction / 0.2
            // Noise burst + tone
            let noise = Float(Int(time(beatFraction, sampleRate)) % 17) / 8.5 - 1.0  // Deterministic pseudo-noise
            let tone = sin(2.0 * .pi * 200.0 * beatFraction * beatDuration)
            drum += (noise * 0.6 + tone * 0.4) * (1.0 - snareProgress)
        }

        // Hihat: every other eighth note
        let eighthIndex = Int(beatInLoop * 2.0) % 32
        if eighthIndex % 2 == 1 && beatFraction > 0.5 {
            let hihatFrac = (beatFraction - 0.5) / 0.5
            if hihatFrac < 0.15 {
                let noise = Float(Int(time(beatFraction + Float(eighthIndex), sampleRate)) % 13) / 6.5 - 1.0
                drum += noise * 0.3 * (1.0 - hihatFrac / 0.15)
            }
        }

        return drum
    }

    /// Deterministic pseudo-noise seed from beat fraction and sample rate
    private static func time(_ beatFraction: Float, _ sampleRate: Float) -> Float {
        beatFraction * sampleRate
    }

    // MARK: - Pad Layer

    private static func synthPad(chord: (root: Float, third: Float, fifth: Float), time: Float) -> Float {
        // Soft sine tones at chord frequencies with slow LFO
        let lfo = (1.0 + sin(2.0 * .pi * 0.5 * time)) * 0.5  // 0.5 Hz tremolo
        let root = sin(2.0 * .pi * chord.root * time)
        let third = sin(2.0 * .pi * chord.third * time)
        let fifth = sin(2.0 * .pi * chord.fifth * time)
        return (root + third + fifth) / 3.0 * lfo
    }
}
