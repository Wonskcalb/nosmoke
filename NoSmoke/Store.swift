import Foundation
import UserNotifications

final class Store: ObservableObject {
    @Published var s: AppState { didSet { save() } }
    @Published var tab = 0
    private let url = URL.documentsDirectory.appending(path: "state.json")

    init() {
        tab = UserDefaults.standard.integer(forKey: "tab")
        s = (try? Data(contentsOf: url)).flatMap { try? JSONDecoder().decode(AppState.self, from: $0) } ?? AppState()
    }

    private func save() {
        try? JSONEncoder().encode(s).write(to: url, options: .atomic)
    }

    var lastCig: Date { ([s.quitDate] + s.slips.map(\.date)).max()! }
    var tabletsToday: [Date] { s.tablets.filter(Calendar.current.isDateInToday) }
    var patchToday: PatchLog? { s.patches.last { Calendar.current.isDateInToday($0.date) } }
    var nextSite: String { sites[((sites.firstIndex(of: s.patches.last?.site ?? "") ?? -1) + 1) % sites.count] }

    func avoided(_ now: Date) -> Int {
        max(0, Int(now.timeIntervalSince(s.quitDate) / 86400 * Double(s.cigsPerDay)) - s.slips.count)
    }

    func saved(_ now: Date) -> Double {
        Double(avoided(now)) * s.weeklySpend / Double(s.cigsPerDay * 7)
    }

    func summary() -> String {
        let cal = Calendar.current
        let lines = (0..<14).compactMap { i -> String? in
            guard let day = cal.date(byAdding: .day, value: -i, to: .now), day >= cal.startOfDay(for: s.quitDate) else { return nil }
            let on = { (d: Date) in cal.isDate(d, inSameDayAs: day) }
            return "\(day.formatted(date: .abbreviated, time: .omitted)) : \(s.tablets.filter(on).count) comprimés, \(s.cravings.filter { on($0.date) }.count) envies, \(s.slips.filter { on($0.date) }.count) cigarettes"
        }
        let plan = s.plan.map { "\($0.mg) mg × \($0.days) j" }.joined(separator: " ; ")
        return "Arrêt du tabac depuis le \(s.quitDate.formatted(date: .long, time: .omitted)). Plan de patch : \(plan).\n" + lines.joined(separator: "\n")
    }
}

enum Reminders {
    static func refresh(_ s: AppState) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { ok, _ in
            guard ok else { return }
            center.removeAllPendingNotificationRequests()
            add(center, "patch", "Changer le patch", "Retire l'ancien et pose le nouveau sur une peau propre et sèche, ailleurs qu'hier.",
                UNCalendarNotificationTrigger(dateMatching: DateComponents(hour: s.patchHour, minute: s.patchMinute), repeats: true))
            let cal = Calendar.current
            var acc = 0
            for (i, p) in s.plan.enumerated() {
                if i > 0, let day = cal.date(byAdding: .day, value: acc, to: cal.startOfDay(for: s.quitDate)),
                   let at = cal.date(bySettingHour: 9, minute: 0, second: 0, of: day), at > .now {
                    add(center, "palier\(i)", "Nouveau palier", "À partir d'aujourd'hui : patch \(p.mg) mg.",
                        UNCalendarNotificationTrigger(dateMatching: cal.dateComponents([.year, .month, .day, .hour, .minute], from: at), repeats: false))
                }
                acc += p.days
            }
        }
    }

    private static func add(_ c: UNUserNotificationCenter, _ id: String, _ title: String, _ body: String, _ trigger: UNNotificationTrigger) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        c.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }
}
