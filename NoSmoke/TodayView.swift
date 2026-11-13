import SwiftUI

private let nbsp = "\u{00A0}"

private func euros(_ v: Double) -> String { String(format: "%.2f", v).replacingOccurrences(of: ".", with: ",") + nbsp + "€" }

private func elapsedText(_ t: TimeInterval) -> String {
    let m = max(0, Int(t / 60)), d = m / 1440, h = m % 1440 / 60, mm = m % 60
    if d > 0 { return "\(d)\(nbsp)j\(nbsp)\(h)\(nbsp)h" }
    if h > 0 { return "\(h)\(nbsp)h\(nbsp)" + String(format: "%02d", mm) }
    return "\(m)\(nbsp)min"
}

private func clock(_ d: Date) -> String {
    let c = Calendar.current.dateComponents([.hour, .minute], from: d)
    return String(format: "%d:%02d", c.hour ?? 0, c.minute ?? 0)
}

struct TodayView: View {
    @EnvironmentObject var store: Store
    @State private var showPatch = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { tl in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header(tl.date)
                    patchHero(tl.date)
                    divider.padding(.vertical, 24)
                    micro(tl.date)
                    divider.padding(.top, 24).padding(.bottom, 6)
                    plantRow(tl.date)
                    divider
                    lungsRow(tl.date)
                    divider
                    piggyRow(tl.date)
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
        }
        .screenBackground()
        .sheet(isPresented: $showPatch) { PatchSheet() }
    }

    private var divider: some View { Rectangle().fill(Jardin.line).frame(height: 1) }

    private func header(_ now: Date) -> some View {
        let s = store.s
        let cal = Calendar.current
        let day = (cal.dateComponents([.day], from: cal.startOfDay(for: s.quitDate), to: cal.startOfDay(for: now)).day ?? 0) + 1
        let el = now.timeIntervalSince(s.lastCig)
        let n = s.avoided(now)
        let date = now.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(Locale(identifier: "fr_FR")))
        return VStack(alignment: .leading, spacing: 0) {
            Text(date.prefix(1).uppercased() + date.dropFirst()).font(Jardin.sans(13)).tracking(0.26).foregroundStyle(Jardin.muted)
            Text("Jour \(max(day, 1))").font(Jardin.serif(52)).tracking(-0.5).foregroundStyle(Jardin.ink).padding(.top, 8)
            Text("\(elapsedText(el))\(nbsp)sans fumer").font(Jardin.serifItalic(22)).foregroundStyle(Jardin.ink).padding(.top, 6)
            Text("\(n) cigarette\(n > 1 ? "s" : "") laissée\(n > 1 ? "s" : "") de côté · \(euros(s.saved(now))) gardés")
                .font(Jardin.sans(15)).foregroundStyle(Jardin.muted).padding(.top, 12)
        }
    }

    private func patchHero(_ now: Date) -> some View {
        let s = store.s
        let last = s.patches.last
        let tired = last.map { now.timeIntervalSince($0.date) > 86400 } ?? false
        let mood: PatchMood = tired ? .tired : s.patchToday != nil ? .flying : .sleeping
        let info = stepInfo(plan: s.plan, start: s.quitDate, now: now)
        return VStack(spacing: 0) {
            SuperPatchView(mood: mood, autoplay: true, idle: true)
                .id(mood)
                .frame(width: 250)
                // The flying pose only uses y 26–112 of its 150-unit viewBox; the mockup crops the rest.
                .padding(.top, mood == .flying ? -8 : 22).padding(.bottom, mood == .flying ? -30 : 6)
            if let p = s.patchToday, !tired {
                Text("Posé à \(clock(p.date)) · \(p.site.lowercased())").font(Jardin.sans(13)).foregroundStyle(Jardin.ink)
            } else {
                Button { showPatch = true } label: {
                    Text(tired ? "Il a donné tout ce qu'il avait · change-le" : "Il t'attend · pose-le quand tu sors de la douche")
                        .font(Jardin.sans(13)).foregroundStyle(Jardin.terra).underline().multilineTextAlignment(.center)
                }
                .buttonStyle(.plain)
            }
            HStack(spacing: 6) {
                ForEach(0..<s.plan.count, id: \.self) { i in
                    let f: CGFloat = info.map { i < $0.index ? 1 : i == $0.index ? max(0.08, CGFloat($0.day) / CGFloat($0.days)) : 0 } ?? 1
                    Capsule().fill(Jardin.line).frame(height: 4)
                        .overlay(alignment: .leading) {
                            GeometryReader { g in Capsule().fill(Jardin.terra).frame(width: g.size.width * f) }
                        }
                }
            }
            .frame(width: 150).padding(.top, 12)
            Text(info.map { "Palier \($0.index + 1)/\(s.plan.count) · jour \($0.day) sur \($0.days)" } ?? "Programme terminé")
                .font(Jardin.sans(12)).foregroundStyle(Jardin.muted).padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
    }

    private func micro(_ now: Date) -> some View {
        let s = store.s
        let today = s.tabletsToday
        let cap = s.tabletCap
        let n = today.count
        let ready = today.max()?.addingTimeInterval(7200)
        let left = ready.map { $0.timeIntervalSince(now) } ?? 0
        let caption: String = n >= cap ? "Les bras pleins · c'est tout pour aujourd'hui"
            : n == 0 ? "Les bras libres"
            : n * 2 >= cap ? "Ça commence à peser · vas\u{2011}y doucement"
            : left > 0 ? "Tranquille · prochain possible à\(nbsp)\(clock(ready!))" : "Tranquille · tu peux en prendre un"
        return VStack(spacing: 0) {
            HStack(spacing: 18) {
                MicroView(count: n, cap: cap).frame(width: 116)
                VStack(alignment: .leading, spacing: 0) {
                    Text("\(n) comprimé\(n > 1 ? "s" : "") aujourd'hui").font(Jardin.serif(20)).foregroundStyle(Jardin.ink)
                    Text(caption).font(Jardin.sans(13)).foregroundStyle(Jardin.muted).padding(.top, 4)
                    if left > 0, n < cap { recharge(left: left).padding(.top, 14) }
                }
                Spacer(minLength: 0)
            }
            Button { store.s.tablets.append(.now) } label: {
                Text("J'ai pris un comprimé")
                    .font(Jardin.sans(16, weight: .semibold)).foregroundStyle(Jardin.paper)
                    .frame(maxWidth: .infinity).frame(height: 52)
                    .background(Jardin.terra, in: Capsule())
            }
            .buttonStyle(.plain).disabled(n >= cap).opacity(n >= cap ? 0.4 : 1)
            .padding(.top, 18)
            if n > 0 {
                Button("Annuler le dernier") {
                    if let l = today.max(), let i = store.s.tablets.lastIndex(of: l) { store.s.tablets.remove(at: i) }
                }
                .font(Jardin.sans(13)).foregroundStyle(Jardin.muted).padding(.top, 10)
            }
        }
    }

    private func recharge(left: TimeInterval) -> some View {
        let mins = Int((left / 60).rounded(.up))
        return HStack(spacing: 10) {
            ZStack {
                Circle().stroke(Jardin.line, lineWidth: 3)
                Circle().trim(from: 0, to: min(max(1 - left / 7200, 0), 1))
                    .stroke(Jardin.terra, style: StrokeStyle(lineWidth: 3, lineCap: .round)).rotationEffect(.degrees(-90))
                Text("\(mins)").font(Jardin.sans(11, weight: .semibold)).foregroundStyle(Jardin.ink)
            }
            .frame(width: 36, height: 36).padding(4)
            VStack(alignment: .leading, spacing: 0) {
                Text("en recharge")
                Text("encore \(mins)\(nbsp)min").fontWeight(.semibold).foregroundStyle(Jardin.ink)
            }
            .font(Jardin.sans(12)).foregroundStyle(Jardin.muted)
        }
    }

    private func plantRow(_ now: Date) -> some View {
        let days = now.timeIntervalSince(store.s.quitDate) / 86400
        let stage = days >= 30 ? 4 : days >= 14 ? 3 : days >= 3 ? 2 : 1
        let line = ["", "Ta pousse est sortie.", "Ta pousse se déploie.", "Ta plante prend de la hauteur.", "Ta plante est bien enracinée."][stage]
        return quiet(PlantView(stage: stage)) {
            Text(line + "\n").font(Jardin.sans(14.5)).foregroundStyle(Jardin.ink)
                + Text("Elle grandit avec chaque jour.").font(Jardin.sans(14.5)).foregroundStyle(Jardin.muted)
        }
    }

    private func lungsRow(_ now: Date) -> some View {
        let el = now.timeIntervalSince(store.s.lastCig)
        let next = milestones.first { el < $0.0 }
        let reached = milestones.filter { el >= $0.0 }.count
        let text = next.map { "Dans\(nbsp)\(elapsedText($0.0 - el))\(nbsp): " + $0.1.prefix(1).lowercased() + $0.1.dropFirst() + "." } ?? "Tous les repères sont atteints."
        return quiet(LungsView(level: Double(reached) / Double(milestones.count))) {
            VStack(alignment: .leading, spacing: 0) {
                Text(text).font(Jardin.sans(14.5)).foregroundStyle(Jardin.ink)
                HStack(spacing: 6) {
                    ForEach(0..<5, id: \.self) { Circle().fill($0 < reached ? Jardin.terra : Jardin.line).frame(width: 7, height: 7) }
                }
                .padding(.top, 8)
            }
        }
    }

    private func piggyRow(_ now: Date) -> some View {
        let saved = store.s.saved(now)
        return quiet(PiggyView()) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Objectif\(nbsp): un resto").font(Jardin.sans(14.5)).foregroundStyle(Jardin.ink)
                Capsule().fill(Jardin.line).frame(height: 4).padding(.top, 8)
                    .overlay(alignment: .leading) {
                        GeometryReader { g in Capsule().fill(Jardin.terra).frame(width: max(5, g.size.width * min(saved / 40, 1))) }
                            .padding(.top, 8)
                    }
                Text("\(euros(saved)) / 40\(nbsp)€").font(Jardin.sans(13)).foregroundStyle(Jardin.muted).padding(.top, 6)
            }
        }
    }

    private func quiet<C: View, T: View>(_ character: C, @ViewBuilder _ text: () -> T) -> some View {
        HStack(spacing: 16) {
            character.frame(width: 60)
            text().frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 14)
    }
}

struct PatchSheet: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var date = Date()
    @State private var site = ""

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Heure de pose", selection: $date, displayedComponents: .hourAndMinute)
                Picker("Endroit", selection: $site) { ForEach(sites, id: \.self, content: Text.init) }
            }
            .themedForm()
            .navigationTitle("Patch posé")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") { store.s.patches.append(PatchLog(date: date, site: site)); dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
        .onAppear {
            site = store.s.nextSite
            let scheduled = Calendar.current.date(bySettingHour: store.s.patchHour, minute: store.s.patchMinute, second: 0, of: .now) ?? .now
            date = min(scheduled, .now)
        }
    }
}
