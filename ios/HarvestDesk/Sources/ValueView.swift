import SwiftUI

/// Valeur de la ferme: everything priced at today's market.
struct ValueView: View {
    @EnvironmentObject var store: Store
    @Environment(\.horizontalSizeClass) private var size

    private func color(_ key: String) -> Color {
        switch key { case "nfts": return Theme.gold; case "wearables": return Theme.fruit; case "buds": return Theme.sheep
        case "resources": return Theme.wood; case "flower": return Theme.honey; default: return Theme.dim }
    }

    var body: some View {
        Page(title: "Valeur de la ferme") {
            if let v = store.value {
                let nft = v.groups.filter { ["nfts", "wearables", "buds"].contains($0.key) }.reduce(0) { $0 + $1.total }
                LazyVGrid(columns: size == .regular ? Array(repeating: GridItem(.flexible(), spacing: 12), count: 3) : [GridItem(.flexible(), spacing: 12), GridItem(.flexible())], spacing: 12) {
                    Kpi(label: "Valeur", value: Fmt.usd(store.usd(v.total)), note: "\(Fmt.num(v.total)) FLOWER", gold: true)
                    Kpi(label: "Si tu vendais tout", value: Fmt.usd(store.usd(v.netIfSold)), note: "après la taxe de 10 %")
                    if size == .regular { Kpi(label: "Dont NFT", value: Fmt.usd(store.usd(nft)), note: "collectibles, wearables, Buds") }
                }
                let shown = v.groups.filter { $0.total > 0 }
                let maxT = shown.map(\.total).max() ?? 1
                Card(title: "Répartition") {
                    VStack(spacing: 10) {
                        ForEach(shown) { g in
                            VStack(spacing: 5) {
                                HStack { Text(g.label).font(Theme.body(14.5, semibold: true)).foregroundStyle(Theme.text); Spacer()
                                    Text(Fmt.usd(store.usd(g.total))).font(Theme.display(15)).foregroundStyle(Theme.text) }
                                Bar(value: g.total / maxT, color: color(g.key), height: 6)
                            }
                        }
                    }
                }
                LazyVGrid(columns: size == .regular ? [GridItem(.flexible(), spacing: 14), GridItem(.flexible())] : [GridItem(.flexible())], alignment: .leading, spacing: 14) {
                    ForEach(shown.filter { !$0.items.isEmpty && $0.key != "coins" && $0.key != "flower" }) { g in
                        Card(title: g.label) {
                            ForEach(g.items.prefix(8), id: \.name) { it in
                                HStack {
                                    Text(it.name).font(Theme.body(14)).foregroundStyle(Theme.text).lineLimit(1)
                                    if it.qty != 1 { Text("×\(Fmt.num(it.qty))").font(Theme.body(12)).foregroundStyle(Theme.faint) }
                                    Spacer()
                                    Text(Fmt.usd(store.usd(it.value))).font(Theme.body(14, semibold: true)).foregroundStyle(Theme.text).monospacedDigit()
                                }
                            }
                        }
                    }
                }
                Text("NFT au prix plancher (ou dernière vente), ressources à la dernière vente, coins au taux de la banque.")
                    .font(Theme.body(12)).foregroundStyle(Theme.faint)
            } else {
                StatusNotice()
                Notice(icon: "dollarsign.circle", text: "La valeur apparaît dès que le marché est lu.")
            }
        }
    }
}
