import Foundation
import SwiftUI
import WidgetKit

/// Everything the app shows. Reads the farm, the market and the GitHub readings, runs core.js.
@MainActor
final class Store: ObservableObject {
    enum Status: Equatable { case idle, loading, ready, needsSetup, error(String) }

    @Published var status: Status = .idle
    @Published var fetchedAt: Date?
    @Published var username: String?
    @Published var timers: TimersResult?
    @Published var value: ValueResult?
    @Published var procs: ProcsResult?
    @Published var revenue: RevenueResult?
    @Published var flowerUsd: Double = 0
    @AppStorage("farmId") var farmId: String = ""
    @AppStorage("readingsBase") var readingsBase: String = "https://raw.githubusercontent.com/wzx-rc/HARVEST-DECK/procs-data"
    /// Groups shown in the widget, in order. Empty = the defaults.
    @AppStorage("follow") var followRaw: String = "crops,greenhouse,trees,stone,iron,gold,sheep,cooking,power"

    var apiKey: String {
        get { Keychain.get("sfl-api-key") ?? "" }
        set { Keychain.set("sfl-api-key", newValue.trimmingCharacters(in: CharacterSet(charactersIn: " <>\n"))); objectWillChange.send() }
    }
    var follow: [String] {
        get { followRaw.split(separator: ",").map(String.init) }
        set { followRaw = newValue.joined(separator: ","); pushWidget() }
    }

    private var farmJSON: String?
    private var marketJSON: String?
    private var marketAt: Date?
    private let cache = SharedStore.folder

    init() {
        loadCache()
        if farmJSON != nil { Task { await pullReadings() } }
    }

    // MARK: Refresh

    func refresh(force: Bool = false) async {
        guard !apiKey.isEmpty, !farmId.isEmpty else { status = .needsSetup; return }
        if case .loading = status { return }
        if !force, let f = fetchedAt, Date().timeIntervalSince(f) < 60 { return }
        status = .loading
        let client = SFLClient(key: apiKey)
        do {
            let farm = try await client.farm(farmId.trimmingCharacters(in: .whitespaces))
            farmJSON = farm
            write("farm.json", farm)
            if force || marketJSON == nil || Date().timeIntervalSince(marketAt ?? .distantPast) > 6 * 3600 {
                try? await Task.sleep(for: .seconds(5)) // community API: one call every 5 s
                if let raw = try? await client.marketplace(), let parsed = Core.shared.market(raw: raw) {
                    marketJSON = parsed; marketAt = .now
                    write("market.json", parsed)
                }
            }
            fetchedAt = .now
            UserDefaults.standard.set(fetchedAt, forKey: "fetchedAt")
            compute()
            status = .ready
            await pullReadings()
        } catch {
            status = .error(error.localizedDescription)
        }
    }

    /// Money Tree pops and the counters for the income, made every 10 min by GitHub.
    func pullReadings() async {
        guard let farm = farmJSON else { return }
        if let reads = await SFLClient.readings(readingsBase, file: "reads.jsonl") {
            procs = Core.shared.procs(reads: reads, farm: farm)
        }
        if let snaps = await SFLClient.readings(readingsBase, file: "snapshots.json"), let m = marketJSON {
            write("snapshots.json", snaps)
            revenue = Core.shared.revenue(farm: farm, market: m, snapshots: snaps)
        }
    }

    private func compute() {
        guard let farm = farmJSON else { return }
        if let d = try? JSONSerialization.jsonObject(with: Data(farm.utf8)) as? [String: Any],
           let f = d["farm"] as? [String: Any] { username = f["username"] as? String }
        timers = Core.shared.timers(farm: farm)
        if let m = marketJSON {
            value = Core.shared.value(farm: farm, market: m)
            if let d = try? JSONSerialization.jsonObject(with: Data(m.utf8)) as? [String: Any] {
                flowerUsd = d["flowerUsd"] as? Double ?? 0
            }
            if let snaps = read("snapshots.json") { revenue = Core.shared.revenue(farm: farm, market: m, snapshots: snaps) }
        }
        pushWidget()
    }

    func pushWidget() {
        guard let t = timers else { return }
        let subs = Dictionary(uniqueKeysWithValues: t.groups.map { ($0.key, $0.sub) })
        SharedStore.save(WidgetSnapshot(at: t.at, timers: t.timers, meta: t.meta, families: t.families,
                                        subs: subs, follow: follow, username: username))
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: Cache (so the app opens with the last data, offline too)

    private func write(_ name: String, _ text: String) {
        try? text.write(to: cache.appendingPathComponent(name), atomically: true, encoding: .utf8)
    }
    private func read(_ name: String) -> String? {
        try? String(contentsOf: cache.appendingPathComponent(name), encoding: .utf8)
    }
    private func loadCache() {
        farmJSON = read("farm.json")
        marketJSON = read("market.json")
        fetchedAt = UserDefaults.standard.object(forKey: "fetchedAt") as? Date
        if farmJSON != nil { compute(); status = .ready }
        if apiKey.isEmpty || farmId.isEmpty { status = .needsSetup }
    }

    // MARK: Helpers for the views

    func usd(_ flower: Double) -> Double { flower * flowerUsd }

    /// Groups at a given moment, with their lines under the names.
    func groups(at now: Date) -> [GroupState] {
        guard let t = timers else { return [] }
        let subs = Dictionary(uniqueKeysWithValues: t.groups.map { ($0.key, $0.sub) })
        return TimerMath.summarize(t.timers, meta: t.meta, subs: subs, at: now)
    }
}
