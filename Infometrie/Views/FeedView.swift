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
                    if model.isDemo { DemoBanner() }
                    if let error = model.feedError {
                        ErrorNotice(message: error) { Task { await model.refresh(reset: true) } }
                            .padding(.vertical, 12)
                    }
                    // Only the cards fade as filters change or passages arrive. Animating the whole stack
                    // would also animate the pinned type row, which then sticks and snaps.
                    Group {
                        if model.isRefreshing && model.items.isEmpty {
                            FeedSkeleton().padding(.vertical, 5).transition(.opacity)
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
                    .motion(value: model.visibleItems.map(\.id))
                    .motion(value: model.isRefreshing && model.items.isEmpty)
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
            AppRule()
        }
        .background(Brand.background)
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

/// Applies only the passage type through the same filters as the full editor.
private struct FeedKindPicker: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dynamicTypeSize) private var dynamicType

    private enum Kind: Int, CaseIterable {
        case all, interventions, citations, tweets
        var title: String {
            switch self {
            case .all: "Tous"
            case .interventions: "Interventions"
            case .citations: "Citations"
            case .tweets: "X"
            }
        }
        var symbol: String? {
            switch self {
            case .all: "square.grid.2x2"
            case .interventions: "waveform"
            case .citations: "quote.bubble"
            case .tweets: nil
            }
        }
        /// X is shown by its official logo alone, on an ink tile so it stands out like in the feed cards.
        var assetSymbol: String? { self == .tweets ? "x.logo" : nil }
        var accessibilityLabel: String { self == .all ? "Tous les contenus" : self == .tweets ? "Publications X" : title }
    }

    private var selection: Kind? {
        model.filters.kindSelection.flatMap(Kind.init(rawValue:))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if dynamicType.isAccessibilitySize { verticalChoices }
            else {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 0) {
                        ForEach(Kind.allCases, id: \.self) { kind in
                            choice(kind).fixedSize(horizontal: true, vertical: false)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .slidingTabUnderline()
                    scrollableChoices
                }
            }
            if selection == nil {
                Text(model.filters.kindSummary).font(.subheadline).foregroundStyle(Brand.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .sensoryFeedback(.selection, trigger: selection)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Types de passages")
        .accessibilityIdentifier("feed-kind-picker")
    }

    private var verticalChoices: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Kind.allCases, id: \.self) { choice($0) }
        }
        .slidingTabUnderline()
    }

    private var scrollableChoices: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 0) {
                ForEach(Kind.allCases, id: \.self) { choice($0) }
            }
            .slidingTabUnderline()
        }
        .scrollIndicators(.hidden)
    }

    private func choice(_ kind: Kind) -> some View {
        AppTabButton(title: kind.title, selected: selection == kind, icon: kind.symbol,
                     assetIcon: kind.assetSymbol, iconOnly: kind.assetSymbol != nil,
                     iconTile: kind.assetSymbol != nil, compact: true, sharedUnderline: true) {
            var filters = model.filters
            filters.selectKind(kind.rawValue)
            guard filters != model.filters else { return }
            Task { await model.apply(filters) }
        }
        .accessibilityLabel(kind.accessibilityLabel)
        .accessibilityIdentifier("feed-kind-\(kind.rawValue)")
    }
}
