import SwiftUI

/// The moving scene behind the alien looks: green space with turning orbit rings, floating glowing
/// orbs, twinkling stars, a bobbing ringed planet and a passing saucer with a flickering beam.
///
/// Drawn by the app itself (no artwork, no video). It stands still with Reduce Motion, and pauses
/// when it isn't on screen: another tab, a pushed screen, or the app in the background.
struct AlienBackground: View {
    /// Darker and calmer, for text on top (the alien terminal).
    var dimmed = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.isActiveTab) private var isActiveTab
    @State private var onScreen = false

    var body: some View {
        let paused = reduceMotion || !onScreen || !isActiveTab || scenePhase != .active
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: paused)) { context in
            Canvas { ctx, size in
                // Reduce Motion: always the same still frame.
                let t = reduceMotion ? 3.0 : context.date.timeIntervalSinceReferenceDate
                draw(in: &ctx, size: size, t: t)
            }
        }
        .onAppear { onScreen = true }
        .onDisappear { onScreen = false }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    // MARK: - Drawing

    private static let ink = Color(red: 0.05, green: 0.16, blue: 0.06)

    private func draw(in ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let w = size.width, h = size.height
        let s = max(w, 1) / 390 // sizes are designed for a 390-point-wide phone

        // Sky.
        let sky: [Color] = dimmed
            ? [Color(red: 0.12, green: 0.35, blue: 0.07), Color(red: 0.04, green: 0.16, blue: 0.03), Color(red: 0.01, green: 0.06, blue: 0.01)]
            : [Color(red: 0.48, green: 0.91, blue: 0.31), Color(red: 0.22, green: 0.66, blue: 0.16), Color(red: 0.08, green: 0.36, blue: 0.09)]
        ctx.fill(Path(CGRect(origin: .zero, size: size)),
                 with: .radialGradient(Gradient(colors: sky), center: CGPoint(x: w * 0.5, y: h * 0.38),
                                       startRadius: 0, endRadius: max(w, h) * 0.8))
        ctx.opacity = dimmed ? 0.6 : 1

        // Stars.
        for i in 0..<48 {
            let x = Self.random(i, 1) * w, y = Self.random(i, 2) * h
            let r = (Self.random(i, 3) < 0.3 ? 1.6 : 1.0) * s
            let alpha = 0.35 + 0.65 * abs(sin(t * 1.3 + Double(i)))
            ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r)),
                     with: .color(Color.white.opacity(alpha)))
        }

        // Orbit rings, turning in opposite directions.
        let ring = dimmed ? Color(red: 0.47, green: 1, blue: 0.35) : Color(red: 0.88, green: 1, blue: 0.47)
        let center = CGPoint(x: w / 2, y: h * 0.42)
        drawRing(ctx, center: center, size: CGSize(width: 330 * s, height: 120 * s),
                 angle: t / 16 * 2 * .pi, color: ring.opacity(0.32), lineWidth: 9 * s)
        drawRing(ctx, center: center, size: CGSize(width: 250 * s, height: 170 * s),
                 angle: -t / 24 * 2 * .pi, color: ring.opacity(0.18), lineWidth: 7 * s)

        // Glowing orbs, floating up and down.
        let orbs: [(x: Double, y: Double, d: Double)] = [(0.2, 0.66, 70), (0.85, 0.33, 40), (0.66, 0.8, 26), (0.42, 0.16, 18)]
        for (i, orb) in orbs.enumerated() {
            let d = orb.d * s
            let c = CGPoint(x: orb.x * w, y: orb.y * h + sin(t * 2 * .pi / 5 + Double(i) * 1.7) * 10 * s)
            let rect = CGRect(x: c.x - d / 2, y: c.y - d / 2, width: d, height: d)
            let glow = Gradient(colors: [Color(red: 0.96, green: 1, blue: 0.69),
                                         Color(red: 0.61, green: 0.91, blue: 0.23).opacity(0.9),
                                         Color(red: 0.35, green: 0.78, blue: 0.16).opacity(0)])
            ctx.fill(Path(ellipseIn: rect),
                     with: .radialGradient(glow, center: CGPoint(x: rect.minX + d * 0.35, y: rect.minY + d * 0.3),
                                           startRadius: 0, endRadius: d * 0.6))
        }

        // Ringed planet, bobbing.
        let bob = sin(t * 2 * .pi / 6) * 8 * s
        let planet = dimmed ? CGPoint(x: w - 45 * s, y: h * 0.62 + bob) : CGPoint(x: w - 45 * s, y: 110 * s + bob)
        let pr = 23 * s
        let planetRect = CGRect(x: planet.x - pr, y: planet.y - pr, width: 2 * pr, height: 2 * pr)
        let planetFill = Gradient(colors: [Color(red: 0.91, green: 1, blue: 0.6), Color(red: 0.38, green: 0.77, blue: 0.16),
                                           Color(red: 0.17, green: 0.48, blue: 0.08)])
        ctx.fill(Path(ellipseIn: planetRect),
                 with: .radialGradient(planetFill, center: CGPoint(x: planetRect.minX + pr * 0.7, y: planetRect.minY + pr * 0.6),
                                       startRadius: 0, endRadius: pr * 2))
        ctx.stroke(Path(ellipseIn: planetRect), with: .color(Self.ink), lineWidth: 3 * s)
        drawRing(ctx, center: planet, size: CGSize(width: 68 * s, height: 14 * s), angle: -18 * .pi / 180,
                 color: Color(red: 0.95, green: 1, blue: 0.48), lineWidth: 3 * s)

        // Saucer crossing every 11 seconds, with a flickering beam.
        let period = 11.0
        let progress = t.truncatingRemainder(dividingBy: period) / period
        let x0 = -60 * s + progress * (w + 120 * s)
        let y0 = h * (dimmed ? 0.12 : 0.18) + sin(t * 2) * 6 * s
        var beam = Path()
        beam.move(to: CGPoint(x: x0 + 20 * s, y: y0 + 26 * s))
        beam.addLine(to: CGPoint(x: x0 + 32 * s, y: y0 + 26 * s))
        beam.addLine(to: CGPoint(x: x0 + 42 * s, y: y0 + 66 * s))
        beam.addLine(to: CGPoint(x: x0 + 10 * s, y: y0 + 66 * s))
        beam.closeSubpath()
        let pulse = 0.6 + 0.4 * sin(t * 4)
        ctx.fill(beam, with: .linearGradient(
            Gradient(colors: [Color(red: 0.94, green: 1, blue: 0.55).opacity(0.55 * pulse), Color(red: 0.94, green: 1, blue: 0.55).opacity(0)]),
            startPoint: CGPoint(x: x0, y: y0 + 26 * s), endPoint: CGPoint(x: x0, y: y0 + 66 * s)))
        let dome = Path(roundedRect: CGRect(x: x0 + 14 * s, y: y0, width: 24 * s, height: 16 * s), cornerRadius: 8 * s)
        ctx.fill(dome, with: .color(Color(red: 0.78, green: 1, blue: 1).opacity(0.85)))
        ctx.stroke(dome, with: .color(Self.ink), lineWidth: 2 * s)
        let saucer = Path(ellipseIn: CGRect(x: x0, y: y0 + 12 * s, width: 52 * s, height: 14 * s))
        ctx.fill(saucer, with: .color(Color(red: 0.78, green: 0.82, blue: 0.86)))
        ctx.stroke(saucer, with: .color(Self.ink), lineWidth: 2 * s)
    }

    private func drawRing(_ ctx: GraphicsContext, center: CGPoint, size: CGSize, angle: Double,
                          color: Color, lineWidth: CGFloat) {
        var c = ctx
        c.translateBy(x: center.x, y: center.y)
        c.rotate(by: .radians(angle))
        c.stroke(Path(ellipseIn: CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height)),
                 with: .color(color), lineWidth: lineWidth)
    }

    /// A fixed pseudo-random number in 0..<1 for star `i`, so the stars don't jump between frames.
    private static func random(_ i: Int, _ salt: Int) -> Double {
        let v = sin(Double(i) * 12.9898 + Double(salt) * 78.233) * 43758.5453
        return v - floor(v)
    }
}

#Preview {
    AlienBackground()
}
