import SwiftUI

@main
struct NoSmokeApp: App {
    @StateObject private var store = Store()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .tint(.teal)
                .onAppear { Reminders.refresh(store.s) }
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var store: Store

    var body: some View {
        TabView(selection: $store.tab) {
            TodayView().tabItem { Label("Aujourd'hui", systemImage: "sun.max") }.tag(0)
            SOSView().tabItem { Label("SOS", systemImage: "lifepreserver") }.tag(1)
            JournalView().tabItem { Label("Journal", systemImage: "list.bullet.clipboard") }.tag(2)
            SettingsView().tabItem { Label("Réglages", systemImage: "gearshape") }.tag(3)
        }
    }
}
