import SwiftUI
import WidgetKit

// MARK: - Timeline

struct FarmEntry: TimelineEntry {
    let date: Date
    let groups: [GroupState]
    let readAt: Date?
    let empty: Bool
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> FarmEntry { Self.sample }

    func getSnapshot(in context: Context, completion: @escaping (FarmEntry) -> Void) {
        completion(entries(from: .now).first ?? Self.sample)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FarmEntry>) -> Void) {
        let list = entries(from: .now)
        // A new entry at each change, then ask again in 30 min.
        completion(Timeline(entries: list.isEmpty ? [Self.emptyEntry] : list, policy: .after(.now.addingTimeInterval(1800))))
    }

    /// One entry now, then one at each moment a followed group becomes ready (next 12 h, at most 30).
    private func entries(from now: Date) -> [FarmEntry] {
        guard let s = SharedStore.load() else { return [] }
        let follow = s.follow.isEmpty ? s.meta.map(\.key) : s.follow
        let timers = s.timers.filter { follow.contains($0.group) }
        let read = Date(timeIntervalSince1970: s.at / 1000)
        let horizon = now.addingTimeInterval(12 * 3600).timeIntervalSince1970 * 1000
        let moments = Set(timers.compactMap(\.readyAt).filter { $0 > now.timeIntervalSince1970 * 1000 && $0 < horizon })
            .sorted().prefix(29).map { Date(timeIntervalSince1970: $0 / 1000 + 1) }
        return ([now] + moments).map { d in
            let groups = TimerMath.summarize(timers, meta: s.meta, subs: s.subs, at: d).sorted { $0.sortKey < $1.sortKey }
            return FarmEntry(date: d, groups: groups, readAt: read, empty: false)
        }
    }

    static let emptyEntry = FarmEntry(date: .now, groups: [], readAt: nil, empty: true)
    static var sample: FarmEntry {
        let now = Date()
        func g(_ k: String, _ l: String, _ sub: String, _ min: Double?, ready: Int = 0) -> GroupState {
            GroupState(key: k, label: l, sub: sub, total: 4, ready: ready, empty: 0, blocked: 0,
                       nextAt: min.map { now.addingTimeInterval($0 * 60) }, allAt: nil, progress: ready > 0 ? 1 : 0.4,
                       nextStart: now.addingTimeInterval(-3600))
        }
        return FarmEntry(date: now, groups: [g("stone", "Pierre", "Pierre ×18", nil, ready: 21), g("trees", "Arbres", "Arbre ×4", 17),
                                             g("cooking", "Cuisine", "Pizza ×3", 42), g("crops", "Parcelles", "Blé ×81", 156),
                                             g("greenhouse", "Serre", "Riz ×4", 207), g("sheep", "Moutons", "30 moutons", 389)],
                         readAt: now, empty: false)
    }
}

// MARK: - Views

struct WidgetRow: View {
    let g: GroupState
    let date: Date
    var compact = false

    var body: some View {
        let color = GroupLook.color(g.key)
        VStack(spacing: 3) {
            HStack(spacing: 7) {
                Image(systemName: GroupLook.symbol(g.key)).font(.system(size: compact ? 11 : 12, weight: .semibold)).foregroundStyle(color)
                    .frame(width: 16)
                Text(g.label).font(Theme.body(compact ? 12.5 : 13.5, semibold: true))
                    .foregroundStyle(g.isReady ? Theme.ready : Theme.text).lineLimit(1)
                Spacer(minLength: 4)
                if g.isReady {
                    Text(TimerMath.when(g, now: date)).font(Theme.body(11, semibold: true)).foregroundStyle(Theme.onGold)
                        .padding(.horizontal, 6).padding(.vertical, 1.5).background(Theme.ready, in: Capsule())
                } else if let n = g.nextAt {
                    Text(n, style: .relative).font(Theme.body(compact ? 12 : 13, semibold: true)).foregroundStyle(Theme.text)
                        .monospacedDigit().multilineTextAlignment(.trailing).lineLimit(1).frame(maxWidth: 74, alignment: .trailing)
                } else {
                    Text(TimerMath.when(g, now: date)).font(Theme.body(12)).foregroundStyle(Theme.loss)
                }
            }
            if let n = g.nextAt, let s = g.nextStart, !g.isReady, n > s {
                ProgressView(timerInterval: s...n, countsDown: false) { EmptyView() } currentValueLabel: { EmptyView() }
                    .progressViewStyle(.linear).tint(color).scaleEffect(x: 1, y: 0.6).padding(.leading, 23)
            } else {
                Capsule().fill(g.isReady ? Theme.sheep : Color.white.opacity(0.08)).frame(height: 2.5).padding(.leading, 23)
            }
        }
        .opacity(g.isReady || g.nextAt == nil ? 1 : 0.7)
    }
}

struct HarvestWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: FarmEntry

    var body: some View {
        switch family {
        case .accessoryInline: inline
        case .accessoryCircular: circular
        case .accessoryRectangular: rectangular
        default: home
        }
    }

    private var rows: Int {
        switch family { case .systemSmall: 3; case .systemMedium: 4; case .systemLarge: 9; case .systemExtraLarge: 10; default: 3 }
    }

    @ViewBuilder private var home: some View {
        if entry.empty {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: "sun.max.fill").foregroundStyle(Theme.gold)
                Text("Ouvre Harvest Desk pour lire ta ferme.").font(Theme.body(13)).foregroundStyle(Theme.text)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            VStack(alignment: .leading, spacing: family == .systemSmall ? 7 : 8) {
                HStack(spacing: 5) {
                    Image(systemName: "sun.max.fill").font(.system(size: 11)).foregroundStyle(Theme.gold)
                    Text("Harvest Desk").font(Theme.display(12)).foregroundStyle(Theme.dim)
                    Spacer()
                    let ready = entry.groups.filter(\.isReady).count
                    if ready > 0 { Text("\(ready) prêt\(ready > 1 ? "s" : "")").font(Theme.body(11, semibold: true)).foregroundStyle(Theme.ready) }
                }
                if family == .systemMedium {
                    let list = Array(entry.groups.prefix(8))
                    Grid(horizontalSpacing: 14, verticalSpacing: 8) {
                        ForEach(0..<min(4, (list.count + 1) / 2), id: \.self) { i in
                            GridRow {
                                WidgetRow(g: list[i * 2], date: entry.date, compact: true)
                                if i * 2 + 1 < list.count { WidgetRow(g: list[i * 2 + 1], date: entry.date, compact: true) } else { Color.clear }
                            }
                        }
                    }
                } else {
                    ForEach(entry.groups.prefix(rows)) { WidgetRow(g: $0, date: entry.date, compact: family == .systemSmall) }
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var next: GroupState? { entry.groups.first(where: { !$0.isReady && $0.nextAt != nil }) }

    @ViewBuilder private var inline: some View {
        if let r = entry.groups.first(where: \.isReady) { Text("\(Image(systemName: "checkmark.circle")) \(r.label) prêt") }
        else if let n = next, let at = n.nextAt { Text("\(n.label) \(at, style: .relative)") }
        else { Text("Harvest Desk") }
    }

    @ViewBuilder private var circular: some View {
        if let n = next, let at = n.nextAt, let s = n.nextStart {
            ProgressView(timerInterval: s...at, countsDown: false) {
                Image(systemName: GroupLook.symbol(n.key))
            } currentValueLabel: { Image(systemName: GroupLook.symbol(n.key)) }
            .progressViewStyle(.circular)
        } else {
            ZStack { AccessoryWidgetBackground(); Image(systemName: entry.groups.contains(where: \.isReady) ? "checkmark" : "sun.max") }
        }
    }

    @ViewBuilder private var rectangular: some View {
        VStack(alignment: .leading, spacing: 1) {
            let ready = entry.groups.filter(\.isReady)
            if !ready.isEmpty {
                Text("\(Image(systemName: "checkmark.circle.fill")) \(ready.prefix(2).map(\.label).joined(separator: ", "))").font(.headline).lineLimit(1)
            }
            ForEach(entry.groups.filter { !$0.isReady && $0.nextAt != nil }.prefix(ready.isEmpty ? 3 : 2)) { g in
                HStack(spacing: 4) {
                    Text(g.label).lineLimit(1)
                    Spacer(minLength: 2)
                    Text(g.nextAt!, style: .timer).monospacedDigit().multilineTextAlignment(.trailing).frame(maxWidth: 60, alignment: .trailing)
                }
                .font(.system(size: 13))
            }
        }
    }
}

