import SwiftUI

private struct Ease {
    let x1, y1, x2, y2: Double
    static let ease = Ease(x1: 0.25, y1: 0.1, x2: 0.25, y2: 1)
    static let io = Ease(x1: 0.45, y1: 0, x2: 0.3, y2: 1)
    static let out = Ease(x1: 0.2, y1: 0.7, x2: 0.3, y2: 1)
    static let spring = Ease(x1: 0.34, y1: 1.56, x2: 0.64, y2: 1)
    static let fall = Ease(x1: 0.55, y1: 0, x2: 1, y2: 0.45)
    static let fill = Ease(x1: 0.3, y1: 0, x2: 0.2, y2: 1)
    static let morph = Ease(x1: 0.42, y1: 0, x2: 0.3, y2: 1)

    func apply(_ u: Double) -> Double {
        var lo = 0.0, hi = 1.0
        for _ in 0..<24 {
            let s = (lo + hi) / 2
            let x = 3 * (1 - s) * (1 - s) * s * x1 + 3 * (1 - s) * s * s * x2 + s * s * s
            if x < u { lo = s } else { hi = s }
        }
        let s = (lo + hi) / 2
        return 3 * (1 - s) * (1 - s) * s * y1 + 3 * (1 - s) * s * s * y2 + s * s * s
    }
}

private struct Tf {
    var sx = 1.0, sy = 1.0, rot = 0.0, tx = 0.0, ty = 0.0, op = 1.0

    func lerp(_ o: Tf, _ w: Double) -> Tf {
        func l(_ a: Double, _ b: Double) -> Double { a + (b - a) * w }
        return Tf(sx: l(sx, o.sx), sy: l(sy, o.sy), rot: l(rot, o.rot), tx: l(tx, o.tx), ty: l(ty, o.ty), op: l(op, o.op))
    }
}

private struct K {
    let p: Double
    let v: Tf
    let e: Ease
}

private func kf(_ p: Double, _ e: Ease = .io, sx: Double = 1, sy: Double = 1, rot: Double = 0, tx: Double = 0, ty: Double = 0, op: Double = 1) -> K {
    K(p: p, v: Tf(sx: sx, sy: sy, rot: rot, tx: tx, ty: ty, op: op), e: e)
}

private func prog(_ t: Double, _ delay: Double, _ dur: Double) -> Double {
    min(max((t - delay) / dur, 0), 1)
}

private func sample(_ ks: [K], _ t: Double, delay: Double = 0, dur: Double) -> Tf {
    let p = prog(t, delay, dur)
    guard let last = ks.last else { return Tf() }
    if p >= last.p { return last.v }
    for i in 0..<(ks.count - 1) where p < ks[i + 1].p {
        let a = ks[i], b = ks[i + 1]
        return a.v.lerp(b.v, a.e.apply((p - a.p) / (b.p - a.p)))
    }
    return last.v
}

private func morphPts(_ frames: [[Double]], _ times: [Double], _ t: Double, delay: Double, dur: Double) -> [Double] {
    let p = prog(t, delay, dur)
    if p >= times[times.count - 1] { return frames[frames.count - 1] }
    for i in 0..<(times.count - 1) where p < times[i + 1] {
        let w = Ease.morph.apply((p - times[i]) / (times[i + 1] - times[i]))
        return zip(frames[i], frames[i + 1]).map { $0 + ($1 - $0) * w }
    }
    return frames[frames.count - 1]
}

private let blinkKF = [kf(0), kf(0.72), kf(0.78, sy: 0.1), kf(0.86), kf(1)]

private func svgPath(_ d: String) -> Path {
    let s = Array(d)
    var i = 0
    var path = Path()
    var cur = CGPoint.zero, start = CGPoint.zero
    var cmd: Character = "M"

    func skip() { while i < s.count, s[i] == " " || s[i] == "," { i += 1 } }
    func num() -> CGFloat? {
        skip()
        guard i < s.count else { return nil }
        var str = ""
        if s[i] == "-" { str.append("-"); i += 1 }
        var dot = false
        while i < s.count, s[i].isNumber || (s[i] == "." && !dot) {
            if s[i] == "." { dot = true }
            str.append(s[i]); i += 1
        }
        return Double(str).map { CGFloat($0) }
    }

    while true {
        skip()
        guard i < s.count else { break }
        if s[i].isLetter { cmd = s[i]; i += 1 }
        let rel = cmd.isLowercase
        switch cmd.uppercased() {
        case "Z":
            path.closeSubpath(); cur = start
        case "M", "L":
            guard let x = num(), let y = num() else { return path }
            let pt = rel ? CGPoint(x: cur.x + x, y: cur.y + y) : CGPoint(x: x, y: y)
            if cmd.uppercased() == "M" { path.move(to: pt); start = pt; cmd = rel ? "l" : "L" } else { path.addLine(to: pt) }
            cur = pt
        case "H":
            guard let x = num() else { return path }
            cur.x = rel ? cur.x + x : x; path.addLine(to: cur)
        case "V":
            guard let y = num() else { return path }
            cur.y = rel ? cur.y + y : y; path.addLine(to: cur)
        case "C":
            guard let a = num(), let b = num(), let c = num(), let d = num(), let e = num(), let f = num() else { return path }
            let o = rel ? cur : .zero
            let end = CGPoint(x: o.x + e, y: o.y + f)
            path.addCurve(to: end, control1: CGPoint(x: o.x + a, y: o.y + b), control2: CGPoint(x: o.x + c, y: o.y + d))
            cur = end
        case "Q":
            guard let a = num(), let b = num(), let c = num(), let d = num() else { return path }
            let o = rel ? cur : .zero
            let end = CGPoint(x: o.x + c, y: o.y + d)
            path.addQuadCurve(to: end, control: CGPoint(x: o.x + a, y: o.y + b))
            cur = end
        default:
            return path
        }
    }
    return path
}

private extension GraphicsContext {
    func tf(_ f: Tf, _ ox: Double, _ oy: Double, _ body: (GraphicsContext) -> Void) {
        var c = self
        c.opacity = opacity * f.op
        c.translateBy(x: f.tx, y: f.ty)
        c.translateBy(x: ox, y: oy)
        c.rotate(by: .degrees(f.rot))
        c.scaleBy(x: f.sx, y: f.sy)
        c.translateBy(x: -ox, y: -oy)
        body(c)
    }

    func shape(_ p: Path, fill: Color? = nil, w: CGFloat = 2, stroke: Color = Jardin.ink) {
        if let fill { self.fill(p, with: .color(fill)) }
        self.stroke(p, with: .color(stroke), style: StrokeStyle(lineWidth: w, lineCap: .round, lineJoin: .round))
    }

    func line(_ d: String, w: CGFloat = 2, stroke: Color = Jardin.ink) { shape(svgPath(d), w: w, stroke: stroke) }

    func dot(_ x: Double, _ y: Double, _ r: Double, _ color: Color = Jardin.ink) {
        fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r)), with: .color(color))
    }
}

private struct StagePlayer: View {
    let width: Double, height: Double, duration: Double
    let autoplay: Bool
    let label: String
    let draw: (GraphicsContext, Double) -> Void

    @State private var trigger = 0
    @State private var start: Date?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(paused: start == nil)) { tl in
            let t = start.map { tl.date.timeIntervalSince($0) } ?? .infinity
            Canvas { ctx, size in
                var c = ctx
                c.concatenate(ViewBox(width: width, height: height).transform(in: size))
                draw(c, t >= duration ? .infinity : t)
            }
        }
        .aspectRatio(width / height, contentMode: .fit)
        .replayOnTap(autoplay: autoplay, trigger: $trigger)
        .task(id: trigger) {
            guard trigger > 0, !reduceMotion else { return }
            start = Date()
            do { try await Task.sleep(nanoseconds: UInt64((duration + 0.05) * 1e9)) } catch { return }
            start = nil
        }
        .accessibilityElement()
        .accessibilityLabel(label)
    }
}

struct PlantView: View {
    /// 0 graine, 1 pousse, 2 deux feuilles, 3 tige, 4 fleur
    var stage: Int
    var autoplay = false

    private static let grow = [
        kf(0, .out, sy: 0.05, op: 0), kf(0.10, .ease), kf(0.50, .io, sx: 0.96, sy: 1.12),
        kf(0.72, .ease, sx: 1.02, sy: 0.96), kf(0.88, .ease, sy: 1.01), kf(1, .ease),
    ]
    private static let leafL = [kf(0, sx: 0.2, sy: 0.2, rot: 55), kf(0.55, sx: 1.05, sy: 1.05, rot: -12), kf(0.78, rot: 5), kf(1)]
    private static let leafR = [kf(0, sx: 0.2, sy: 0.2, rot: -55), kf(0.55, sx: 1.05, sy: 1.05, rot: 12), kf(0.78, rot: -5), kf(1)]
    private static let pot = [kf(0, .spring), kf(0.14, .spring, sx: 1.04, sy: 0.95), kf(0.36, .io, sx: 0.98, sy: 1.03), kf(0.60), kf(1)]

    private static let leaves: [[(String, Double, Double)]] = [
        [],
        [("M60 74C54 66 46 66 42 70C46 76 54 78 60 74Z", 60, 74), ("M60 70C66 62 74 62 78 66C74 72 66 74 60 70Z", 60, 70)],
        [("M60 70C50 58 38 60 34 66C40 74 52 76 60 70Z", 60, 70), ("M60 64C70 52 82 54 86 60C80 68 68 70 60 64Z", 60, 64)],
        [("M60 74C52 66 42 66 38 70C42 76 52 78 60 74Z", 60, 74), ("M60 66C68 58 78 58 82 62C78 68 68 70 60 66Z", 60, 66),
         ("M60 56C52 48 42 48 38 52C42 58 52 60 60 56Z", 60, 56), ("M60 50C68 42 78 42 82 46C78 52 68 54 60 50Z", 60, 50)],
    ]
    private static let stems = ["", "M60 88V68", "M60 88V58", "M60 88V42"]

    var body: some View {
        StagePlayer(width: 120, height: 136, duration: 1.5, autoplay: autoplay, label: "Plante") { ctx, t in
            let s = max(0, stage)
            let part = min(s, 3)
            ctx.tf(sample(Self.grow, t, dur: 1.2), 60, 88) { c in
                if part == 0 { c.shape(Path(ellipseIn: CGRect(x: 54, y: 75, width: 12, height: 8)), fill: Jardin.paper) }
                else { c.line(Self.stems[part]) }
                for (i, leaf) in Self.leaves[part].enumerated() {
                    let f = sample(i % 2 == 1 ? Self.leafR : Self.leafL, t, delay: 0.32 + Double(i) * 0.06, dur: 1)
                    c.tf(f, leaf.1, leaf.2) { $0.shape(svgPath(leaf.0), fill: Jardin.ink) }
                }
                if s == 3 { c.shape(Path(ellipseIn: CGRect(x: 56, y: 32, width: 8, height: 12)), fill: Jardin.terra) }
                if s >= 4 {
                    for k in 0..<5 {
                        let a = Double(k * 72 - 90) * .pi / 180
                        c.shape(Path(ellipseIn: CGRect(x: 60 + 7 * cos(a) - 6, y: 28 + 7 * sin(a) - 6, width: 12, height: 12)), fill: Jardin.terra)
                    }
                    c.shape(Path(ellipseIn: CGRect(x: 56, y: 24, width: 8, height: 8)), fill: Jardin.paper)
                }
            }
            ctx.tf(sample(Self.pot, t, dur: 0.8), 60, 130) { c in
                c.shape(svgPath("M38 94L82 94L77 130L43 130Z"), fill: Jardin.terra)
                c.shape(Path(roundedRect: CGRect(x: 32, y: 82, width: 56, height: 12), cornerRadius: 4), fill: Jardin.terra)
                c.tf(sample(blinkKF, t, dur: 1.4), 60, 106) { $0.dot(52, 106, 2.5); $0.dot(68, 106, 2.5) }
                c.line("M54 113Q60 118 66 113")
            }
        }
    }
}

struct PiggyView: View {
    var autoplay = false

    private static let coin = [
        kf(0, .fall, ty: -24, op: 0), kf(0.08, .ease, ty: -24), kf(0.30, .out, sx: 1.15, sy: 0.85, ty: 14),
        kf(0.42, .fall, ty: 5), kf(0.56, .ease, ty: 32), kf(0.60, .ease, ty: 32, op: 0), kf(1, .ease, ty: 32, op: 0),
    ]
    private static let bounce = [
        kf(0, .out), kf(0.52, .out), kf(0.62, .spring, sx: 1.05, sy: 0.93), kf(0.76, .io, sx: 0.98, sy: 1.03), kf(0.88, .io, sx: 1.01, sy: 0.99), kf(1),
    ]
    private static let ear = [kf(0), kf(0.58), kf(0.70, rot: -14), kf(0.84, rot: 6), kf(1)]
    private static let tail: [[Double]] = [
        [32, 60, 22, 58, 18, 50, 23, 46, 27, 43, 30, 50, 24, 53],
        [32, 60, 22, 58, 18, 50, 23, 46, 27, 43, 30, 50, 24, 53],
        [32, 60, 20, 60, 14, 50, 20, 44, 25, 40, 30, 47, 24, 50],
        [32, 60, 23, 57, 20, 51, 24, 47, 28, 44, 30, 51, 25, 54],
        [32, 60, 22, 58, 18, 50, 23, 46, 27, 43, 30, 50, 24, 53],
    ]

    var body: some View {
        StagePlayer(width: 130, height: 100, duration: 1.4, autoplay: autoplay, label: "Tirelire") { ctx, t in
            ctx.line("M20 96h96", stroke: Jardin.line)
            ctx.tf(sample(Self.coin, t, dur: 1.4), 63, 23) { c in
                c.shape(Path(ellipseIn: CGRect(x: 56, y: 9, width: 14, height: 14)), fill: Jardin.terra)
                c.line("M63 12.5v7", w: 1.5)
            }
            ctx.tf(sample(Self.bounce, t, dur: 1.4), 64, 96) { c in
                c.shape(Path(roundedRect: CGRect(x: 42, y: 78, width: 10, height: 16), cornerRadius: 4), fill: Jardin.paper)
                c.shape(Path(roundedRect: CGRect(x: 74, y: 78, width: 10, height: 16), cornerRadius: 4), fill: Jardin.paper)
                let p = morphPts(Self.tail, [0, 0.55, 0.7, 0.85, 1], t, delay: 0.05, dur: 1.4)
                var tail = Path()
                tail.move(to: CGPoint(x: p[0], y: p[1]))
                tail.addCurve(to: CGPoint(x: p[6], y: p[7]), control1: CGPoint(x: p[2], y: p[3]), control2: CGPoint(x: p[4], y: p[5]))
                tail.addCurve(to: CGPoint(x: p[12], y: p[13]), control1: CGPoint(x: p[8], y: p[9]), control2: CGPoint(x: p[10], y: p[11]))
                c.shape(tail)
                c.tf(sample(Self.ear, t, dur: 1.4), 82, 44) { $0.shape(svgPath("M74 42L82 26L90 46Z"), fill: Jardin.paper) }
                c.shape(Path(ellipseIn: CGRect(x: 28, y: 36, width: 72, height: 52)), fill: Jardin.paper)
                c.line("M56 40h14", w: 3)
                c.shape(Path(ellipseIn: CGRect(x: 93, y: 53, width: 14, height: 18)), fill: Jardin.paper)
                c.dot(98, 62, 1.4); c.dot(102, 62, 1.4)
                c.tf(sample(blinkKF, t, dur: 1.4), 86, 54) { $0.dot(86, 54, 2.5) }
                c.line("M82 70q4 3 8 0")
            }
        }
    }
}

struct LungsView: View {
    /// 0…1, share of health milestones reached
    var level: Double
    var autoplay = false

    private static let breath = [
        kf(0, .io), kf(0.18, .spring, sx: 0.97, sy: 0.98), kf(0.50, .io, sx: 1.07, sy: 1.05), kf(0.72, .io, sx: 0.99, sy: 0.99), kf(1),
    ]
    private static let fillRise = [kf(0, .fill, ty: 16), kf(0.60, .fill, ty: -2), kf(1, .fill)]

    private static func lung(_ c: GraphicsContext, _ d: String, _ ox: Double, _ eyes: (Double, Double), _ mouth: String, fillY: Double, fill: Tf, blink: Tf) {
        let path = svgPath(d)
        c.shape(path, fill: Jardin.paper)
        c.drawLayer { l in
            l.clip(to: Path(CGRect(x: 0, y: fillY + fill.ty, width: 140, height: 140)))
            l.fill(path, with: .color(Jardin.terra))
        }
        c.shape(path)
        c.tf(blink, eyes.0 + 5, 68) { $0.dot(eyes.0, 68, 2.5); $0.dot(eyes.1, 68, 2.5) }
        c.line(mouth)
    }

    var body: some View {
        let lv = min(max(level, 0), 1)
        StagePlayer(width: 140, height: 106, duration: 1.4, autoplay: autoplay, label: "Poumons") { ctx, t in
            let fillY = 100 - 72 * lv
            let rise = sample(Self.fillRise, t, delay: 0.2, dur: 1.1)
            let blink = sample(blinkKF, t, dur: 1.4)
            ctx.line("M70 6V42M70 42L60 52M70 42L80 52")
            ctx.tf(sample(Self.breath, t, dur: 1.4), 64, 36) {
                Self.lung($0, "M64 36C50 26 26 40 22 70C19 92 32 102 48 98C60 95 64 86 64 74Z", 64, (38, 48), "M39 76Q43 79 47 76", fillY: fillY, fill: rise, blink: blink)
            }
            ctx.tf(sample(Self.breath, t, delay: 0.05, dur: 1.4), 76, 36) {
                Self.lung($0, "M76 36C90 26 114 40 118 70C121 92 108 102 92 98C80 95 76 86 76 74Z", 76, (92, 102), "M93 76Q97 79 101 76", fillY: fillY, fill: rise, blink: blink)
            }
        }
    }
}
