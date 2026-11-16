import Charts
import SwiftUI

/// Pops Money Tree, from the GitHub readings (every 10 min).
struct ProcsView: View {
    @EnvironmentObject var store: Store
    @Environment(\.horizontalSizeClass) private var size

    var body: some View {
        Page(title: "Money Tree") {
            if let p = store.procs {
                let s = p.stats
                let perDay = s.chops > 0 && s.chopsPerDay > 0 ? s.coins / s.chops * s.chopsPerDay : s.coins / max(s.hours / 24, 1 / 24)
                let luck = s.expectedPops > 0 ? Double(s.pops) / s.expectedPops : 0
                let toUsd = { (c: Double) in c / p.coinsPerFlower * store.flowerUsd }
                LazyVGrid(columns: size == .regular ? Array(repeating: GridItem(.flexible(), spacing: 12), count: 3) : [GridItem(.flexible(), spacing: 12), GridItem(.flexible())], spacing: 12) {
                    Kpi(label: "Pops relevés", value: "\(s.pops)", note: "sur \(Fmt.num(s.hours)) h suivies, rang \(p.rank)", gold: true)
                    Kpi(label: "Par jour", value: "\(Fmt.num(perDay)) coins", note: "≈ \(Fmt.usd(toUsd(perDay) * 30.4)) par mois")
                    Kpi(label: "Ta chance", value: s.expectedPops >= 0.5 ? "\(Int((luck * 100).rounded())) %" : "—",
                        note: "\(s.pops) pops pour \(Fmt.num(s.expectedPops, 1)) attendus" + (s.expectedPops < 10 ? ". Encore trop tôt pour conclure" : ""))
                }
                Card(title: "Coins par jour", hint: "Barres : ce que tu as reçu. Trait : la moyenne attendue avec tes coupes.") {
                    Chart {
                        ForEach(s.perDay.suffix(14)) { d in
                            BarMark(x: .value("Jour", Date(timeIntervalSince1970: d.day / 1000), unit: .day), y: .value("Coins", d.coins))
                                .foregroundStyle(Theme.gold).cornerRadius(4)
                            RuleMark(xStart: .value("d", Date(timeIntervalSince1970: d.day / 1000 + 4 * 3600)),
                                     xEnd: .value("f", Date(timeIntervalSince1970: d.day / 1000 + 20 * 3600)),
                                     y: .value("Attendu", d.expectedCoins))
                                .foregroundStyle(Theme.dim).lineStyle(StrokeStyle(lineWidth: 2, dash: [4, 3]))
                        }
                    }
                    .chartXAxis { AxisMarks(values: .stride(by: .day)) { _ in AxisValueLabel(format: .dateTime.day().month(.defaultDigits)).foregroundStyle(Theme.dim) } }
                    .chartYAxis { AxisMarks { _ in AxisGridLine().foregroundStyle(Theme.line); AxisValueLabel().foregroundStyle(Theme.dim) } }
                    .frame(height: 200)
                }
                LazyVGrid(columns: size == .regular ? [GridItem(.flexible(), spacing: 14), GridItem(.flexible())] : [GridItem(.flexible())], alignment: .leading, spacing: 14) {
                    Card(title: "Par arbre", hint: "Un pop vaut 200 coins × le multiplicateur de l'arbre.") {
                        ForEach(s.byTree) { t in
                            HStack {
                                Label(p.treeNames[t.tree] ?? t.tree, systemImage: "tree.fill").foregroundStyle(Theme.text).font(Theme.body(14.5))
                                Spacer()
                                Text("\(t.pops)").font(Theme.display(15)).foregroundStyle(Theme.text)
                                Text("/ \(Fmt.num(t.expectedPops, 1))").font(Theme.body(12)).foregroundStyle(Theme.faint)
                                Text(Fmt.num(t.coins)).font(Theme.body(14, semibold: true)).foregroundStyle(Theme.gold).frame(width: 64, alignment: .trailing)
                            }
                        }
                    }
                    Card(title: "Derniers pops") {
                        if p.events.isEmpty { Text("Aucun pop pour l'instant.").font(Theme.body(14)).foregroundStyle(Theme.dim) }
                        ForEach(p.events.prefix(12)) { e in
                            HStack {
                                Text(Fmt.day(e.at, "EEE d MMM, HH:mm")).font(Theme.body(14)).foregroundStyle(Theme.text)
                                Spacer()
                                Text(e.before == true ? "avant le suivi" : (e.tree.flatMap { p.treeNames[$0] } ?? "arbre inconnu"))
                                    .font(Theme.body(12.5)).foregroundStyle(Theme.dim)
                                Text(e.coins.map { "+\(Fmt.num($0))" } ?? "—").font(Theme.body(14, semibold: true)).foregroundStyle(Theme.gold)
                                    .frame(width: 60, alignment: .trailing)
                            }
                        }
                    }
                }
                Text("GitHub relit ta ferme toutes les 10 minutes, même téléphone éteint. Le jeu ne garde que l'heure du dernier pop : deux pops dans les mêmes 10 minutes comptent pour un.")
                    .font(Theme.body(12)).foregroundStyle(Theme.faint)
            } else {
                StatusNotice()
                Notice(icon: "tree.fill", text: "Les relevés Money Tree arrivent de GitHub. Tire vers le bas pour les charger.")
            }
        }
    }
}
