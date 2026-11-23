import AppIntents
import Foundation
import WidgetKit

enum Persistence {
    // Derived from the bundle id so a build re-signed under another identity still finds its own group.
    static let group = "group." + (Bundle.main.bundleIdentifier ?? "fr.famelart.nosmoketracker")
        .replacingOccurrences(of: #"\.widgets?$"#, with: "", options: .regularExpression)

    static var url: URL {
        (FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) ?? URL.documentsDirectory)
            .appending(path: "state.json")
    }

    // Fallback copy outside the App Group: if the group file is lost or unreadable,
    // the state comes back from here instead of starting over.
    static let mirror = URL.documentsDirectory.appending(path: "state.json")

    static func load() -> AppState {
        for u in [url, mirror] {
            if let d = try? Data(contentsOf: u), let s = try? JSONDecoder().decode(AppState.self, from: d) { return s }
        }
        return AppState()
    }

    static func save(_ s: AppState) {
        guard let data = try? JSONEncoder().encode(s) else { return }
        try? data.write(to: url, options: .atomic)
        try? data.write(to: mirror, options: .atomic)
        WidgetCenter.shared.reloadAllTimelines()
    }
}

struct LogTabletIntent: AppIntent {
    static var title: LocalizedStringResource = "Comprimé pris"

    func perform() async throws -> some IntentResult {
        var s = Persistence.load()
        s.tablets.append(.now)
        Persistence.save(s)
        return .result()
    }
}
