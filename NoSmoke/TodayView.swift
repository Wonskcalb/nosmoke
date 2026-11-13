import SwiftUI

struct Card<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.caption.weight(.semibold)).textCase(.uppercase).foregroundStyle(.secondary)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
    }
}

struct TodayView: View {
    @EnvironmentObject var store: Store
    @State private var showPatch = false

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 60)) { tl in
                ScrollView {
                    VStack(spacing: 12) {
                        smoke(tl.date)
                        patch(tl.date)
                        tablets(tl.date)
                        health(tl.date)
                    }
                    .padding()
                }
            }
            .navigationTitle("Aujourd'hui")
            .sheet(isPresented: $showPatch) { PatchSheet() }
        }
    }

    private func smoke(_ now: Date) -> some View {
        let el = now.timeIntervalSince(store.lastCig)
        return Card(title: "Sans fumer") {
            Text(duration(el)).font(.system(size: 36, weight: .bold, design: .rounded))
            Text("\(store.avoided(now)) cigarette\(store.avoided(now) > 1 ? "s" : "") évitée\(store.avoided(now) > 1 ? "s" : "") · \(store.saved(now), format: .currency(code: "EUR")) économisés")
                .font(.subheadline).foregroundStyle(.secondary)
            if let next = milestones.first(where: { el < $0.0 }) {
                Text("Prochain repère à \(duration(next.0)) : \(next.1)").font(.footnote).foregroundStyle(.secondary)
            }
        }
    }

    private func patch(_ now: Date) -> some View {
        let info = stepInfo(plan: store.s.plan, start: store.s.quitDate, now: now)
        return Card(title: "Patch") {
            if let i = info {
                Text("\(i.mg) mg").font(.system(size: 36, weight: .bold, design: .rounded))
                Text("Jour \(i.day)/\(i.days) · \(i.left) j avant \(i.next.map { "\($0) mg" } ?? "la fin du programme")")
                    .font(.subheadline).foregroundStyle(.secondary)
            } else {
                Text("Programme terminé").font(.title2.bold())
            }
            if let p = store.patchToday {
                Label("Posé à \(p.date.formatted(date: .omitted, time: .shortened)) · \(p.site)", systemImage: "checkmark.circle.fill")
            } else {
                Button("Patch posé · \(store.nextSite)") { showPatch = true }.buttonStyle(.borderedProminent)
            }
        }
    }

    private func tablets(_ now: Date) -> some View {
        let today = store.tabletsToday
        let over = today.count >= store.s.tabletCap
        return Card(title: "Comprimés sublinguaux") {
            Text("\(today.count) / \(store.s.tabletCap)")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(over ? .red : .primary)
            if over {
                Text("Plafond atteint. Pas de prise de plus sans avis de ton médecin ou pharmacien.").font(.subheadline).foregroundStyle(.red)
            } else if let last = today.max() {
                Text("Dernière prise à \(last.formatted(date: .omitted, time: .shortened)) · prochaine à partir de \(last.addingTimeInterval(7200).formatted(date: .omitted, time: .shortened))")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            HStack {
                Button("+ Pris un comprimé") { store.s.tablets.append(.now) }.buttonStyle(.borderedProminent)
                Button("Annuler") { if let l = store.tabletsToday.max(), let i = store.s.tablets.lastIndex(of: l) { store.s.tablets.remove(at: i) } }
                    .buttonStyle(.bordered).disabled(today.isEmpty)
            }
        }
    }

    private func health(_ now: Date) -> some View {
        let el = now.timeIntervalSince(store.lastCig)
        return Card(title: "Repères de santé") {
            ForEach(milestones, id: \.0) { m in
                Label(m.1, systemImage: el >= m.0 ? "checkmark.circle.fill" : "circle")
                    .font(.subheadline).foregroundStyle(el >= m.0 ? .primary : .secondary)
            }
        }
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
            site = store.nextSite
            let scheduled = Calendar.current.date(bySettingHour: store.s.patchHour, minute: store.s.patchMinute, second: 0, of: .now) ?? .now
            date = min(scheduled, .now)
        }
    }
}
