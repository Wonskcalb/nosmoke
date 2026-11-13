import SwiftUI

struct SOSView: View {
    @EnvironmentObject var store: Store
    @State private var end: Date?
    @State private var big = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                TimelineView(.periodic(from: .now, by: 1)) { tl in
                    let left = Int(max(0, end?.timeIntervalSince(tl.date) ?? 600))
                    Text(String(format: "%02d:%02d", left / 60, left % 60))
                        .font(.system(size: 56, weight: .bold, design: .rounded)).monospacedDigit()
                }
                Circle().fill(.tint.opacity(0.3)).frame(width: 200, height: 200)
                    .scaleEffect(big ? 1 : 0.55)
                    .animation(.easeInOut(duration: 5).repeatForever(autoreverses: true), value: big)
                Text("Inspire, puis expire lentement. Une envie passe en 5 à 10 minutes.")
                    .multilineTextAlignment(.center).foregroundStyle(.secondary)
                Button("Lancer 10 minutes") { end = .now.addingTimeInterval(600) }.buttonStyle(.borderedProminent)
                VStack(alignment: .leading, spacing: 4) {
                    Text("• Un grand verre d'eau")
                    Text("• Marche, escaliers")
                    Text("• Brosse-toi les dents")
                    Text("• Occupe tes mains")
                }.font(.subheadline)
                HStack {
                    Button("+ Comprimé") { store.s.tablets.append(.now); store.tab = 0 }
                    Button("Noter l'envie") { store.tab = 2 }
                }.buttonStyle(.bordered)
                Spacer()
            }
            .padding()
            .navigationTitle("Envie ?")
            .onAppear { big = true }
        }
    }
}

struct JournalView: View {
    @EnvironmentObject var store: Store
    @State private var intensity = 3
    @State private var trigger = ""

    private struct Row: Identifiable { let id = UUID(); let date: Date; let label: String }

    private var rows: [Row] {
        (store.s.cravings.map { Row(date: $0.date, label: "Envie \($0.intensity)/5" + ($0.trigger.isEmpty ? "" : " · \($0.trigger)")) }
         + store.s.slips.map { Row(date: $0.date, label: "Dérapage" + ($0.trigger.isEmpty ? "" : " · \($0.trigger)")) })
            .sorted { $0.date > $1.date }
    }

    private var topTriggers: String {
        Dictionary(grouping: store.s.cravings.map(\.trigger).filter { !$0.isEmpty }, by: { $0 })
            .mapValues(\.count).sorted { $0.value > $1.value }.prefix(3)
            .map { "\($0.key) (\($0.value))" }.joined(separator: ", ")
    }

    private var peakHour: (hour: Int, count: Int)? {
        Dictionary(grouping: store.s.cravings, by: { Calendar.current.component(.hour, from: $0.date) })
            .mapValues(\.count).max { $0.value < $1.value }.map { ($0.key, $0.value) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Intensité", selection: $intensity) { ForEach(1...5, id: \.self) { Text("\($0)").tag($0) } }
                        .pickerStyle(.segmented)
                    Picker("Déclencheur", selection: $trigger) {
                        Text("—").tag("")
                        ForEach(triggers, id: \.self, content: Text.init)
                    }
                    Button("Noter une envie") {
                        store.s.cravings.append(Craving(date: .now, intensity: intensity, trigger: trigger)); reset()
                    }
                    Button("J'ai fumé", role: .destructive) {
                        store.s.slips.append(Slip(date: .now, trigger: trigger)); reset()
                    }
                } footer: {
                    Text("Un dérapage n'est pas un échec : note-le et repars.")
                }
                if store.s.cravings.count > 1 {
                    Section("Tes schémas") {
                        if !topTriggers.isEmpty { Text("Déclencheurs : \(topTriggers)") }
                        if let p = peakHour { Text("Heure la plus fréquente : \(p.hour) h (\(p.count) envies)") }
                    }
                }
                Section("Historique") {
                    if rows.isEmpty { Text("Rien pour l'instant.").foregroundStyle(.secondary) }
                    ForEach(rows.prefix(30)) { r in
                        HStack { Text(r.label); Spacer(); Text(r.date.formatted(date: .abbreviated, time: .shortened)).foregroundStyle(.secondary) }
                            .font(.subheadline)
                    }
                }
            }
            .navigationTitle("Journal")
        }
    }

    private func reset() { intensity = 3; trigger = "" }
}

struct SettingsView: View {
    @EnvironmentObject var store: Store

    private var patchTime: Binding<Date> {
        Binding(
            get: { Calendar.current.date(from: DateComponents(hour: store.s.patchHour, minute: store.s.patchMinute)) ?? .now },
            set: {
                let c = Calendar.current.dateComponents([.hour, .minute], from: $0)
                store.s.patchHour = c.hour ?? 8
                store.s.patchMinute = c.minute ?? 0
            })
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Dernière cigarette") {
                    DatePicker("Date", selection: $store.s.quitDate)
                }
                Section {
                    ForEach($store.s.plan) { $p in
                        HStack {
                            Stepper("\(p.mg) mg", value: $p.mg, in: 7...21, step: 7)
                            Stepper("\(p.days) j", value: $p.days, in: 1...120)
                        }
                    }
                    .onDelete { store.s.plan.remove(atOffsets: $0) }
                    Button("Ajouter un palier") { store.s.plan.append(PatchStep(mg: 7, days: 28)) }
                    DatePicker("Heure de pose", selection: patchTime, displayedComponents: .hourAndMinute)
                } header: {
                    Text("Plan de patch")
                } footer: {
                    Text("À vérifier avec ta notice et ton médecin. Les rappels se mettent à jour en quittant cet écran.")
                }
                Section("Comprimés") {
                    Stepper("Plafond : \(store.s.tabletCap) par jour", value: $store.s.tabletCap, in: 1...40)
                }
                Section("Avant l'arrêt") {
                    Stepper("\(store.s.cigsPerDay) cigarettes par jour", value: $store.s.cigsPerDay, in: 1...60)
                    HStack {
                        Text("Dépense par semaine")
                        TextField("€", value: $store.s.weeklySpend, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                    }
                }
                Section {
                    ShareLink("Résumé pour mon médecin", item: store.summary())
                }
            }
            .navigationTitle("Réglages")
            .onDisappear { Reminders.refresh(store.s) }
        }
    }
}
