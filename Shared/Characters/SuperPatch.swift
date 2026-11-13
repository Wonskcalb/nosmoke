import SwiftUI

enum PatchMood { case sleeping, flying, tired }

struct SuperPatchView: View {
    var mood: PatchMood
    var autoplay = false
    var idle = false

    @State private var trigger = 0
    @State private var playStart: Date?
    @State private var playing = false
    @State private var t0 = Date()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var idleOn: Bool { idle && mood == .flying && !reduceMotion }

    var body: some View {
        TimelineView(.animation(paused: !(playing || idleOn))) { tl in
            Canvas { ctx, size in
                ctx.concatenate(ViewBox(width: 220, height: 150).transform(in: size))
                let now = tl.date
                let el = playStart.map { now.timeIntervalSince($0) } ?? 99
                switch mood {
                case .flying:
                    ctx.translateBy(x: 0, y: 5)
                    drawFly(&ctx, el: el, idleOn: idleOn, ti: now.timeIntervalSince(t0), capeIdleStart: playStart.map { $0.timeIntervalSince(t0) + 1.5 } ?? 0)
                case .sleeping: drawSleep(&ctx, el: el)
                case .tired: drawTired(&ctx, el: el)
                }
            }
        }
        .aspectRatio(220.0 / 150.0, contentMode: .fit)
        .accessibilityElement()
        .accessibilityLabel(mood == .flying ? "Super-patch en plein vol" : mood == .sleeping ? "Super-patch endormi" : "Super-patch fatigué sur un banc")
        .replayOnTap(autoplay: autoplay, trigger: $trigger)
        .task(id: trigger) {
            guard trigger > 0 else { return }
            playStart = Date()
            playing = true
            try? await Task.sleep(for: .seconds(1.7))
            playing = false
        }
    }
}

// MARK: - Easing and interpolation

private struct Bez {
    let a, b, c, d: Double
    func callAsFunction(_ x: Double) -> Double {
        if x <= 0 { return 0 }
        if x >= 1 { return 1 }
        var lo = 0.0, hi = 1.0
        for _ in 0..<32 {
            let s = (lo + hi) / 2
            let xs = 3 * (1 - s) * (1 - s) * s * a + 3 * (1 - s) * s * s * c + s * s * s
            if xs < x { lo = s } else { hi = s }
        }
        let s = (lo + hi) / 2
        return 3 * (1 - s) * (1 - s) * s * b + 3 * (1 - s) * s * s * d + s * s * s
    }
}

private let io = Bez(a: 0.45, b: 0, c: 0.3, d: 1)
private let outE = Bez(a: 0.2, b: 0.7, c: 0.3, d: 1)
private let springE = Bez(a: 0.34, b: 1.56, c: 0.64, d: 1)
private let smil = Bez(a: 0.42, b: 0, c: 0.3, d: 1)

private struct K {
    let t: Double
    let v: [Double]
    var e: Bez = io
}

private func clamp(_ x: Double) -> Double { min(max(x, 0), 1) }

private func kf(_ ks: [K], _ p: Double) -> [Double] {
    if p <= ks[0].t { return ks[0].v }
    for i in 0..<ks.count - 1 where p < ks[i + 1].t {
        let u = ks[i].e((p - ks[i].t) / (ks[i + 1].t - ks[i].t))
        return zip(ks[i].v, ks[i + 1].v).map { $0 + ($1 - $0) * u }
    }
    return ks[ks.count - 1].v
}

private func morph(_ frames: [[Double]], _ times: [Double], dur: Double, delay: Double, el: Double) -> [Double] {
    kf(zip(times, frames).map { K(t: $0, v: $1, e: smil) }, clamp((el - delay) / dur))
}

private func nums(_ s: String) -> [Double] {
    var out: [Double] = [], cur = ""
    func flush() { if let d = Double(cur) { out.append(d) }; cur = "" }
    for ch in s {
        if ch.isNumber || ch == "." { cur.append(ch) }
        else if ch == "-" { flush(); cur = "-" }
        else { flush() }
    }
    flush()
    return out
}

private func tf(_ tx: Double = 0, _ ty: Double = 0, _ sx: Double = 1, _ sy: Double = 1, _ op: Double = 1) -> [Double] { [tx, ty, sx, sy, op] }

private extension GraphicsContext {
    mutating func xf(_ ox: Double, _ oy: Double, _ v: [Double], _ body: (inout GraphicsContext) -> Void) {
        drawLayer { l in
            l.opacity = v.count > 4 ? v[4] : 1
            l.translateBy(x: ox + v[0], y: oy + v[1])
            l.scaleBy(x: v[2], y: v[3])
            l.translateBy(x: -ox, y: -oy)
            body(&l)
        }
    }

    func ink(_ p: Path, _ c: Color = Jardin.ink, w: CGFloat = 2, dash: [CGFloat] = []) {
        stroke(p, with: .color(c), style: StrokeStyle(lineWidth: w, lineCap: .round, lineJoin: .round, dash: dash))
    }

    func shape(_ p: Path, fill f: Color) {
        fill(p, with: .color(f))
        ink(p)
    }

    func dot(_ x: Double, _ y: Double, _ r: Double = 3, _ c: Color = Jardin.ink) {
        fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r)), with: .color(c))
    }

    func limb(_ f: [Double]) {
        var p = Path()
        p.move(to: CGPoint(x: f[0], y: f[1]))
        p.addQuadCurve(to: CGPoint(x: f[4], y: f[5]), control: CGPoint(x: f[2], y: f[3]))
        ink(p)
    }

    func hand(_ f: [Double]) {
        dot(f[4], f[5], 4.5)
        dot(f[4], f[5], 2.5, Jardin.paper)
    }

    func line(_ pts: [(Double, Double)], _ c: Color = Jardin.ink, w: CGFloat = 2) {
        var p = Path()
        p.move(to: CGPoint(x: pts[0].0, y: pts[0].1))
        for q in pts.dropFirst() { p.addLine(to: CGPoint(x: q.0, y: q.1)) }
        ink(p, c, w: w)
    }
}

private func rr(_ x: Double, _ y: Double, _ w: Double, _ h: Double, _ r: Double) -> Path {
    Path(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerRadius: r)
}

private func qpath(_ x0: Double, _ y0: Double, _ cx: Double, _ cy: Double, _ x1: Double, _ y1: Double) -> Path {
    var p = Path()
    p.move(to: CGPoint(x: x0, y: y0))
    p.addQuadCurve(to: CGPoint(x: x1, y: y1), control: CGPoint(x: cx, y: cy))
    return p
}

private func halfDisc(_ cx: Double, _ cy: Double, _ r: Double) -> Path {
    let k = r * 0.5523
    var p = Path()
    p.move(to: CGPoint(x: cx + r, y: cy))
    p.addCurve(to: CGPoint(x: cx, y: cy + r), control1: CGPoint(x: cx + r, y: cy + k), control2: CGPoint(x: cx + k, y: cy + r))
    p.addCurve(to: CGPoint(x: cx - r, y: cy), control1: CGPoint(x: cx - k, y: cy + r), control2: CGPoint(x: cx - r, y: cy + k))
    p.closeSubpath()
    return p
}

// MARK: - Flying

private let flyCapeStrings = [
    "M86 44C66 36 48 44 28 38C34 50 30 62 38 72C54 68 68 74 86 70Z",
    "M86 44C64 42 40 46 14 46C20 52 18 58 22 64C44 64 66 68 86 70Z",
    "M86 44C70 30 52 40 30 30C36 44 32 58 40 66C54 60 70 72 86 70Z",
    "M86 44C66 44 50 30 26 40C32 52 28 64 36 76C52 76 66 66 86 70Z",
    "M86 44C68 38 48 40 28 34C34 48 30 60 38 70C54 70 68 70 86 70Z",
    "M86 44C66 38 48 42 28 40C34 52 30 63 38 73C54 67 68 74 86 70Z",
    "M86 44C66 36 48 44 28 38C34 50 30 62 38 72C54 68 68 74 86 70Z",
].map(nums)

private let flyCapeIdle = [
    "M86 44C66 36 48 44 28 38C34 50 30 62 38 72C54 68 68 74 86 70Z",
    "M86 44C66 38 48 42 28 39C34 51 30 62 38 72C54 68 68 73 86 70Z",
    "M86 44C66 35 48 45 28 37C34 49 30 61 37 71C54 69 68 74 86 70Z",
    "M86 44C66 36 48 44 28 38C34 50 30 62 38 72C54 68 68 74 86 70Z",
].map(nums)

private func capePath(_ n: [Double]) -> Path {
    var p = Path()
    p.move(to: CGPoint(x: n[0], y: n[1]))
    for i in 0..<3 {
        let b = 2 + i * 6
        p.addCurve(to: CGPoint(x: n[b + 4], y: n[b + 5]), control1: CGPoint(x: n[b], y: n[b + 1]), control2: CGPoint(x: n[b + 2], y: n[b + 3]))
    }
    p.closeSubpath()
    return p
}

private let flyArm: [[Double]] = [[166, 56, 178, 51, 191, 44], [166, 56, 180, 56, 195, 51], [166, 56, 178, 46, 191, 36], [166, 56, 179, 53, 192, 47], [166, 56, 178, 51, 191, 44]]
private let flyLegL: [[Double]] = [[100, 88, 94, 98, 84, 102], [100, 88, 90, 94, 78, 96], [100, 88, 98, 100, 88, 106], [100, 88, 93, 97, 83, 101], [100, 88, 94, 98, 84, 102]]
private let flyLegR: [[Double]] = [[114, 88, 108, 100, 98, 104], [114, 88, 104, 96, 92, 98], [114, 88, 112, 102, 102, 108], [114, 88, 107, 99, 97, 103], [114, 88, 108, 100, 98, 104]]
private let flyT: [Double] = [0, 0.25, 0.5, 0.72, 1]

private func drawFly(_ c: inout GraphicsContext, el: Double, idleOn: Bool, ti: Double, capeIdleStart: Double) {
    let N = Jardin.line
    if !idleOn {
        let p = clamp(el / 0.9)
        let u = p < 0.25 ? 0 : Bez(a: 0.3, b: 0, c: 0.2, d: 1)((p - 0.25) / 0.75)
        c.xf(0, 0, tf(30 * (1 - u), 0, 1, 1, u)) { l in
            var s = Path()
            for (x, y, w) in [(6.0, 52.0, 14.0), (12, 62, 12), (18, 86, 16)] {
                s.move(to: CGPoint(x: x, y: y)); s.addLine(to: CGPoint(x: x + w, y: y))
            }
            l.ink(s, N)
        }
    } else {
        for (x, y, w, delay) in [(34.0, 52.0, 14.0, 1.2), (40, 64, 12, 2.0), (30, 80, 16, 2.8)] {
            let local = ti - delay
            guard local >= 0 else { continue }
            let p = local.truncatingRemainder(dividingBy: 2.4) / 2.4
            let e = Bez(a: 0.3, b: 0, c: 0.4, d: 1)
            let fade = e(max(0, (p - 0.25) / 0.75))
            let op = p < 0.25 ? 0.3 * e(p / 0.25) : 0.3 * (1 - fade)
            c.xf(0, 0, tf(-26 * fade, 0, 1, 1, op)) { l in
                l.ink(qpath(x, y, x, y, x + w, y), w: 1.5)
            }
        }
    }

    var hover = 0.0
    if idleOn, ti > 1.2 {
        let cyc = (ti - 1.2) / 3.2
        let k = Int(cyc), f = cyc - Double(k)
        hover = -1.5 * Bez(a: 0.45, b: 0, c: 0.55, d: 1)(k % 2 == 0 ? f : 1 - f)
    }

    let entering = kf([
        K(t: 0, v: tf(-80, 8, 1.18, 0.86), e: outE),
        K(t: 0.45, v: tf(5, -3, 0.93, 1.07), e: springE),
        K(t: 0.7, v: tf(-1, 1, 1.02, 0.98)),
        K(t: 1, v: tf()),
    ], clamp(el / 1.1))
    let pe = clamp(el / 1.1)
    let opacity = pe < 0.12 ? outE(pe / 0.12) : 1
    let v = [entering[0], entering[1] + hover, entering[2], entering[3], opacity]

    var cape = morph(flyCapeStrings, [0, 0.15, 0.38, 0.55, 0.72, 0.86, 1], dur: 1.5, delay: 0, el: el)
    if idleOn, ti >= capeIdleStart {
        let p = ((ti - capeIdleStart).truncatingRemainder(dividingBy: 3.6)) / 3.6
        cape = kf(zip([0, 0.35, 0.7, 1], flyCapeIdle).map { K(t: $0, v: $1, e: Bez(a: 0.45, b: 0, c: 0.55, d: 1)) }, p)
    }
    let legL = morph(flyLegL, flyT, dur: 1.3, delay: 0.06, el: el)
    let legR = morph(flyLegR, flyT, dur: 1.3, delay: 0.1, el: el)
    let arm = morph(flyArm, flyT, dur: 1.3, delay: 0.04, el: el)
    let bp = clamp(el / 1.4)
    let blink = kf([K(t: 0, v: [1]), K(t: 0.72, v: [1]), K(t: 0.78, v: [0.1]), K(t: 0.86, v: [1]), K(t: 1, v: [1])], bp)[0]

    c.xf(126, 65, v) { l in
        l.shape(capePath(cape), fill: Jardin.terra)
        l.limb(legL); l.limb(legR); l.limb(arm)
        l.shape(rr(80, 37, 92, 56, 16), fill: Jardin.paper)
        l.ink(rr(86, 43, 80, 44, 11), N, w: 1.5, dash: [3, 4])
        l.hand(arm)
        l.xf(148, 60, tf(0, 0, 1, blink)) { b in b.dot(140, 60); b.dot(156, 60) }
        l.ink(qpath(140, 70, 148, 76, 156, 70))
    }
}

// MARK: - Sleeping

private let sleepCape: [[Double]] = [
    nums("M88 52L68 130Q110 138 152 130L132 52Z"), nums("M88 52L69 131Q110 141 151 131L132 52Z"),
    nums("M88 52L66 128Q110 132 154 128L132 52Z"), nums("M88 52L68 131Q110 139 152 131L132 52Z"),
    nums("M88 52L68 130Q110 138 152 130L132 52Z"),
]
private let sleepArm: [[Double]] = [[86, 90, 74, 96, 70, 108], [86, 91, 75, 99, 71, 110], [86, 88, 72, 92, 67, 104], [86, 90, 73, 95, 69, 107], [86, 90, 74, 96, 70, 108]]
private let sleepT: [Double] = [0, 0.2, 0.55, 0.78, 1]

private func drawSleep(_ c: inout GraphicsContext, el: Double) {
    let N = Jardin.line
    c.line([(40, 141), (180, 141)], N)

    let bp = clamp(el / 1.5)
    let body = kf([
        K(t: 0, v: tf()),
        K(t: 0.2, v: tf(0, 0, 1.03, 0.96), e: springE),
        K(t: 0.55, v: tf(0, 0, 0.97, 1.05)),
        K(t: 0.8, v: tf(0, 0, 1.01, 0.99)),
        K(t: 1, v: tf()),
    ], bp)
    let mouth = kf([K(t: 0, v: [1]), K(t: 0.25, v: [1]), K(t: 0.55, v: [1.35]), K(t: 1, v: [1])], bp)[0]
    let cp = morph(sleepCape, sleepT, dur: 1.5, delay: 0.03, el: el)
    let aL = morph(sleepArm, sleepT, dur: 1.5, delay: 0.05, el: el)
    let aR = morph(sleepArm.map { [220 - $0[0], $0[1], 220 - $0[2], $0[3], 220 - $0[4], $0[5]] }, sleepT, dur: 1.5, delay: 0.08, el: el)

    c.xf(110, 140, body) { l in
        var cape = Path()
        cape.move(to: CGPoint(x: cp[0], y: cp[1]))
        cape.addLine(to: CGPoint(x: cp[2], y: cp[3]))
        cape.addQuadCurve(to: CGPoint(x: cp[6], y: cp[7]), control: CGPoint(x: cp[4], y: cp[5]))
        cape.addLine(to: CGPoint(x: cp[8], y: cp[9]))
        cape.closeSubpath()
        l.shape(cape, fill: Jardin.terra)
        l.ink(qpath(98, 118, 96, 127, 96, 135)); l.ink(qpath(122, 118, 124, 127, 124, 135))
        for x in [93.0, 127] {
            l.shape(Path(ellipseIn: CGRect(x: x - 6, y: 134, width: 12, height: 6)), fill: Jardin.paper)
        }
        l.limb(aL); l.limb(aR); l.hand(aL); l.hand(aR)
        l.shape(rr(80, 44, 60, 80, 16), fill: Jardin.paper)
        l.ink(rr(86, 50, 48, 68, 11), N, w: 1.5, dash: [3, 4])
        l.ink(qpath(96, 80, 100, 84, 104, 80)); l.ink(qpath(116, 80, 120, 84, 124, 80))
        l.xf(110, 94, tf(0, 0, mouth, mouth)) { m in
            m.ink(Path(ellipseIn: CGRect(x: 107.5, y: 91.5, width: 5, height: 5)))
        }
    }

    for (text, size, x, y, ox, oy, delay) in [("z", 20.0, 148.0, 46.0, 154.0, 40.0, 0.35), ("z", 14.0, 163.0, 30.0, 167.0, 26.0, 0.45)] {
        let v = kf([K(t: 0, v: tf(-8, 10, 0.4, 0.4, 0), e: springE), K(t: 1, v: tf())], clamp((el - delay) / 0.85))
        c.xf(ox, oy, v) { l in
            l.draw(Text(text).font(Jardin.serifItalic(size)).foregroundColor(Jardin.ink), at: CGPoint(x: x, y: y + size * 0.22), anchor: .bottomLeading)
        }
    }
}

// MARK: - Tired

private let tiredHair: [[Double]] = [
    nums("M104 41q-2-6 2-8M110 41q0-7 4-8M116 41q2-6 6-5"), nums("M104 41q-1-6 3-8M110 41q1-7 5-7M116 41q3-6 7-4"),
    nums("M104 41q-4-5-1-8M110 41q-2-6 1-8M116 41q0-6 3-6"), nums("M104 41q-1-6 3-8M110 41q1-7 5-8M116 41q3-6 7-5"),
    nums("M104 41q-2-6 2-8M110 41q0-7 4-8M116 41q2-6 6-5"),
]
private let tiredMouth: [[Double]] = [nums("M104 87Q110 90 116 87"), nums("M104 87Q110 90 116 87"), nums("M106 87Q110 92 114 87"), nums("M104 87Q110 90 116 87")]
private let tiredAR: [[Double]] = [[134, 80, 144, 82, 151, 90], [133.5, 77, 143, 79, 151, 90], [134.7, 84.5, 145, 86, 151, 90], [133.8, 78.7, 144, 81, 151, 90], [134, 80, 144, 82, 151, 90]]
private let tiredAL: [[Double]] = [[86, 80, 80, 90, 78, 100], [86, 80, 82, 89, 80, 98], [86, 80, 78, 92, 75, 102], [86, 80, 81, 90, 79, 99], [86, 80, 80, 90, 78, 100]]
private let tiredT: [Double] = [0, 0.22, 0.52, 0.75, 1]

private func drawTired(_ c: inout GraphicsContext, el: Double) {
    let N = Jardin.line, M = Jardin.muted
    let p = clamp(el / 1.5)
    let sigh = kf([
        K(t: 0, v: tf()),
        K(t: 0.22, v: tf(0, -2, 0.98, 1.03), e: Bez(a: 0.5, b: 0, c: 0.2, d: 1)),
        K(t: 0.52, v: tf(0, 3, 1.03, 0.95), e: springE),
        K(t: 0.75, v: tf(0, -1, 0.99, 1.01)),
        K(t: 1, v: tf()),
    ], p)
    let blink = kf([K(t: 0, v: [1]), K(t: 0.42, v: [1]), K(t: 0.54, v: [0.1]), K(t: 0.72, v: [0.1]), K(t: 0.86, v: [1]), K(t: 1, v: [1])], p)[0]
    let puffT = Bez(a: 0.25, b: 0.8, c: 0.4, d: 1)
    let puffOp: Double = p < 0.45 ? 0 : p < 0.62 ? puffT((p - 0.45) / 0.17) : 1 - puffT((p - 0.62) / 0.38)
    let pu = p < 0.45 ? 0 : puffT((p - 0.45) / 0.55)
    let puff = tf(-14 * pu, 0, 0.6 + 0.6 * pu, 0.6 + 0.6 * pu, puffOp)
    let aR = morph(tiredAR, tiredT, dur: 1.5, delay: 0, el: el)
    let aL = morph(tiredAL, tiredT, dur: 1.5, delay: 0.08, el: el)
    let hair = morph(tiredHair, [0, 0.28, 0.6, 0.82, 1], dur: 1.5, delay: 0.06, el: el)
    let m = morph(tiredMouth, [0, 0.3, 0.55, 1], dur: 1.5, delay: 0, el: el)

    c.line([(30, 143), (190, 143)], N)
    c.line([(58, 118), (58, 142)]); c.line([(170, 118), (170, 142)])

    c.xf(110, 110, sigh) { l in
        var cape = Path()
        cape.move(to: CGPoint(x: 90, y: 50))
        for q in [(70.0, 116.0), (150, 116), (130, 50)] { cape.addLine(to: CGPoint(x: q.0, y: q.1)) }
        cape.closeSubpath()
        l.shape(cape, fill: Jardin.terra)
    }
    c.fill(rr(44, 110, 132, 8, 3), with: .color(N))
    c.stroke(rr(44, 110, 132, 8, 3), with: .color(Jardin.ink), style: StrokeStyle(lineWidth: 2, lineJoin: .round))
    var cane = Path()
    cane.move(to: CGPoint(x: 152, y: 142)); cane.addLine(to: CGPoint(x: 152, y: 78))
    cane.addQuadCurve(to: CGPoint(x: 160, y: 68), control: CGPoint(x: 152, y: 68))
    cane.addQuadCurve(to: CGPoint(x: 168, y: 75), control: CGPoint(x: 168, y: 68))
    c.ink(cane, w: 2.5)

    c.xf(110, 110, sigh) { l in
        l.ink(qpath(98, 108, 97, 118, 98, 127)); l.ink(qpath(122, 108, 123, 118, 122, 127))
        for x in [95.0, 125] {
            l.shape(Path(ellipseIn: CGRect(x: x - 5.5, y: 127, width: 11, height: 6)), fill: Jardin.paper)
        }
        l.limb(aL); l.hand(aL)
    }
    c.limb(aR)

    c.xf(110, 110, sigh) { l in
        l.shape(rr(82, 42, 56, 68, 14), fill: Jardin.paper)
        l.ink(rr(88, 48, 44, 56, 10), N, w: 1.5, dash: [3, 4])
        var w = Path()
        w.move(to: CGPoint(x: 100, y: 60))
        for _ in 0..<2 {
            let cur = w.currentPoint!
            w.addQuadCurve(to: CGPoint(x: cur.x + 5, y: cur.y), control: CGPoint(x: cur.x + 2.5, y: cur.y - 2))
            let c2 = w.currentPoint!
            w.addQuadCurve(to: CGPoint(x: c2.x + 5, y: c2.y), control: CGPoint(x: c2.x + 2.5, y: c2.y + 2))
        }
        l.ink(w, M, w: 1.4)
        var h = Path()
        for i in 0..<3 {
            let n = Array(hair[i * 6..<i * 6 + 6])
            h.move(to: CGPoint(x: n[0], y: n[1]))
            h.addQuadCurve(to: CGPoint(x: n[0] + n[4], y: n[1] + n[5]), control: CGPoint(x: n[0] + n[2], y: n[1] + n[3]))
        }
        l.ink(h, M, w: 1.4)
        l.xf(110, 72, tf(0, 0, 1, blink)) { b in
            b.fill(halfDisc(100, 72, 4), with: .color(Jardin.ink)); b.fill(halfDisc(120, 72, 4), with: .color(Jardin.ink))
        }
        l.line([(96, 72), (104, 72)]); l.line([(116, 72), (124, 72)])
        l.ink(qpath(m[0], m[1], m[2], m[3], m[4], m[5]))
    }
    c.hand(aR)
    c.xf(76, 84, puff) { l in
        var s = Path()
        s.move(to: CGPoint(x: 64, y: 84))
        s.addQuadCurve(to: CGPoint(x: 70, y: 84), control: CGPoint(x: 67, y: 81))
        s.addQuadCurve(to: CGPoint(x: 76, y: 84), control: CGPoint(x: 73, y: 87))
        l.ink(s, M, w: 1.5)
    }
}
