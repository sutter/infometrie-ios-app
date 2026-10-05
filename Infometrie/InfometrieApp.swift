import SwiftUI

@main
struct InfometrieApp: App {
    @State private var model = makeAppModel()
    @AppStorage("appearance") private var appearance = "system"
    @AppStorage("readingSize") private var readingSize = ReadingSize.medium

    init() {
        ReadingSize.migrateLegacyPreference()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .environment(\.locale, Locale(identifier: "fr_FR"))
                .tint(Brand.tint)
                .modifier(ReadingSizeModifier(selection: readingSize))
                // Text grows or shrinks smoothly when a reading size is chosen.
                .motion(value: readingSize)
                .preferredColorScheme(appearance == "dark" ? .dark : appearance == "light" ? .light : nil)
        }
    }
}

@MainActor
private func makeAppModel() -> AppModel {
    #if DEBUG
    if let fixture = UITestServer.appModel() { return fixture }
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
    @Environment(\.dynamicTypeSize) private var dynamicType
    private var activityKey: String { "\(model.isAuthenticated)-\(scenePhase == .active)" }
    var body: some View {
        @Bindable var binding = model
        Group {
            if model.isRestoring {
                VStack(alignment: .leading, spacing: 24) { Wordmark(); FeedSkeleton(label: "Ouverture d’InfoMétrie") }
                    .padding(20).frame(maxWidth: AppLayout.readingWidth, maxHeight: .infinity, alignment: .top)
            } else if model.isAuthenticated {
                let layout = horizontalSizeClass == .regular && !dynamicType.isAccessibilitySize
                    ? AnyLayout(HStackLayout(alignment: .top, spacing: 0))
                    : AnyLayout(VStackLayout(spacing: 0))
                layout {
                    if horizontalSizeClass == .regular { MainNavigation() }
                    TabView(selection: $binding.tab) {
                        Tab("Le fil", systemImage: "newspaper", value: .feed) {
                            NavigationStack {
                                FeedView().toolbar(horizontalSizeClass == .regular ? .hidden : .automatic, for: .tabBar)
                            }
                            .tint(Brand.tint)
                        }
                        Tab("Mes suivis", systemImage: "binoculars", value: .saved) {
                            NavigationStack {
                                SavedSearchesView().toolbar(horizontalSizeClass == .regular ? .hidden : .automatic, for: .tabBar)
                            }
                            .tint(Brand.tint)
                        }
                        Tab("Compte", systemImage: "person.circle", value: .account) {
                            NavigationStack {
                                AccountView().toolbar(horizontalSizeClass == .regular ? .hidden : .automatic, for: .tabBar)
                            }
                            .tint(Brand.tint)
                        }
                    }
                    .tint(Brand.tint)
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

/// The iPad separates destinations from the filters inside the timeline.
private struct MainNavigation: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dynamicTypeSize) private var dynamicType

    var body: some View {
        Group {
            if dynamicType.isAccessibilitySize {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal) {
                        HStack(spacing: 8) { destinations }
                            .padding(.horizontal, 20)
                    }
                    .onChange(of: model.tab, initial: true) { _, tab in
                        proxy.scrollTo(tab, anchor: .center)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                .overlay(alignment: .bottom) { AppRule() }
            } else {
                VStack(alignment: .leading, spacing: 24) {
                    Wordmark(size: 22).padding(.horizontal, 12).padding(.top, 12)
                    VStack(alignment: .leading, spacing: 6) { destinations }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 12).padding(.vertical, 16)
                .frame(width: 192).frame(maxHeight: .infinity)
                .overlay(alignment: .trailing) {
                    Rectangle().fill(Brand.sidebarRule).frame(width: 0.5).accessibilityHidden(true)
                }
            }
        }
        .background(Brand.sidebar)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Navigation principale")
        .accessibilityIdentifier("primary-navigation")
    }

    @ViewBuilder private var destinations: some View {
        destination("Le fil", symbol: "newspaper", tab: .feed, identifier: "navigation-feed")
        destination("Mes suivis", symbol: "binoculars", tab: .saved, identifier: "navigation-saved")
        destination("Compte", symbol: "person.circle", tab: .account, identifier: "navigation-account")
    }

    private func destination(_ title: String, symbol: String, tab: AppModel.Tab, identifier: String) -> some View {
        let selected = model.tab == tab
        return Button { model.tab = tab } label: {
            Label(title, systemImage: selected ? "\(symbol).fill" : symbol)
                .font(.body.weight(selected ? .bold : .medium))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 12).padding(.vertical, 12)
                .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                .foregroundStyle(selected ? Brand.tint : Brand.ink)
                .background(selected ? Brand.selection : .clear, in: RoundedRectangle(cornerRadius: AppLayout.controlRadius))
                .contentShape(RoundedRectangle(cornerRadius: AppLayout.controlRadius))
        }
        .buttonStyle(.plain)
        .id(tab)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier(identifier)
    }
}
