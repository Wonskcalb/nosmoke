import AppIntents
import SwiftUI
import WidgetKit

struct Entry: TimelineEntry {
    let date: Date
    let state: AppState
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> Entry { Entry(date: .now, state: AppState()) }

    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        completion(Entry(date: .now, state: Persistence.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        let s = Persistence.load()
        let entries = (0..<16).map { Entry(date: Date.now.addingTimeInterval(Double($0) * 900), state: s) }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

struct WidgetView: View {
    let entry: Entry
    @Environment(\.widgetFamily) private var family

    private var s: AppState { entry.state }
    private var now: Date { entry.date }
    private var tablets: Int { s.tabletsToday.count }

    private var day: Int {
        let cal = Calendar.current
        let d = cal.dateComponents([.day], from: cal.startOfDay(for: s.quitDate), to: cal.startOfDay(for: now)).day ?? 0
        return max(1, d + 1)
    }

    private var mood: PatchMood {
        if s.patchToday != nil { return .flying }
        if let last = s.patches.last, now.timeIntervalSince(last.date) > 86400 { return .tired }
        return .sleeping
    }

    private var tabletCaption: String {
        if tablets >= s.tabletCap { return "plafond atteint" }
        guard let last = s.tabletsToday.max() else { return "aucune prise aujourd'hui" }
        return "prochain à \(last.addingTimeInterval(7200).formatted(date: .omitted, time: .shortened))"
    }

    private var patchStatus: String {
        guard let p = s.patchToday else { return "patch à poser" }
        let c = Calendar.current.dateComponents([.hour, .minute], from: p.date)
        return String(format: "patch posé · %d:%02d", c.hour ?? 0, c.minute ?? 0)
    }

    var body: some View {
        switch family {
        case .accessoryCircular: circular
        case .accessoryRectangular: rectangular
        case .systemMedium: medium
        default: small
        }
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 0) {
            SuperPatchView(mood: mood, autoplay: false, idle: false)
                .frame(width: 130)
                .frame(maxWidth: .infinity)
            Spacer(minLength: 0)
            Text("Jour \(day)").font(Jardin.serif(22))
        }
        .padding(EdgeInsets(top: 14, leading: 14, bottom: 12, trailing: 14))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var medium: some View {
        HStack(spacing: 20) {
            MicroView(count: tablets, cap: s.tabletCap, autoplay: false)
                .frame(width: 104)
            VStack(alignment: .leading, spacing: 8) {
                Text("\(tablets) / \(s.tabletCap)").bigNumber(38)
                Text(tabletCaption).font(Jardin.sans(13)).foregroundStyle(Jardin.muted)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .bottomTrailing) { plus.padding(16) }
    }

    private var plus: some View {
        Button(intent: LogTabletIntent()) {
            Image(systemName: "plus")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Jardin.paper)
                .frame(width: 44, height: 44)
                .background(Jardin.terra, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("J'ai pris un comprimé")
    }

    private var circular: some View {
        Gauge(value: Double(min(tablets, s.tabletCap)), in: 0...Double(s.tabletCap)) {
            EmptyView()
        } currentValueLabel: {
            Text("\(tablets)/\(s.tabletCap)")
        }
        .gaugeStyle(.accessoryCircular)
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Jour \(day)").font(Jardin.serif(20))
            Text(patchStatus).font(Jardin.sans(12))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct NoSmokeWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "NoSmoke", provider: Provider()) { entry in
            WidgetView(entry: entry).containerBackground(for: .widget) { Jardin.cream }
        }
        .configurationDisplayName("NoSmoke")
        .description("Temps sans fumer, patch du jour et comprimés.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
    }
}

@main
struct NoSmokeWidgetBundle: WidgetBundle {
    var body: some Widget { NoSmokeWidget() }
}
