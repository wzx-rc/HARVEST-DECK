import SwiftUI

enum Tab: String, CaseIterable, Identifiable {
    case timers, revenue, procs, value, settings
    /// Only for the CI screenshots.
    case gallery
    static var allCases: [Tab] { [.timers, .revenue, .procs, .value, .settings] }
    var id: String { rawValue }
    var title: String {
        switch self { case .timers: "Minuteurs"; case .revenue: "Revenus"; case .procs: "Money Tree"; case .value: "Valeur"; case .settings: "Réglages"; case .gallery: "Widgets" }
    }
    var symbol: String {
        switch self { case .timers: "timer"; case .revenue: "chart.bar.fill"; case .procs: "tree.fill"; case .value: "dollarsign.circle.fill"; case .settings: "gearshape.fill"; case .gallery: "square.grid.2x2" }
    }
    @MainActor @ViewBuilder var screen: some View {
        switch self {
        case .timers: TimersView()
        case .revenue: RevenueView()
        case .procs: ProcsView()
        case .value: ValueView()
        case .settings: SettingsView()
        case .gallery: WidgetGallery()
        }
    }
}

/// iPhone: tab bar. iPad: sidebar and a wide detail.
struct RootView: View {
    @EnvironmentObject var store: Store
    @Environment(\.horizontalSizeClass) private var size
    @SceneStorage("tab") private var tab: Tab = .timers

    var body: some View {
        Group {
            if tab == .gallery {
                WidgetGallery()
            } else if size == .regular {
                NavigationSplitView {
                    List(Tab.allCases, selection: Binding<Tab?>(get: { tab }, set: { if let t = $0 { tab = t } })) { t in
                        Label(t.title, systemImage: t.symbol).font(Theme.body(16, semibold: true)).tag(t)
                    }
                    .navigationTitle(store.username ?? "Harvest Desk")
                    .scrollContentBackground(.hidden)
                    .background(Color(hex: 0x160F12).ignoresSafeArea())
                } detail: {
                    NavigationStack { tab.screen }
                }
                .navigationSplitViewStyle(.balanced)
            } else {
                TabView(selection: $tab) {
                    ForEach(Tab.allCases) { t in
                        NavigationStack { t.screen }
                            .tabItem { Label(t.title, systemImage: t.symbol) }
                            .tag(t)
                    }
                }
            }
        }
        .tint(Theme.gold)
        .preferredColorScheme(.dark)
        .onAppear {
            // Screenshots in CI: -tab <name> opens that screen.
            let args = ProcessInfo.processInfo.arguments
            if let i = args.firstIndex(of: "-tab"), i + 1 < args.count, let t = Tab(rawValue: args[i + 1]) { tab = t; return }
            if store.status == .needsSetup { tab = .settings }
        }
    }
}
