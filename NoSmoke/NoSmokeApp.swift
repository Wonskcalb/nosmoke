import SwiftUI

@main
struct NoSmokeApp: App {
    @StateObject private var store = Store()
    @Environment(\.scenePhase) private var phase

    init() {
        let bar = UITabBarAppearance()
        bar.configureWithOpaqueBackground()
        bar.backgroundColor = UIColor(Jardin.cream)
        bar.shadowColor = UIColor(Jardin.line)
        for item in [bar.stackedLayoutAppearance, bar.inlineLayoutAppearance, bar.compactInlineLayoutAppearance] {
            item.normal.iconColor = UIColor(Jardin.muted)
            item.normal.titleTextAttributes = [.foregroundColor: UIColor(Jardin.muted), .font: UIFont.systemFont(ofSize: 10.5, weight: .medium)]
            item.selected.iconColor = UIColor(Jardin.terra)
            item.selected.titleTextAttributes = [.foregroundColor: UIColor(Jardin.terra), .font: UIFont.systemFont(ofSize: 10.5, weight: .medium)]
        }
        UITabBar.appearance().standardAppearance = bar
        UITabBar.appearance().scrollEdgeAppearance = bar
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .tint(Jardin.terra)
                .foregroundStyle(Jardin.ink)
                .preferredColorScheme(.light)
                .environment(\.locale, Locale(identifier: "fr_FR"))
                .onAppear { if store.s.onboarded == true { Reminders.refresh(store.s) } }
                .onChange(of: phase) { if phase == .active { store.reload() } }
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var store: Store

    var body: some View {
        if store.s.onboarded != true {
            OnboardingView(initial: store.s)
        } else {
            tabs
        }
    }

    private var tabs: some View {
        TabView(selection: $store.tab) {
            TodayView().tabItem { Label("Aujourd'hui", systemImage: "sun.max") }.tag(0)
            SOSView().tabItem { Label("Respirer", systemImage: "wind") }.tag(1)
            JournalView().tabItem { Label("Journal", systemImage: "book") }.tag(2)
            SettingsView().tabItem { Label("Plan", systemImage: "point.topleft.down.to.point.bottomright.curvepath") }.tag(3)
        }
    }
}
