import Foundation
import AVFoundation

/// Stores and serves parent-recorded model clips. Recordings are small AAC `.m4a` files
/// kept in a dedicated folder under Application Support — on-device only, never uploaded,
/// in keeping with the app's privacy promise. Files are keyed by a caller-supplied name
/// (we use the target's UUID) so a clip survives edits to the word text.
struct AudioStore {
    static let shared = AudioStore()

    /// Folder that holds all recorded clips, created on first use.
    private var directory: URL {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent("Recordings", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// The file URL for a stored clip name (e.g. "<uuid>.m4a").
    func url(for filename: String) -> URL {
        directory.appendingPathComponent(filename)
    }

    /// The conventional filename for a target id.
    func filename(for id: UUID) -> String { "\(id.uuidString).m4a" }

    /// Whether a clip with this filename exists on disk.
    func exists(_ filename: String?) -> Bool {
        guard let filename, !filename.isEmpty else { return false }
        return FileManager.default.fileExists(atPath: url(for: filename).path)
    }

    /// Delete a stored clip, ignoring a missing file.
    func delete(_ filename: String?) {
        guard let filename, !filename.isEmpty else { return }
        try? FileManager.default.removeItem(at: url(for: filename))
    }
}

/// Records a single short model clip with `AVAudioRecorder`. A thin `@Observable` wrapper so
/// a SwiftUI control can show a live recording state and hand back the saved filename.
@Observable
final class ClipRecorder: NSObject, AVAudioRecorderDelegate {
    private(set) var isRecording = false
    private var recorder: AVAudioRecorder?
    private let store = AudioStore.shared

    /// Ask for microphone permission. Returns whether it was granted.
    func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    /// Begin recording into `filename`, overwriting any existing clip there. Returns false
    /// if the session or recorder couldn't be started.
    @discardableResult
    func start(filename: String) -> Bool {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
        } catch {
            return false
        }
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
        ]
        store.delete(filename)
        guard let rec = try? AVAudioRecorder(url: store.url(for: filename), settings: settings) else {
            return false
        }
        rec.delegate = self
        recorder = rec
        guard rec.record() else { return false }
        isRecording = true
        return true
    }

    /// Stop recording. The clip is left on disk under the filename passed to `start`.
    func stop() {
        recorder?.stop()
        recorder = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        isRecording = false
    }
}
