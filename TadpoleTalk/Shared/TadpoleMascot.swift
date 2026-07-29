import SwiftUI

/// The Tadpole Talk mascot, drawn entirely with SwiftUI shapes (no bundled artwork) so it scales
/// crisply and recolours with the theme in light/dark. Geometry is ported 1:1 from
/// `design_handoff/assets/mascot.svg` (a 0–100 viewBox) and mapped onto `Theme` tokens — same
/// approach as the rest of the app's native SwiftUI artwork.
struct TadpoleMascot: View {
    var body: some View {
        Canvas { ctx, size in
            // Work in the SVG's 0–100 space, then scale to the view.
            let s = min(size.width, size.height) / 100
            func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * s, y: y * s) }
            func circle(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat) -> Path {
                Path(ellipseIn: CGRect(x: (cx - r) * s, y: (cy - r) * s, width: 2 * r * s, height: 2 * r * s))
            }

            let body = Theme.brandInk          // #235C90
            let belly = Theme.brand.opacity(0.18)   // #EAF6FF soft pond highlight
            let cheek = Theme.accent.opacity(0.55)  // #F4A24A @0.55
            let eyeWhite = Theme.card          // #FFFFFF
            let ink = Theme.label              // #16344E pupil / mouth

            // Tail: path M55 47 C70 35 80 31 92 23 C88 38 93 49 84 59 C76 66 63 63 56 58 Z
            var tail = Path()
            tail.move(to: p(55, 47))
            tail.addCurve(to: p(92, 23), control1: p(70, 35), control2: p(80, 31))
            tail.addCurve(to: p(84, 59), control1: p(88, 38), control2: p(93, 49))
            tail.addCurve(to: p(56, 58), control1: p(76, 66), control2: p(63, 63))
            tail.closeSubpath()
            ctx.fill(tail, with: .color(body))

            // Head: circle 44,55 r22
            ctx.fill(circle(44, 55, 22), with: .color(body))

            // Belly: ellipse 39,63 rx13.5 ry10.5
            let belRect = CGRect(x: (39 - 13.5) * s, y: (63 - 10.5) * s, width: 27 * s, height: 21 * s)
            ctx.fill(Path(ellipseIn: belRect), with: .color(belly))

            // Cheek: circle 29,59 r4.2
            ctx.fill(circle(29, 59, 4.2), with: .color(cheek))

            // Eye white: circle 40.5,49 r7.6
            ctx.fill(circle(40.5, 49, 7.6), with: .color(eyeWhite))
            // Pupil: circle 43,50 r3.7
            ctx.fill(circle(43, 50, 3.7), with: .color(ink))
            // Catchlight: circle 41.3,47.6 r1.5
            ctx.fill(circle(41.3, 47.6, 1.5), with: .color(.white))

            // Smile: path M31 61 Q39 68 47 60
            var smile = Path()
            smile.move(to: p(31, 61))
            smile.addQuadCurve(to: p(47, 60), control: p(39, 68))
            ctx.stroke(smile, with: .color(ink), style: StrokeStyle(lineWidth: 2.4 * s, lineCap: .round))
        }
        .accessibilityHidden(true)
    }
}

#Preview {
    HStack(spacing: 24) {
        TadpoleMascot().frame(width: 120, height: 120)
        TadpoleMascot().frame(width: 64, height: 64)
    }
    .padding()
    .background(Theme.bg)
}
