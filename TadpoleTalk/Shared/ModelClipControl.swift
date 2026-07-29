import SwiftUI

/// A small record / preview / delete control for a parent's own spoken model of a word.
/// Writes the clip to `AudioStore` keyed by `clipID` and reflects the saved filename back
/// through the `filename` binding. Reusable — the target editor uses it now, and a sound
/// detail screen could host it later.
struct ModelClipControl: View {
    /// Stable key for the clip on disk (the target's id).
    let clipID: UUID
    /// The saved filename, nil when no clip exists. Bound so the parent's edit persists.
    @Binding var filename: String?
    /// Spoken when previewing — falls back to TTS if somehow the file went missing.
    let previewText: String

    @State private var recorder = ClipRecorder()
    @State private var player = SpeechModelPlayer()
    @State private var deniedPermission = false

    private let store = AudioStore.shared
    private var hasClip: Bool { store.exists(filename) }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.sp2) {
            HStack(spacing: Theme.sp3) {
                recordButton
                if hasClip {
                    previewButton
                    deleteButton
                }
            }
            Text(hasClip
                 ? "Your child will hear your voice for this word."
                 : "Optional — record yourself saying the word in a clear, friendly voice.")
                .font(.caption).foregroundStyle(Theme.label3)
            if deniedPermission {
                Text("Microphone access is off. Turn it on in Settings to record.")
                    .font(.caption).foregroundStyle(Theme.red)
            }
        }
    }

    private var recordButton: some View {
        Button {
            recorder.isRecording ? stopRecording() : startRecording()
        } label: {
            Label(recorder.isRecording ? "Stop" : (hasClip ? "Re-record" : "Record"),
                  systemImage: recorder.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(recorder.isRecording ? Theme.red : Theme.brandInk)
        }
        .accessibilityIdentifier(A11y.targetRecordModel)
    }

    private var previewButton: some View {
        Button {
            player.play(text: previewText, recordingFilename: filename)
        } label: {
            Label("Play", systemImage: "play.circle.fill")
                .font(.subheadline.weight(.medium)).foregroundStyle(Theme.brandInk)
        }
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            store.delete(filename)
            filename = nil
        } label: {
            Label("Delete", systemImage: "trash")
                .font(.subheadline.weight(.medium)).foregroundStyle(Theme.red)
        }
    }

    private func startRecording() {
        Task {
            let granted = await recorder.requestPermission()
            guard granted else { deniedPermission = true; return }
            deniedPermission = false
            let name = store.filename(for: clipID)
            if recorder.start(filename: name) { filename = name }
        }
    }

    private func stopRecording() {
        recorder.stop()
        // Confirm the file landed; clear the binding if recording produced nothing.
        if !store.exists(filename) { filename = nil }
    }
}
