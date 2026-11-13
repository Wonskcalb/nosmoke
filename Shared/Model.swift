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
    var onboarded: Bool?
    var quitDate = Date()
    var plan = defaultPlan(startingAt: 21)
    var patchHour = 8
    var patchMinute = 0
    var tabletCap = 12
    var cigsPerDay = 10
    var weeklySpend = 20.0
    var patches: [PatchLog] = []
    var tablets: [Date] = []
    var cravings: [Craving] = []
    var slips: [Slip] = []
}

extension AppState {
    var lastCig: Date { ([quitDate] + slips.map(\.date)).max()! }
    var tabletsToday: [Date] { tablets.filter(Calendar.current.isDateInToday) }
    var patchToday: PatchLog? { patches.last { Calendar.current.isDateInToday($0.date) } }
    var nextSite: String { sites[((sites.firstIndex(of: patches.last?.site ?? "") ?? -1) + 1) % sites.count] }

    func avoided(_ now: Date) -> Int {
        max(0, Int(now.timeIntervalSince(quitDate) / 86400 * Double(cigsPerDay)) - slips.count)
    }

    func saved(_ now: Date) -> Double {
        Double(avoided(now)) * weeklySpend / Double(cigsPerDay * 7)
    }
}

/// Patch notices step down 21 → 14 → 7 mg, about four weeks each.
func defaultPlan(startingAt mg: Int) -> [PatchStep] {
    [21, 14, 7].filter { $0 <= mg }.map { PatchStep(mg: $0, days: 28) }
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
let intensityLabels = ["Légère", "Présente", "Bien là", "Forte", "Très forte"]
let triggerIcons = ["Café": "cup.and.saucer", "Après repas": "fork.knife", "Stress": "bolt", "Alcool": "wineglass", "Ennui": "hourglass", "Social": "person.2", "Pause": "pause.circle", "Conduite": "car"]
let sites = ["Bras gauche", "Bras droit", "Hanche gauche", "Hanche droite", "Dos gauche", "Dos droit"]

func duration(_ t: TimeInterval) -> String {
    let m = max(0, Int(t / 60)), d = m / 1440, h = m % 1440 / 60
    return d > 0 ? "\(d) j \(h) h" : h > 0 ? "\(h) h \(m % 60) min" : "\(m) min"
}
