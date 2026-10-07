import SwiftUI

struct LoginView: View {
    @Environment(AppModel.self) private var model
    @State private var password = ""
    @State private var showPassword = false
    @State private var selectedDevice: DeviceInfo?
    @State private var viewportHeight: CGFloat = 0
    @FocusState private var focused: Field?
    private enum Field { case email, password }

    /// What the app is, on the dawn of the icon's colors: the wordmark, the three kinds and the promise.
    private var showcase: some View {
        VStack(spacing: 18) {
            Wordmark(size: 26)
            KindFan()
            Text("Ce que disent les personnalités politiques, à la radio, à la télévision et sur\u{00A0}X.")
                .font(.subheadline).foregroundStyle(Brand.secondary)
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26).padding(.horizontal, 20)
    }

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    showcase.padding(.top, 25)
                    Text("Connectez-vous").font(.title2.weight(.bold)).foregroundStyle(Brand.ink)
                        .accessibilityAddTraits(.isHeader).padding(.top, 6)
                    VStack(alignment: .leading, spacing: 18) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Email").font(.body.weight(.medium))
                            TextField("Email", text: $model.email, prompt: Text(verbatim: "vous@organisation.fr").foregroundStyle(Brand.secondaryOnSurface))
                                .textContentType(.username).keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never).autocorrectionDisabled()
                                .focused($focused, equals: .email).submitLabel(.next).onSubmit { focused = .password }
                                .padding(15).appInput()
                                .accessibilityIdentifier("login-email")
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Mot de passe").font(.body.weight(.medium))
                            HStack {
                                Group {
                                    if showPassword { TextField("Mot de passe", text: $password, prompt: Text("Votre mot de passe").foregroundStyle(Brand.secondaryOnSurface)) }
                                    else { SecureField("Mot de passe", text: $password, prompt: Text("Votre mot de passe").foregroundStyle(Brand.secondaryOnSurface)) }
                                }.textContentType(.password).textInputAutocapitalization(.never).autocorrectionDisabled().focused($focused, equals: .password)
                                    .submitLabel(.go).onSubmit { signIn() }.accessibilityIdentifier("login-password")
                                Button { showPassword.toggle() } label: { Image(systemName: showPassword ? "eye.slash" : "eye").foregroundStyle(Brand.tint).frame(width: 52, height: 52).contentShape(Rectangle()) }
                                    .accessibilityLabel(showPassword ? "Masquer le mot de passe" : "Afficher le mot de passe")
                            }.padding(.leading, 15).padding(.trailing, 4).appInput()
                        }
                        if let error = model.loginError { ErrorNotice(message: error).accessibilityIdentifier("login-error") }
                        Button(action: signIn) {
                            HStack {
                                Text(model.isLoggingIn ? "Connexion…" : "Se connecter").fontWeight(.semibold)
                                    .skeleton(model.isLoggingIn, shapes: false)
                                if !model.isLoggingIn { Image(systemName: "arrow.right") }
                            }.frame(maxWidth: .infinity)
                        }
                        .buttonStyle(ActionButtonStyle(prominent: true))
                        .disabled(model.email.trimmingCharacters(in: .whitespaces).isEmpty || password.isEmpty || model.isLoggingIn)
                        .accessibilityIdentifier("login-submit")
                    }

                    Text("L’abonnement et la gestion du compte se font sur le portail web InfoMétrie.")
                        .font(.footnote).foregroundStyle(Brand.secondary).multilineTextAlignment(.center).lineSpacing(3)
                        .frame(maxWidth: .infinity)
                }.padding(.horizontal, 24).padding(.bottom, 35).frame(maxWidth: 520)
                    .frame(maxWidth: .infinity)
                    // The form sits in the middle of the screen; it still scrolls when taller.
                    .frame(minHeight: viewportHeight)
            }
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { viewportHeight = $0 }
            .background(alignment: .top) { LoginDawn().frame(height: max(430, viewportHeight * 0.55)).ignoresSafeArea() }
            .background(Brand.background).scrollDismissesKeyboard(.interactively)
            .sheet(item: $model.quota) { quota in
                NavigationStack {
                    List {
                        PageHeading(title: "Vos appareils").padding(.vertical, 20)
                            .listRowBackground(Color.clear).listRowSeparator(.hidden)
                        Section {
                            Text("Votre compte autorise \(quota.maximum) appareils. Choisissez celui que vous souhaitez remplacer pour vous connecter ici. L’appareil remplacé sera déconnecté.")
                                .foregroundStyle(Brand.secondary).padding(.vertical, 12)
                        }.listRowBackground(Color.clear).listRowSeparator(.hidden)
                        Section {
                            ForEach(quota.devices) { device in
                                Button { selectedDevice = device } label: {
                                    VStack(alignment: .leading, spacing: 5) {
                                        Label(device.name ?? "Appareil \(device.id)", systemImage: "iphone")
                                        Text(device.model ?? "").font(.footnote).foregroundStyle(Brand.secondary)
                                        if let seen = device.lastSeen, let date = APIDate.parse(seen) { Text("Vu le \(date.formatted(date: .abbreviated, time: .shortened))").font(.footnote).foregroundStyle(Brand.secondary) }
                                    }
                                }
                            }
                            if quota.devices.isEmpty { Text("Gérez vos appareils sur le portail web InfoMétrie.").foregroundStyle(Brand.secondary) }
                        } header: {
                            Text("Appareils autorisés").font(.headline)
                                .foregroundStyle(Brand.ink).textCase(nil)
                        }
                        .listRowBackground(Color.clear)
                    }
                    .listStyle(.plain).scrollContentBackground(.hidden).background(Brand.background)
                    .appNavigationTitle("Limite d’appareils")
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Annuler") { model.quota = nil } } }
                    .confirmationDialog("Remplacer cet appareil ?", isPresented: Binding(get: { selectedDevice != nil }, set: { if !$0 { selectedDevice = nil } }), titleVisibility: .visible) {
                        Button("Remplacer cet appareil", role: .destructive) {
                            let id = selectedDevice?.id; selectedDevice = nil
                            Task { await model.login(password: password, replaceDevice: id) }
                        }
                    } message: { Text("« \(selectedDevice?.name ?? "Cet appareil") » sera déconnecté de votre compte.") }
                }.presentationDetents([.large])
            }
        }
    }
    private func signIn() {
        guard !password.isEmpty, !model.email.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        focused = nil
        Task { await model.login(password: password); if model.isAuthenticated { password = "" } }
    }
}

/// A soft dawn of the app icon's colors behind the top of the login screen, stronger in dark so it still shows.
private struct LoginDawn: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let dark = colorScheme == .dark
        LinearGradient(colors: [Brand.iconStart.opacity(dark ? 0.32 : 0.16), Brand.iconStop.opacity(dark ? 0.22 : 0.1),
                                Brand.iconStop.opacity(0)],
                       startPoint: .topLeading, endPoint: UnitPoint(x: 0.6, y: 1))
            // The diagonal alone left a faint edge at the bottom left; this fade ends it at nothing.
            .mask { LinearGradient(colors: [.black, .clear], startPoint: UnitPoint(x: 0.5, y: 0.4), endPoint: .bottom) }
            .accessibilityHidden(true)
    }
}
