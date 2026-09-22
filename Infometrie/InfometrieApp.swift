import SwiftUI

@main
struct InfometrieApp: App {
    @State private var model = makeAppModel()
    @AppStorage("appearance") private var appearance = "system"
    @AppStorage("comfortableReading") private var comfortableReading = true
    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .environment(\.locale, Locale(identifier: "fr_FR"))
                .tint(Brand.blue)
                .dynamicTypeSize((comfortableReading ? DynamicTypeSize.xLarge : .xSmall)...)
                .preferredColorScheme(appearance == "dark" ? .dark : appearance == "light" ? .light : nil)
        }
    }
}

@MainActor
private func makeAppModel() -> AppModel {
    #if DEBUG
    if let fixture = LoginTestProtocol.appModel() { return fixture }
    if ProcessInfo.processInfo.arguments.contains("--uitesting") {
        return AppModel(remembersEmail: false, restoresSession: false)
    }
    #endif
    return AppModel()
}

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase
    private var activityKey: String { "\(model.isAuthenticated)-\(model.isDemo)-\(scenePhase == .active)" }
    var body: some View {
        @Bindable var binding = model
        Group {
            if model.isRestoring {
                VStack(spacing: 24) { Wordmark(); ProgressView("Ouverture d’InfoMétrie…") }
            } else if model.isAuthenticated {
                TabView(selection: $binding.tab) {
                    Tab("Le fil", systemImage: "dot.radiowaves.left.and.right", value: .feed) { NavigationStack { FeedView() } }
                    Tab("Mes suivis", systemImage: "bookmark", value: .saved) { NavigationStack { SavedSearchesView() } }
                    Tab("Compte", systemImage: "person.crop.circle", value: .account) { NavigationStack { AccountView() } }
                }
                .sheet(isPresented: $binding.isSearchPresented) {
                    NavigationStack { SearchView() }.environment(model)
                }
                .sheet(isPresented: Binding(get: { model.player.isPodcast }, set: { if !$0 { model.player.stop() } })) {
                    PodcastView().environment(model)
                }
            } else { LoginView() }
        }
        .task { @MainActor in await model.restore() }
        .task(id: activityKey) { @MainActor in
            guard model.isAuthenticated, scenePhase == .active else { model.player.pause(); return }
            let appModel = model
            async let choices: Void = appModel.loadChoices()
            await appModel.refresh(reset: appModel.items.isEmpty)
            await choices
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(30)) } catch { return }
                guard !Task.isCancelled else { return }
                if !model.isRefreshing { await model.refresh() }
            }
        }
        .alert("InfoMétrie", isPresented: Binding(get: { model.notice != nil }, set: { if !$0 { model.notice = nil } })) {
            Button("OK", role: .cancel) { model.notice = nil }
        } message: { Text(model.notice ?? "") }
    }
}
