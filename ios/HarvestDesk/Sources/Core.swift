import Foundation
import JavaScriptCore

/// The desktop app's calculations (core.js, built from harvest-desk/src/mobile/bridge.ts).
final class Core {
    static let shared = Core()
    private let ctx: JSContext
    private let hd: JSValue

    private init() {
        ctx = JSContext()!
        ctx.exceptionHandler = { _, e in print("core.js:", e?.toString() ?? "?") }
        let url = Bundle.main.url(forResource: "core", withExtension: "js")!
        ctx.evaluateScript(try! String(contentsOf: url, encoding: .utf8))
        hd = ctx.objectForKeyedSubscript("HD")
    }

    private func call(_ fn: String, _ args: [Any]) -> String? {
        let v = hd.objectForKeyedSubscript(fn).call(withArguments: args)
        guard let s = v?.toString(), s != "undefined", s != "null" else { return nil }
        return s
    }

    private func decode<T: Decodable>(_ s: String?) -> T? {
        guard let s else { return nil }
        do { return try JSONDecoder().decode(T.self, from: Data(s.utf8)) } catch { print("decode", T.self, error); return nil }
    }

    func timers(farm: String, now: Date = .now) -> TimersResult? {
        decode(call("timers", [farm, now.timeIntervalSince1970 * 1000]))
    }
    /// Parsed market (kept as JSON text for the other calls).
    func market(raw: String) -> String? { call("market", [raw]) }
    func value(farm: String, market: String) -> ValueResult? { decode(call("value", [farm, market])) }
    func procs(reads: String, farm: String) -> ProcsResult? { decode(call("procs", [reads, farm])) }
    func revenue(farm: String, market: String, snapshots: String) -> RevenueResult? {
        decode(call("revenue", [farm, market, snapshots]))
    }
}

// MARK: - What core.js returns

struct TimersResult: Decodable {
    struct Group: Decodable { var key: String; var sub: String }
    var at: Double
    var timers: [FarmTimer]
    var groups: [Group]
    var meta: [GroupMeta]
    var families: [Family]
}

struct ValueResult: Decodable {
    struct Item: Decodable, Hashable { var name: String; var qty: Double; var unit: Double; var value: Double; var source: String }
    struct Group: Decodable, Identifiable { var id: String { key }; var key: String; var label: String; var total: Double; var items: [Item] }
    var total: Double
    var netIfSold: Double
    var unpriced: Int
    var groups: [Group]
}

struct ProcsResult: Decodable {
    struct Day: Decodable, Identifiable { var id: Double { day }; var day: Double; var pops: Int; var coins: Double; var expectedPops: Double; var expectedCoins: Double; var chops: Double; var hours: Double }
    struct Tree: Decodable, Identifiable { var id: String { tree }; var tree: String; var pops: Int; var coins: Double; var expectedPops: Double }
    struct Stats: Decodable {
        var hours: Double; var chopsPerDay: Double; var pops: Int; var coins: Double; var chops: Double
        var unknown: Int; var expectedPops: Double; var expectedCoins: Double; var perDay: [Day]; var byTree: [Tree]
    }
    struct Event: Decodable, Identifiable { var id: Double { at }; var at: Double; var tree: String?; var coins: Double?; var before: Bool? }
    var since: Double
    var rank: Int
    var stats: Stats
    var treeNames: [String: String]
    var coinsPerFlower: Double
    var events: [Event]
}

struct RevenueResult: Decodable {
    struct Line: Decodable, Identifiable, Hashable { var id: String { key }; var key: String; var label: String; var net: Double; var gross: Double; var cost: Double }
    struct Category: Decodable, Identifiable { var id: String { key }; var key: String; var net: Double; var gross: Double; var cost: Double; var lines: [Line] }
    var days: Double
    var usd: Double
    var net: Double
    var gross: Double
    var cost: Double
    var categories: [Category]
}
