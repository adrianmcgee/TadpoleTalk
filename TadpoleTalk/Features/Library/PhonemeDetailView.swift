import SwiftUI

/// How to make one speech sound using plain-language guidance for place, manner, voicing,
/// modelling, and an optional hand cue.
struct PhonemeDetailView: View {
    let phoneme: Phoneme

    @State private var showingVideo = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.sp5) {
                VStack(alignment: .leading, spacing: Theme.sp2) {
                    Text(phoneme.label).font(.title2.bold()).foregroundStyle(Theme.label)
                    Text("Sound: /\(phoneme.ipa)/  ·  \(phoneme.kind == .vowel ? "Vowel" : "Consonant")")
                        .font(.subheadline).foregroundStyle(Theme.label2)
                }

                if let url = phoneme.videoURL {
                    WatchButton { showingVideo = true }
                        .sheet(isPresented: $showingVideo) {
                            VideoPlayerSheet(title: phoneme.label, videoURL: url)
                        }
                }

                VStack(alignment: .leading, spacing: Theme.sp3) {
                    fact("Where", phoneme.place, "mappin.circle.fill")
                    fact("How", phoneme.manner, "waveform")
                    fact("Voice", phoneme.voicing.label, "speaker.wave.2.fill")
                }
                .padding(Theme.sp4)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.corner))

                if let cue = phoneme.handCue {
                    handCueCard(cue)
                }

                calloutCard

                VStack(alignment: .leading, spacing: Theme.sp2) {
                    Text("Example words").font(.headline).foregroundStyle(Theme.label)
                    HStack {
                        ForEach(phoneme.exampleWords, id: \.self) { word in
                            Text(word)
                                .font(.subheadline.weight(.medium))
                                .padding(.horizontal, Theme.sp3).padding(.vertical, Theme.sp2)
                                .background(Theme.brand.opacity(0.12), in: Capsule())
                                .foregroundStyle(Theme.brandInk)
                        }
                    }
                }
            }
            .frame(maxWidth: Theme.contentMaxWidth)
            .frame(maxWidth: .infinity)
            .padding(Theme.sp4)
        }
        .background(Theme.bg.ignoresSafeArea())
        .navigationTitle(phoneme.label)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var calloutCard: some View {
        VStack(alignment: .leading, spacing: Theme.sp3) {
            HStack(spacing: Theme.sp2) {
                Image(systemName: "hand.point.up.left.fill").foregroundStyle(Theme.accent)
                Text("Show your child").font(.headline).foregroundStyle(Theme.label)
            }
            HowToSteps(steps: phoneme.howToSteps)
        }
        .padding(Theme.sp4)
        .background(Theme.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: Theme.corner))
    }

    /// An original, plain-language hand cue a parent can make alongside the sound — not
    /// licensed Cued Articulation artwork. Shown only when the phoneme has a `handCue`.
    private func handCueCard(_ cue: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.sp3) {
            HStack(spacing: Theme.sp2) {
                Image(systemName: "hand.raised.fingers.spread.fill").foregroundStyle(Theme.brand)
                Text("Hand cue").font(.headline).foregroundStyle(Theme.label)
            }
            Text(cue).font(.subheadline).foregroundStyle(Theme.label2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(Theme.sp4)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.corner))
        .accessibilityElement(children: .combine)
    }

    private func fact(_ title: String, _ value: String, _ symbol: String) -> some View {
        HStack(alignment: .top, spacing: Theme.sp3) {
            Image(systemName: symbol).foregroundStyle(Theme.brand).frame(width: 24)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.caption.weight(.semibold)).foregroundStyle(Theme.label3)
                Text(value).font(.subheadline).foregroundStyle(Theme.label)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// How to make one Key Word Sign, in plain language.
struct SignDetailView: View {
    let sign: SignEntry

    @State private var showingVideo = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.sp5) {
                VStack(spacing: Theme.sp2) {
                    Image(systemName: sign.symbol)
                        .font(.system(size: 64))
                        .foregroundStyle(Theme.brand)
                        .frame(maxWidth: .infinity, minHeight: 140)
                        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.corner))
                        // A hand badge signals this is a sign, not the gesture itself.
                        .overlay(alignment: .topTrailing) {
                            Image(systemName: "hand.raised.fill")
                                .font(.subheadline)
                                .foregroundStyle(Theme.brand)
                                .padding(Theme.sp2)
                                .background(Theme.brand.opacity(0.12), in: Circle())
                                .padding(Theme.sp3)
                        }
                    Text("A picture reminder of the word — copy the hand shape from the steps below.")
                        .font(.footnote).foregroundStyle(Theme.label2)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Picture reminder for \(sign.word). Follow the steps below for the hand shape.")

                Text(sign.word).font(.title2.bold()).foregroundStyle(Theme.label)

                if let url = sign.videoURL {
                    WatchButton { showingVideo = true }
                        .sheet(isPresented: $showingVideo) {
                            VideoPlayerSheet(title: sign.word, videoURL: url)
                        }
                }

                VStack(alignment: .leading, spacing: Theme.sp3) {
                    HStack(spacing: Theme.sp2) {
                        Image(systemName: "hand.raised.fill").foregroundStyle(Theme.brand)
                        Text("How to sign it").font(.headline).foregroundStyle(Theme.label)
                    }
                    HowToSteps(steps: sign.howToSteps)
                    Divider().padding(.vertical, Theme.sp1)
                    fact("When to use it", sign.when, "clock.fill")
                }
                .padding(Theme.sp4)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.corner))

                Text("Always say the word as you sign it.")
                    .font(.footnote).foregroundStyle(Theme.label2)
            }
            .frame(maxWidth: Theme.contentMaxWidth)
            .frame(maxWidth: .infinity)
            .padding(Theme.sp4)
        }
        .background(Theme.bg.ignoresSafeArea())
        .navigationTitle(sign.word)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func fact(_ title: String, _ value: String, _ symbol: String) -> some View {
        HStack(alignment: .top, spacing: Theme.sp3) {
            Image(systemName: symbol).foregroundStyle(Theme.brand).frame(width: 24)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.caption.weight(.semibold)).foregroundStyle(Theme.label3)
                Text(value).font(.subheadline).foregroundStyle(Theme.label)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// A numbered list of short "do this" steps, shared by sound and sign detail screens.
/// A single step renders as one plain line; two or more get numbered badges.
struct HowToSteps: View {
    let steps: [String]

    var body: some View {
        if steps.count <= 1 {
            Text(steps.first ?? "").font(.subheadline).foregroundStyle(Theme.label2)
        } else {
            VStack(alignment: .leading, spacing: Theme.sp3) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: Theme.sp3) {
                        Text("\(index + 1)")
                            .font(.caption.bold()).foregroundStyle(Theme.onColor)
                            .frame(width: 22, height: 22)
                            .background(Theme.accent, in: Circle())
                        Text(step).font(.subheadline).foregroundStyle(Theme.label)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}

/// A "Watch how" button shown only when a sound or sign has a demo clip.
struct WatchButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.sp2) {
                Image(systemName: "play.circle.fill")
                Text("Watch how").font(.headline)
            }
            .frame(maxWidth: .infinity, minHeight: Theme.btnHeight)
        }
        .buttonStyle(.borderedProminent)
    }
}
