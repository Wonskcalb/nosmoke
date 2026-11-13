import SwiftUI

struct CravingCloud: View {
    /// 0 Légère … 4 Très forte
    var level: Int
    var autoplay = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown: Double
    @State private var trigger = 0
    @State private var start: Date?

    init(level: Int, autoplay: Bool = false) {
        self.level = level
        self.autoplay = autoplay
        _shown = State(initialValue: Double(min(4, max(0, level))))
    }

    private var target: Double { Double(min(4, max(0, level))) }

    var body: some View {
        // Rain and bolt hang below the 82-unit viewBox (the SVG is overflow:visible), so draw on a taller canvas without changing layout.
        Color.clear
            .aspectRatio(120.0 / 82.0, contentMode: .fit)
            .overlay(alignment: .top) {
                GeometryReader { geo in
                    TimelineView(.animation(paused: start == nil)) { tl in
                        CloudCanvas(lv: shown, t: start.map { tl.date.timeIntervalSince($0) }, storm: target >= 3)
                    }
                    .frame(width: geo.size.width, height: geo.size.width * 108 / 120)
                }
                .allowsHitTesting(false)
            }
        .replayOnTap(autoplay: autoplay, trigger: $trigger)
        .onChange(of: level) { _, _ in
            if reduceMotion { shown = target } else { withAnimation(.easeInOut(duration: 0.9)) { shown = target } }
        }
        .task(id: trigger) {
            guard trigger > 0, !reduceMotion else { return }
            start = Date()
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            if !Task.isCancelled { start = nil }
        }
        .accessibilityElement()
        .accessibilityLabel(["Nuage d'envie légère", "Nuage d'envie présente", "Nuage d'envie bien là",
                             "Nuage d'envie forte, avec pluie", "Nuage d'envie très forte, orage"][Int(target)])
    }
}

private struct Ease {
    let a, b, c, d: Double
    static let io = Ease(a: 0.45, b: 0, c: 0.3, d: 1)
    static let rumble = Ease(a: 0.45, b: 0, c: 0.55, d: 1)
    static let spring = Ease(a: 0.34, b: 1.56, c: 0.64, d: 1)
    static let fall = Ease(a: 0.55, b: 0, c: 1, d: 0.45)

    func apply(_ x: Double) -> Double {
        func bez(_ u: Double, _ p1: Double, _ p2: Double) -> Double {
            let m = 1 - u
            return 3 * m * m * u * p1 + 3 * m * u * u * p2 + u * u * u
        }
        var lo = 0.0, hi = 1.0, u = x
        for _ in 0..<24 {
            u = (lo + hi) / 2
            if bez(u, a, c) < x { lo = u } else { hi = u }
        }
        return bez(u, b, d)
    }
}

private struct Key {
    let t: Double, v: Double, ease: Ease
    init(_ t: Double, _ v: Double, _ ease: Ease = .io) { self.t = t; self.v = v; self.ease = ease }
}

private func kf(_ p: Double, _ keys: [Key]) -> Double {
    guard let first = keys.first, let last = keys.last else { return 0 }
    if p <= first.t { return first.v }
    if p >= last.t { return last.v }
    for i in 0..<keys.count - 1 where p < keys[i + 1].t {
        let a = keys[i], b = keys[i + 1]
        let f = a.ease.apply((p - a.t) / (b.t - a.t))
        return a.v + (b.v - a.v) * f
    }
    return last.v
}

private func clamp01(_ x: Double) -> Double { min(1, max(0, x)) }
private func lerp(_ a: Double, _ b: Double, _ f: Double) -> Double { a + (b - a) * f }

private typealias RGB = (Double, Double, Double)
private func mix(_ a: RGB, _ b: RGB, _ f: Double) -> Color {
    Color(red: lerp(a.0, b.0, f), green: lerp(a.1, b.1, f), blue: lerp(a.2, b.2, f))
}
private func rgb(_ hex: Int) -> RGB {
    (Double((hex >> 16) & 255) / 255, Double((hex >> 8) & 255) / 255, Double(hex & 255) / 255)
}

private struct CloudCanvas: View, Animatable {
    var lv: Double
    var t: Double?
    var storm: Bool

    var animatableData: Double {
        get { lv }
        set { lv = newValue }
    }

    private static let paper = rgb(0xFBF8F2), line = rgb(0xD9D1C1), muted = rgb(0x6E6A5E), ink = rgb(0x2F3A2E)
    private static let fills = [paper, paper, line, muted, ink]
    private static let mouths: [[Double]] = [
        [50, 66, 59, 72, 68, 66], [52, 67, 59, 67.5, 66, 67], [52, 68, 59, 66.5, 66, 68],
        [53, 68, 59, 66.5, 65, 68], [53, 68.5, 59, 66, 65, 68.5],
    ]
    private static let mouthO: [Double] = [52, 66, 59, 74, 66, 66]
    private static let puffs: [(x: Double, y: Double, delay: Double)] = [(58, 34, 0), (26, 54, 0.06), (92, 50, 0.12), (62, 63, 0.03)]

    var body: some View {
        Canvas { ctx, size in
            let ink = Jardin.ink, mutedC = Jardin.muted
            var g = ctx
            g.concatenate(ViewBox(width: 120, height: 108).transform(in: size))

            let i = min(3, Int(lv)), fr = lv - Double(i)
            let fill = mix(Self.fills[i], Self.fills[i + 1], fr)
            let face = mix(Self.ink, Self.paper, clamp01(lv - 2))
            let rainA = clamp01(lv - 2), boltA = clamp01(lv - 3)

            let still = t == nil
            let tt = t ?? 0

            func local(_ c: GraphicsContext, ox: Double, oy: Double, sx: Double = 1, sy: Double = 1, dx: Double = 0, dy: Double = 0) -> GraphicsContext {
                var l = c
                l.translateBy(x: ox + dx, y: oy + dy)
                l.scaleBy(x: sx, y: sy)
                l.translateBy(x: -ox, y: -oy)
                return l
            }

            let drops: [(Double, Double)] = [(32, 0), (60, 1), (88, 2)]
            let drops4: [(Double, Double)] = [(22, 0), (38, 1), (82, 2), (98, 3)]
            let rainDelay = [0, 0.08, 0.16, 0.04]
            func rain(_ list: [(Double, Double)], _ alpha: Double) {
                guard alpha > 0 else { return }
                for (x, k) in list {
                    let idx = Int(k)
                    var p = 0.0
                    if !still { p = (tt - rainDelay[idx]) / 0.55 }
                    let fp = p <= 0 ? 0 : p >= 2 ? 1 : p.truncatingRemainder(dividingBy: 1)
                    let ex = kf(fp, [Key(0, 0, .fall), Key(0.7, -3, .fall), Key(0.71, 0, .fall), Key(1, 0)])
                    let ey = kf(fp, [Key(0, 0, .fall), Key(0.7, 10, .fall), Key(0.71, -5, .fall), Key(1, 0)])
                    let eo = kf(fp, [Key(0, 1, .fall), Key(0.7, 0, .fall), Key(0.71, 0, .fall), Key(1, 1)])
                    var s = Path()
                    let y = 86 + Double(idx % 2) * 4
                    s.move(to: CGPoint(x: x + ex, y: y + ey))
                    s.addLine(to: CGPoint(x: x + ex - 3, y: y + ey + 7))
                    var r = g
                    r.opacity = alpha * eo
                    r.stroke(s, with: .color(mutedC), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                }
            }
            rain(drops, rainA * (1 - boltA))
            rain(drops4, boltA)

            if boltA > 0 {
                let p = clamp01(tt / 1.0)
                let op = still ? 1 : kf(p, [Key(0, 1), Key(0.15, 1), Key(0.25, 0), Key(0.38, 1), Key(0.48, 0.2), Key(0.62, 1), Key(1, 1)])
                let sc = still ? 1 : kf(p, [Key(0, 1), Key(0.15, 1), Key(0.38, 1.15), Key(0.62, 1), Key(1, 1)])
                var b = Path()
                b.move(to: CGPoint(x: 60, y: 74)); b.addLine(to: CGPoint(x: 52, y: 90)); b.addLine(to: CGPoint(x: 58, y: 90))
                b.addLine(to: CGPoint(x: 54, y: 102)); b.addLine(to: CGPoint(x: 68, y: 84)); b.addLine(to: CGPoint(x: 61, y: 84))
                b.addLine(to: CGPoint(x: 65, y: 74)); b.closeSubpath()
                var l = local(g, ox: 60, oy: 88, sx: sc, sy: sc)
                l.opacity = boltA * op
                l.fill(b, with: .color(Jardin.terra))
                l.stroke(b, with: .color(ink), style: StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round))
            }

            var bsx = 1.0, bsy = 1.0, bdx = 0.0
            var puffScale: [Double] = [1, 1, 1, 1]
            var blink = 1.0, mouthO = 0.0
            if !still {
                if storm {
                    let p = clamp01(tt / 1.1), e = Ease.rumble
                    bdx = kf(p, [Key(0, 0, e), Key(0.08, -1.6, e), Key(0.16, 1.6, e), Key(0.24, -1.3, e), Key(0.32, 1.1, e), Key(0.42, -0.8, e), Key(0.54, 0.5, e), Key(0.68, -0.2, e), Key(1, 0, e)])
                    bsx = kf(p, [Key(0, 1, e), Key(0.08, 1.02, e), Key(0.16, 1, e), Key(1, 1, e)])
                    bsy = kf(p, [Key(0, 1, e), Key(0.08, 0.98, e), Key(0.16, 1, e), Key(1, 1, e)])
                } else {
                    let p = clamp01(tt / 1.3)
                    bsx = kf(p, [Key(0, 1), Key(0.15, 1.04, .spring), Key(0.45, 0.96), Key(0.7, 1.01), Key(1, 1)])
                    bsy = kf(p, [Key(0, 1), Key(0.15, 0.94, .spring), Key(0.45, 1.06), Key(0.7, 0.99), Key(1, 1)])
                    mouthO = kf(clamp01((tt - 0.08) / 1.3), [Key(0, 0), Key(0.45, 1), Key(1, 0)])
                }
                let dur = storm ? 1.0 : 1.2
                for k in 0..<4 {
                    let p = clamp01((tt - Self.puffs[k].delay) / dur)
                    puffScale[k] = kf(p, [Key(0, 1), Key(0.25, 0.96), Key(0.5, 1.07, .spring), Key(0.75, 0.99), Key(1, 1)])
                }
                blink = kf(clamp01(tt / 1.4), [Key(0, 1), Key(0.72, 1), Key(0.78, 0.1), Key(0.86, 1), Key(1, 1)])
            }

            let body = local(g, ox: 60, oy: 78, sx: bsx, sy: bsy, dx: bdx)

            func puffPath(_ k: Int) -> Path {
                switch k {
                case 0: return Path(ellipseIn: CGRect(x: 28, y: 4, width: 60, height: 60))
                case 1: return Path(ellipseIn: CGRect(x: 4, y: 32, width: 44, height: 44))
                case 2: return Path(ellipseIn: CGRect(x: 68, y: 26, width: 48, height: 48))
                default: return Path(roundedRect: CGRect(x: 10, y: 48, width: 104, height: 30), cornerRadius: 15)
                }
            }
            let order = [0, 1, 2, 3]
            for pass in 0..<2 {
                for k in order {
                    let o = Self.puffs[k]
                    let l = local(body, ox: o.x, oy: o.y, sx: puffScale[k], sy: puffScale[k])
                    let p = puffPath(k)
                    if pass == 0 {
                        l.stroke(p, with: .color(ink), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                    }
                    if pass == 1 { l.fill(p, with: .color(fill)) }
                }
                if pass == 0 {
                    for k in order {
                        let o = Self.puffs[k]
                        local(body, ox: o.x, oy: o.y, sx: puffScale[k], sy: puffScale[k]).fill(puffPath(k), with: .color(fill))
                    }
                }
            }

            let sw = StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
            let eyes = local(body, ox: 59, oy: 56, sy: blink)
            for x in [48.0, 70.0] {
                eyes.fill(Path(ellipseIn: CGRect(x: x - 3, y: 53, width: 6, height: 6)), with: .color(face))
            }

            let browA = clamp01(lv - 1)
            if browA > 0 {
                let w = clamp01(lv - 2)
                let y0 = lerp(49.5, 50, w), y1 = lerp(49.5, 48.5, w)
                var b = Path()
                b.move(to: CGPoint(x: 43, y: y0)); b.addLine(to: CGPoint(x: 51, y: y1))
                b.move(to: CGPoint(x: 75, y: y0)); b.addLine(to: CGPoint(x: 67, y: y1))
                var l = body
                l.opacity = browA
                l.stroke(b, with: .color(face), style: sw)
            }

            let m = Self.mouths[i].enumerated().map { lerp($0.element, Self.mouths[i + 1][$0.offset], fr) }
            let mm = m.enumerated().map { lerp($0.element, Self.mouthO[$0.offset], mouthO) }
            var mp = Path()
            mp.move(to: CGPoint(x: mm[0], y: mm[1]))
            mp.addQuadCurve(to: CGPoint(x: mm[4], y: mm[5]), control: CGPoint(x: mm[2], y: mm[3]))
            body.stroke(mp, with: .color(face), style: sw)
        }
    }
}
