import SwiftUI

struct AccountView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var sizeClass
    @AppStorage("appearance") private var appearance = "system"
    @AppStorage("readingSize") private var readingSize = ReadingSize.medium
    @State private var showLogout = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                PageHeading(title: "Compte")
                HStack(alignment: .top, spacing: 16) {
                    AccountAvatar(name: model.session?.fullname)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(model.session?.fullname?.isEmpty == false ? model.session!.fullname! : "Votre compte")
                            .font(.headline)
                        Text(model.session?.email ?? "")
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
                }
                AppRule()
                Button("Se déconnecter", role: .destructive) { showLogout = true }
                .font(.body.weight(.medium)).foregroundStyle(Brand.destructive)
                .frame(maxWidth: .infinity, minHeight: 52).contentShape(Rectangle())
                .accessibilityIdentifier("logout")
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, sizeClass == .regular ? AppLayout.wideMargin : AppLayout.margin)
            .padding(.top, 24).padding(.bottom, 32)
            .frame(maxWidth: AppLayout.readingWidth).frame(maxWidth: .infinity)
        }
        .background(Brand.background)
        .navigationTitle("").navigationBarTitleDisplayMode(.inline)
        .toolbar(sizeClass == .regular ? .hidden : .visible, for: .navigationBar)
        .toolbarBackground(Brand.background, for: .navigationBar)
        .toolbar {
            if sizeClass != .regular {
                ToolbarItem(placement: .topBarLeading) { Wordmark(size: 21, scheme: colorScheme) }
                    .sharedBackgroundVisibility(.hidden)
            }
        }
        .confirmationDialog("Se déconnecter ?", isPresented: $showLogout, titleVisibility: .visible) {
            Button("Se déconnecter", role: .destructive) { model.logout() }
        } message: { Text("Vos suivis seront conservés sur cet appareil.") }
    }

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(title: "Apparence")
            // Theme and text size share one control, the S / M / L capsule: the theme was a menu until 2026-10-09.
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    CapsulePicker(selection: $appearance, choices: Appearance.allCases.map { ($0.rawValue, $0.title) },
                                  label: "Thème", identifier: { "appearance-\($0)" })
                        .accessibilityIdentifier("appearance-picker")
                    Text("Thème · \(Appearance(rawValue: appearance)?.title ?? Appearance.system.title)")
                        .font(.footnote).foregroundStyle(Brand.secondary)
                }
                VStack(alignment: .leading, spacing: 8) {
                    CapsulePicker(selection: $readingSize, choices: ReadingSize.allCases.map { ($0, $0.rawValue) },
                                  label: "Taille du texte", identifier: { "reading-size-\($0.rawValue)" },
                                  spokenTitle: { "Taille du texte : \($0.title.lowercased())" })
                    Text("Taille du texte · \(readingSize.title)")
                        .font(.footnote).foregroundStyle(Brand.secondary)
                        .accessibilityIdentifier("reading-size-description")
                }
            }
            // Contain, or this identifier would replace the pickers' and their buttons' own.
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("appearance-card")
        }
    }
}

/// The stored theme choice; the root applies it.
private enum Appearance: String, CaseIterable {
    case system, light, dark
    var title: String {
        switch self {
        case .system: "Système"
        case .light: "Clair"
        case .dark: "Sombre"
        }
    }
}

/// A row of choices in a gris clair capsule, the chosen one on a raised pill that slides to it.
private struct CapsulePicker<Value: Hashable>: View {
    @Binding var selection: Value
    let choices: [(Value, String)]
    let label: String
    let identifier: (Value) -> String
    var spokenTitle: ((Value) -> String)?
    @Namespace private var pill

    var body: some View {
        HStack(spacing: 4) {
            ForEach(choices, id: \.0) { value, title in
                let selected = selection == value
                Button { selection = value } label: {
                    Text(title)
                        .font(.body.weight(selected ? .semibold : .regular))
                        .foregroundStyle(selected ? AnyShapeStyle(Brand.actionText) : AnyShapeStyle(Brand.ink))
                        .lineLimit(1).minimumScaleFactor(0.8)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background {
                            if selected { Capsule().fill(Brand.raised).matchedGeometryEffect(id: "pill", in: pill) }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(spokenTitle?(value) ?? "\(label) : \(title.lowercased())")
                .accessibilityAddTraits(selected ? .isSelected : [])
                .accessibilityIdentifier(identifier(value))
            }
        }
        .padding(4).background(Brand.surface, in: Capsule())
        .motion(value: selection)
        .sensoryFeedback(.selection, trigger: selection)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(label)
    }
}

/// The account's initials on bleu canard; a person when the name is unknown.
private struct AccountAvatar: View {
    let name: String?

    var body: some View {
        Group {
            if let initials { Text(initials).font(.system(size: 20, weight: .bold)) } else { Image(systemName: "person").font(.title2) }
        }
        .foregroundStyle(.white)
        .frame(width: 56, height: 56)
        .background(Brand.canardFill, in: Circle())
        .accessibilityHidden(true)
    }

    private var initials: String? {
        let letters = (name ?? "").split(separator: " ").prefix(2).compactMap(\.first).map { String($0).uppercased() }
        return letters.isEmpty ? nil : letters.joined()
    }
}
