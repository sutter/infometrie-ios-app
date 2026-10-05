import SwiftUI

struct LoginView: View {
    @Environment(AppModel.self) private var model
    @State private var password = ""
    @State private var showPassword = false
    @State private var selectedDevice: DeviceInfo?
    @State private var viewportHeight: CGFloat = 0
    @Environment(\.horizontalSizeClass) private var sizeClass
    @FocusState private var focused: Field?
    private enum Field { case email, password }

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Wordmark(size: 32).padding(.top, 25)
                    PageHeading(title: "Connectez-vous", subtitle: "Retrouvez votre fil et écoutez les passages qui vous intéressent.")
                    AppRule()
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
                    // On iPad the form sits in the middle of the screen; it still scrolls when taller.
                    .frame(minHeight: sizeClass == .regular ? viewportHeight : 0)
            }
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { viewportHeight = $0 }
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
