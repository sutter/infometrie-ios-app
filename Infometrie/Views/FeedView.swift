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
                Section {
                    // Period and display scroll with the list: only the types stay pinned, so the cards get the room.
                    FeedViewOptions().padding(.top, 10)
                    statusRow.padding(.top, 8).padding(.bottom, 4)
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

    /// The result count and its freshness on one line, with "Tout écouter" at its end.
    /// When both cannot fit, the button moves below rather than the text wrapping.
    private var statusRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                FeedStatus(singleLine: true)
                Spacer(minLength: 0)
                if usesWideLayout { filtersButton }
                listenButton
            }
            VStack(alignment: .leading, spacing: 8) {
                FeedStatus(singleLine: !dynamicType.isAccessibilitySize)
                HStack(spacing: 12) {
                    if usesWideLayout { filtersButton }
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
                    HStack(spacing: 20) { choices }
                    ScrollView(.horizontal) { HStack(spacing: 20) { choices } }
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
                    .font(.body).foregroundStyle(checked ? Brand.tint : Brand.secondary)
                // The bare X mark: an ink tile beside a filled checkbox would read as a second box.
                if kind == .tweets {
                    Image("x.logo").font(.subheadline.weight(.semibold))
                        .foregroundStyle(checked ? Brand.ink : Brand.secondary)
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
/// wait for an API, so they stay visible and explain in an alert, rather than on screen, that they are coming.
private struct FeedViewOptions: View {
    @Environment(\.dynamicTypeSize) private var dynamicType
    @State private var comingSoon: String?

    var body: some View {
        Group {
            if dynamicType.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) { period; display }
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) { period; Spacer(minLength: 0); display }
                    VStack(alignment: .leading, spacing: 8) { period; display }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .alert("Bientôt disponible", isPresented: Binding(get: { comingSoon != nil }, set: { if !$0 { comingSoon = nil } })) {
            Button("OK", role: .cancel) { comingSoon = nil }
        } message: { Text(comingSoon ?? "") }
    }

    private var period: some View {
        ChoiceGroup(label: "Période", selected: "live", options: [
            .init(id: "live", title: "Live", accessibilityLabel: "Live, dernières 24 heures", isAvailable: true),
            .init(id: "7", title: "7 j", accessibilityLabel: "7 jours", isAvailable: false),
            .init(id: "30", title: "30 j", accessibilityLabel: "30 jours", isAvailable: false)
        ], identifier: "feed-period") { _ in
            comingSoon = "Les périodes de 7 et 30 jours arriveront avec une prochaine version du service."
        }
    }

    private var display: some View {
        ChoiceGroup(label: "Affichage", selected: "list", options: [
            .init(id: "list", title: "Liste", accessibilityLabel: "Liste", isAvailable: true),
            .init(id: "chart", title: "Graphique", accessibilityLabel: "Synthèse graphique", isAvailable: false)
        ], identifier: "feed-display") { _ in
            comingSoon = "La synthèse graphique arrivera avec une prochaine version du service."
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
