import Foundation
import AVFoundation

/// Plays the spoken model of a word: an on-device text-to-speech voice for every target,
/// or a parent's own recording when they've attached one. The model is the heart of
/// imitation-based apraxia practice — the child hears it, then has a go.
///
/// Audio uses the `.playback` category so the model is heard even with the silent switch on
/// (a phone in a pocket-quiet house should still speak). Everything is on-device; nothing
/// is sent anywhere.
@Observable
final class SpeechModelPlayer: NSObject, AVAudioPlayerDelegate, AVSpeechSynthesizerDelegate {
    /// Pulses true while something is speaking/playing, for a simple UI state.
    private(set) var isPlaying = false

    private let synthesizer = AVSpeechSynthesizer()
    private var player: AVAudioPlayer?
    private let store = AudioStore.shared

    /// Slowed playback rate for both TTS and recordings, so a toddler can track the mouth.
    private static let slowTTSRate: Float = 0.35
    private static let slowClipRate: Float = 0.6

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    /// Speak/​play the model for a target. Prefers the parent recording when present,
    /// otherwise speaks `text` with TTS. `slow` slows whichever source is used.
    func play(text: String, recordingFilename: String? = nil, slow: Bool = false) {
        if let filename = recordingFilename, store.exists(filename) {
            playClip(filename, slow: slow)
        } else {
            speak(text, slow: slow)
        }
    }

    /// Speak text with the on-device voice. Prefers an Australian English voice when one is
    /// installed (matching the app's Key Word Sign framing), else the device default.
    func speak(_ text: String, slow: Bool = false) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        activate(.playback)
        let utterance = AVSpeechUtterance(string: trimmed)
        utterance.voice = Self.preferredVoice
        utterance.rate = slow ? Self.slowTTSRate : AVSpeechUtteranceDefaultSpeechRate
        utterance.pitchMultiplier = 1.05   // a touch brighter, friendlier for a young child
        synthesizer.stopSpeaking(at: .immediate)
        isPlaying = true
        synthesizer.speak(utterance)
    }

    /// Play a recorded clip, optionally slowed via the player's rate.
    private func playClip(_ filename: String, slow: Bool) {
        activate(.playback)
        guard let p = try? AVAudioPlayer(contentsOf: store.url(for: filename)) else { return }
        p.delegate = self
        p.enableRate = true
        p.rate = slow ? Self.slowClipRate : 1.0
        player = p
        isPlaying = true
        p.play()
    }

    /// Stop any current speech or playback.
    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        player?.stop()
        player = nil
        isPlaying = false
    }

    private func activate(_ category: AVAudioSession.Category) {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(category, mode: .default, options: [.duckOthers])
        try? session.setActive(true)
    }

    private static let preferredVoice: AVSpeechSynthesisVoice? = {
        if let au = AVSpeechSynthesisVoice(language: "en-AU") { return au }
        return AVSpeechSynthesisVoice(language: AVSpeechSynthesisVoice.currentLanguageCode())
    }()

    // MARK: - Delegates

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        isPlaying = false
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        isPlaying = false
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
    }
}
