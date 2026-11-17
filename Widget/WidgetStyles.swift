import SwiftUI
import WidgetKit

// The widget's Alien signal and Terminal styles (Phase 24).

private enum Alien {
    static let ink = Color(red: 0.05, green: 0.16, blue: 0.06)
    static let lime = Color(red: 0.78, green: 1.0, blue: 0.23)
    static let ring = Color(red: 0.88, green: 1.0, blue: 0.47)
    static let sky = [Color(red: 0.48, green: 0.91, blue: 0.31), Color(red: 0.22, green: 0.66, blue: 0.16),
                      Color(red: 0.08, green: 0.36, blue: 0.09)]
    /// The darker sky behind the alien terminal (same as the app's dimmed scene).
    static let dimSky = [Color(red: 0.12, green: 0.35, blue: 0.07), Color(red: 0.04, green: 0.16, blue: 0.03),
                         Color(red: 0.01, green: 0.06, blue: 0.01)]
    static let dimRing = Color(red: 0.47, green: 1, blue: 0.35)
    static let glow = [Color(red: 0.96, green: 1, blue: 0.69), Color(red: 0.61, green: 0.91, blue: 0.23).opacity(0.9),
                       Color(red: 0.35, green: 0.78, blue: 0.16).opacity(0)]
    static let planet = [Color(red: 0.91, green: 1, blue: 0.6), Color(red: 0.38, green: 0.77, blue: 0.16),
                         Color(red: 0.17, green: 0.48, blue: 0.08)]

    static func font(_ style: Font.TextStyle, _ weight: Font.Weight = .black) -> Font {
        .system(style, design: .rounded, weight: weight)
    }

    /// A fixed pseudo-random number in 0..<1, so stars keep their places.
    static func random(_ i: Int, _ salt: Int) -> Double {
        let v = sin(Double(i) * 12.9898 + Double(salt) * 78.233) * 43758.5453
        return v - floor(v)
    }
}

// MARK: - Moving scene

/// The app's alien scene (`Shared/AlienBackground.swift`, drawn with Canvas at 30 fps) rebuilt from
/// SwiftUI shapes. A widget can't run its own animation: each timeline entry is one pose (one per
/// minute), and iOS animates the shapes from one pose to the next. Same colours and layout as the
/// app's version; keep the two in step.
struct AlienWidgetScene: View {
    let date: Date
    /// Darker and calmer, for terminal text on top (like the app's alien terminal).
    var dimmed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Minutes since a fixed date: the pose. Reduce Motion: always the same pose.
    private var step: Int { reduceMotion ? 0 : Int(date.timeIntervalSinceReferenceDate / 60) }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let s = max(min(w, h), 1) / 160
            let center = CGPoint(x: w / 2, y: h * 0.45)
            let ring = dimmed ? Alien.dimRing : Alien.ring
            ZStack {
                RadialGradient(colors: dimmed ? Alien.dimSky : Alien.sky, center: UnitPoint(x: 0.5, y: 0.38),
                               startRadius: 0, endRadius: max(w, h) * 0.8)
                ZStack {
                    stars(w: w, h: h, s: s)
                    Ellipse()
                        .stroke(ring.opacity(0.32), lineWidth: 6 * s)
                        .frame(width: w * 0.95, height: h * 0.42)
                        .rotationEffect(.degrees(Double(step) * 12))
                        .position(center)
                    Ellipse()
                        .stroke(ring.opacity(0.18), lineWidth: 5 * s)
                        .frame(width: min(w, h) * 0.85, height: min(w, h) * 0.6)
                        .rotationEffect(.degrees(Double(step) * -8))
                        .position(center)
                    orbs(w: w, h: h, s: s)
                    planet(w: w, s: s)
                    saucer(w: w, h: h, s: s)
                }
                .opacity(dimmed ? 0.6 : 1)
            }
            .animation(.smooth(duration: 1.8), value: step)
        }
        .accessibilityHidden(true)
    }

    private func stars(w: Double, h: Double, s: Double) -> some View {
        ForEach(0..<16, id: \.self) { i in
            let r = (Alien.random(i, 3) < 0.3 ? 1.6 : 1.0) * s
            Circle()
                .fill(Color.white)
                .frame(width: 2 * r, height: 2 * r)
                .opacity((i + step) % 3 == 0 ? 0.35 : 1)
                .position(x: Alien.random(i, 1) * w, y: Alien.random(i, 2) * h)
        }
    }

    private func orbs(w: Double, h: Double, s: Double) -> some View {
        let list: [(x: Double, y: Double, d: Double)] = [(0.16, 0.74, 44), (0.86, 0.3, 26), (0.6, 0.86, 16)]
        return ForEach(Array(list.enumerated()), id: \.offset) { i, orb in
            let d = orb.d * s
            Circle()
                .fill(RadialGradient(colors: Alien.glow, center: UnitPoint(x: 0.35, y: 0.3),
                                     startRadius: 0, endRadius: d * 0.6))
                .frame(width: d, height: d)
                .position(x: orb.x * w, y: orb.y * h + sin(Double(step) * 0.9 + Double(i) * 1.7) * 6 * s)
        }
    }

    private func planet(w: Double, s: Double) -> some View {
        let r = 15 * s
        let bob = (step % 2 == 0 ? -1.0 : 1.0) * 4 * s
        return ZStack {
            Circle()
                .fill(RadialGradient(colors: Alien.planet, center: UnitPoint(x: 0.35, y: 0.3),
                                     startRadius: 0, endRadius: r * 2))
                .overlay(Circle().stroke(Alien.ink, lineWidth: 2 * s))
                .frame(width: 2 * r, height: 2 * r)
            Ellipse()
                .stroke(Color(red: 0.95, green: 1, blue: 0.48), lineWidth: 2 * s)
                .frame(width: 44 * s, height: 9 * s)
                .rotationEffect(.degrees(-18))
        }
        .position(x: w - 26 * s, y: 24 * s + bob)
    }

    /// Crosses in 12 one-minute hops; hidden at both ends so the jump back happens off screen.
    private func saucer(w: Double, h: Double, s: Double) -> some View {
        let k = step % 12
        let x = -30 * s + Double(k) / 11 * (w + 60 * s)
        let y = h * 0.2 + (k % 2 == 0 ? -3.0 : 3.0) * s
        return ZStack(alignment: .top) {
            SaucerBeam()
                .fill(LinearGradient(colors: [Color(red: 0.94, green: 1, blue: 0.55).opacity(0.55),
                                              Color(red: 0.94, green: 1, blue: 0.55).opacity(0)],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: 22 * s, height: 26 * s)
                .offset(y: 16 * s)
            Capsule()
                .fill(Color(red: 0.78, green: 1, blue: 1).opacity(0.85))
                .overlay(Capsule().stroke(Alien.ink, lineWidth: 1.5 * s))
                .frame(width: 16 * s, height: 11 * s)
            Ellipse()
                .fill(Color(red: 0.78, green: 0.82, blue: 0.86))
                .overlay(Ellipse().stroke(Alien.ink, lineWidth: 1.5 * s))
                .frame(width: 34 * s, height: 9 * s)
                .offset(y: 8 * s)
        }
        .frame(width: 34 * s, height: 44 * s, alignment: .top)
        .opacity(k == 0 || k == 11 ? 0 : 1)
        .position(x: x, y: y)
    }
}

private struct SaucerBeam: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + rect.width * 0.3, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.3, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

// MARK: - Alien signal content

/// White text with a thick dark outline, like the app's chunky headings.
private struct Outlined: ViewModifier {
    func body(content: Content) -> some View {
        content
            .foregroundStyle(Color.white)
            .shadow(color: Alien.ink, radius: 0, x: 1.2, y: 0)
            .shadow(color: Alien.ink, radius: 0, x: -1.2, y: 0)
            .shadow(color: Alien.ink, radius: 0, x: 0, y: 1.2)
            .shadow(color: Alien.ink, radius: 0, x: 0, y: -1.2)
            .shadow(color: Alien.ink, radius: 0, x: 0, y: 2.5)
    }
}

struct AlienWidgetContent: View {
    let entry: WidgetEntry
    let family: WidgetFamily

    var body: some View {
        if family == .systemMedium {
            HStack(alignment: .top, spacing: 10) {
                communityDay
                raids
            }
        } else {
            communityDay
        }
    }

    private func sticker<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 2, content: content)
            .foregroundStyle(Alien.ink)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Alien.ink, lineWidth: 2.5))
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Alien.ink).offset(y: 3))
            .rotationEffect(.degrees(-2))
    }

    private var communityDay: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Community Day")
                .font(Alien.font(.caption))
                .modifier(Outlined())
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 0)
            sticker {
                if let cd = entry.communityDay {
                    Text(cd.name).font(Alien.font(.caption2, .bold)).lineLimit(2)
                    if cd.isLive {
                        Text("Live now!").font(Alien.font(.headline))
                    } else if let start = cd.start {
                        Text(start, style: .relative)
                            .font(Alien.font(.headline))
                            .lineLimit(2)
                            .minimumScaleFactor(0.6)
                    }
                } else {
                    Text(entry.hasData ? "None announced yet" : "No data yet").font(Alien.font(.caption, .bold))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var raids: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(entry.raidTier ?? "Raids")
                .font(Alien.font(.caption))
                .modifier(Outlined())
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            if entry.bosses.isEmpty {
                Text("No raid bosses yet").font(Alien.font(.caption2, .bold)).modifier(Outlined())
            } else {
                ForEach(entry.bosses.prefix(3)) { boss in
                    HStack(spacing: 3) {
                        Text(boss.name).font(Alien.font(.caption, .heavy)).lineLimit(1)
                        if boss.canBeShiny {
                            Image(systemName: "sparkles").font(.caption2).foregroundStyle(.orange)
                                .accessibilityLabel("Can be shiny")
                        }
                    }
                    .foregroundStyle(Alien.ink)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Alien.ink, lineWidth: 2))
                }
                if entry.bosses.count > 3 {
                    Text("+ \(entry.bosses.count - 3) more").font(Alien.font(.caption2, .heavy)).modifier(Outlined())
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Terminal content

private enum Terminal {
    static let green = Color(red: 0.22, green: 1.0, blue: 0.42)
    static let dim = Color(red: 0.6, green: 0.86, blue: 0.68)
}

struct TerminalWidgetContent: View {
    let entry: WidgetEntry
    let family: WidgetFamily
    /// On a see-through dark panel over the dimmed alien scene (the alien terminal).
    var onAlienScene = false

    var body: some View {
        Group {
            if family == .systemMedium {
                HStack(alignment: .top, spacing: 12) {
                    communityDay
                    raids
                }
            } else {
                communityDay
            }
        }
        .font(.system(.caption, design: .monospaced))
        .foregroundStyle(Terminal.green)
        .padding(onAlienScene ? 8 : 0)
        .background {
            if onAlienScene {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.black.opacity(0.62))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Terminal.green.opacity(0.35)))
            }
        }
    }

    private func prompt(_ command: String) -> Text {
        let sign: Text = Text(verbatim: onAlienScene ? "ufo$ " : "$ ").foregroundStyle(Terminal.dim)
        let typed: Text = Text(verbatim: command).foregroundStyle(Color.white)
        return sign + typed
    }

    private var communityDay: some View {
        VStack(alignment: .leading, spacing: 2) {
            prompt("cd --next")
            if let cd = entry.communityDay {
                Text(verbatim: cd.name).foregroundStyle(Terminal.dim).lineLimit(2)
                if cd.isLive {
                    Text(verbatim: "LIVE NOW").foregroundStyle(Color.white)
                } else if let start = cd.start {
                    let prefix: Text = Text(verbatim: "T-")
                    (prefix + Text(start, style: .relative))
                        .foregroundStyle(Color.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                }
            } else {
                Text(verbatim: entry.hasData ? "none announced yet" : "waiting for data...")
            }
            Spacer(minLength: 0)
            HStack(spacing: 0) {
                Text(verbatim: "$ ").foregroundStyle(Terminal.dim)
                Rectangle().fill(Terminal.green).frame(width: 7, height: 12)
            }
            .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var raids: some View {
        VStack(alignment: .leading, spacing: 2) {
            prompt("raids --top")
            if entry.bosses.isEmpty {
                Text(verbatim: "no raid bosses yet").foregroundStyle(Terminal.dim)
            } else {
                ForEach(Array(entry.bosses.prefix(4).enumerated()), id: \.offset) { index, boss in
                    let marker: String = index == 0 ? "> " : "  "
                    Text(verbatim: marker + boss.name + (boss.canBeShiny ? " *" : ""))
                        .foregroundStyle(index == 0 ? Color.white : Terminal.green)
                        .lineLimit(1)
                }
                if entry.bosses.count > 4 {
                    Text(verbatim: "  ... \(entry.bosses.count - 4) more").foregroundStyle(Terminal.dim)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
