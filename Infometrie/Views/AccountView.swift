import SwiftUI

struct AccountView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.horizontalSizeClass) private var sizeClass
    @AppStorage("appearance") private var appearance = "system"
    @AppStorage("readingSize") private var readingSize = ReadingSize.medium
    @State private var showLogout = false
    @Namespace private var sizeSelection

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PageHeading(title: "Compte")
                HStack(alignment: .top, spacing: 16) {
                    Image(systemName: model.isDemo ? "sparkles" : "person")
                        .font(.title2).foregroundStyle(Brand.tint)
                        .frame(width: 56, height: 56).background(Brand.surface, in: Circle())
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(model.isDemo ? "Mode démonstration" : (model.session?.fullname?.isEmpty == false ? model.session!.fullname! : "Votre compte"))
                            .font(.headline)
                        Text(model.isDemo ? "Découvrez InfoMétrie" : model.session?.email ?? "")
                            .font(.subheadline).foregroundStyle(Brand.secondary)
                        if let organisation = model.session?.organisation, !organisation.isEmpty {
                            Text(organisation).font(.subheadline).foregroundStyle(Brand.secondary)
                        }
                    }.fixedSize(horizontal: false, vertical: true)
                }
                appearanceSection
                AppSection(title: "Votre abonnement") {
                    Label("Abonnement InfoMétrie", systemImage: "checkmark.seal")
                    Text("L’abonnement, les appareils autorisés et la facturation se gèrent sur le portail web InfoMétrie.")
                        .font(.subheadline).foregroundStyle(Brand.secondary)
                }
                AppSection(title: "À propos") {
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
                AppRule()
                Button(model.isDemo ? "Quitter la démonstration" : "Se déconnecter", role: .destructive) {
                    if model.isDemo { model.logout() } else { showLogout = true }
                }
                .font(.body.weight(.medium)).foregroundStyle(Brand.destructive)
                .frame(maxWidth: .infinity, minHeight: 52).contentShape(Rectangle())
                .accessibilityIdentifier("logout")
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, sizeClass == .regular ? AppLayout.wideMargin : 20)
            .padding(.top, 24).padding(.bottom, 32)
            .frame(maxWidth: AppLayout.readingWidth).frame(maxWidth: .infinity)
        }
        .background(Brand.background)
        .navigationTitle("").navigationBarTitleDisplayMode(.inline)
        .toolbar(sizeClass == .regular ? .hidden : .visible, for: .navigationBar)
        .toolbarBackground(Brand.background, for: .navigationBar)
        .toolbar {
            if sizeClass != .regular {
                ToolbarItem(placement: .topBarLeading) { Wordmark(size: 21) }
                    .sharedBackgroundVisibility(.hidden)
            }
        }
        .confirmationDialog("Se déconnecter ?", isPresented: $showLogout, titleVisibility: .visible) {
            Button("Se déconnecter", role: .destructive) { model.logout() }
        } message: { Text("Vos suivis seront conservés sur cet appareil.") }
    }

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Apparence").font(.headline).accessibilityAddTraits(.isHeader)
            VStack(spacing: 12) {
                AdaptiveRow {
                    Text("Thème").font(.body)
                    Spacer(minLength: 0)
                    Picker("Thème", selection: $appearance) {
                        Text("Système").tag("system")
                        Text("Clair").tag("light")
                        Text("Sombre").tag("dark")
                    }
                    .pickerStyle(.menu).labelsHidden().tint(Brand.secondary)
                    .frame(minHeight: 44)
                    .accessibilityLabel("Thème")
                    .accessibilityIdentifier("appearance-picker")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                AppRule()
                HStack(spacing: 4) {
                    ForEach(ReadingSize.allCases, id: \.self) { size in
                        Button { readingSize = size } label: {
                            Text(size.rawValue)
                                .font(.body.weight(readingSize == size ? .semibold : .regular))
                                .foregroundStyle(Brand.ink)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .background {
                                    // The selection pill slides to the chosen size.
                                    if readingSize == size {
                                        Capsule().fill(Brand.card).matchedGeometryEffect(id: "size", in: sizeSelection)
                                    }
                                }
                                .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Taille du texte : \(size.title.lowercased())")
                        .accessibilityAddTraits(readingSize == size ? .isSelected : [])
                        .accessibilityIdentifier("reading-size-\(size.rawValue)")
                    }
                }
                .padding(4).background(Brand.surface, in: Capsule())
                .motion(value: readingSize)
                .sensoryFeedback(.selection, trigger: readingSize)
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Taille du texte")
            }
            .padding(16)
            .background(Brand.card, in: RoundedRectangle(cornerRadius: 24))
            .overlay { RoundedRectangle(cornerRadius: 24).strokeBorder(Brand.rule, lineWidth: 0.5) }
            .accessibilityIdentifier("appearance-card")
            Text("Taille du texte · \(readingSize.title)")
                .font(.footnote).foregroundStyle(Brand.secondary)
                .accessibilityIdentifier("reading-size-description")
        }
    }
}
