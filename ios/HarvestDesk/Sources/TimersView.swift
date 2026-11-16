import SwiftUI

/// Minuteurs: every group of the farm, by family, the soonest first.
struct TimersView: View {
    @EnvironmentObject var store: Store
    @Environment(\.horizontalSizeClass) private var size

    var body: some View {
        Page(title: "Minuteurs") {
            StatusNotice()
            TimelineView(.periodic(from: .now, by: 30)) { ctx in
                let groups = store.groups(at: ctx.date)
                let families = (store.timers?.families ?? []).compactMap { f -> (Family, [GroupState])? in
                    let rows = groups.filter { f.groups.contains($0.key) }.sorted { $0.sortKey < $1.sortKey }
                    return rows.isEmpty ? nil : (f, rows)
                }.sorted { $0.1[0].sortKey < $1.1[0].sortKey }

                if groups.isEmpty, store.status != .loading {
                    Notice(icon: "clock", text: "Rien à afficher pour l'instant. Tire vers le bas pour relire ta ferme.")
                } else {
                    ReadySummary(groups: groups)
                    LazyVGrid(columns: size == .regular ? [GridItem(.adaptive(minimum: 340), spacing: 14, alignment: .top)] : [GridItem(.flexible())],
                              alignment: .leading, spacing: 14) {
                        ForEach(families, id: \.0.key) { fam, rows in
                            Card(title: fam.label) {
                                VStack(spacing: 4) { ForEach(rows) { TimerRow(g: $0, now: ctx.date) } }
                            }
                        }
                    }
                }
            }
        }
    }
}

/// "3 groupes prêts" header strip.
struct ReadySummary: View {
    var groups: [GroupState]
    var body: some View {
        let ready = groups.filter(\.isReady)
        let next = groups.compactMap(\.nextAt).min()
        HStack(spacing: 12) {
            Kpi(label: "Prêt à récolter", value: "\(ready.count)",
                note: ready.isEmpty ? "rien pour l'instant" : ready.prefix(3).map(\.label).joined(separator: ", "), gold: !ready.isEmpty)
            Kpi(label: "Prochain", value: next.map { TimerMath.countdown($0.timeIntervalSinceNow) } ?? "—",
                note: next.map { "à " + TimerMath.clock($0) })
        }
    }
}

struct TimerRow: View {
    var g: GroupState
    var now: Date

    var body: some View {
        let color = GroupLook.color(g.key)
        VStack(spacing: 6) {
            HStack(spacing: 12) {
                Image(systemName: GroupLook.symbol(g.key))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 32, height: 32)
                    .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                VStack(alignment: .leading, spacing: 1) {
                    Text(g.label).font(Theme.body(15, semibold: true)).foregroundStyle(g.isReady ? Theme.ready : Theme.text)
                    if !g.sub.isEmpty { Text(g.sub).font(Theme.body(12.5)).foregroundStyle(Theme.dim).lineLimit(1) }
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 1) {
                    if g.isReady {
                        Text(TimerMath.when(g, now: now)).font(Theme.body(13, semibold: true))
                            .foregroundStyle(Theme.onGold)
                            .padding(.horizontal, 9).padding(.vertical, 3)
                            .background(Theme.ready, in: Capsule())
                    } else {
                        Text(TimerMath.when(g, now: now)).font(Theme.display(16)).foregroundStyle(Theme.text).monospacedDigit()
                    }
                    if let n = g.nextAt, !g.isReady { Text(TimerMath.clock(n, now: now)).font(Theme.body(12)).foregroundStyle(Theme.faint) }
                    else if g.isReady, let a = g.allAt { Text("reste " + TimerMath.countdown(a.timeIntervalSince(now))).font(Theme.body(12)).foregroundStyle(Theme.faint) }
                }
            }
            Bar(value: g.progress, color: g.isReady ? Theme.sheep : color, height: 3)
                .padding(.leading, 44)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 6)
        .opacity(g.isReady || g.nextAt == nil ? 1 : 0.62)
        .background(g.isReady ? Theme.ready.opacity(0.06) : .clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(g.isReady ? Theme.ready.opacity(0.28) : .clear, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}

struct StatusNotice: View {
    @EnvironmentObject var store: Store
    var body: some View {
        switch store.status {
        case .needsSetup: Notice(icon: "key.fill", text: "Ajoute ta clé API Sunflower Land et ton numéro de ferme dans Réglages.")
        case .error(let e): Notice(icon: "exclamationmark.triangle.fill", text: e, color: Theme.loss)
        default:
            if let f = store.fetchedAt {
                Text("Ferme lue \(f.formatted(.relative(presentation: .named, unitsStyle: .wide)))")
                    .font(Theme.body(12.5)).foregroundStyle(Theme.faint)
            }
        }
    }
}
