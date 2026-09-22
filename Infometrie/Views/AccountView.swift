import SwiftUI

struct AccountView: View {
    @Environment(AppModel.self) private var model
    @AppStorage("appearance") private var appearance = "system"
    @AppStorage("comfortableReading") private var comfortableReading = true
    @State private var showLogout = false
    var body: some View {
        Form {
            Section {
                HStack(spacing: 15) {
                    Image(systemName: model.isDemo ? "sparkles" : "person.crop.circle.fill")
                        .font(.largeTitle).foregroundStyle(Brand.blue)
                        .frame(width: 64, height: 64).background(Brand.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 21))
                    VStack(alignment: .leading, spacing: 5) {
                        Text(model.isDemo ? "Mode démonstration" : (model.session?.fullname?.isEmpty == false ? model.session!.fullname! : "Votre compte"))
                            .font(.headline)
                        Text(model.isDemo ? "Découvrez InfoMétrie" : model.session?.email ?? "").font(.subheadline).foregroundStyle(Brand.secondary)
                        if let organisation = model.session?.organisation, !organisation.isEmpty { Text(organisation).font(.caption).foregroundStyle(Brand.secondary) }
                    }
                }.padding(.vertical, 10)
            }
            Section {
                Toggle("Texte plus grand", isOn: $comfortableReading)
                    .accessibilityIdentifier("comfortable-reading")
            } header: { Text("Confort de lecture") } footer: {
                Text("Agrandit le texte dans l’application. Les tailles plus grandes choisies dans les réglages de l’iPhone sont toujours respectées.")
            }
            Section("Apparence") {
                Picker("Thème", selection: $appearance) {
                    Text("Automatique").tag("system")
                    Text("Clair").tag("light")
                    Text("Sombre").tag("dark")
                }
            }
            Section("Votre abonnement") {
                Label("Abonnement InfoMétrie", systemImage: "checkmark.seal")
                Text("L’abonnement, les appareils autorisés et la facturation se gèrent sur le portail web InfoMétrie.")
                    .font(.subheadline).foregroundStyle(Brand.secondary)
            }
            Section("À propos") {
                LabeledContent("Version", value: "0.4.0 · iOS")
                LabeledContent("Environnement", value: "HLS Test")
                Label("Consultation seule", systemImage: "lock.shield")
                Text("Les séquences ne peuvent être ni exportées, ni copiées, ni partagées.")
                    .font(.caption).foregroundStyle(Brand.secondary)
                if model.isDemo { Text("Les personnalités, médias et contenus affichés dans cette démonstration sont fictifs.").font(.caption).foregroundStyle(Brand.secondary) }
            }
            Section {
                Button(model.isDemo ? "Quitter la démonstration" : "Se déconnecter", role: .destructive) {
                    if model.isDemo { model.logout() } else { showLogout = true }
                }.frame(maxWidth: .infinity).accessibilityIdentifier("logout")
            }
        }
        .navigationTitle("Compte")
        .confirmationDialog("Se déconnecter ?", isPresented: $showLogout, titleVisibility: .visible) {
            Button("Se déconnecter", role: .destructive) { model.logout() }
        } message: { Text("Vos suivis seront conservés sur cet appareil.") }
    }
}
