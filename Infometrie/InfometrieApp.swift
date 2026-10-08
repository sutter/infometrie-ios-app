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
                    .padding(.horizontal, AppLayout.margin).padding(.vertical, 20).frame(maxWidth: AppLayout.readingWidth, maxHeight: .infinity, alignment: .top)
            } else if model.isAuthenticated {
                let layout = horizontalSizeClass == .regular && !dynamicType.isAccessibilitySize
                    ? AnyLayout(HStackLayout(alignment: .top, spacing: 0))
                    : AnyLayout(VStackLayout(spacing: 0))
                layout {
                    if horizontalSizeClass == .regular { MainNavigation() }
                    TabView(selection: $binding.tab) {
                        // The system tab bar stays hidden: the iPhone shows `MainTabBar` under each root page,
                        // the iPad the sidebar.
                        Tab("Le journal", systemImage: "house", value: AppModel.Tab.feed) {
                            NavigationStack { FeedView().withMainTabBar() }.tint(Brand.tint)
                        }
                        Tab("Mes suivis", systemImage: "bookmark", value: AppModel.Tab.saved) {
                            NavigationStack { SavedSearchesView().withMainTabBar() }.tint(Brand.tint)
                        }
                        Tab("Compte", systemImage: "person", value: AppModel.Tab.account) {
                            NavigationStack { AccountView().withMainTabBar() }.tint(Brand.tint)
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
            if appModel.period.isLive { await appModel.refresh(reset: appModel.items.isEmpty) }
            else { await appModel.reloadHistoryIfDayChanged() }
            await choices
            // Only Live polls: 7 j and 30 j end yesterday, so their days no longer change.
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(30)) } catch { return }
                guard !Task.isCancelled else { return }
                if model.period.isLive, !model.isRefreshing { await model.refresh() }
            }
        }
        .alert("InfoMétrie", isPresented: Binding(get: { model.notice != nil }, set: { if !$0 { model.notice = nil } })) {
            Button("OK", role: .cancel) { model.notice = nil }
        } message: { Text(model.notice ?? "") }
    }
}

extension View {
    /// Hides the system tab bar and docks `MainTabBar` under a root page at compact width. Pushed pages have no
    /// bar, like the passage page, which needs the room for its player.
    func withMainTabBar() -> some View { modifier(MainTabBarDock()) }
}

private struct MainTabBarDock: ViewModifier {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    func body(content: Content) -> some View {
        content
            .toolbar(.hidden, for: .tabBar)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if horizontalSizeClass != .regular { MainTabBar() }
            }
    }
}

/// The iPhone's main navigation: a gris clair capsule docked at the bottom, the active destination in ink on a raised
/// pill, like the S / M / L control (the user's pick on 2026-10-08). No kind color: noir chaud is X and vermillon the
/// interventions, so the former noir chaud bar with its vermillon tab read as content. Drawn by hand: the system tab
/// bar takes no fill color.
private struct MainTabBar: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 0) {
            item("Le journal", symbol: "house", tab: .feed, identifier: "navigation-feed")
            item("Mes suivis", symbol: "bookmark", tab: .saved, identifier: "navigation-saved")
            item("Compte", symbol: "person", tab: .account, identifier: "navigation-account")
        }
        .padding(4)
        .background(Brand.surface, in: Capsule())
        .overlay(Capsule().strokeBorder(Brand.rule.opacity(0.6), lineWidth: 0.5))
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.35 : 0.08), radius: 14, y: 5)
        // Like the system tab bar, the labels stop growing at the largest standard size; a long press on an item
        // shows it enlarged at accessibility sizes.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .padding(.bottom, 4)
        .sensoryFeedback(.selection, trigger: model.tab)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Navigation principale")
        .accessibilityIdentifier("main-tab-bar")
    }

    /// Filled when active, outlined otherwise.
    private func item(_ title: String, symbol: String, tab: AppModel.Tab, identifier: String) -> some View {
        let selected = model.tab == tab
        return Button { model.tab = tab } label: {
            VStack(spacing: 3) {
                Image(systemName: selected ? "\(symbol).fill" : symbol).font(.title3.weight(.medium))
                Text(title).font(.caption2.weight(selected ? .semibold : .medium)).lineLimit(1)
            }
            .foregroundStyle(selected ? Brand.ink : Brand.secondaryOnSurface)
            .frame(width: 92).frame(minHeight: 54)
            .background {
                if selected {
                    Capsule().fill(Brand.raised)
                        .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.08), radius: 3, y: 1)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(title)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityShowsLargeContentViewer { Label(title, systemImage: symbol) }
        .accessibilityIdentifier(identifier)
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
        destination("Le journal", symbol: "house", tab: .feed, identifier: "navigation-feed")
        destination("Mes suivis", symbol: "bookmark", tab: .saved, identifier: "navigation-saved")
        destination("Compte", symbol: "person", tab: .account, identifier: "navigation-account")
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
