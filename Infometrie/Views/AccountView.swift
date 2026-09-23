import SwiftUI

struct AccountView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.horizontalSizeClass) private var sizeClass
    @AppStorage("appearance") private var appearance = "system"
    @AppStorage("comfortableReading") private var comfortableReading = true
    @State private var showLogout = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                EditorialPageHeading(title: "Compte")
                HStack(alignment: .top, spacing: 16) {
                    Image(systemName: model.isDemo ? "sparkles" : "person")
                        .font(.title2).foregroundStyle(Brand.citation)
                        .frame(width: 56, height: 56).background(Brand.citation.opacity(0.07), in: Circle())
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(model.isDemo ? "Mode démonstration" : (model.session?.fullname?.isEmpty == false ? model.session!.fullname! : "Votre compte"))
                            .font(.system(.title3, design: .serif, weight: .semibold))
                        Text(model.isDemo ? "Découvrez InfoMétrie" : model.session?.email ?? "")
                            .font(.subheadline).foregroundStyle(Brand.secondary)
                        if let organisation = model.session?.organisation, !organisation.isEmpty {
                            Text(organisation).font(.subheadline).foregroundStyle(Brand.secondary)
                        }
                    }.fixedSize(horizontal: false, vertical: true)
                }
                EditorialSection(title: "Confort de lecture") {
                    Toggle("Texte plus grand", isOn: $comfortableReading)
                        .tint(Brand.citation).frame(minHeight: 52)
                        .accessibilityIdentifier("comfortable-reading")
                    Text("Agrandit le texte dans l’application. Les tailles plus grandes choisies dans les réglages de votre appareil sont toujours respectées.")
                        .font(.subheadline).foregroundStyle(Brand.secondary)
                }
                EditorialSection(title: "Apparence") {
                    Picker("Thème", selection: $appearance) {
                        Text("Automatique").tag("system")
                        Text("Clair").tag("light")
                        Text("Sombre").tag("dark")
                    }.pickerStyle(.menu).frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                        .accessibilityIdentifier("appearance-picker")
                }
                EditorialSection(title: "Votre abonnement") {
                    Label("Abonnement InfoMétrie", systemImage: "checkmark.seal")
                    Text("L’abonnement, les appareils autorisés et la facturation se gèrent sur le portail web InfoMétrie.")
                        .font(.subheadline).foregroundStyle(Brand.secondary)
                }
                EditorialSection(title: "À propos") {
                    AdaptiveRow { Text("Version"); Spacer(minLength: 0); Text("0.4.0 · iOS").foregroundStyle(Brand.secondary) }
                    AdaptiveRow { Text("Environnement"); Spacer(minLength: 0); Text("HLS Test").foregroundStyle(Brand.secondary) }
                    Label("Consultation seule", systemImage: "lock.shield")
                    Text("Les séquences ne peuvent être ni exportées, ni copiées, ni partagées.")
                        .font(.subheadline).foregroundStyle(Brand.secondary)
                    if model.isDemo {
                        Text("Les personnalités, médias et contenus affichés dans cette démonstration sont fictifs.")
                            .font(.footnote).foregroundStyle(Brand.secondary)
                    }
                }
                EditorialRule()
                Button(model.isDemo ? "Quitter la démonstration" : "Se déconnecter", role: .destructive) {
                    if model.isDemo { model.logout() } else { showLogout = true }
                }
                .font(.body.weight(.medium)).foregroundStyle(Brand.citation)
                .frame(maxWidth: .infinity, minHeight: 52).contentShape(Rectangle())
                .accessibilityIdentifier("logout")
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, sizeClass == .regular ? EditorialLayout.wideMargin : 20)
            .padding(.top, 24).padding(.bottom, 32)
            .frame(maxWidth: EditorialLayout.readingWidth).frame(maxWidth: .infinity)
        }
        .background(Brand.background)
        .navigationTitle("").navigationBarTitleDisplayMode(.inline)
        .toolbar(sizeClass == .regular ? .hidden : .visible, for: .navigationBar)
        .toolbar { if sizeClass != .regular { ToolbarItem(placement: .principal) { Wordmark(size: 21) } } }
        .confirmationDialog("Se déconnecter ?", isPresented: $showLogout, titleVisibility: .visible) {
            Button("Se déconnecter", role: .destructive) { model.logout() }
        } message: { Text("Vos suivis seront conservés sur cet appareil.") }
    }
}
