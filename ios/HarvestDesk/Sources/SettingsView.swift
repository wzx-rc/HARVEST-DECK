import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: Store
    @State private var key = ""
    @State private var saved = false

    var body: some View {
        Form {
            Section {
                SecureField("Clé API Community", text: $key)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                TextField("Numéro de ferme", text: $store.farmId).keyboardType(.numberPad)
                Button(saved ? "Enregistré" : "Enregistrer et lire la ferme") {
                    if !key.isEmpty { store.apiKey = key }
                    key = ""; saved = true
                    Task { await store.refresh(force: true) }
                }
                .tint(Theme.gold)
            } header: { Text("Sunflower Land") } footer: {
                Text(store.apiKey.isEmpty ? "La clé se trouve dans le jeu : Réglages, API Community. Elle reste dans le trousseau de ton iPhone."
                                          : "Une clé est enregistrée dans le trousseau. Saisis-en une nouvelle pour la remplacer.")
            }

            Section {
                ForEach(store.timers?.meta ?? [], id: \.key) { m in
                    Toggle(isOn: Binding(
                        get: { store.follow.contains(m.key) },
                        set: { on in store.follow = on ? store.follow + [m.key] : store.follow.filter { $0 != m.key } })) {
                        Label(m.label, systemImage: GroupLook.symbol(m.key)).foregroundStyle(Theme.text)
                    }
                    .tint(Theme.gold)
                }
            } header: { Text("Widget") } footer: { Text("Ce que le widget suit. Il range les groupes du plus tôt prêt au plus tard.") }

            Section {
                TextField("Adresse des relevés", text: $store.readingsBase).textInputAutocapitalization(.never).autocorrectionDisabled().font(.footnote)
            } header: { Text("Relevés GitHub") } footer: { Text("Les relevés Money Tree et les compteurs du jour, faits toutes les 10 minutes par GitHub.") }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.ground.ignoresSafeArea())
        .navigationTitle("Réglages")
    }
}
