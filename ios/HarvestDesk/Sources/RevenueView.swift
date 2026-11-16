import SwiftUI

/// Revenus: net per day by category, from the counters GitHub keeps every day.
struct RevenueView: View {
    @EnvironmentObject var store: Store
    @Environment(\.horizontalSizeClass) private var size
    @State private var open: String?

    static let names: [String: (String, String, Color)] = [
        "crops": ("Cultures", "leaf.fill", Theme.wheat), "animals": ("Animaux", "pawprint.fill", Theme.sheep),
        "greenhouse": ("Serre", "drop.fill", Theme.glass), "minerals": ("Minerais", "diamond.fill", Theme.ore),
        "wood": ("Bois", "tree.fill", Theme.wood), "fruits": ("Fruits", "applelogo", Theme.fruit),
        "honey": ("Miel", "hexagon.fill", Theme.honey),
    ]

    var body: some View {
        Page(title: "Revenus") {
            if let r = store.revenue, r.days >= 0.5 {
                let perDay = r.net * r.usd
                HStack(spacing: 12) {
                    Kpi(label: "Par jour", value: Fmt.usd(perDay), note: "net, moyenne sur \(Fmt.num(r.days, 1)) j", gold: true)
                    Kpi(label: "Par mois", value: Fmt.usd(perDay * 30.4), note: "\(Fmt.num(r.net, 1)) FLOWER par jour")
                }
                let cats = r.categories.filter { abs($0.net) > 0.001 }.sorted { $0.net > $1.net }
                let maxNet = cats.map { abs($0.net) }.max() ?? 1
                LazyVGrid(columns: size == .regular ? [GridItem(.flexible(), spacing: 14), GridItem(.flexible())] : [GridItem(.flexible())], spacing: 14) {
                    Card(title: "Par catégorie", hint: "Touche une catégorie pour son détail.") {
                        VStack(spacing: 12) {
                            ForEach(cats) { c in
                                let look = Self.names[c.key] ?? (c.key, "circle", Theme.dim)
                                Button { withAnimation { open = open == c.key ? nil : c.key } } label: {
                                    VStack(spacing: 6) {
                                        HStack {
                                            Label(look.0, systemImage: look.1).font(Theme.body(15, semibold: true)).foregroundStyle(Theme.text)
                                            Spacer()
                                            Text(Fmt.signedUsd(c.net * r.usd)).font(Theme.display(15)).foregroundStyle(c.net < 0 ? Theme.loss : Theme.text)
                                        }
                                        Bar(value: abs(c.net) / maxNet, color: c.net < 0 ? Theme.loss : look.2, height: 6)
                                        if open == c.key {
                                            VStack(spacing: 6) {
                                                ForEach(c.lines) { l in
                                                    HStack {
                                                        Text(l.label).font(Theme.body(13.5)).foregroundStyle(Theme.dim)
                                                        Spacer()
                                                        Text(Fmt.signedUsd(l.net * r.usd)).font(Theme.body(13.5)).foregroundStyle(l.net < 0 ? Theme.loss : Theme.text).monospacedDigit()
                                                    }
                                                }
                                            }
                                            .padding(.top, 4)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    Card(title: "Brut et coûts") {
                        row("Produit", r.gross * r.usd, Theme.text)
                        row("Graines, outils, nourriture", -r.cost * r.usd, Theme.loss)
                        Divider().overlay(Theme.line)
                        row("Net par jour", perDay, Theme.gold)
                    }
                }
                Text("Ressources au prix du marché, coins au taux de la banque. Mêmes calculs que l'app PC.")
                    .font(Theme.body(12)).foregroundStyle(Theme.faint)
            } else {
                StatusNotice()
                Notice(icon: "chart.bar.fill", text: "Les revenus apparaissent après environ 12 h de relevés. GitHub note tes compteurs chaque jour, puis l'app calcule ta moyenne.")
            }
        }
    }

    private func row(_ label: String, _ v: Double, _ color: Color) -> some View {
        HStack { Text(label).font(Theme.body(14)).foregroundStyle(Theme.dim); Spacer(); Text(Fmt.signedUsd(v)).font(Theme.display(15)).foregroundStyle(color) }
    }
}
