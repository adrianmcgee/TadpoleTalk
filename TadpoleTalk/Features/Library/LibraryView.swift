import SwiftUI

/// Reference library: a quick place to look up how a sound is made or how to make a Key
/// Word Sign between appointments. Two segments in one tab so it stays a single mental
/// "where do I look things up" destination.
struct LibraryView: View {
    enum Segment: String, CaseIterable, Identifiable {
        case sounds = "Sounds"
        case signs = "Signs"
        var id: String { rawValue }
        var a11yID: String { self == .sounds ? A11y.tabSounds : A11y.tabSigns }
    }

    @State private var segment: Segment = .sounds

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Library", selection: $segment) {
                    ForEach(Segment.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(Theme.sp4)

                switch segment {
                case .sounds: PhonemeLibraryView()
                case .signs: SignLibraryView()
                }
            }
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle("Library")
        }
    }
}

/// Grid of speech sounds. Each sound uses a neutral IPA badge until reviewed
/// instructional illustrations are available.
struct PhonemeLibraryView: View {
    private let phonemes = ContentStore.shared.phonemes

    var body: some View {
        ScrollView {
            LazyVGrid(columns: Theme.adaptiveColumns(min: 150), spacing: Theme.sp3) {
                ForEach(phonemes) { p in
                    NavigationLink {
                        PhonemeDetailView(phoneme: p)
                    } label: {
                        VStack(spacing: Theme.sp2) {
                            Text("/\(p.ipa)/")
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundStyle(Theme.brandInk)
                                .frame(maxWidth: .infinity, minHeight: 84)
                                .background(
                                    Theme.brand.opacity(0.10),
                                    in: RoundedRectangle(cornerRadius: Theme.cornerSm)
                                )
                            Text(p.label).font(.subheadline.weight(.medium))
                                .foregroundStyle(Theme.label)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(Theme.sp3)
                        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.corner))
                    }
                    .accessibilityLabel("Sound \(p.label)")
                }
            }
            .frame(maxWidth: Theme.playMaxWidth)
            .frame(maxWidth: .infinity)
            .padding(Theme.sp4)
        }
    }
}

/// Key Word Sign reference, grouped by everyday category.
struct SignLibraryView: View {
    private let groups = ContentStore.shared.signsByCategory

    var body: some View {
        List {
            Section {
                Text("Signs are a bridge to speech — use them alongside the spoken word, never instead of it.")
                    .font(.footnote).foregroundStyle(Theme.label2)
            }
            ForEach(groups, id: \.category) { group in
                Section(group.category) {
                    ForEach(group.signs) { sign in
                        NavigationLink {
                            SignDetailView(sign: sign)
                        } label: {
                            Label(sign.word, systemImage: sign.symbol)
                        }
                    }
                }
            }
        }
    }
}
