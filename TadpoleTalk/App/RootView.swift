import SwiftUI
import SwiftData

/// Decides what to show: the one-time disclaimer, then first-run onboarding to create the
/// child profile, then the main app. A non-blocking save-failure banner sits over it all.
struct RootView: View {
    @Environment(SaveStatus.self) private var saveStatus
    @Environment(PersistenceController.self) private var persistence
    @Environment(\.modelContext) private var context
    @Query(sort: \Child.createdAt) private var children: [Child]

    @AppStorage("hasAcceptedDisclaimer") private var hasAcceptedDisclaimer = false

    // Skip the splash under UI tests (`-localStore`) so screenshot/flow tests aren't delayed.
    @State private var showSplash = !ProcessInfo.processInfo.arguments.contains("-localStore")

    var body: some View {
        Group {
            if !hasAcceptedDisclaimer {
                DisclaimerView()
            } else if let child = children.first {
                MainView(child: child)
            } else {
                OnboardingView()
            }
        }
        .overlay(alignment: .top) {
            if saveStatus.lastFailure != nil {
                SaveFailureBanner { saveStatus.clear() }
            }
        }
        .animation(.spring(duration: 0.3), value: saveStatus.lastFailure)
        .task {
            // Skip against a throwaway store: with no words in it, the recordings sweep would
            // wipe real clips on the device, and it could race files a test is writing.
            guard !persistence.isInMemory else { return }
            await LaunchMaintenance.run(in: context)
        }
        .overlay {
            if showSplash {
                SplashView()
                    .transition(.opacity)
                    .task {
                        try? await Task.sleep(for: .seconds(1.5))
                        withAnimation(.easeInOut(duration: 0.4)) { showSplash = false }
                    }
            }
        }
    }
}

/// One non-blocking banner for the whole app, shown when a save fails.
private struct SaveFailureBanner: View {
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: Theme.sp3) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.white)
            Text("Couldn't save — your last change may not have been recorded. Please try again.")
                .font(.subheadline).foregroundStyle(.white)
            Spacer(minLength: 0)
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill").foregroundStyle(.white.opacity(0.85))
            }
            .accessibilityLabel("Dismiss")
        }
        .padding(Theme.sp4)
        .background(Theme.red, in: RoundedRectangle(cornerRadius: Theme.cornerSm))
        .padding(.horizontal, Theme.sp4)
        .padding(.top, Theme.sp2)
        .shadow(color: .black.opacity(0.15), radius: 8, y: 3)
        .transition(.move(edge: .top).combined(with: .opacity))
        .accessibilityElement(children: .combine)
        .task { try? await Task.sleep(for: .seconds(6)); onDismiss() }
    }
}
