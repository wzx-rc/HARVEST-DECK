import SwiftUI

@main
struct HarvestDeskApp: App {
    @StateObject private var store = Store()
    @Environment(\.scenePhase) private var phase

    init() {
        let title = UIColor(Theme.text)
        UINavigationBar.appearance().largeTitleTextAttributes = [.foregroundColor: title, .font: UIFont(name: "BricolageGrotesque-Bold", size: 32) ?? .boldSystemFont(ofSize: 32)]
        UINavigationBar.appearance().titleTextAttributes = [.foregroundColor: title, .font: UIFont(name: "BricolageGrotesque-SemiBold", size: 17) ?? .boldSystemFont(ofSize: 17)]
        UITabBar.appearance().backgroundColor = UIColor(Color(hex: 0x160F12))
    }

    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(store)
                .onChange(of: phase) { _, p in if p == .active { Task { await store.refresh() } } }
                .task { await store.refresh() }
        }
    }
}
