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
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private var activityKey: String { "\(model.isAuthenticated)-\(model.isDemo)-\(scenePhase == .active)" }
    var body: some View {
        @Bindable var binding = model
        Group {
            if model.isRestoring {
                VStack(spacing: 24) { Wordmark(); ProgressView("Ouverture d’InfoMétrie…") }
            } else if model.isAuthenticated {
                VStack(spacing: 0) {
                    if horizontalSizeClass == .regular { EditorialNavigation() }
                    TabView(selection: $binding.tab) {
                        Tab("Le fil", systemImage: "newspaper", value: .feed) {
                            NavigationStack {
                                FeedView().toolbar(horizontalSizeClass == .regular ? .hidden : .automatic, for: .tabBar)
                            }
                            .tint(Brand.blue)
                        }
                        Tab("Mes suivis", systemImage: "bookmark", value: .saved) {
                            NavigationStack {
                                SavedSearchesView().toolbar(horizontalSizeClass == .regular ? .hidden : .automatic, for: .tabBar)
                            }
                            .tint(Brand.blue)
                        }
                        Tab("Compte", systemImage: "person.crop.circle", value: .account) {
                            NavigationStack {
                                AccountView().toolbar(horizontalSizeClass == .regular ? .hidden : .automatic, for: .tabBar)
                            }
                            .tint(Brand.blue)
                        }
                    }
                    .tint(Brand.citation)
                    .toolbarBackground(Brand.background, for: .tabBar)
                }
                .background(Brand.background)
                .sheet(isPresented: $binding.isSearchPresented) {
                    NavigationStack { SearchView() }.environment(model)
                }
                .sheet(isPresented: Binding(get: { model.player.isPodcast }, set: { if !$0 { model.player.stop() } })) {
                    PodcastView().environment(model)
                }
            } else { LoginView() }
        }
        .foregroundStyle(Brand.ink)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Brand.background)
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

/// Keep the three navigation stacks while giving the iPad a magazine masthead.
private struct EditorialNavigation: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 28) {
                Wordmark()
                destinations.fixedSize(horizontal: true, vertical: false)
                    .frame(maxWidth: .infinity)
            }
            VStack(alignment: .leading, spacing: 8) {
                Wordmark()
                destinations
            }
        }
        .padding(.top, 8)
        .overlay(alignment: .bottom) { EditorialRule() }
        .padding(.horizontal, EditorialLayout.wideMargin)
        .frame(maxWidth: EditorialLayout.maximumWidth).frame(maxWidth: .infinity)
        .background(Brand.background)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Navigation principale")
        .accessibilityIdentifier("primary-navigation")
    }

    private var destinations: some View {
        HStack(spacing: 16) {
            destination("Le fil", tab: .feed, identifier: "navigation-feed")
            destination("Mes suivis", tab: .saved, identifier: "navigation-saved")
            destination("Compte", tab: .account, identifier: "navigation-account")
        }
    }

    private func destination(_ title: String, tab: AppModel.Tab, identifier: String) -> some View {
        EditorialTabButton(title: title, selected: model.tab == tab, accent: Brand.citation) {
            model.tab = tab
        }
        .accessibilityIdentifier(identifier)
    }
}
