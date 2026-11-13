import AppIntents
import Foundation
import WidgetKit

enum Persistence {
    static let group = "group.fr.famelart.nosmoke"

    static var url: URL {
        (FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) ?? URL.documentsDirectory)
            .appending(path: "state.json")
    }

    static func load() -> AppState {
        (try? Data(contentsOf: url)).flatMap { try? JSONDecoder().decode(AppState.self, from: $0) } ?? AppState()
    }

    static func save(_ s: AppState) {
        try? JSONEncoder().encode(s).write(to: url, options: .atomic)
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
