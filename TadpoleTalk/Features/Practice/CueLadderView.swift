import SwiftUI

/// Interactive modelling-support steps. The caregiver stays in control because their
/// speech pathologist knows which cues are appropriate for their child.
struct CueLadderView: View {
    let level: PracticeSupportLevel
    let onSelect: (PracticeSupportLevel) -> Void
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.sp2) {
            Button {
                withAnimation(.easeInOut) { expanded.toggle() }
            } label: {
                HStack {
                    Image(systemName: "stairs")
                    Text("How much help?").font(.subheadline.weight(.medium))
                    Spacer()
                    Text(level.title).font(.caption.weight(.semibold))
                    Image(systemName: expanded ? "chevron.up" : "chevron.down").font(.caption)
                }
                .foregroundStyle(Theme.brandInk)
            }

            if expanded {
                VStack(alignment: .leading, spacing: Theme.sp2) {
                    ForEach(PracticeSupportLevel.allCases) { option in
                        Button {
                            onSelect(option)
                        } label: {
                            HStack(alignment: .top, spacing: Theme.sp2) {
                                Image(systemName: option == level ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(option == level ? Theme.brand : Theme.label3)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(option.title)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(Theme.label)
                                    Text(option.detail)
                                        .font(.caption)
                                        .foregroundStyle(Theme.label2)
                                }
                                Spacer(minLength: 0)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier(A11y.practiceSupport(option))
                    }
                    Text("Fade help as success grows. Only use touch cues your speech pathologist has shown you.")
                        .font(.caption2)
                        .foregroundStyle(Theme.label3)
                        .padding(.top, Theme.sp1)
                }
                .padding(.top, Theme.sp1)
            }
        }
        .padding(Theme.sp3)
        .background(Theme.brand.opacity(0.10), in: RoundedRectangle(cornerRadius: Theme.cornerSm))
        .accessibilityElement(children: .contain)
    }
}
