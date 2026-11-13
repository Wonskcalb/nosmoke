import Foundation

struct PatchStep: Codable, Hashable, Identifiable {
    var id = UUID()
    var mg: Int
    var days: Int
}

struct PatchLog: Codable, Identifiable {
    var id = UUID()
    var date: Date
    var site: String
}

struct Craving: Codable, Identifiable {
    var id = UUID()
    var date: Date
    var intensity: Int
    var trigger: String
}

struct Slip: Codable, Identifiable {
    var id = UUID()
    var date: Date
    var trigger: String
}

struct AppState: Codable {
    var quitDate = Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 13, hour: 7, minute: 30))!
    var plan = [PatchStep(mg: 14, days: 28), PatchStep(mg: 14, days: 28), PatchStep(mg: 7, days: 30)]
    var patchHour = 8
    var patchMinute = 0
    var tabletCap = 12
    var cigsPerDay = 12
    var weeklySpend = 26.0
    var patches: [PatchLog] = []
    var tablets: [Date] = []
    var cravings: [Craving] = []
    var slips: [Slip] = []
}

struct StepInfo: Equatable {
    let index: Int
    let mg: Int
    let day: Int
    let days: Int
    let left: Int
    let next: Int?
}

func stepInfo(plan: [PatchStep], start: Date, now: Date, calendar cal: Calendar = .current) -> StepInfo? {
    let d = cal.dateComponents([.day], from: cal.startOfDay(for: start), to: cal.startOfDay(for: now)).day ?? 0
    var acc = 0
    for (i, p) in plan.enumerated() {
        if d < acc + p.days {
            return StepInfo(index: i, mg: p.mg, day: d - acc + 1, days: p.days, left: acc + p.days - d, next: i + 1 < plan.count ? plan[i + 1].mg : nil)
        }
        acc += p.days
    }
    return nil
}

let milestones: [(TimeInterval, String)] = [
    (20 * 60, "Pouls et tension reviennent à la normale"),
    (24 * 3600, "Le monoxyde de carbone a quitté le sang"),
    (48 * 3600, "Goût et odorat s'améliorent"),
    (72 * 3600, "Respirer devient plus facile"),
    (14 * 86400, "La circulation s'améliore"),
    (90 * 86400, "Toux et essoufflement diminuent"),
    (365 * 86400, "Risque d'infarctus divisé par 2 environ"),
]

let triggers = ["Café", "Après repas", "Stress", "Alcool", "Ennui", "Social", "Pause", "Conduite"]
let sites = ["Bras gauche", "Bras droit", "Hanche gauche", "Hanche droite", "Dos gauche", "Dos droit"]

func duration(_ t: TimeInterval) -> String {
    let m = max(0, Int(t / 60)), d = m / 1440, h = m % 1440 / 60
    return d > 0 ? "\(d) j \(h) h" : h > 0 ? "\(h) h \(m % 60) min" : "\(m) min"
}
