import SwiftUI

struct FeedView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicType
    /// New criteria show their results from the top, while only the cards fade.
    @State private var scrollPosition = ScrollPosition(edge: .top)
    private var playable: [FeedItem] { model.visibleItems.filter(\.canPlay).sorted { $0.at < $1.at } }
    private var hasAudienceFilters: Bool { !model.filters.isEmpty }
    private var usesWideLayout: Bool { horizontalSizeClass == .regular }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: dynamicType.isAccessibilitySize ? [] : [.sectionHeaders]) {
                Section {
                    // Period and display scroll with the list: only the types stay pinned, so the cards get the room.
                    FeedViewOptions().padding(.top, 8)
                    statusRow.padding(.top, 16).padding(.bottom, 8)
                    if hasAudienceFilters { selectionSummary.padding(.vertical, 12) }
                    if let error = model.feedError {
                        ErrorNotice(message: error) { Task { await model.refresh(reset: true) } }
                            .padding(.vertical, 12)
                    }
                    // The cards change without animation: the user asked for a still list.
                    Group {
                        if model.isRefreshing && model.items.isEmpty {
                            FeedSkeleton().padding(.vertical, 5)
                        } else if !model.filters.hasKinds {
                            // Every type unchecked: say why the journal is empty and offer to fill it again.
                            NoKindState {
                                var filters = model.filters
                                filters.selectKind(0)
                                Task { await model.apply(filters) }
                            }
                        } else if model.visibleItems.isEmpty && model.feedError == nil {
                            VStack(alignment: .leading, spacing: 12) {
                                AppEmptyState(title: "Aucun passage pour le moment", icon: "text.magnifyingglass", message: "Aucun résultat sur les dernières 24 heures avec ces critères.")
                                Button("Modifier la recherche") { model.openSearch(model.filters) }
                                    .buttonStyle(ActionButtonStyle())
                            }
                        } else {
                            ForEach(model.visibleItems) { item in
                                NavigationLink { SequenceView(item: item) } label: {
                                    FeedCard(item: item, seen: model.isSeen(item))
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain).accessibilityIdentifier("feed-item-\(item.id)")
                                // A long press, or VoiceOver's actions, can undo or set the state by hand.
                                .contextMenu { seenToggle(item) }
                                .accessibilityAction(named: model.isSeen(item) ? "Marquer comme non vu" : "Marquer comme vu") {
                                    model.toggleSeen(item)
                                }
                            }
                        }
                    }
                } header: { filterControls }
            }
            // The iPhone tab bar floats above the scroll view. Leave enough
            // scrollable tail space to bring the final card clear of the bar.
            .padding(.horizontal, AppLayout.margin).padding(.bottom, usesWideLayout ? 24 : 112)
            .frame(maxWidth: AppLayout.readingWidth).frame(maxWidth: .infinity)
        }
        .scrollPosition($scrollPosition)
        .onChange(of: model.filters) {
            // Jump, never animate: pinned headers do not follow an animated programmatic scroll,
            // which leaves a gap under the type row and makes the heading pop in at the end.
            var jump = Transaction(); jump.disablesAnimations = true
            withTransaction(jump) { scrollPosition.scrollTo(edge: .top) }
        }
        .refreshable { await model.refresh(reset: true) }
        .modifier(FeedScrollOverflow(overTabBar: !usesWideLayout))
        // No scroll edge effect: the pinned type row already covers the cards under the bar, and on
        // iOS 27 the hard effect drew a hairline and a different tint under the bar at rest.
        .scrollEdgeEffectHidden(true)
        .background(Brand.background)
        .navigationTitle("").navigationBarTitleDisplayMode(.inline)
        .toolbar(usesWideLayout ? .hidden : .visible, for: .navigationBar)
        .toolbarBackground(Brand.background, for: .navigationBar)
        .toolbarBackgroundVisibility(.visible, for: .navigationBar)
        .toolbar {
            if !usesWideLayout {
                ToolbarItem(placement: .topBarLeading) { Wordmark(size: 21, scheme: colorScheme, showsTile: false) }
                    .sharedBackgroundVisibility(.hidden)
                ToolbarItem(placement: .topBarTrailing) { filtersButton(scheme: colorScheme) }
                    .sharedBackgroundVisibility(.hidden)
            }
        }
    }

    /// The result count and its freshness on one line, with "Tout écouter" at its end.
    /// When both cannot fit, the button moves below rather than the text wrapping.
    private var statusRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                FeedStatus(singleLine: true)
                Spacer(minLength: 0)
                if usesWideLayout { filtersButton() }
                listenButton
            }
            VStack(alignment: .leading, spacing: 8) {
                FeedStatus(singleLine: !dynamicType.isAccessibilitySize)
                HStack(spacing: 12) {
                    if usesWideLayout { filtersButton() }
                    listenButton
                }
            }
        }
    }

    private var filterControls: some View {
        VStack(spacing: 0) {
            FeedKindPicker()
            AppRule()
        }
        // Full width: cards scrolling under the pinned header no longer show in the side margins.
        .background { Brand.background.containerRelativeFrame(.horizontal).padding(.vertical, -8) }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("feed-filter-bar")
    }

    private var selectionSummary: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(model.filters.summary).font(.subheadline).foregroundStyle(Brand.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button { Task { await model.apply(SearchFilters()) } } label: {
                Label("Tout afficher", systemImage: "arrow.counterclockwise")
                    .font(.subheadline.weight(.semibold)).frame(minHeight: 48)
            }
            .buttonStyle(.plain).foregroundStyle(Brand.tint)
            .accessibilityIdentifier("clear-filters")
            AppRule()
        }
    }

    private func seenToggle(_ item: FeedItem) -> some View {
        let seen = model.isSeen(item)
        return Button(seen ? "Marquer comme non vu" : "Marquer comme vu",
                      systemImage: seen ? "circle" : "checkmark.circle") { model.toggleSeen(item) }
    }

    /// `scheme` is set in the navigation bar, which may not follow a theme change (`Brand.fixed`).
    private func filtersButton(scheme: ColorScheme? = nil) -> some View {
        Button { model.openSearch(model.filters) } label: {
            Label("Rechercher", systemImage: hasAudienceFilters ? "magnifyingglass.circle.fill" : "magnifyingglass")
                .labelStyle(.titleAndIcon)
                .font(.subheadline.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 8).frame(minHeight: 48)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain).foregroundStyle(Brand.fixed(Brand.tint, for: scheme))
        .accessibilityIdentifier("edit-filters")
        .accessibilityValue(hasAudienceFilters ? "Recherche active" : "")
    }

    private var listenButton: some View {
        Button { model.player.start(items: playable, app: model, podcast: true) } label: {
            Label("Tout écouter", systemImage: "play.fill")
                .font(.subheadline.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .frame(minHeight: 44)
                // Outlined, like the secondary action buttons: it stays findable without outweighing the count.
                .foregroundStyle(Brand.ink)
                .background(Brand.card, in: Capsule())
                .overlay { Capsule().strokeBorder(Brand.rule) }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(playable.isEmpty).opacity(playable.isEmpty ? 0.45 : 1)
        .accessibilityIdentifier("start-podcast")
    }
}

/// How many results the list holds and how fresh they are, like "50 résultats · il y a 3 min".
private struct FeedStatus: View {
    @Environment(AppModel.self) private var model
    var singleLine = true

    var body: some View {
        // Re-read the age every 15 seconds; the feed itself refreshes every 30.
        TimelineView(.periodic(from: .now, by: 15)) { context in
            let count = model.visibleItems.count
            // One text, so that at accessibility sizes the age wraps under the count rather than beside it.
            (Text(count <= 1 ? "\(count) résultat" : "\(count) résultats").fontWeight(.semibold).foregroundStyle(Brand.ink)
                + Text(model.lastRefresh.map { " · \(Self.age(of: $0, at: context.date))" } ?? "").foregroundStyle(Brand.secondary))
                .font(.footnote.monospacedDigit())
                .fixedSize(horizontal: singleLine, vertical: true)
                .accessibilityIdentifier("feed-status")
        }
    }

    /// The age of the last refresh, short enough to keep the line whole beside "Tout écouter".
    static func age(of date: Date, at now: Date) -> String {
        let seconds = max(0, now.timeIntervalSince(date))
        if seconds < 60 { return "à l’instant" }
        if seconds < 3_600 { return "il y a \(Int(seconds / 60)) min" }
        return "il y a \(Int(seconds / 3_600)) h"
    }
}

/// The journal with every type unchecked: the three kind tiles fanned out, a short explanation and one
/// action that checks them all again, so the empty screen reads as a choice to make, not a dead end.
private struct NoKindState: View {
    let showAll: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            KindFan()
            VStack(spacing: 8) {
                Text("Aucun type sélectionné")
                    .font(.title3.weight(.bold)).foregroundStyle(Brand.ink)
                    .accessibilityAddTraits(.isHeader)
                Text("Choisissez ce que vous voulez suivre : interventions, citations ou publications X.")
                    .font(.body).foregroundStyle(Brand.secondary)
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            Button("Tout afficher", systemImage: "checkmark.square", action: showAll)
                .buttonStyle(ActionButtonStyle(prominent: true))
                .frame(maxWidth: 280)
                .accessibilityIdentifier("show-all-kinds")
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 48).padding(.bottom, 24)
    }
}

/// On iPhone, extend the scroll viewport behind the floating system tab bar.
/// On iPad, keep the feed clipped to its column so it stays below the status bar.
private struct FeedScrollOverflow: ViewModifier {
    let overTabBar: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if overTabBar {
            content.ignoresSafeArea(.container, edges: .bottom)
        } else {
            content.clipped()
        }
    }
}

/// Applies only the passage types through the same filters as the full editor, one checkbox per type.
private struct FeedKindPicker: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dynamicTypeSize) private var dynamicType

    private enum Kind: Int, CaseIterable {
        case interventions = 1, citations, tweets
        /// The API kind, which carries the color shared with the rows' tags and left border.
        var apiKind: String {
            switch self {
            case .interventions: "intervention"
            case .citations: "citation"
            case .tweets: "tweet"
            }
        }
        var title: String {
            switch self {
            case .interventions: "Interventions"
            case .citations: "Citations"
            case .tweets: "Publications X"
            }
        }
    }

    private func isChecked(_ kind: Kind) -> Bool {
        switch kind {
        case .interventions: model.filters.interventions
        case .citations: model.filters.citations
        case .tweets: model.filters.tweets
        }
    }

    var body: some View {
        Group {
            if dynamicType.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) { choices }
            } else {
                // Categories will grow: one row of chips that scrolls, drawn out to the screen edges
                // instead of being cut at the content margins.
                ScrollView(.horizontal) { HStack(spacing: 8) { choices } }
                    .scrollIndicators(.hidden)
                    .scrollClipDisabled()
            }
        }
        // The navigation bar already leaves room under the logo; the chips' invisible touch margin
        // (48 pt around a 40 pt chip) tucks under it instead of widening the gap.
        .padding(.top, -4).padding(.bottom, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sensoryFeedback(.selection, trigger: model.filters.selectedKinds)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Types de passages")
        .accessibilityIdentifier("feed-kind-picker")
    }

    private var choices: some View {
        ForEach(Kind.allCases, id: \.self) { checkbox($0) }
    }

    private func checkbox(_ kind: Kind) -> some View {
        // Plain on/off, at the client's request: every type can be unchecked, the journal then says so.
        let checked = isChecked(kind)
        return Button { toggle(kind) } label: {
            HStack(spacing: 6) {
                // The kind's color, matching the tags and left border of the rows it shows.
                Image(systemName: checked ? "checkmark.square.fill" : "square")
                    .font(.body).foregroundStyle(checked ? FeedItem.color(ofKind: kind.apiKind) : Brand.secondary)
                // The bare X mark: an ink tile beside a filled checkbox would read as a second box.
                if kind == .tweets {
                    Image("x.logo").font(.subheadline.weight(.semibold))
                        .foregroundStyle(checked ? Brand.ink : Brand.secondary)
                } else {
                    Text(kind.title)
                        .font(.subheadline)
                        .foregroundStyle(checked ? Brand.ink : Brand.secondary)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .chip(selected: checked, wash: FeedItem.wash(ofKind: kind.apiKind))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(kind.title)
        .accessibilityValue(checked ? "Coché" : "Non coché")
        .accessibilityIdentifier("feed-kind-\(kind.rawValue)")
    }

    private func toggle(_ kind: Kind) {
        var filters = model.filters
        switch kind {
        case .interventions: filters.interventions.toggle()
        case .citations: filters.citations.toggle()
        case .tweets: filters.tweets.toggle()
        }
        Task { await model.apply(filters) }
    }
}

/// Period and display of the feed. Only Live and Liste work today: 7 j, 30 j and the chart synthesis
/// wait for an API, so they stay visible and explain in an alert, rather than on screen, that they are coming.
private struct FeedViewOptions: View {
    @State private var comingSoon: String?

    var body: some View {
        // One row of underlined tabs on a hairline: period on the left, display as icons on the right,
        // so every single choice in the header shares the same selection mark.
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) { periods; Spacer(minLength: 8); displays }
            // At the largest text sizes the display icons move under the periods.
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) { periods }
                HStack(spacing: 8) { displays }
            }
        }
        // The tabs' inner padding would push "Live" past the checkboxes' edge.
        .padding(.leading, -4)
        .overlay(alignment: .bottom) { AppRule() }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Période et affichage")
        .alert("Bientôt disponible", isPresented: Binding(get: { comingSoon != nil }, set: { if !$0 { comingSoon = nil } })) {
            Button("OK", role: .cancel) { comingSoon = nil }
        } message: { Text(comingSoon ?? "") }
    }

    @ViewBuilder private var periods: some View {
        tab("Live", label: "Live, dernières 24 heures", id: "feed-period-live", selected: true)
        tab("7 j", label: "7 jours", id: "feed-period-7", message: Self.periods)
        tab("30 j", label: "30 jours", id: "feed-period-30", message: Self.periods)
    }

    @ViewBuilder private var displays: some View {
        tab("Liste", icon: "list.bullet", label: "Liste", id: "feed-display-list", selected: true)
        tab("Graphique", icon: "chart.bar.xaxis", label: "Synthèse graphique", id: "feed-display-chart", message: Self.chart)
    }

    private static let periods = "Les périodes de 7 et 30 jours arriveront avec une prochaine version du service."
    private static let chart = "La synthèse graphique arrivera avec une prochaine version du service."

    /// A tab that works when `message` is nil; otherwise it is coming soon and says so when tapped.
    private func tab(_ title: String, icon: String? = nil, label: String, id: String, selected: Bool = false, message: String? = nil) -> some View {
        AppTabButton(title: title, selected: selected, icon: icon, iconOnly: icon != nil, compact: true) {
            if let message { comingSoon = message }
        }
        .accessibilityLabel(label)
        .accessibilityValue(message == nil ? "" : "Bientôt disponible")
        .accessibilityIdentifier(id)
    }
}
