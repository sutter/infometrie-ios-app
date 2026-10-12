import SwiftUI

struct SavedSearchesView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.dynamicTypeSize) private var dynamicType
    @State private var deleting: SavedSearch?
    private var searches: [SavedSearch] { lastUsedFirst(model.savedSearches.filter { !$0.isArchived }) }
    private var archivedCount: Int { model.savedSearches.count - searches.count }
    var body: some View {
        SuiviList {
            heading
            if searches.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    AppEmptyState(
                        title: "Retrouvez vos sujets de veille", icon: "bookmark",
                        message: "Choisissez des personnalités ou des partis, puis enregistrez votre recherche pour la retrouver ici."
                    )
                    // The only "Créer un suivi" while nothing is followed: the navigation bar shows none then.
                    Button { model.newSearch() } label: { Text("Créer un suivi") }
                        .buttonStyle(ActionButtonStyle(prominent: true)).accessibilityIdentifier("new-search")
                }
            } else if !dynamicType.isAccessibilitySize {
                // One legend for the right-hand column, rather than "passages sur 7 jours" in every row.
                Text("Passages sur 7 jours").font(.footnote.weight(.semibold)).foregroundStyle(Brand.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, SuiviRow.actionsWidth + SuiviRow.spacing).padding(.bottom, 6)
                    .overlay(alignment: .bottom) { AppRule() }
                    .accessibilityHidden(true)
            }
            ForEach(searches) { search in
                SuiviRow(search: search) { deleting = search }
            }
            if archivedCount > 0 { archivedLink }
            if !model.savedSearches.isEmpty {
                Text("Vos suivis sont enregistrés sur cet appareil, pour votre compte.")
                    .font(.footnote).foregroundStyle(Brand.secondary).padding(.vertical, 24)
            }
        }
        .navigationTitle("").navigationBarTitleDisplayMode(.inline)
        .toolbar(sizeClass == .regular ? .hidden : .visible, for: .navigationBar)
        .toolbarBackground(Brand.background, for: .navigationBar)
        .toolbar {
            if sizeClass != .regular {
                ToolbarItem(placement: .topBarLeading) { Wordmark(size: 21, scheme: colorScheme) }
                    .sharedBackgroundVisibility(.hidden)
                if !searches.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) { createButton(scheme: colorScheme) }
                        .sharedBackgroundVisibility(.hidden)
                }
            }
        }
        .task(id: searches.map(\.filters)) { await model.loadTrends() }
        .modifier(SuiviDeletion(deleting: $deleting))
    }
    /// The title, then how many suivis and in what order: they move up each time one is used, and saying so
    /// keeps that move from reading as disorder.
    private var heading: some View {
        AdaptiveRow {
            PageHeading(title: "Mes suivis", subtitle: searches.isEmpty ? nil
                        : "\(searches.count) \(searches.count == 1 ? "suivi" : "suivis"), les derniers utilisés en premier")
            // On iPad the page has no navigation bar: the button sits beside the title instead.
            if sizeClass == .regular && !searches.isEmpty { createButton() }
        }
        .padding(.top, 16).padding(.bottom, 16)
    }
    /// In the navigation bar, like "Rechercher" on the journal.
    private func createButton(scheme: ColorScheme? = nil) -> some View {
        Button { model.newSearch() } label: {
            Label("Créer un suivi", systemImage: "plus")
                .labelStyle(.titleAndIcon)
                .font(.subheadline.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 8).frame(minHeight: 48)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain).foregroundStyle(Brand.fixed(Brand.tint, for: scheme))
        .accessibilityIdentifier("new-search")
    }
    /// Archived suivis wait on a page of their own, a row under the active ones: Actifs / Archivés chips above
    /// the list cost about 70 pt for a rare use.
    private var archivedLink: some View {
        NavigationLink { ArchivedSearchesView() } label: {
            HStack(spacing: 12) {
                Image(systemName: "archivebox").foregroundStyle(Brand.secondary)
                Text("Suivis archivés").foregroundStyle(Brand.ink)
                Spacer(minLength: 8)
                Text(archivedCount.formatted()).foregroundStyle(Brand.secondary)
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(Brand.secondary)
            }
            .font(.body)
            .frame(minHeight: 52).contentShape(Rectangle())
        }
        // Its own chevron, drawn like the rest of the row, rather than the list's.
        .navigationLinkIndicatorVisibility(.hidden)
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) { AppRule() }
        .padding(.top, 24)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Suivis archivés, \(archivedCount)")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("saved-archived")
    }
}

/// The archived suivis, out of the way of the active ones: each can be restored or deleted.
private struct ArchivedSearchesView: View {
    @Environment(AppModel.self) private var model
    @State private var deleting: SavedSearch?
    private var searches: [SavedSearch] { lastUsedFirst(model.savedSearches.filter(\.isArchived)) }
    var body: some View {
        SuiviList {
            if searches.isEmpty {
                AppEmptyState(title: "Aucun suivi archivé", icon: "archivebox",
                              message: "Un suivi archivé peut être restauré à tout moment.")
            } else {
                ForEach(searches) { search in
                    SuiviRow(search: search) { deleting = search }
                }
                Text("Un suivi archivé peut être restauré à tout moment.")
                    .font(.footnote).foregroundStyle(Brand.secondary).padding(.vertical, 24)
            }
        }
        .appNavigationTitle("Suivis archivés")
        .pushedPage(model)
        .modifier(SuiviDeletion(deleting: $deleting))
    }
}

/// Most recently used first, then most recently created.
private func lastUsedFirst(_ searches: [SavedSearch]) -> [SavedSearch] {
    searches.sorted { ($0.lastUsedAt ?? $0.createdAt) > ($1.lastUsedAt ?? $1.createdAt) }
}

/// The plain page both suivi lists share: rows on hairlines in the page margins, no list chrome.
private struct SuiviList<Content: View>: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @ViewBuilder let content: () -> Content
    var body: some View {
        let margin = sizeClass == .regular ? AppLayout.wideMargin : AppLayout.margin
        List {
            Group { content() }
                .listRowInsets(EdgeInsets(top: 0, leading: margin, bottom: 0, trailing: margin))
                .listRowBackground(Color.clear).listRowSeparator(.hidden)
        }
        .listStyle(.plain).scrollContentBackground(.hidden)
        // The column legend is shorter than a list row's default 44 pt, which floated it away from the rows.
        .environment(\.defaultMinListRowHeight, 1)
        .frame(maxWidth: AppLayout.readingWidth).frame(maxWidth: .infinity)
        .background(Brand.background)
    }
}

/// Asks before deleting a suivi, on either page.
private struct SuiviDeletion: ViewModifier {
    @Environment(AppModel.self) private var model
    @Binding var deleting: SavedSearch?
    func body(content: Content) -> some View {
        content.alert("Supprimer ce suivi ?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
            Button("Annuler", role: .cancel) { deleting = nil }
            Button("Supprimer", role: .destructive) { if let deleting { model.delete(deleting) }; deleting = nil }
        } message: { Text("« \(deleting?.name ?? "") » disparaîtra de cet appareil. Cette action est définitive.") }
    }
}

/// One suivi on a hairline: what it follows on the left, its last 7 days on the right, its actions behind "⋯".
/// Touching the row anywhere but "⋯" opens the journal on it. An archived suivi has no trend and offers to restore.
private struct SuiviRow: View {
    static let actionsWidth: CGFloat = 44
    static let spacing: CGFloat = 12
    @Environment(AppModel.self) private var model
    @Environment(\.dynamicTypeSize) private var dynamicType
    let search: SavedSearch
    let delete: () -> Void
    private var criteria: String? { search.criteria(parties: model.parties) }
    private var trend: [DayCount]? { model.trends[search.filters] }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: dynamicType.isAccessibilitySize ? .top : .center, spacing: Self.spacing) {
                if search.isArchived {
                    description.frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Button { Task { await model.apply(search.filters) } } label: { opener }
                        // Plain, so that the row's own "⋯" menu stays a separate target.
                        .buttonStyle(.plain)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(spokenLabel)
                        .accessibilityHint("Affiche le journal de ce suivi")
                        .accessibilityAddTraits(.isButton)
                        .accessibilityAction(named: "Modifier la recherche") { model.openSearch(search.filters) }
                        .accessibilityAction(named: "Archiver") { model.archive(search) }
                        .accessibilityAction(named: "Supprimer") { delete() }
                        .accessibilityIdentifier("saved-search-\(search.name)")
                }
                Menu { actions } label: {
                    Image(systemName: "ellipsis").font(.body.weight(.semibold)).foregroundStyle(Brand.secondary)
                        // A minimum, not a fixed width: at accessibility sizes the glyph outgrew 44 pt and ran past the margin.
                        .frame(minWidth: Self.actionsWidth, minHeight: 44).contentShape(Rectangle())
                }
                .accessibilityLabel("Options de \(search.name)").accessibilityIdentifier("saved-actions-\(search.name)")
            }
            if search.isArchived {
                Button("Restaurer ce suivi") { model.archive(search) }
                    .buttonStyle(ActionButtonStyle()).accessibilityIdentifier("restore-search-\(search.name)")
            }
        }
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) { AppRule() }
        .contentShape(Rectangle())
        .contextMenu { actions }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button("Supprimer", role: .destructive) { delete() }
            Button(search.isArchived ? "Restaurer" : "Archiver") { model.archive(search) }.tint(Brand.primary)
        }
    }

    /// The description and the trend, side by side; stacked at accessibility sizes, where the trend reads in words.
    @ViewBuilder private var opener: some View {
        if dynamicType.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 8) {
                description
                SuiviTrend(filters: search.filters, days: trend, inWords: true).accessibilityIdentifier("saved-trend-\(search.name)")
            }
            .frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
        } else {
            HStack(spacing: Self.spacing) {
                description.frame(maxWidth: .infinity, alignment: .leading)
                SuiviTrend(filters: search.filters, days: trend, inWords: false).accessibilityIdentifier("saved-trend-\(search.name)")
            }
            .contentShape(Rectangle())
        }
    }

    private var description: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(search.name).font(.headline).foregroundStyle(Brand.ink)
                .fixedSize(horizontal: false, vertical: true)
            if let criteria {
                Text(criteria).font(.subheadline).foregroundStyle(Brand.secondary)
                    .lineLimit(dynamicType.isAccessibilitySize ? 3 : 1)
            }
            KindNames(filters: search.filters)
        }
    }

    @ViewBuilder private var actions: some View {
        if !search.isArchived {
            Button("Modifier la recherche", systemImage: "magnifyingglass") { model.openSearch(search.filters) }
        }
        Button(search.isArchived ? "Restaurer" : "Archiver", systemImage: search.isArchived ? "arrow.uturn.backward" : "archivebox") { model.archive(search) }
        Button("Supprimer", systemImage: "trash", role: .destructive) { delete() }
    }

    private var spokenLabel: String {
        let kinds = KindNames.restricted(search.filters) ? search.filters.kindSummary.replacingOccurrences(of: " · ", with: ", ") : nil
        return [search.name, criteria, kinds, SuiviTrend.spoken(filters: search.filters, days: trend)]
            .compactMap { $0 }.joined(separator: ", ")
    }
}

/// The kinds a suivi keeps, named only when it leaves one out: pictogram and name in the kind's color, with no tag,
/// on one line, or one under the other when they do not fit.
private struct KindNames: View {
    let filters: SearchFilters
    static func restricted(_ filters: SearchFilters) -> Bool { (1...2).contains(filters.selectedKinds.count) }

    var body: some View {
        if Self.restricted(filters) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) { names }
                VStack(alignment: .leading, spacing: 4) { names }
            }
            .accessibilityElement(children: .combine)
        }
    }

    private var names: some View {
        ForEach(filters.selectedKinds, id: \.self) { kind in
            HStack(spacing: 4) {
                // X uses its own mark, a custom symbol sized by the font only.
                if kind == "tweet" { Image("x.logo") } else { Image(systemName: FeedItem.symbol(ofKind: kind)) }
                Text(kind == "intervention" ? "Interventions" : kind == "citation" ? "Citations" : "Publications X")
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(FeedItem.labelColor(ofKind: kind))
        }
    }
}

/// A suivi's last 7 complete days: its total over one small bar per day, its kinds stacked in their colors,
/// so the suivi that is stirring shows at a glance. At accessibility sizes, the bars then the total in words.
private struct SuiviTrend: View {
    let filters: SearchFilters
    let days: [DayCount]?
    let inWords: Bool
    @ScaledMetric(relativeTo: .footnote) private var barHeight = 20.0

    private var placeholder: [DayCount] {
        ParisDay.days(count: 7, before: Date()).enumerated().map { DayCount(day: $1, interventions: 2 + $0 % 3) }
    }
    private var shown: [DayCount] { days ?? placeholder }
    private var kinds: [String] { days == nil ? ["intervention"] : filters.selectedKinds }
    private var total: Int { shown.reduce(0) { $0 + $1.total(for: filters) } }

    /// French counts 0 and 1 in the singular.
    static func spoken(filters: SearchFilters, days: [DayCount]?) -> String {
        guard let days else { return "Chargement de la tendance" }
        let total = days.reduce(0) { $0 + $1.total(for: filters) }
        return "\(total) \(total <= 1 ? "passage" : "passages") sur les 7 derniers jours"
    }

    var body: some View {
        Group {
            if inWords {
                HStack(alignment: .bottom, spacing: 8) {
                    bars
                    Text("\(Text(total.formatted()).bold().foregroundStyle(Brand.ink)) \(total <= 1 ? "passage" : "passages") sur 7 jours")
                        .font(.footnote).foregroundStyle(Brand.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                VStack(alignment: .trailing, spacing: 4) {
                    Text(total.formatted()).font(.headline.weight(.bold).monospacedDigit()).foregroundStyle(Brand.ink)
                    bars
                }
            }
        }
        .skeleton(days == nil)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.spoken(filters: filters, days: days))
    }

    private var bars: some View {
        let peak = max(1, shown.map { $0.total(for: filters) }.max() ?? 1)
        return HStack(alignment: .bottom, spacing: 3) {
            ForEach(shown) { day in
                // Bottom to top in the order of the type checkboxes, like the journal's chart.
                VStack(spacing: 0) {
                    ForEach(kinds.reversed(), id: \.self) { kind in
                        let count = day.count(ofKind: kind)
                        if count > 0 {
                            Rectangle().fill(FeedItem.color(ofKind: kind))
                                .frame(height: barHeight * CGFloat(count) / CGFloat(peak))
                        }
                    }
                }
                .frame(width: 5, height: barHeight, alignment: .bottom)
                .background(alignment: .bottom) { Rectangle().fill(Brand.rule).frame(height: 1) }
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 2, topTrailingRadius: 2))
            }
        }
        .accessibilityHidden(true)
    }
}
