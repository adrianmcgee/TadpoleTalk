import SwiftUI
import SwiftData

/// Add or edit a practice word: its text, syllable shape, the sounds it focuses on, an
/// optional note from the SLP, and whether it's in this week's set.
struct TargetEditorView: View {
    let child: Child
    var existing: WordTarget?
    let onClose: () -> Void

    @Environment(\.modelContext) private var context
    @State private var vm = TargetsViewModel()

    @State private var text: String = ""
    @State private var shape: SyllableShape = .cv
    @State private var notes: String = ""
    @State private var activeThisWeek: Bool = true
    @State private var phonemeIDs: Set<String> = []
    @State private var carrierPreset: CarrierPhrasePreset = .none
    @State private var customPhrase: String = ""
    @State private var audioFilename: String?
    /// Stable id for this target so a recorded clip keys to it before the first save.
    @State private var clipID = UUID()

    private let allPhonemes = ContentStore.shared.phonemes

    /// The carrier-phrase template to persist, resolved from the picker + custom field.
    private var resolvedCarrierPhrase: String? {
        switch carrierPreset {
        case .none:
            return nil
        case .custom:
            let trimmed = customPhrase.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        default:
            return carrierPreset.template
        }
    }

    /// A live preview of what the child will see/hear at phrase level.
    private var phrasePreview: String {
        let word = text.trimmingCharacters(in: .whitespaces).isEmpty ? "word" : text
        guard let template = resolvedCarrierPhrase else { return word }
        return template.contains("___")
            ? template.replacingOccurrences(of: "___", with: word)
            : "\(template) \(word)"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Word") {
                    TextField("e.g. more", text: $text)
                        .textInputAutocapitalization(.never)
                        .accessibilityIdentifier(A11y.targetText)
                }
                Section("Sound shape") {
                    Picker("Shape", selection: $shape) {
                        ForEach(SyllableShape.allCases) { s in
                            Text("\(s.code) · \(s.example)").tag(s)
                        }
                    }
                    .accessibilityIdentifier(A11y.targetShape)
                }
                Section("Focus sounds (optional)") {
                    ForEach(allPhonemes) { p in
                        Button {
                            if phonemeIDs.contains(p.id) { phonemeIDs.remove(p.id) }
                            else { phonemeIDs.insert(p.id) }
                        } label: {
                            HStack {
                                Text(p.label).foregroundStyle(Theme.label)
                                Spacer()
                                if phonemeIDs.contains(p.id) {
                                    Image(systemName: "checkmark").foregroundStyle(Theme.brand)
                                }
                            }
                        }
                        .accessibilityAddTraits(phonemeIDs.contains(p.id) ? [.isSelected] : [])
                    }
                }
                Section {
                    Picker("Phrase", selection: $carrierPreset) {
                        ForEach(CarrierPhrasePreset.allCases) { preset in
                            Text(preset.title).tag(preset)
                        }
                    }
                    .accessibilityIdentifier(A11y.targetCarrier)
                    if carrierPreset == .custom {
                        TextField("e.g. I want ___", text: $customPhrase)
                            .textInputAutocapitalization(.never)
                    }
                    if resolvedCarrierPhrase != nil {
                        LabeledContent("Practises as", value: phrasePreview)
                    }
                } header: {
                    Text("Carrier phrase (optional)")
                } footer: {
                    Text("Drops the word into a short phrase to step up from word to sentence. "
                         + "Use ___ for where the word goes.")
                }

                Section {
                    ModelClipControl(clipID: clipID, filename: $audioFilename,
                                     previewText: text.isEmpty ? "word" : text)
                } header: {
                    Text("Model voice (optional)")
                }

                Section("Note from your therapist (optional)") {
                    TextField("e.g. focus on the final sound", text: $notes, axis: .vertical)
                }
                Section {
                    Toggle("Practise this week", isOn: $activeThisWeek)
                        .accessibilityIdentifier(A11y.targetActive)
                }
            }
            .navigationTitle(existing == nil ? "New word" : "Edit word")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onClose)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
                        .accessibilityIdentifier(A11y.targetSave)
                }
            }
            .onAppear(perform: loadExisting)
        }
    }

    private func loadExisting() {
        guard let existing else { return }
        text = existing.text
        shape = existing.shape
        notes = existing.notes
        activeThisWeek = existing.isActiveThisWeek
        phonemeIDs = Set(existing.phonemeIDs)
        clipID = existing.id
        audioFilename = existing.audioFilename
        carrierPreset = CarrierPhrasePreset.matching(existing.carrierPhrase)
        if carrierPreset == .custom { customPhrase = existing.carrierPhrase ?? "" }
    }

    private func save() {
        if let existing {
            existing.text = text.trimmingCharacters(in: .whitespaces)
            existing.shape = shape
            existing.notes = notes
            existing.isActiveThisWeek = activeThisWeek
            existing.phonemeIDs = Array(phonemeIDs)
            existing.carrierPhrase = resolvedCarrierPhrase
            existing.audioFilename = audioFilename
            vm.save(in: context)
        } else {
            vm.add(text: text, shape: shape, phonemeIDs: Array(phonemeIDs),
                   notes: notes, activeThisWeek: activeThisWeek,
                   carrierPhrase: resolvedCarrierPhrase, audioFilename: audioFilename,
                   id: clipID, to: child, in: context)
        }
        onClose()
    }
}
