import SwiftUI

struct MicroView: View {
    var count: Int
    var cap: Int = 12
    var autoplay = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var trigger = 0
    @State private var start: Date?

    private static let total = 1.5

    var body: some View {
        TimelineView(.animation(paused: start == nil)) { tl in
            let elapsed = start.map { min(Self.total, tl.date.timeIntervalSince($0)) } ?? Self.total
            Canvas { ctx, size in
                MicroPose(n: max(0, count), cap: max(1, cap), t: elapsed).draw(&ctx, size: size)
            }
        }
        .aspectRatio(160.0 / 200.0, contentMode: .fit)
        .replayOnTap(autoplay: autoplay, trigger: $trigger)
        .onChange(of: trigger) {
            guard !reduceMotion else { return }
            let s = Date()
            start = s
            Task {
                try? await Task.sleep(for: .seconds(Self.total + 0.05))
                if start == s { start = nil }
            }
        }
        .accessibilityElement()
        .accessibilityLabel(count == 0 ? "Micro, sans comprimé" : "Micro porte \(count) comprimé\(count > 1 ? "s" : "")")
    }
}

private struct Ease {
    let x1, y1, x2, y2: Double
    static let io = Ease(x1: 0.45, y1: 0, x2: 0.3, y2: 1)
    static let limb = Ease(x1: 0.42, y1: 0, x2: 0.3, y2: 1)
    static let out = Ease(x1: 0.2, y1: 0.7, x2: 0.3, y2: 1)
    static let spring = Ease(x1: 0.34, y1: 1.56, x2: 0.64, y2: 1)
    static let fall = Ease(x1: 0.55, y1: 0, x2: 1, y2: 0.45)
    static let sym = Ease(x1: 0.45, y1: 0, x2: 0.55, y2: 1)

    func apply(_ x: Double) -> Double {
        if x <= 0 { return 0 }
        if x >= 1 { return 1 }
        var lo = 0.0, hi = 1.0
        for _ in 0..<30 {
            let m = (lo + hi) / 2
            let bx = 3 * (1 - m) * (1 - m) * m * x1 + 3 * (1 - m) * m * m * x2 + m * m * m
            if bx < x { lo = m } else { hi = m }
        }
        let m = (lo + hi) / 2
        return 3 * (1 - m) * (1 - m) * m * y1 + 3 * (1 - m) * m * m * y2 + m * m * m
    }
}

private struct Key {
    let t: Double
    let v: [Double]
    var e: Ease = .io
    init(_ t: Double, _ v: [Double], _ e: Ease = .io) { self.t = t; self.v = v; self.e = e }
}

private func kf(_ p: Double, _ keys: [Key]) -> [Double] {
    if p <= keys[0].t { return keys[0].v }
    for i in 1..<keys.count where p <= keys[i].t {
        let a = keys[i - 1], b = keys[i]
        let f = a.e.apply((p - a.t) / (b.t - a.t))
        return zip(a.v, b.v).map { $0 + ($1 - $0) * f }
    }
    return keys[keys.count - 1].v
}

private func scalar(_ p: Double, _ keys: [(Double, Double, Ease)]) -> Double {
    kf(p, keys.map { Key($0.0, [$0.1], $0.2) })[0]
}

private struct MicroPose {
    let n: Int
    let cap: Int
    let t: Double

    private var strain: Bool { n >= max(1, Int((Double(cap) * 0.5).rounded())) }
    private var heavy: Bool { n >= max(2, Int((Double(cap) * 11 / 12).rounded())) }
    private let D = 1.4

    private func local(_ delay: Double = 0) -> Double { min(1, max(0, (t - delay) / D)) }

    private func mir(_ f: [Double]) -> [Double] { [160 - f[0], f[1], 160 - f[2], f[3], 160 - f[4], f[5]] }

    private func limb(_ frames: [[Double]], _ times: [Double], _ delay: Double) -> [Double] {
        kf(local(delay), zip(times, frames).map { Key($0, $1, .limb) })
    }

    private func quad(_ f: [Double]) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: f[0], y: f[1]))
        p.addQuadCurve(to: CGPoint(x: f[4], y: f[5]), control: CGPoint(x: f[2], y: f[3]))
        return p
    }

    func draw(_ ctx: inout GraphicsContext, size: CGSize) {
        let s = min(size.width / 160, size.height / 200)
        ctx.translateBy(x: (size.width - 160 * s) / 2, y: size.height - 200 * s)
        ctx.scaleBy(x: s, y: s)

        let ink = Jardin.ink, paper = Jardin.paper, terra = Jardin.terra
        let style = StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
        let p = local()

        let times = n > 0 ? [0, 0.24, 0.34, 0.52, 1] : [0, 0.25, 0.5, 0.72, 1]
        let legF: [[Double]] = n == 0
            ? [[70, 164, 67, 173, 68, 181], [70, 164, 68, 173, 68, 181], [70, 164, 65, 172, 68, 181], [70, 164, 67, 173, 68, 181], [70, 164, 67, 173, 68, 181]]
            : strain
            ? [[70, 163, 56, 173, 67, 181], [70, 163, 56, 173, 67, 181], [70, 163, 51, 172, 67, 181], [70, 163, 59, 173, 67, 181], [70, 163, 56, 173, 67, 181]]
            : [[70, 164, 67, 173, 68, 181], [70, 164, 67, 173, 68, 181], [70, 164, 61, 172, 68, 181], [70, 164, 69, 173, 68, 181], [70, 164, 67, 173, 68, 181]]
        let armF: [[Double]] = n > 0
            ? [[54, 128, 51, 112, 60, 97], [54, 128, 51, 112, 60, 97], [54, 128, 48.5, 113, 60, 97], [54, 128, 52, 111.5, 60, 97], [54, 128, 51, 112, 60, 97]]
            : [[54, 130, 44, 142, 46, 158], [54, 128, 46, 138, 49, 152], [54, 130, 42, 146, 42, 160], [54, 130, 45, 143, 48, 158], [54, 130, 44, 142, 46, 158]]

        let legL = limb(legF, times, 0)
        let legR = mir(limb(legF, times, 0.03))
        let armL = limb(armF, times, 0.04)
        let armR = mir(limb(armF, times, 0.06))

        var ground = Path()
        ground.move(to: CGPoint(x: 42, y: 187)); ground.addLine(to: CGPoint(x: 118, y: 187))
        ctx.stroke(ground, with: .color(Jardin.line), style: style)

        var body = ctx
        if heavy {
            let dx = kf(p, [Key(0, [0]), Key(0.30, [0], .sym), Key(0.35, [-1.6], .sym), Key(0.41, [1.6], .sym), Key(0.47, [-1.4], .sym),
                            Key(0.53, [1.2], .sym), Key(0.59, [-1], .sym), Key(0.66, [0.7], .sym), Key(0.74, [-0.4], .sym),
                            Key(0.84, [0.2], .sym), Key(1, [0], .sym)])[0]
            body.translateBy(x: dx, y: 0)
        }
        let sq: [Double] = n > 0
            ? kf(p, [Key(0, [1, 1], .out), Key(0.24, [1, 1], .out), Key(0.32, [1.06, 0.92], .spring), Key(0.5, [0.97, 1.04]), Key(0.68, [1.01, 0.99]), Key(1, [1, 1])]) + [0]
            : kf(p, [Key(0, [1, 1, 0]), Key(0.25, [0.97, 1.05, -2], Ease(x1: 0.5, y1: 0, x2: 0.2, y2: 1)), Key(0.5, [1.03, 0.97, 0], .spring), Key(0.72, [0.99, 1.01, 0]), Key(1, [1, 1, 0])])
        body.translateBy(x: 80, y: 186 + sq[2])
        body.scaleBy(x: sq[0], y: sq[1])
        body.translateBy(x: -80, y: -186)

        body.stroke(quad(legL), with: .color(ink), style: style)
        body.stroke(quad(legR), with: .color(ink), style: style)
        for cx in [strain ? 66.0 : 65.0, strain ? 94.0 : 95.0] {
            let e = Path(ellipseIn: CGRect(x: cx - 6, y: 180, width: 12, height: 6))
            body.fill(e, with: .color(paper)); body.stroke(e, with: .color(ink), style: style)
        }
        body.stroke(quad(armL), with: .color(ink), style: style)
        body.stroke(quad(armR), with: .color(ink), style: style)

        let torso = Path(ellipseIn: CGRect(x: 50, y: 113, width: 60, height: 54))
        body.fill(torso, with: .color(paper)); body.stroke(torso, with: .color(ink), style: style)

        if strain {
            let k = kf(p, [Key(0, [1, 1]), Key(0.24, [1, 1]), Key(0.34, [1.1, 0.6]), Key(0.55, [1, 1]), Key(1, [1, 1])])
            var e = body
            e.translateBy(x: 80, y: 136); e.scaleBy(x: k[0], y: k[1]); e.translateBy(x: -80, y: -136)
            var pa = Path()
            for pts in [[(66.0, 132.0), (72, 136), (66, 140)], [(94, 132), (88, 136), (94, 140)]] {
                pa.move(to: CGPoint(x: pts[0].0, y: pts[0].1))
                pa.addLine(to: CGPoint(x: pts[1].0, y: pts[1].1))
                pa.addLine(to: CGPoint(x: pts[2].0, y: pts[2].1))
            }
            e.stroke(pa, with: .color(ink), style: style)
        } else {
            let k = kf(p, [Key(0, [1]), Key(0.72, [1]), Key(0.78, [0.1]), Key(0.86, [1]), Key(1, [1])])[0]
            var e = body
            e.translateBy(x: 80, y: 136); e.scaleBy(x: 1, y: k); e.translateBy(x: -80, y: -136)
            for x in [70.0, 90.0] { e.fill(Path(ellipseIn: CGRect(x: x - 3, y: 133, width: 6, height: 6)), with: .color(ink)) }
        }

        var mouth = Path()
        if heavy {
            mouth.move(to: CGPoint(x: 70, y: 150))
            for i in 0..<4 {
                let x = 70.0 + Double(i) * 5
                mouth.addQuadCurve(to: CGPoint(x: x + 5, y: 150), control: CGPoint(x: x + 2.5, y: i % 2 == 0 ? 147 : 153))
            }
        } else {
            let frames: [[Double]] = strain
                ? [[72, 150, 80, 146, 88, 150], [72, 150, 80, 146, 88, 150], [73, 150, 80, 144, 87, 150], [72, 150, 80, 147, 88, 150], [72, 150, 80, 146, 88, 150]]
                : [[72, 147, 80, 154, 88, 147], [72, 147, 80, 154, 88, 147], [73, 148, 80, 151, 87, 148], [72, 146, 80, 155, 88, 146], [72, 147, 80, 154, 88, 147]]
            mouth = quad(kf(local(0.05), zip(times, frames).map { Key($0, $1, .limb) }))
        }
        body.stroke(mouth, with: .color(ink), style: style)

        var stack = body
        if heavy { stack.translateBy(x: 80, y: 93); stack.rotate(by: .degrees(-3)); stack.translateBy(x: -80, y: -93) }
        if n > 0 {
            let amp = heavy ? [-6.0, 4, -2] : [-3.0, 2, -0.8]
            let a = kf(p, [Key(0, [0]), Key(0.30, [0]), Key(0.46, [amp[0]]), Key(0.63, [amp[1]]), Key(0.80, [amp[2]]), Key(1, [0])])[0]
            stack.translateBy(x: 80, y: 93); stack.rotate(by: .degrees(a)); stack.translateBy(x: -80, y: -93)
        }
        for i in 0..<n {
            let top = i == n - 1
            var ty = 0.0, op = 1.0
            if top {
                ty = scalar(p, [(0, -40, .fall), (0.25, 0, .out), (0.33, -4, .fall), (0.42, 0, .io), (1, 0, .io)])
                op = Ease.fall.apply(min(1, p / 0.08))
            }
            var r = stack
            r.opacity = op
            let rect = Path(roundedRect: CGRect(x: 58, y: Double(87 - 7 * i) + ty, width: 44, height: 6), cornerRadius: 3)
            r.fill(rect, with: .color(top ? terra : paper)); r.stroke(rect, with: .color(ink), style: style)
        }

        for h in [armL, armR] {
            let c = CGPoint(x: h[4], y: h[5])
            body.fill(Path(ellipseIn: CGRect(x: c.x - 4.5, y: c.y - 4.5, width: 9, height: 9)), with: .color(ink))
            body.fill(Path(ellipseIn: CGRect(x: c.x - 2.5, y: c.y - 2.5, width: 5, height: 5)), with: .color(paper))
        }

        var drops: [(Double, Double)] = []
        if strain { drops.append((115, 110)) }
        if heavy { drops.append((45, 108)) }
        let dty = scalar(p, [(0, 0, .fall), (0.30, 0, .fall), (0.55, 22, .io), (1, 22, .io)])
        let ds: Double = p < 0.56 ? 1 : scalar(p, [(0.56, 0, .spring), (0.85, 1.1, .io), (1, 1, .io)])
        let dop: Double = p < 0.30 ? 1 : p < 0.55 ? 1 - Ease.fall.apply((p - 0.30) / 0.25) : p < 0.56 ? 0 : min(1, (p - 0.56) / 0.06)
        for (x, y) in drops {
            var d = body
            d.opacity = dop
            d.translateBy(x: x, y: y + (p < 0.56 ? dty : 0)); d.scaleBy(x: ds, y: ds); d.translateBy(x: -x, y: -y)
            var dp = Path()
            dp.move(to: CGPoint(x: x, y: y))
            dp.addQuadCurve(to: CGPoint(x: x, y: y + 12), control: CGPoint(x: x + 5, y: y + 8))
            dp.addQuadCurve(to: CGPoint(x: x, y: y), control: CGPoint(x: x - 5, y: y + 8))
            d.fill(dp, with: .color(paper)); d.stroke(dp, with: .color(ink), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
        }
    }
}
