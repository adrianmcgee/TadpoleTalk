import SwiftUI

/// The grown-up corner: a plain-language explainer of Childhood Apraxia of Speech, the
/// handful of practice principles the whole app is built on, trusted external links, and
/// the disclaimer. External links live here, behind the adult-facing screen.
struct LearnView: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(Self.articles) { article in
                        NavigationLink {
                            ArticleView(article: article)
                        } label: {
                            Label(article.title, systemImage: article.symbol)
                        }
                    }
                }

                Section("Trusted organisations") {
                    link("Apraxia Kids", "https://www.apraxia-kids.org")
                    link("Child Apraxia Treatment (Once Upon a Time Foundation)", "https://childapraxiatreatment.org")
                    link("Key Word Sign Australia", "https://www.scopeaust.org.au/services/key-word-sign")
                }

                Section("More caregiver guidance") {
                    link("Positive home practice", "https://childapraxiatreatment.org/home-practice/")
                    link("Reducing communication frustration",
                         "https://childapraxiatreatment.org/how-to-decrease-frustration/")
                }

                Section {
                    NavigationLink {
                        ArticleView(article: Self.disclaimer)
                    } label: {
                        Label("About & disclaimer", systemImage: "info.circle")
                    }
                } footer: {
                    Text("Tadpole Talk supports therapy directed by your speech pathologist. "
                         + "It does not diagnose or replace professional care.")
                }
            }
            .navigationTitle("Learn")
        }
    }

    private func link(_ title: String, _ urlString: String) -> some View {
        Group {
            if let url = URL(string: urlString) {
                Link(destination: url) {
                    HStack {
                        Text(title).foregroundStyle(Theme.label)
                        Spacer()
                        Image(systemName: "arrow.up.right.square").foregroundStyle(Theme.label3)
                    }
                }
            }
        }
    }
}

/// A short piece of original, parent-friendly guidance.
struct Article: Identifiable {
    let id = UUID()
    let title: String
    let symbol: String
    let body: [String]   // paragraphs
}

private struct ArticleView: View {
    let article: Article

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.sp4) {
                Text(article.title).font(.title.bold()).foregroundStyle(Theme.label)
                ForEach(article.body, id: \.self) { para in
                    Text(para).font(.body).foregroundStyle(Theme.label2)
                }
            }
            .frame(maxWidth: Theme.contentMaxWidth)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.sp4)
        }
        .background(Theme.bg.ignoresSafeArea())
        .navigationTitle(article.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

extension LearnView {
    static let articles: [Article] = [
        Article(
            title: "What is apraxia of speech?",
            symbol: "questionmark.circle.fill",
            body: [
                "Childhood Apraxia of Speech (CAS) is a motor speech difference. Your child knows exactly what they want to say "
                    + "— but the brain has trouble planning and co-ordinating the precise mouth movements to say it.",
                "That's why the same word can come out differently each time, and why longer or more complex words are harder. "
                    + "It is not a problem with muscles, intelligence, or wanting to talk.",
                "CAS responds best to frequent, focused practice of speech movements — which is exactly what your weekly sessions "
                    + "and short home practice are building."
            ]
        ),
        Article(
            title: "How to practise well at home",
            symbol: "checklist",
            body: [
                "Choose a moment when your child is calm enough, able to look and listen, and willing to have a go. "
                    + "If they are tired, upset, or resisting, it is okay to try later.",
                "Little and often beats long and rare. A few minutes at a time gives you a better chance of keeping practice "
                    + "focused and successful.",
                "Aim for success, not volume. A handful of good attempts is worth more than many wrong ones "
                    + "— getting it right is what trains the movement. After a couple of difficult tries, add help, model the word, "
                    + "or move on positively.",
                "Start with enough help for success: say the word together or let your child try just after your model. "
                    + "Fade that help as the movement becomes easier.",
                "Acknowledge every form of communication, including speech, signs, gestures, pictures, or a device. "
                    + "Feeling heard takes pressure off speech practice.",
                "Follow your speech pathologist's targets and cueing advice. If a target remains consistently difficult, "
                    + "pause it and ask whether it should be made easier or changed."
            ]
        ),
        Article(
            title: "Signing and speech together",
            symbol: "hands.sparkles.fill",
            body: [
                "Key Word Sign is a bridge to speech, not a replacement for it. Always say the word as you sign it.",
                "Giving your child a reliable way to be understood reduces frustration and actually supports talking "
                    + "— it takes the pressure off while the spoken words develop.",
                "As speech comes, the signs naturally fall away. There's no rush either way."
            ]
        )
    ]

    static let disclaimer = Article(
        title: "About & disclaimer",
        symbol: "info.circle",
        body: [
            "Tadpole Talk is a home-practice companion for families of children with Childhood Apraxia of Speech. "
                + "It is designed to be used alongside therapy directed by a qualified speech pathologist.",
            "It does not diagnose, assess, or treat any condition, and it is not a substitute for professional advice. "
                + "Always check new targets and techniques with your speech pathologist.",
            "Your privacy matters: everything you enter stays on this device. There is no account, no tracking, and nothing is uploaded."
        ]
    )
}
