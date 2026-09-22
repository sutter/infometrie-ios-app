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
                    VStack(alignment: .leading, spacing: 15) {
                        Eyebrow(text: "Votre boussole politique")
                        Text("L’actualité politique.\nÀ portée d’écoute.")
                            .font(.system(.largeTitle, design: .rounded, weight: .bold)).tracking(-1)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Les prises de parole, les citations et leur contexte. Toute votre veille, au même endroit.")
                            .font(.body).foregroundStyle(.secondary).lineSpacing(4)
                    }
                    HStack(spacing: 14) {
                        Image(systemName: "waveform").font(.title2).foregroundStyle(.white)
                            .frame(width: 52, height: 52).glassEffect(.regular.tint(.white.opacity(0.1)), in: RoundedRectangle(cornerRadius: 17))
                        VStack(alignment: .leading, spacing: 5) {
                            Text("L’essentiel, à votre rythme").font(.subheadline.weight(.semibold))
                            Text("Écoutez. Retrouvez. Comprenez.").font(.caption).foregroundStyle(.white.opacity(0.65))
                        }
                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(.white).padding(18).frame(maxWidth: .infinity)
                    .background(LinearGradient(colors: [Brand.navy, Brand.blue.opacity(0.9)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 24))

                    VStack(alignment: .leading, spacing: 18) {
                        Text("Bienvenue").font(.title2.bold())
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Email").font(.subheadline.weight(.medium))
                            TextField("vous@organisation.fr", text: $model.email)
                                .textContentType(.username).keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never).autocorrectionDisabled()
                                .focused($focused, equals: .email).submitLabel(.next).onSubmit { focused = .password }
                                .padding(15).background(Brand.background, in: RoundedRectangle(cornerRadius: 15))
                                .accessibilityIdentifier("login-email")
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Mot de passe").font(.subheadline.weight(.medium))
                            HStack {
                                Group {
                                    if showPassword { TextField("Votre mot de passe", text: $password) }
                                    else { SecureField("Votre mot de passe", text: $password) }
                                }.textContentType(.password).focused($focused, equals: .password)
                                    .submitLabel(.go).onSubmit { signIn() }.accessibilityIdentifier("login-password")
                                Button { showPassword.toggle() } label: { Image(systemName: showPassword ? "eye.slash" : "eye").foregroundStyle(.secondary) }
                                    .accessibilityLabel(showPassword ? "Masquer le mot de passe" : "Afficher le mot de passe")
                            }.padding(15).background(Brand.background, in: RoundedRectangle(cornerRadius: 15))
                        }
                        if let error = model.loginError { ErrorNotice(message: error).accessibilityIdentifier("login-error") }
                        Button(action: signIn) {
                            HStack {
                                if model.isLoggingIn { ProgressView().tint(.white) }
                                Text(model.isLoggingIn ? "Connexion…" : "Se connecter").fontWeight(.semibold)
                                if !model.isLoggingIn { Image(systemName: "arrow.right") }
                            }.frame(maxWidth: .infinity).padding(.vertical, 10)
                        }
                        .buttonStyle(.glassProminent).controlSize(.large)
                        .disabled(model.email.trimmingCharacters(in: .whitespaces).isEmpty || password.isEmpty || model.isLoggingIn)
                        .accessibilityIdentifier("login-submit")
                    }
                    .padding(23).background(Brand.card, in: RoundedRectangle(cornerRadius: 28))

                    VStack(spacing: 18) {
                        Button { password = ""; focused = nil; model.enterDemo() } label: {
                            Label("Découvrir l’interface", systemImage: "sparkles").font(.subheadline.weight(.semibold))
                        }.disabled(model.isLoggingIn).accessibilityIdentifier("enter-demo")
                        Text("L’abonnement et la gestion du compte se font sur le portail web InfoMétrie.")
                            .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center).lineSpacing(3)
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
                                        Text(device.model ?? "").font(.caption).foregroundStyle(.secondary)
                                        if let seen = device.lastSeen, let date = APIDate.parse(seen) { Text("Vu le \(date.formatted(date: .abbreviated, time: .shortened))").font(.caption).foregroundStyle(.secondary) }
                                    }
                                }
                            }
                            if quota.devices.isEmpty { Text("Gérez vos appareils sur le portail web InfoMétrie.").foregroundStyle(.secondary) }
                        }
                    }
                    .navigationTitle("Limite d’appareils").navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Annuler") { model.quota = nil } } }
                    .confirmationDialog("Remplacer cet appareil ?", isPresented: Binding(get: { selectedDevice != nil }, set: { if !$0 { selectedDevice = nil } }), titleVisibility: .visible) {
                        Button("Remplacer cet appareil", role: .destructive) {
                            let id = selectedDevice?.id; selectedDevice = nil
                            Task { await model.login(password: password, replaceDevice: id) }
                        }
                    } message: { Text("L’appareil sélectionné sera déconnecté de votre compte.") }
                }.presentationDetents([.medium, .large])
            }
        }
    }
    private func signIn() {
        guard !password.isEmpty, !model.email.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        focused = nil
        Task { await model.login(password: password); if model.isAuthenticated { password = "" } }
    }
}
