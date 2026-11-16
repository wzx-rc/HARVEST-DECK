import Foundation

/// One timer of the farm, as the desktop core computes it (src/core/timers.ts).
struct FarmTimer: Codable, Hashable {
    var group: String
    var label: String
    /// Epoch ms, nil when idle or paused.
    var readyAt: Double?
    var state: String?
    var startedAt: Double?
}

struct GroupMeta: Codable, Hashable { var key: String; var label: String; var icon: String }
struct Family: Codable, Hashable { var key: String; var label: String; var groups: [String] }

/// What the app hands to the widget through the shared App Group folder.
struct WidgetSnapshot: Codable {
    var at: Double
    var timers: [FarmTimer]
    var meta: [GroupMeta]
    var families: [Family]
    /// Line under each group's name ("Blé ×81", "30 moutons").
    var subs: [String: String]
    /// Groups the person follows, in the order they chose (empty = all).
    var follow: [String]
    var username: String?
}

/// One group's state at a given moment (summarize() in timers.ts).
struct GroupState: Identifiable, Hashable {
    var id: String { key }
    var key: String
    var label: String
    var sub: String
    var total: Int
    var ready: Int
    var empty: Int
    var blocked: Int
    var nextAt: Date?
    var allAt: Date?
    var progress: Double
    /// Start and end of the next running item, for live progress bars.
    var nextStart: Date?

    var isReady: Bool { ready > 0 }
    /// Sort key: ready first, then empty or blocked, then the soonest.
    var sortKey: Double {
        if ready > 0 { return -2 }
        if nextAt == nil && (empty + blocked) > 0 { return -1 }
        return nextAt?.timeIntervalSince1970 ?? .greatestFiniteMagnitude
    }
}

enum TimerMath {
    static func summarize(_ timers: [FarmTimer], meta: [GroupMeta], subs: [String: String], at now: Date) -> [GroupState] {
        let t = now.timeIntervalSince1970 * 1000
        return meta.compactMap { m in
            let list = timers.filter { $0.group == m.key }
            guard !list.isEmpty else { return nil }
            let readyCount = list.filter { ($0.readyAt ?? .infinity) <= t }.count
            let running = list.filter { ($0.readyAt ?? -1) > t }.sorted { $0.readyAt! < $1.readyAt! }
            let next = running.first
            var progress = 0.0
            if readyCount > 0 { progress = 1 }
            else if let n = next, let s = n.startedAt, let r = n.readyAt, r > s { progress = min(1, max(0, (t - s) / (r - s))) }
            return GroupState(
                key: m.key, label: m.label, sub: subs[m.key] ?? "", total: list.count, ready: readyCount,
                empty: list.filter { $0.state == "empty" }.count,
                blocked: list.filter { $0.state == "paused" || $0.state == "sick" }.count,
                nextAt: next?.readyAt.map { Date(timeIntervalSince1970: $0 / 1000) },
                allAt: running.last?.readyAt.map { Date(timeIntervalSince1970: $0 / 1000) },
                progress: progress,
                nextStart: next?.startedAt.map { Date(timeIntervalSince1970: $0 / 1000) })
        }
    }

    /// "2 h 10", "35 min", "3 j 4 h" (countdown() in timers.ts).
    static func countdown(_ seconds: Double) -> String {
        if seconds <= 0 { return "prêt" }
        let m = Int(ceil(seconds / 60))
        if m < 60 { return "\(m) min" }
        let h = m / 60, r = m % 60
        if h < 24 { return r > 0 ? "\(h) h \(String(format: "%02d", r))" : "\(h) h" }
        let d = h / 24, hh = h % 24
        return hh > 0 ? "\(d) j \(hh) h" : "\(d) j"
    }

    /// "14:20", "demain 07:10", "sam. 09:00".
    static func clock(_ date: Date, now: Date = .now) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "fr_FR"); f.dateFormat = "HH:mm"
        let cal = Calendar.current
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: now), to: cal.startOfDay(for: date)).day ?? 0
        if days <= 0 { return f.string(from: date) }
        if days == 1 { return "demain " + f.string(from: date) }
        let w = DateFormatter(); w.locale = Locale(identifier: "fr_FR"); w.dateFormat = "EEE"
        return w.string(from: date) + " " + f.string(from: date)
    }

    /// Short state text for the right side of a row.
    static func when(_ g: GroupState, now: Date = .now) -> String {
        if g.ready > 0 { return g.nextAt == nil ? "Prêt" : "\(g.ready) prêt\(g.ready > 1 ? "s" : "")" }
        if let n = g.nextAt { return countdown(n.timeIntervalSince(now)) }
        if g.blocked > 0 { return g.key == "honey" ? "en pause" : "malade" }
        if g.empty > 0 { return "\(g.empty) vide\(g.empty > 1 ? "s" : "")" }
        return "—"
    }
}

/// Shared folder between the app and its widget.
enum SharedStore {
    static let group = "group.com.wzx.harvestdesk"
    static var folder: URL {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    }
    static var snapshotURL: URL { folder.appendingPathComponent("widget.json") }

    static func save(_ s: WidgetSnapshot) {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        if let d = try? JSONEncoder().encode(s) { try? d.write(to: snapshotURL, options: .atomic) }
    }
    static func load() -> WidgetSnapshot? {
        guard let d = try? Data(contentsOf: snapshotURL) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: d)
    }
}
