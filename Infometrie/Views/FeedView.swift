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
                    if !model.period.isLive { FeedDayChart().padding(.top, 16) }
                    statusRow.padding(.top, 16).padding(.bottom, 8)
                    if hasAudienceFilters { selectionSummary.padding(.bottom, 8) }
                    if let error = model.feedError {
                        ErrorNotice(message: error) { Task { await model.reload() } }
                            .padding(.vertical, 12)
                    }
                    // The cards change without animation: the user asked for a still list.
                    Group {
                        if model.isLoadingPassages && model.visibleItems.isEmpty {
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
                                AppEmptyState(title: emptyTitle, icon: "text.magnifyingglass", message: emptyMessage)
                                // 7 j and 30 j end yesterday: someone quiet all week may be speaking today.
                                if !model.period.isLive {
                                    Button("Voir aujourd’hui dans Live") { Task { await model.selectPeriod(.live) } }
                                        .buttonStyle(ActionButtonStyle(prominent: true))
                                        .accessibilityIdentifier("empty-show-live")
                                }
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
                                // Every period pages through the history: the last card asks for the next page.
                                .onAppear {
                                    if item.id == model.visibleItems.last?.id { Task { await model.loadMore() } }
                                }
                            }
                            if model.isLoadingMore {
                                FeedSkeleton(label: "Chargement de la suite").padding(.vertical, 5)
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
        .onChange(of: model.filters) { jumpToTop() }
        .onChange(of: model.period) { jumpToTop() }
        .refreshable { await model.reload() }
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
                ToolbarItem(placement: .topBarLeading) { Wordmark(size: 21, scheme: colorScheme) }
                    .sharedBackgroundVisibility(.hidden)
                ToolbarItem(placement: .topBarTrailing) { filtersButton(scheme: colorScheme) }
                    .sharedBackgroundVisibility(.hidden)
            }
        }
    }

    /// Jump, never animate: pinned headers do not follow an animated programmatic scroll,
    /// which leaves a gap under the type row and makes the heading pop in at the end.
    private func jumpToTop() {
        var jump = Transaction(); jump.disablesAnimations = true
        withTransaction(jump) { scrollPosition.scrollTo(edge: .top) }
    }

    private var emptyTitle: String {
        model.period.isLive ? "Aucun passage pour le moment" : model.selectedDay == nil ? "Aucun passage sur la période" : "Aucun passage ce jour-là"
    }
    private var emptyMessage: String {
        if model.selectedDay != nil { return "Aucun résultat ce jour-là avec ces critères. Choisissez un autre jour sur le graphique." }
        guard !model.period.isLive, let first = model.historyDays.first, let last = model.historyDays.last else {
            return "Aucun résultat sur les dernières 24 heures avec ces critères."
        }
        // Name the days: "7 jours" alone hid that today is left out, in Live.
        return "Aucun résultat du \(DayLabel.short(first)) au \(DayLabel.short(last)) avec ces critères. Les passages d’aujourd’hui sont dans Live."
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

    /// The active search as removable pills, one per person or party (the user's pick on 2026-10-08, option A of
    /// sheet 03, then split per criterion): the former name line, "Tout afficher" button and rule took three rows, and
    /// one pill for several criteria could only clear them all. From two criteria on, "Tout effacer" ends the row.
    private var selectionSummary: some View {
        let persons = model.filters.persons.sorted()
        let parties = model.filters.parties.sorted()
        let several = persons.count + parties.count > 1
        let pills = Group {
            ForEach(persons, id: \.self) { name in
                criterionPill(name, icon: "person", single: !several) { $0.persons.remove(name) }
            }
            ForEach(parties, id: \.self) { code in
                let label = model.parties.first { $0.code == code }?.name ?? code
                criterionPill(label, icon: "building.columns", single: !several) { $0.parties.remove(code) }
            }
            if several {
                Button("Tout effacer") { Task { await model.apply(SearchFilters()) } }
                    .font(.subheadline.weight(.semibold)).foregroundStyle(Brand.tint)
                    .buttonStyle(.plain).frame(minHeight: 44).padding(.horizontal, 4)
                    .accessibilityIdentifier("clear-filters")
            }
        }
        return Group {
            if dynamicType.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) { pills }
            } else {
                // One row that scrolls and draws out to the screen edges, like the type chips above.
                ScrollView(.horizontal) { HStack(spacing: 8) { pills } }
                    .scrollIndicators(.hidden)
                    .scrollClipDisabled()
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Recherche active")
    }

    /// One person or party; touching it removes that criterion only. Alone, it carries `clear-filters`.
    private func criterionPill(_ title: String, icon: String, single: Bool, remove: @escaping (inout SearchFilters) -> Void) -> some View {
        Button {
            var filters = model.filters
            remove(&filters)
            Task { await model.apply(filters) }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.caption.weight(.semibold)).foregroundStyle(Brand.secondary)
                Text(title).font(.subheadline.weight(.medium)).foregroundStyle(Brand.ink)
                    .lineLimit(dynamicType.isAccessibilitySize ? nil : 1)
                Image(systemName: "xmark").font(.caption.weight(.bold)).foregroundStyle(Brand.secondary)
            }
            .padding(.horizontal, 12).padding(.vertical, 8).frame(minHeight: 36)
            .background(Brand.surface, in: Capsule())
            .overlay(Capsule().strokeBorder(Brand.rule, lineWidth: 0.5))
            .frame(minHeight: 44).contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(title)
        .accessibilityHint("Touchez pour retirer ce critère")
        .accessibilityIdentifier(single ? "clear-filters" : "remove-criterion-\(title)")
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
        // A play link with no background: a capsule on a pale wash read as a fourth type checkbox beside the ones above.
        Button { model.player.start(items: playable, app: model, podcast: true) } label: {
            HStack(spacing: 6) {
                Image(systemName: "play.circle.fill").font(.title2).foregroundStyle(Brand.accent).accessibilityHidden(true)
                Text("Tout écouter").font(.subheadline.weight(.semibold)).foregroundStyle(Brand.actionText)
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .disabled(playable.isEmpty)
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
            let count = total
            // One text, so that at accessibility sizes the age wraps under the count rather than beside it.
            // 7 j and 30 j end yesterday: their age says nothing, only Live shows it.
            (Text(count <= 1 ? "\(count) résultat" : "\(count) résultats").fontWeight(.semibold).foregroundStyle(Brand.ink)
                + Text(model.period.isLive ? model.lastRefresh.map { " · \(Self.age(of: $0, at: context.date))" } ?? "" : "").foregroundStyle(Brand.secondary))
                .font(.footnote.monospacedDigit())
                .fixedSize(horizontal: singleLine, vertical: true)
                .accessibilityIdentifier("feed-status")
        }
    }

    /// Live counts its list; 7 j and 30 j count the period or the chosen day from `/days`, beyond the loaded pages.
    private var total: Int {
        guard !model.period.isLive, !model.dayCounts.isEmpty else { return model.visibleItems.count }
        let days = model.dayCounts.filter { model.selectedDay == nil || $0.day == model.selectedDay }
        return days.reduce(0) { $0 + $1.total(for: model.filters) }
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
        // Checked, the chip fills with the kind's color, so the row of types reads like the list below it.
        let checked = isChecked(kind)
        let onFill = kind == .tweets ? Brand.primaryForeground : Color.white
        return Button { toggle(kind) } label: {
            HStack(spacing: 6) {
                // White on the kind's fill when checked, secondary otherwise.
                Image(systemName: checked ? "checkmark.square.fill" : "square")
                    .font(.body).foregroundStyle(checked ? onFill : Brand.secondary)
                // The bare X mark: an ink tile beside a filled checkbox would read as a second box.
                if kind == .tweets {
                    Image("x.logo").font(.subheadline.weight(.semibold))
                        .foregroundStyle(checked ? onFill : Brand.secondary)
                } else {
                    Text(kind.title)
                        .font(.subheadline)
                        .foregroundStyle(checked ? onFill : Brand.secondary)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .chip(selected: checked, wash: FeedItem.fill(ofKind: kind.apiKind))
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

/// The journal's period (Live, or the last 7 or 30 complete days with their day chart) and its display.
/// Liste is the only display today: Graphique, a synthesis per person and per party, waits for an API, so it stays
/// visible and explains in an alert, rather than on screen, that it is coming.
private struct FeedViewOptions: View {
    @Environment(AppModel.self) private var model
    @State private var comingSoon = false

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
        .sensoryFeedback(.selection, trigger: model.period)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Période et affichage")
        .alert("Bientôt disponible", isPresented: $comingSoon) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("La synthèse graphique par personnalité et par parti arrivera avec une prochaine version du service.")
        }
    }

    @ViewBuilder private var periods: some View {
        period(.live, title: "Live", label: "Live, dernières 24 heures", id: "feed-period-live")
        period(.week, title: "7 j", label: "7 derniers jours", id: "feed-period-7")
        period(.month, title: "30 j", label: "30 derniers jours", id: "feed-period-30")
    }

    @ViewBuilder private var displays: some View {
        AppTabButton(title: "Liste", selected: true, icon: "list.bullet", iconOnly: true, compact: true) { }
            .accessibilityLabel("Liste")
            .accessibilityIdentifier("feed-display-list")
        AppTabButton(title: "Graphique", selected: false, icon: "chart.bar.xaxis", iconOnly: true, compact: true) { comingSoon = true }
            .accessibilityLabel("Synthèse graphique")
            .accessibilityValue("Bientôt disponible")
            .accessibilityIdentifier("feed-display-chart")
    }

    private func period(_ period: FeedPeriod, title: String, label: String, id: String) -> some View {
        AppTabButton(title: title, selected: model.period == period, compact: true) {
            Task { await model.selectPeriod(period) }
        }
        .accessibilityLabel(label)
        .accessibilityIdentifier(id)
    }
}
