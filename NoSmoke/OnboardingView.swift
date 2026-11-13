import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var store: Store
    @State private var d: AppState
    @State private var page = 0
    @State private var startMg = 21
    @FocusState private var editingSpend: Bool

    private let pages = 5

    init(initial: AppState) {
        _d = State(initialValue: initial)
        _startMg = State(initialValue: initial.plan.first?.mg ?? 21)
    }

    private var patchTime: Binding<Date> {
        Binding(
            get: { Calendar.current.date(from: DateComponents(hour: d.patchHour, minute: d.patchMinute)) ?? .now },
            set: {
                let c = Calendar.current.dateComponents([.hour, .minute], from: $0)
                d.patchHour = c.hour ?? 8
                d.patchMinute = c.minute ?? 0
            })
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                ForEach(0..<pages, id: \.self) { i in
                    Capsule().fill(i <= page ? Jardin.terra : Jardin.line).frame(height: 4)
                }
            }
            .padding(.horizontal, 24).padding(.top, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    switch page {
                    case 0: welcome
                    case 1: lastCigarette
                    case 2: before
                    case 3: patches
                    default: tablets
                    }
                }
                .padding(.horizontal, 24).padding(.top, 28).padding(.bottom, 24)
                .id(page)
                .transition(.push(from: .trailing))
            }
            .scrollDismissesKeyboard(.interactively)

            VStack(spacing: 12) {
                Button(page == pages - 1 ? "C'est parti" : "Continuer") { next() }
                    .buttonStyle(PrimaryButtonStyle())
                    .frame(maxWidth: .infinity)
                if page > 0 {
                    Button("Retour") { withAnimation(Jardin.spring) { page -= 1 } }
                        .font(Jardin.sans(15)).foregroundStyle(Jardin.muted)
                }
            }
            .padding(.horizontal, 24).padding(.bottom, 16)
        }
        .screenBackground()
        .foregroundStyle(Jardin.ink)
        .toolbar {
            // The decimal pad has no return key, so it needs its own way out.
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("OK") { editingSpend = false }.fontWeight(.semibold)
            }
        }
    }

    private func next() {
        editingSpend = false
        guard page == pages - 1 else { return withAnimation(Jardin.spring) { page += 1 } }
        d.onboarded = true
        store.s = d
        Reminders.refresh(d)
    }

    private func title(_ t: String, _ sub: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(t).font(Jardin.serif(32))
            Text(sub).font(Jardin.sans(16)).foregroundStyle(Jardin.muted).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func hero<V: View>(_ v: V, width: CGFloat) -> some View {
        v.frame(width: width).frame(maxWidth: .infinity).padding(.vertical, 18)
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 0) {
            hero(SuperPatchView(mood: .flying, autoplay: true, idle: true), width: 240)
            title("Bienvenue", "On règle l'app sur ton arrêt : ta dernière cigarette, tes patchs, tes comprimés. Une minute, et tout reste modifiable ensuite dans Plan.")
        }
    }

    private var lastCigarette: some View {
        VStack(alignment: .leading, spacing: 0) {
            title("Ta dernière cigarette", "C'était quand ? Le compteur part de là.")
            hero(PlantView(stage: 0, autoplay: true), width: 90)
            DatePicker("Dernière cigarette", selection: $d.quitDate, in: ...Date.now, displayedComponents: [.date, .hourAndMinute])
                .datePickerStyle(.graphical)
                .tint(Jardin.terra)
                .labelsHidden()
            Button("C'est maintenant") { d.quitDate = .now }
                .font(Jardin.sans(15, weight: .medium)).underline().foregroundStyle(Jardin.terra)
                .buttonStyle(.plain)
        }
    }

    private var before: some View {
        VStack(alignment: .leading, spacing: 0) {
            title("Avant d'arrêter", "Pour compter les cigarettes laissées de côté et l'argent gardé.")
            hero(PiggyView(autoplay: true), width: 130)
            row("Cigarettes par jour") { RoundStepper(value: $d.cigsPerDay, range: 1...60) { "\($0)" } }
            Rectangle().fill(Jardin.line).frame(height: 1)
            row("Dépense par semaine") {
                HStack(spacing: 8) {
                    TextField("€", value: $d.weeklySpend, format: .number)
                        .keyboardType(.decimalPad)
                        .focused($editingSpend)
                        .multilineTextAlignment(.trailing)
                        .font(Jardin.sans(16, weight: .medium))
                        .frame(width: 70)
                        .hairline()
                    Text("€").foregroundStyle(Jardin.muted)
                }
            }
        }
    }

    private var patches: some View {
        VStack(alignment: .leading, spacing: 0) {
            title("Tes patchs", "Choisis le dosage de départ : le plan se remplit selon la notice, puis ajuste chaque palier.")
            HStack(spacing: 10) {
                Text("Je commence à").font(Jardin.sans(15))
                Segmented(selection: $startMg, options: [7, 14, 21])
                Text("mg").font(Jardin.sans(15)).foregroundStyle(Jardin.muted)
            }
            .padding(.top, 24)
            .onChange(of: startMg) { _, mg in d.plan = defaultPlan(startingAt: mg) }

            PlanSteps(plan: $d.plan, start: d.quitDate).padding(.top, 24)

            Rectangle().fill(Jardin.line).frame(height: 1).padding(.top, 20)
            row("Pose chaque jour à") {
                DatePicker("", selection: patchTime, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.compact).labelsHidden()
            }
            Text("À ajuster avec ta notice et ton médecin.")
                .font(Jardin.sans(13)).foregroundStyle(Jardin.muted).padding(.top, 8)
        }
    }

    private var tablets: some View {
        VStack(alignment: .leading, spacing: 0) {
            title("Tes comprimés", "En renfort quand une envie monte : un toutes les 2 h au plus. Micro les porte pour toi.")
            hero(MicroView(count: min(3, d.tabletCap), cap: d.tabletCap, autoplay: true), width: 120)
            row("Maximum par jour") { RoundStepper(value: $d.tabletCap, range: 1...40) { "\($0)" } }
        }
    }

    private func row<C: View>(_ label: String, @ViewBuilder _ content: () -> C) -> some View {
        HStack {
            Text(label).font(Jardin.sans(15))
            Spacer()
            content()
        }
        .padding(.vertical, 14)
    }
}
