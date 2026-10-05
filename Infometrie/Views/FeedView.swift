import SwiftUI

struct FeedView: View {
    @Environment(AppModel.self) private var model
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
                feedHeading.padding(.vertical, 12)
                Section {
                    if hasAudienceFilters { selectionSummary.padding(.vertical, 12) }
                    if let error = model.feedError {
                        ErrorNotice(message: error) { Task { await model.refresh(reset: true) } }
                            .padding(.vertical, 12)
                    }
                    // The cards change without animation: the user asked for a still list.
                    Group {
                        if model.isRefreshing && model.items.isEmpty {
                            FeedSkeleton().padding(.vertical, 5)
                        } else if model.visibleItems.isEmpty && model.feedError == nil {
                            VStack(alignment: .leading, spacing: 12) {
                                AppEmptyState(title: "Aucun passage pour le moment", icon: "text.magnifyingglass", message: "Aucun résultat sur les dernières 24 heures avec ces critères.")
                                Button("Modifier les filtres") { model.openSearch(model.filters) }
                                    .buttonStyle(ActionButtonStyle())
                            }
                        } else {
                            ForEach(model.visibleItems) { item in
                                NavigationLink { SequenceView(item: item) } label: {
                                    FeedCard(item: item).padding(.vertical, 5)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain).accessibilityIdentifier("feed-item-\(item.id)")
                            }
                        }
                    }
                    if let date = model.lastRefresh {
                        Text("Mis à jour à \(date.formatted(date: .omitted, time: .shortened))")
                            .font(.footnote).foregroundStyle(Brand.secondary)
                            .frame(maxWidth: .infinity).padding(.vertical, 20)
                    }
                } header: { filterControls }
            }
            // The iPhone tab bar floats above the scroll view. Leave enough
            // scrollable tail space to bring the final card clear of the bar.
            .padding(.horizontal, 20).padding(.bottom, usesWideLayout ? 24 : 112)
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
        .scrollEdgeEffectHidden(true, for: .bottom)
        .scrollEdgeEffectStyle(.hard, for: .top)
        .background(Brand.background)
        .navigationTitle("").navigationBarTitleDisplayMode(.inline)
        .toolbar(usesWideLayout ? .hidden : .visible, for: .navigationBar)
        .toolbarBackground(Brand.background, for: .navigationBar)
        .toolbar {
            if !usesWideLayout {
                ToolbarItem(placement: .topBarLeading) { Wordmark(size: 21) }
                    .sharedBackgroundVisibility(.hidden)
                ToolbarItem(placement: .topBarTrailing) { filtersButton }
                    .sharedBackgroundVisibility(.hidden)
            }
        }
    }

    private var feedHeading: some View {
        AdaptiveRow {
            VStack(alignment: .leading, spacing: 3) {
                Text("Le fil").font(.title2.bold()).foregroundStyle(Brand.ink)
                    .accessibilityAddTraits(.isHeader)
                HStack(spacing: 4) {
                    Text("24 h ·").accessibilityHint("Passages des dernières 24 heures")
                    Text(model.visibleItems.count == 1 ? "1 passage" : "\(model.visibleItems.count) passages")
                }
                .font(.footnote).foregroundStyle(Brand.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
            if !dynamicType.isAccessibilitySize { Spacer(minLength: 0) }
            if usesWideLayout { filtersButton }
            listenButton
        }
    }

    private var filterControls: some View {
        VStack(spacing: 0) {
            FeedKindPicker()
            FeedViewOptions().padding(.bottom, 8)
            AppRule()
        }
        .background(Brand.background)
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

    private var filtersButton: some View {
        Button { model.openSearch(model.filters) } label: {
            Label("Filtrer", systemImage: hasAudienceFilters ? "line.3.horizontal.decrease.circle.fill" : "slider.horizontal.3")
                .labelStyle(.titleAndIcon)
                .font(.subheadline.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 8).frame(minHeight: 48)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain).foregroundStyle(Brand.tint)
        .accessibilityIdentifier("edit-filters")
        .accessibilityValue(hasAudienceFilters ? "Filtres actifs" : "")
    }

    private var listenButton: some View {
        Button { model.player.start(items: playable, app: model, podcast: true) } label: {
            Label("Tout écouter", systemImage: "play.fill")
                .font(.subheadline.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .frame(minHeight: 48)
                .foregroundStyle(Brand.primaryForeground)
                .background(Brand.primary, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(playable.isEmpty).opacity(playable.isEmpty ? 0.45 : 1)
        .accessibilityIdentifier("start-podcast")
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
    @ScaledMetric(relativeTo: .subheadline) private var tileSize = 20.0

    private enum Kind: Int, CaseIterable {
        case interventions = 1, citations, tweets
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
                VStack(alignment: .leading, spacing: 4) { choices }
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 16) { choices }
                    ScrollView(.horizontal) { HStack(spacing: 16) { choices } }
                        .scrollIndicators(.hidden)
                }
            }
        }
        .padding(.vertical, 4)
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
        let checked = isChecked(kind)
        // Unchecking the last type would empty the feed, so it stays checked.
        let isLast = checked && model.filters.selectedKinds.count == 1
        return Button { toggle(kind) } label: {
            HStack(spacing: 8) {
                Image(systemName: checked ? "checkmark.square.fill" : "square")
                    .font(.title3).foregroundStyle(checked ? Brand.tint : Brand.secondary)
                // X is shown by its official logo alone, on an ink tile like in the feed cards.
                if kind == .tweets {
                    MarkTile(image: Image("x.logo"), size: tileSize)
                } else {
                    Text(kind.title)
                        .font(.subheadline.weight(checked ? .semibold : .regular))
                        .foregroundStyle(checked ? Brand.ink : Brand.secondary)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(minWidth: 44, minHeight: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isLast)
        .accessibilityLabel(kind.title)
        .accessibilityValue(checked ? "Coché" : "Non coché")
        .accessibilityHint(isLast ? "Au moins un type reste coché" : "")
        .accessibilityIdentifier("feed-kind-\(kind.rawValue)")
    }

    private func toggle(_ kind: Kind) {
        var filters = model.filters
        switch kind {
        case .interventions: filters.interventions.toggle()
        case .citations: filters.citations.toggle()
        case .tweets: filters.tweets.toggle()
        }
        guard filters.hasKinds else { return }
        Task { await model.apply(filters) }
    }
}

/// Period and display of the feed. Only Live and Liste work today: 7 j, 30 j and the chart synthesis
/// wait for an API, so they stay visible and say they are coming instead of pretending to work.
private struct FeedViewOptions: View {
    @Environment(\.dynamicTypeSize) private var dynamicType
    @State private var comingSoon: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if dynamicType.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) { period; display }
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) { period; Spacer(minLength: 0); display }
                    VStack(alignment: .leading, spacing: 8) { period; display }
                }
            }
            if let comingSoon {
                Text(comingSoon).font(.footnote).foregroundStyle(Brand.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("feed-coming-soon")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var period: some View {
        ChoiceGroup(label: "Période", selected: "live", options: [
            .init(id: "live", title: "Live", accessibilityLabel: "Live, dernières 24 heures", isAvailable: true),
            .init(id: "7", title: "7 j", accessibilityLabel: "7 jours", isAvailable: false),
            .init(id: "30", title: "30 j", accessibilityLabel: "30 jours", isAvailable: false)
        ], identifier: "feed-period") { _ in
            comingSoon = "Bientôt disponible : les périodes de 7 et 30 jours arrivent avec une prochaine version du service."
        }
    }

    private var display: some View {
        ChoiceGroup(label: "Affichage", selected: "list", options: [
            .init(id: "list", title: "Liste", accessibilityLabel: "Liste", isAvailable: true),
            .init(id: "chart", title: "Graphique", accessibilityLabel: "Synthèse graphique", isAvailable: false)
        ], identifier: "feed-display") { _ in
            comingSoon = "Bientôt disponible : la synthèse graphique arrive avec une prochaine version du service."
        }
    }
}

/// Mutually exclusive choices on one capsule. An unavailable choice stays visible and explains itself when tapped.
private struct ChoiceGroup: View {
    struct Option: Identifiable {
        let id: String
        let title: String
        let accessibilityLabel: String
        let isAvailable: Bool
    }
    let label: String
    let selected: String
    let options: [Option]
    let identifier: String
    let onUnavailable: (Option) -> Void

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options) { option in
                let isSelected = option.id == selected
                Button { if !option.isAvailable { onUnavailable(option) } } label: {
                    Text(option.title)
                        .font(.footnote.weight(isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? Brand.ink : Brand.secondaryOnSurface)
                        .fixedSize()
                        .padding(.horizontal, 12).frame(minHeight: 44)
                        .background(isSelected ? Brand.card : .clear, in: Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(option.accessibilityLabel)
                .accessibilityValue(option.isAvailable ? "" : "Bientôt disponible")
                .accessibilityAddTraits(isSelected ? .isSelected : [])
                .accessibilityIdentifier("\(identifier)-\(option.id)")
            }
        }
        .padding(2)
        .background(Brand.surface, in: Capsule())
        .accessibilityElement(children: .contain)
        .accessibilityLabel(label)
    }
}
