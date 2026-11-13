import SwiftUI

struct JournalView: View {
    @EnvironmentObject var store: Store
    @State private var level = 1
    @State private var trigger = ""
    @State private var confirmation = ""

    private struct Row: Identifiable { let id = UUID(); let date: Date; let slip: Bool; let label: String }

    private var rows: [Row] {
        (store.s.cravings.map { Row(date: $0.date, slip: false, label: intensityLabels[$0.intensity - 1] + ($0.trigger.isEmpty ? "" : " · \($0.trigger)")) }
         + store.s.slips.map { Row(date: $0.date, slip: true, label: "Cigarette fumée" + ($0.trigger.isEmpty ? "" : " · \($0.trigger)")) })
            .sorted { $0.date > $1.date }
    }

    private var topTrigger: String? {
        Dictionary(grouping: store.s.cravings.map(\.trigger).filter { !$0.isEmpty }, by: { $0 })
            .mapValues(\.count).max { $0.value < $1.value }?.key
    }

    private var hourCounts: [Int] {
        var h = [Int](repeating: 0, count: 24)
        for c in store.s.cravings { h[Calendar.current.component(.hour, from: c.date)] += 1 }
        return h
    }

    private static let phrases = [
        "Café": "après le café", "Après repas": "après le repas", "Stress": "quand tu es sous tension",
        "Alcool": "avec un verre", "Ennui": "quand tu t'ennuies", "Social": "entre amis",
        "Pause": "pendant les pauses", "Conduite": "au volant",
    ]

    private var insight: String {
        guard store.s.cravings.count >= 2, let t = topTrigger else {
            return "Après quelques envies notées, tu verras ici ce qui les déclenche et l'heure où elles arrivent le plus."
        }
        return "Tes envies arrivent surtout \(Self.phrases[t] ?? "autour de « \(t) »")."
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Journal").font(Jardin.serif(34)).foregroundStyle(Jardin.ink).padding(.top, 6)
                Text("Une envie, là\u{202F}?").font(Jardin.serif(26)).foregroundStyle(Jardin.ink).padding(.top, 22)
                clouds
                Text("Ce qui l'a amenée").font(Jardin.sans(13, weight: .semibold)).foregroundStyle(Jardin.muted).padding(.top, 26)
                FlowLayout(spacing: 8) {
                    ForEach(triggers, id: \.self) { t in
                        ChoiceChip(title: t, icon: triggerIcons[t], selected: trigger == t) { trigger = trigger == t ? "" : t }
                    }
                }
                .padding(.top, 12)

                Button("Noter l'envie") {
                    store.s.cravings.append(Craving(date: .now, intensity: level + 1, trigger: trigger))
                    confirm("Envie notée. Elle va passer.")
                }
                .buttonStyle(PrimaryButtonStyle()).frame(maxWidth: .infinity).padding(.top, 24)

                Button {
                    store.s.slips.append(Slip(date: .now, trigger: trigger))
                    confirm("C'est noté. On repart, le compteur continue avec toi.")
                } label: {
                    Text("J'ai fumé une cigarette").font(Jardin.sans(15, weight: .medium)).foregroundStyle(Jardin.muted)
                        .underline(true, color: Jardin.muted)
                }
                .buttonStyle(.plain).frame(maxWidth: .infinity).padding(.top, 18)

                if !confirmation.isEmpty {
                    Text(confirmation).font(Jardin.sans(14)).foregroundStyle(Jardin.ink)
                        .padding(.horizontal, 14).padding(.vertical, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Jardin.paper, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Jardin.line))
                        .padding(.top, 10)
                }

                Rectangle().fill(Jardin.line).frame(height: 1).padding(.vertical, 24)
                Text("Ce que tu apprends").font(Jardin.serif(20)).foregroundStyle(Jardin.ink)
                HourChart(counts: hourCounts).padding(.top, 14)
                Text(insight).font(Jardin.sans(15)).foregroundStyle(store.s.cravings.count < 2 ? Jardin.muted : Jardin.ink).padding(.top, 10)

                Rectangle().fill(Jardin.line).frame(height: 1).padding(.vertical, 24)
                Text("Historique").font(Jardin.serif(20)).foregroundStyle(Jardin.ink)
                if rows.isEmpty {
                    Text("Rien pour l'instant.").font(Jardin.sans(14)).foregroundStyle(Jardin.muted).padding(.top, 8)
                }
                ForEach(rows.prefix(30)) { r in
                    HStack(spacing: 10) {
                        Text(r.label).foregroundStyle(r.slip ? Jardin.muted : Jardin.ink)
                        Spacer()
                        Text(r.date.formatted(date: .abbreviated, time: .shortened)).foregroundStyle(Jardin.muted)
                    }
                    .font(Jardin.sans(14)).padding(.vertical, 12).hairline()
                }
            }
            .padding(.horizontal, 24).padding(.bottom, 32)
        }
        .screenBackground()
        .sensoryFeedback(.success, trigger: store.s.cravings.count + store.s.slips.count)
    }

    private var clouds: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(0..<5, id: \.self) { i in
                let w = CGFloat(44 + 8 * i)
                VStack(spacing: 0) {
                    CravingCloud(level: i)
                        .frame(width: w)
                        .simultaneousGesture(TapGesture().onEnded { level = i })
                        .frame(height: 64, alignment: .bottom)
                    Text(level == i ? intensityLabels[i] : "")
                        .font(Jardin.sans(13, weight: .semibold)).foregroundStyle(Jardin.terra)
                        .fixedSize().frame(width: w, height: 20).padding(.top, 16)
                }
                if i < 4 { Spacer(minLength: 0) }
            }
        }
        .padding(.top, 20)
    }

    private func confirm(_ text: String) {
        confirmation = text
        level = 1
        trigger = ""
    }
}

private struct HourChart: View {
    let counts: [Int]

    var body: some View {
        Canvas { ctx, size in
            let s = size.width / 342
            ctx.scaleBy(x: s, y: s)
            let peak = counts.max() ?? 0
            let peakHour = peak > 1 ? counts.firstIndex(of: peak) : nil
            for (h, v) in counts.enumerated() {
                let ht: CGFloat = v == 0 ? 2 : CGFloat(v) / CGFloat(peak) * 56
                let color = h == peakHour ? Jardin.terra : v > 0 ? Jardin.ink : Jardin.line
                ctx.fill(Path(roundedRect: CGRect(x: 4 + CGFloat(h) * 14, y: 74 - ht, width: 6, height: ht), cornerRadius: 2), with: .color(color))
            }
            var base = Path(); base.move(to: CGPoint(x: 0, y: 76.5)); base.addLine(to: CGPoint(x: 342, y: 76.5))
            ctx.stroke(base, with: .color(Jardin.line), lineWidth: 1)
            let labels: [(CGFloat, String, UnitPoint)] = [(0, "0 h", .leading), (7 + 6 * 14, "6 h", .center), (7 + 12 * 14, "12 h", .center), (7 + 18 * 14, "18 h", .center), (342, "24 h", .trailing)]
            for (x, l, a) in labels {
                ctx.draw(Text(l).font(Jardin.sans(11)).foregroundColor(Jardin.muted), at: CGPoint(x: x, y: 94), anchor: a)
            }
            if let p = peakHour {
                ctx.draw(Text("\(p) h").font(Jardin.sans(11, weight: .semibold)).foregroundColor(Jardin.terra),
                         at: CGPoint(x: 7 + CGFloat(p) * 14, y: 74 - 56 - 6), anchor: .bottom)
            }
        }
        .aspectRatio(342.0 / 100.0, contentMode: .fit)
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(proposal.width ?? 0, subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for (sv, p) in zip(subviews, arrange(bounds.width, subviews).points) {
            sv.place(at: CGPoint(x: bounds.minX + p.x, y: bounds.minY + p.y), proposal: .unspecified)
        }
    }

    private func arrange(_ width: CGFloat, _ subviews: Subviews) -> (points: [CGPoint], size: CGSize) {
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0, maxX: CGFloat = 0
        var pts: [CGPoint] = []
        for sv in subviews {
            let s = sv.sizeThatFits(.unspecified)
            if x > 0, x + s.width > width { x = 0; y += rowH + spacing; rowH = 0 }
            pts.append(CGPoint(x: x, y: y))
            x += s.width + spacing; rowH = max(rowH, s.height); maxX = max(maxX, x - spacing)
        }
        return (pts, CGSize(width: maxX, height: y + rowH))
    }
}
