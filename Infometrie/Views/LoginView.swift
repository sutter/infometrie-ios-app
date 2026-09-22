import SwiftUI

struct LoginView: View {
    @Environment(AppModel.self) private var model
    @State private var password = ""
    @State private var showPassword = false
    @State private var selectedDevice: DeviceInfo?
    @FocusState private var focused: Field?
    private enum Field { case email, password }

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    Wordmark(size: 32).padding(.top, 25)
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Connectez-vous").font(.title.bold())
                        Text("Retrouvez votre fil et écoutez les passages qui vous intéressent.")
                            .font(.body).foregroundStyle(Brand.secondary)
                    }
                    VStack(alignment: .leading, spacing: 18) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Email").font(.body.weight(.medium))
                            TextField("vous@organisation.fr", text: $model.email)
                                .textContentType(.username).keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never).autocorrectionDisabled()
                                .focused($focused, equals: .email).submitLabel(.next).onSubmit { focused = .password }
                                .padding(15).background(Brand.background, in: RoundedRectangle(cornerRadius: 15))
                                .accessibilityIdentifier("login-email")
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Mot de passe").font(.body.weight(.medium))
                            HStack {
                                Group {
                                    if showPassword { TextField("Votre mot de passe", text: $password) }
                                    else { SecureField("Votre mot de passe", text: $password) }
                                }.textContentType(.password).textInputAutocapitalization(.never).autocorrectionDisabled().focused($focused, equals: .password)
                                    .submitLabel(.go).onSubmit { signIn() }.accessibilityIdentifier("login-password")
                                Button { showPassword.toggle() } label: { Image(systemName: showPassword ? "eye.slash" : "eye").foregroundStyle(Brand.blue).frame(width: 52, height: 52).contentShape(Rectangle()) }
                                    .accessibilityLabel(showPassword ? "Masquer le mot de passe" : "Afficher le mot de passe")
                            }.padding(.leading, 15).padding(.trailing, 4).background(Brand.background, in: RoundedRectangle(cornerRadius: 15))
                        }
                        if let error = model.loginError { ErrorNotice(message: error).accessibilityIdentifier("login-error") }
                        Button(action: signIn) {
                            HStack {
                                if model.isLoggingIn { ProgressView().tint(.white) }
                                Text(model.isLoggingIn ? "Connexion…" : "Se connecter").fontWeight(.semibold)
                                if !model.isLoggingIn { Image(systemName: "arrow.right") }
                            }.frame(maxWidth: .infinity)
                        }
                        .buttonStyle(ActionButtonStyle(prominent: true))
                        .disabled(model.email.trimmingCharacters(in: .whitespaces).isEmpty || password.isEmpty || model.isLoggingIn)
                        .accessibilityIdentifier("login-submit")
                    }
                    .padding(23).background(Brand.card, in: RoundedRectangle(cornerRadius: 28))

                    VStack(spacing: 18) {
                        Button { password = ""; focused = nil; model.enterDemo() } label: {
                            Label("Essayer la démonstration", systemImage: "play.circle")
                        }.buttonStyle(ActionButtonStyle()).disabled(model.isLoggingIn).accessibilityIdentifier("enter-demo")
                        Text("L’abonnement et la gestion du compte se font sur le portail web InfoMétrie.")
                            .font(.footnote).foregroundStyle(Brand.secondary).multilineTextAlignment(.center).lineSpacing(3)
                    }.frame(maxWidth: .infinity)
                }.padding(.horizontal, 24).padding(.bottom, 35).frame(maxWidth: 520)
                    .frame(maxWidth: .infinity)
            }
            .background(Brand.background).scrollDismissesKeyboard(.interactively)
            .sheet(item: $model.quota) { quota in
                NavigationStack {
                    List {
                        Section {
                            Text("Votre compte autorise \(quota.maximum) appareils. Choisissez celui que vous souhaitez remplacer pour vous connecter ici. L’appareil remplacé sera déconnecté.")
                        }
                        Section("Appareils autorisés") {
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
                        }
                    }
                    .navigationTitle("Limite d’appareils").navigationBarTitleDisplayMode(.inline)
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
