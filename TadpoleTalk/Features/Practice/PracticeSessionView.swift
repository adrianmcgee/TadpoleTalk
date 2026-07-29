import SwiftUI
import SwiftData

/// The core of the app: a short, parent-led practice session. One word at a time, with a
/// reminder of how to make it, a cueing-ladder prompt, three simple ways to log how it
/// went, and a celebration when the child gets it. Ends on a warm summary.
struct PracticeSessionView: View {
    let child: Child
    let targets: [WordTarget]
    /// Practice settings, supplied by the caller (read from Settings on the home screen).
    var order: PracticeOrder = .blocked
    var repGoal: Int = 5
    var autoAdvance: Bool = false
    var autoPlayModel: Bool = false

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var vm: PracticeSessionViewModel?
    @State private var howToPhoneme: Phoneme?
    @State private var player = SpeechModelPlayer()
    @State private var readinessConfirmed = false
    /// When on, words are shown and spoken inside their carrier phrase.
    @State private var phraseLevel = false
    /// True when at least one word in the set carries a phrase — gates the phrase toggle.
    private var anyPhrases: Bool {
        targets.contains { ($0.carrierPhrase?.isEmpty == false) }
    }

    var body: some View {
        Group {
            if !readinessConfirmed {
                PracticeReadinessView(
                    onStart: startSession,
                    onTryLater: { dismiss() }
                )
            } else if let vm {
                if vm.finished {
                    SessionSummaryView(vm: vm) { dismiss() }
                } else {
                    sessionBody(vm)
                }
            } else {
                Color.clear
            }
        }
    }

    /// Confirming readiness is the point where a persisted session begins. Choosing
    /// "Try later" therefore leaves no empty history behind.
    private func startSession() {
        let newVM = PracticeSessionViewModel(
            child: child,
            targets: targets,
            context: context,
            order: order,
            repGoal: repGoal,
            autoAdvance: autoAdvance
        )
        vm = newVM
        readinessConfirmed = true
        if autoPlayModel { hear(newVM, slow: false) }
    }

    private func sessionBody(_ vm: PracticeSessionViewModel) -> some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack(spacing: Theme.sp4) {
                topBar(vm)
                ScrollView {
                    VStack(spacing: Theme.sp4) {
                        wordCard(vm)
                        CueLadderView(level: vm.supportLevel, onSelect: vm.selectSupport)
                        if vm.isShowingDifficultyIntervention {
                            difficultyIntervention(vm)
                        } else {
                            ratingButtons(vm)
                        }
                    }
                    .frame(maxWidth: Theme.contentMaxWidth)
                    .frame(maxWidth: .infinity)
                    .padding(Theme.sp4)
                }
                advanceBar(vm)
            }

            RewardBurst(trigger: Binding(
                get: { vm.celebrate },
                set: { vm.celebrate = $0 }
            ))
        }
        .sheet(item: $howToPhoneme) { phoneme in
            NavigationStack {
                PhonemeDetailView(phoneme: phoneme)
            }
        }
    }

    private func topBar(_ vm: PracticeSessionViewModel) -> some View {
        VStack(spacing: Theme.sp2) {
            HStack {
                Button { vm.finish() } label: {
                    Image(systemName: "xmark.circle.fill").font(.title2).foregroundStyle(Theme.label3)
                }
                .accessibilityLabel("End practice")
                Spacer()
                Text(vm.progressText).font(.subheadline.weight(.medium)).foregroundStyle(Theme.label2)
                Spacer()
                Label("\(vm.successCount)", systemImage: "star.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                    .accessibilityLabel("\(vm.successCount) great reps")
            }
            if anyPhrases {
                Toggle(isOn: $phraseLevel.animation(.easeInOut)) {
                    Label("Phrase level", systemImage: "text.bubble.fill")
                        .font(.subheadline.weight(.medium))
                }
                .toggleStyle(.button)
                .tint(Theme.brand)
                .accessibilityIdentifier(A11y.practicePhraseToggle)
            }
        }
        .padding(.horizontal, Theme.sp4)
        .padding(.top, Theme.sp4)
    }

    private func wordCard(_ vm: PracticeSessionViewModel) -> some View {
        VStack(spacing: Theme.sp3) {
            if let phoneme = vm.currentPhoneme() {
                Button {
                    howToPhoneme = phoneme
                } label: {
                    Label("How to make this sound", systemImage: "info.circle")
                        .font(.subheadline.weight(.medium))
                }
                .foregroundStyle(Theme.brandInk)
            }
            wordText(vm)
            hearButtons(vm)
            if let shape = vm.currentTarget?.shape {
                Text(shape.code).font(.caption.weight(.semibold))
                    .padding(.horizontal, Theme.sp2).padding(.vertical, 4)
                    .background(Theme.brand.opacity(0.14), in: Capsule())
                    .foregroundStyle(Theme.brandInk)
            }
            if let notes = vm.currentTarget?.notes, !notes.isEmpty {
                Text(notes).font(.subheadline).foregroundStyle(Theme.label2)
                    .multilineTextAlignment(.center)
            }
            goalLabel(vm)
        }
        .frame(maxWidth: .infinity)
        .padding(Theme.sp5)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.corner))
    }

    /// The big word — or, at phrase level, the carrier phrase with the target word emphasised.
    @ViewBuilder
    private func wordText(_ vm: PracticeSessionViewModel) -> some View {
        let target = vm.currentTarget
        let showPhrase = phraseLevel && (target?.carrierPhrase?.isEmpty == false)
        Group {
            if showPhrase, let target {
                phraseText(target)
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
            } else {
                Text(target?.text ?? "")
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.label)
            }
        }
        .minimumScaleFactor(0.5)
        .lineLimit(2)
        .accessibilityIdentifier("practice.word")
    }

    /// The phrase with the target word in full colour and the rest dimmed.
    private func phraseText(_ target: WordTarget) -> Text {
        let phrase = target.phraseText
        guard let range = phrase.range(of: target.text) else {
            return Text(phrase).foregroundStyle(Theme.label)
        }
        let before = String(phrase[phrase.startIndex..<range.lowerBound])
        let word = String(phrase[range])
        let after = String(phrase[range.upperBound...])
        return Text(before).foregroundStyle(Theme.label2)
            + Text(word).foregroundStyle(Theme.label)
            + Text(after).foregroundStyle(Theme.label2)
    }

    private func hearButtons(_ vm: PracticeSessionViewModel) -> some View {
        HStack(spacing: Theme.sp3) {
            Button { hear(vm, slow: false) } label: {
                Label("Hear it", systemImage: "speaker.wave.2.fill")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.bordered)
            .tint(Theme.brand)
            .accessibilityIdentifier(A11y.practiceHear)

            Button { hear(vm, slow: true) } label: {
                Label("Slow", systemImage: "tortoise.fill")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.bordered)
            .tint(Theme.brand)
            .accessibilityIdentifier(A11y.practiceHearSlow)
        }
    }

    @ViewBuilder
    private func goalLabel(_ vm: PracticeSessionViewModel) -> some View {
        HStack(spacing: Theme.sp2) {
            Image(systemName: vm.isCurrentComplete ? "checkmark.circle.fill" : "star.circle")
                .foregroundStyle(vm.isCurrentComplete ? Theme.correct : Theme.accent)
            Text(vm.goalText).font(.caption.weight(.medium)).foregroundStyle(Theme.label2)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(vm.currentSuccessReps) of \(vm.repGoal) good reps")
    }

    /// Speak the model: the carrier phrase (via TTS) at phrase level, otherwise the word —
    /// playing the parent's recording when they've attached one.
    private func hear(_ vm: PracticeSessionViewModel, slow: Bool) {
        guard let target = vm.currentTarget else { return }
        if phraseLevel, target.carrierPhrase?.isEmpty == false {
            player.speak(target.phraseText, slow: slow)
        } else {
            player.play(text: target.text, recordingFilename: target.audioFilename, slow: slow)
        }
    }

    private func ratingButtons(_ vm: PracticeSessionViewModel) -> some View {
        HStack(spacing: Theme.sp3) {
            ratingButton(.correct, A11y.practiceRatingCorrect, vm)
            ratingButton(.approx, A11y.practiceRatingApprox, vm)
            ratingButton(.tryAgain, A11y.practiceRatingTryAgain, vm)
        }
    }

    private func ratingButton(_ rating: TrialRating, _ id: String, _ vm: PracticeSessionViewModel) -> some View {
        Button {
            vm.log(rating)
            if vm.shouldAutoAdvance { autoAdvanceAfterCelebration(vm) }
        } label: {
            VStack(spacing: Theme.sp2) {
                Image(systemName: rating.symbol).font(.title)
                Text(rating.title).font(.subheadline.weight(.semibold))
            }
            .frame(maxWidth: .infinity, minHeight: Theme.bigButton)
            .foregroundStyle(rating.color)
            .background(rating.color.opacity(0.14), in: RoundedRectangle(cornerRadius: Theme.corner))
        }
        .accessibilityIdentifier(id)
    }

    private func difficultyIntervention(_ vm: PracticeSessionViewModel) -> some View {
        VStack(alignment: .leading, spacing: Theme.sp3) {
            Label("Good trying — let’s make this easier", systemImage: "heart.fill")
                .font(.headline)
                .foregroundStyle(Theme.brandInk)
            Text("A little more help or a fresh word keeps practice positive.")
                .font(.subheadline)
                .foregroundStyle(Theme.label2)

            Button {
                vm.resumeWithMoreSupport()
            } label: {
                Label(moreSupportTitle(vm), systemImage: "person.2.fill")
                    .frame(maxWidth: .infinity, minHeight: Theme.btnHeight)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier(A11y.practiceMoreSupport)

            Button {
                hear(vm, slow: true)
                vm.resumeAfterModel()
            } label: {
                Label("Hear it slowly, then try", systemImage: "tortoise.fill")
                    .frame(maxWidth: .infinity, minHeight: Theme.btnHeight)
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier(A11y.practiceModelAndRetry)

            Button {
                moveOnPositively(vm)
            } label: {
                Label(vm.canMoveToAnotherTarget ? "Move to another word" : "Finish positively",
                      systemImage: vm.canMoveToAnotherTarget ? "arrow.right" : "checkmark.circle")
                    .frame(maxWidth: .infinity, minHeight: Theme.btnHeight)
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier(A11y.practiceMoveOn)
        }
        .padding(Theme.sp4)
        .background(Theme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: Theme.corner))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(A11y.practiceIntervention)
    }

    private func moreSupportTitle(_ vm: PracticeSessionViewModel) -> String {
        vm.supportLevel == .together ? "Try together again" : "Try with more help"
    }

    private func advanceBar(_ vm: PracticeSessionViewModel) -> some View {
        HStack {
            if vm.showFinish {
                Button { vm.finish() } label: {
                    Text("Finish").font(.headline).frame(maxWidth: .infinity, minHeight: Theme.btnHeight)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier(A11y.practiceDone)
            } else {
                Button { goNext(vm) } label: {
                    HStack { Text("Next word"); Image(systemName: "arrow.right") }
                        .font(.headline).frame(maxWidth: .infinity, minHeight: Theme.btnHeight)
                }
                .buttonStyle(.borderedProminent)
                // Nudge the parent on once a word's goal is met.
                .tint(vm.isCurrentComplete ? Theme.correct : Theme.brand)
                .accessibilityIdentifier(A11y.practiceNext)
            }
        }
        .frame(maxWidth: Theme.contentMaxWidth)
        .frame(maxWidth: .infinity)
        .padding(Theme.sp4)
    }

    /// Advance to the next word and, if enabled, speak its model.
    private func goNext(_ vm: PracticeSessionViewModel) {
        vm.nextWord()
        if autoPlayModel { hear(vm, slow: false) }
    }

    private func moveOnPositively(_ vm: PracticeSessionViewModel) {
        vm.moveOnPositively()
        if !vm.finished && autoPlayModel { hear(vm, slow: false) }
    }

    /// After a word hits its goal, let the celebration play, then move on.
    private func autoAdvanceAfterCelebration(_ vm: PracticeSessionViewModel) {
        Task {
            try? await Task.sleep(for: .seconds(1.2))
            goNext(vm)
        }
    }
}

/// A no-pressure check before practice. It is guidance rather than a scored checklist and
/// is intentionally not stored as child data.
private struct PracticeReadinessView: View {
    let onStart: () -> Void
    let onTryLater: () -> Void

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            ScrollView {
                VStack(spacing: Theme.sp5) {
                    TadpoleMascot()
                        .frame(width: 112, height: 112)
                    VStack(spacing: Theme.sp2) {
                        Text("Is this a good moment?")
                            .font(.largeTitle.bold())
                            .foregroundStyle(Theme.label)
                            .multilineTextAlignment(.center)
                        Text("Practice works best when your child is calm enough, able to look and listen, and willing to have a go.")
                            .font(.body)
                            .foregroundStyle(Theme.label2)
                            .multilineTextAlignment(.center)
                    }

                    VStack(alignment: .leading, spacing: Theme.sp3) {
                        readinessLine("Calm enough", "heart.fill")
                        readinessLine("Ready to look and listen", "eye.fill")
                        readinessLine("Willing to try", "hand.thumbsup.fill")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Theme.sp4)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.corner))

                    VStack(spacing: Theme.sp3) {
                        Button(action: onStart) {
                            Label("Start now", systemImage: "play.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity, minHeight: Theme.btnHeight)
                        }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier(A11y.practiceReadinessStart)

                        Button("Try later", action: onTryLater)
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: Theme.btnHeight)
                            .buttonStyle(.bordered)
                            .accessibilityIdentifier(A11y.practiceReadinessLater)
                    }
                }
                .frame(maxWidth: Theme.contentMaxWidth)
                .frame(maxWidth: .infinity)
                .padding(Theme.sp5)
            }
        }
    }

    private func readinessLine(_ text: String, _ symbol: String) -> some View {
        Label(text, systemImage: symbol)
            .font(.body.weight(.medium))
            .foregroundStyle(Theme.label)
    }
}

/// Warm end-of-session screen — celebrate the effort, show the simple tally, get out.
private struct SessionSummaryView: View {
    let vm: PracticeSessionViewModel
    let onDone: () -> Void

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack(spacing: Theme.sp5) {
                TadpoleMascot()
                    .frame(width: 120, height: 120)
                Image(systemName: "star.circle.fill")
                    .font(.system(size: 84)).foregroundStyle(Theme.accent)
                Text("Great practising!").font(.largeTitle.bold()).foregroundStyle(Theme.label)
                Text(vm.summaryMessage).font(.title3).foregroundStyle(Theme.label2)
                    .multilineTextAlignment(.center)

                HStack(spacing: Theme.sp4) {
                    tally("\(vm.successCount)", "great reps", Theme.correct)
                    tally("\(vm.totalCount)", "brave tries", Theme.brand)
                }

                Button(action: onDone) {
                    Text("Done").font(.headline).frame(maxWidth: .infinity, minHeight: Theme.btnHeight)
                }
                .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: Theme.contentMaxWidth)
            .frame(maxWidth: .infinity)
            .padding(Theme.sp5)
        }
        .accessibilityIdentifier(A11y.practiceSummary)
    }

    private func tally(_ value: String, _ label: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 40, weight: .bold, design: .rounded)).foregroundStyle(color)
            Text(label).font(.caption).foregroundStyle(Theme.label2)
        }
        .frame(maxWidth: .infinity)
        .padding(Theme.sp4)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.corner))
        .accessibilityElement(children: .combine)
    }
}
