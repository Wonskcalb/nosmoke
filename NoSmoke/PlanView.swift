import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: Store
    @FocusState private var editingSpend: Bool

    private var patchTime: Binding<Date> {
        Binding(
            get: { Calendar.current.date(from: DateComponents(hour: store.s.patchHour, minute: store.s.patchMinute)) ?? .now },
            set: {
                let c = Calendar.current.dateComponents([.hour, .minute], from: $0)
                store.s.patchHour = c.hour ?? 8
                store.s.patchMinute = c.minute ?? 0
            })
    }

    private var line: some View {
        Rectangle().fill(Jardin.line).frame(height: 1)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Plan").font(Jardin.serif(34)).padding(.top, 6)
                Text("Ton patch, palier par palier.")
                    .font(Jardin.sans(15)).foregroundStyle(Jardin.muted).padding(.top, 8)

                PlanSteps(plan: $store.s.plan, start: store.s.quitDate)
                    .padding(.top, 22)

                line.padding(.vertical, 24)

                VStack(spacing: 0) {
                    fact("Pose du patch") {
                        DatePicker("", selection: patchTime, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.compact).labelsHidden()
                    }
                    line
                    fact("Comprimés") {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("\(store.s.tabletCap) par jour au maximum, toutes les 2 h")
                                .font(Jardin.sans(14.5)).lineSpacing(2)
                            RoundStepper(value: $store.s.tabletCap, range: 1...40) { "\($0)" }
                        }
                    }
                    line
                    fact("Avant") {
                        VStack(alignment: .leading, spacing: 10) {
                            RoundStepper(value: $store.s.cigsPerDay, range: 1...60) { "\($0)" }
                            Text("cigarettes par jour")
                                .font(Jardin.sans(14.5)).foregroundStyle(Jardin.muted)
                            HStack(spacing: 8) {
                                TextField("€", value: $store.s.weeklySpend, format: .number)
                                    .keyboardType(.decimalPad)
                                    .focused($editingSpend)
                                    .multilineTextAlignment(.trailing)
                                    .font(Jardin.sans(14.5, weight: .medium))
                                    .frame(width: 64)
                                    .hairline()
                                Text("€ par semaine")
                                    .font(Jardin.sans(14.5)).foregroundStyle(Jardin.muted)
                            }
                        }
                    }
                    line
                    fact("Dernière cigarette") {
                        DatePicker("", selection: $store.s.quitDate, displayedComponents: [.date, .hourAndMinute])
                            .datePickerStyle(.compact).labelsHidden()
                    }
                }

                ShareLink(item: store.summary()) {
                    Text("Envoyer un résumé à mon médecin")
                        .font(Jardin.sans(16, weight: .semibold)).foregroundStyle(Jardin.ink)
                        .frame(maxWidth: .infinity).frame(height: 52)
                        .overlay(Capsule().strokeBorder(Jardin.ink, lineWidth: 1.5))
                }
                .padding(.top, 20)

                Text("À ajuster avec ta notice et ton médecin.")
                    .font(Jardin.sans(13)).foregroundStyle(Jardin.muted)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 12)
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            // The decimal pad has no return key, so it needs its own way out.
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("OK") { editingSpend = false }.fontWeight(.semibold)
            }
        }
        .screenBackground()
        .onDisappear { Reminders.refresh(store.s) }
    }

    private func fact<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Text(label)
                .font(Jardin.sans(14.5)).foregroundStyle(Jardin.muted)
                .frame(width: 112, alignment: .leading)
            content().frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 12)
    }
}

struct PlanSteps: View {
    @Binding var plan: [PatchStep]
    let start: Date

    private static let dayFormat = Date.FormatStyle().day().month(.abbreviated).locale(Locale(identifier: "fr_FR"))

    private var ranges: [(start: Date, end: Date)] {
        let cal = Calendar.current
        var start = cal.startOfDay(for: start)
        return plan.map { p in
            let range = (start: start, end: cal.date(byAdding: .day, value: p.days - 1, to: start) ?? start)
            start = cal.date(byAdding: .day, value: p.days, to: start) ?? start
            return range
        }
    }

    var body: some View {
        let info = stepInfo(plan: plan, start: start, now: .now)
        VStack(alignment: .leading, spacing: 0) {
            ForEach(plan.indices, id: \.self) { i in
                stepRow(i, info: info)
            }
            Button {
                plan.append(PatchStep(mg: 7, days: 28))
            } label: {
                Text("+ Ajouter un palier")
                    .font(Jardin.sans(15, weight: .medium)).underline().foregroundStyle(Jardin.terra)
            }
            .buttonStyle(.plain)
            .padding(.leading, 30)
        }
    }

    private func stepRow(_ i: Int, info: StepInfo?) -> some View {
        let range = ranges[i]
        let isCurrent = info?.index == i
        let last = i == plan.count - 1
        return HStack(alignment: .top, spacing: 18) {
            VStack(spacing: 0) {
                ZStack {
                    Circle().fill(isCurrent ? Jardin.terra : Jardin.cream)
                    Circle().stroke(isCurrent ? Jardin.terra : Jardin.ink, lineWidth: 1.5)
                }
                .frame(width: 12, height: 12)
                .padding(.top, 6)
                Rectangle().fill(last ? Color.clear : Jardin.line)
                    .frame(width: 1.5)
                    .frame(maxHeight: .infinity)
            }
            .frame(width: 12)

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text("Palier \(i + 1)").font(Jardin.serif(19))
                    if isCurrent, let day = info?.day {
                        Text("tu es ici · jour \(day)")
                            .font(Jardin.sans(12, weight: .semibold)).foregroundStyle(Jardin.terra)
                    }
                    Spacer(minLength: 8)
                    if plan.count > 1 {
                        Button("Retirer") { plan.remove(at: i) }
                            .font(Jardin.sans(13)).foregroundStyle(Jardin.muted)
                            .buttonStyle(.plain)
                    }
                }
                Text("Du \(range.start.formatted(Self.dayFormat)) au \(range.end.formatted(Self.dayFormat))")
                    .font(Jardin.sans(14)).foregroundStyle(Jardin.muted).padding(.top, 4)

                HStack(spacing: 10) {
                    Text("Dosage").font(Jardin.sans(13, weight: .semibold)).frame(width: 56, alignment: .leading)
                    Segmented(selection: $plan[i].mg, options: [7, 14, 21])
                    Text("mg").font(Jardin.sans(13)).foregroundStyle(Jardin.muted)
                }
                .padding(.top, 12)

                HStack(spacing: 10) {
                    Text("Durée").font(Jardin.sans(13, weight: .semibold)).frame(width: 56, alignment: .leading)
                    RoundStepper(value: $plan[i].days, range: 1...120) { $0 == 1 ? "1 jour" : "\($0) jours" }
                }
                .padding(.top, 10)
            }
            .padding(.bottom, 26)
        }
    }

}

struct Segmented: View {
    @Binding var selection: Int
    let options: [Int]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.self) { option in
                Button {
                    selection = option
                } label: {
                    Text("\(option)")
                        .font(Jardin.sans(14, weight: .medium))
                        .foregroundStyle(selection == option ? Jardin.paper : Jardin.ink)
                        .frame(width: 42, height: 28)
                        .background(selection == option ? Jardin.terra : Color.clear, in: Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .overlay(Capsule().strokeBorder(Jardin.line, lineWidth: 1.5))
        .animation(.easeOut(duration: 0.15), value: selection)
    }
}

struct RoundStepper: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    let text: (Int) -> String

    var body: some View {
        HStack(spacing: 10) {
            roundButton("−", "Moins", enabled: value > range.lowerBound) { value -= 1 }
            Text(text(value))
                .font(Jardin.sans(14, weight: .medium))
                .frame(minWidth: 64)
            roundButton("+", "Plus", enabled: value < range.upperBound) { value += 1 }
        }
    }

    private func roundButton(_ symbol: String, _ label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(symbol)
                .font(Jardin.sans(17)).foregroundStyle(Jardin.ink)
                .frame(width: 30, height: 30)
                .overlay(Circle().strokeBorder(Jardin.line, lineWidth: 1.5))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
        .accessibilityLabel(label)
    }
}
