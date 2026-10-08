import SwiftUI

struct SavedSearchesView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.dynamicTypeSize) private var dynamicType
    @State private var archived = false
    @State private var deleting: SavedSearch?
    private var searches: [SavedSearch] {
        model.savedSearches.filter { $0.isArchived == archived }
            .sorted { ($0.lastUsedAt ?? $0.createdAt) > ($1.lastUsedAt ?? $1.createdAt) }
    }
    var body: some View {
        List {
            Group {
                VStack(alignment: .leading, spacing: 20) {
                    PageHeading(title: "Mes suivis", subtitle: "Vos sujets, au fil de l’actualité.")
                    // At accessibility sizes the "+" left too little room and the label broke inside "Créer".
                    Button { model.newSearch() } label: {
                        if dynamicType.isAccessibilitySize { Text("Créer un suivi") } else { Label("Créer un suivi", systemImage: "plus") }
                    }
                        // Prominent only while the list is empty; afterwards the suivis themselves lead.
                        .buttonStyle(ActionButtonStyle(prominent: model.savedSearches.isEmpty)).accessibilityIdentifier("new-search")
                    // Chips, like the feed's types: one look for every choice that narrows a list.
                    HStack(spacing: 8) {
                        category("Actifs", archived: false)
                        category("Archivés", archived: true)
                        Spacer(minLength: 0)
                    }
                    .sensoryFeedback(.selection, trigger: archived)
                }.padding(.top, 16).padding(.bottom, 8)
                if searches.isEmpty {
                    AppEmptyState(
                        title: archived ? "Aucun suivi archivé" : "Retrouvez vos sujets de veille",
                        icon: archived ? "archivebox" : "bookmark",
                        message: archived ? "Un suivi archivé peut être restauré à tout moment." : "Choisissez des personnalités ou des partis, puis enregistrez votre recherche pour la retrouver ici."
                    )
                }
                ForEach(searches) { search in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(search.name).font(.headline)
                            .fixedSize(horizontal: false, vertical: true).accessibilityAddTraits(.isHeader)
                        Text(search.filters.isEmpty ? "Toutes les personnalités" : search.filters.summary)
                            .font(.subheadline).foregroundStyle(Brand.secondary)
                        if !archived {
                            SuiviTrend(filters: search.filters, days: model.trends[search.filters])
                                .accessibilityIdentifier("saved-trend-\(search.name)")
                        }
                        // The kinds as tags, as in the feed; stacked when the three do not fit the width, since a
                        // row wider than the screen pushed the whole suivi off its left edge.
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 6) { kindTags(search.filters) }
                            VStack(alignment: .leading, spacing: 6) { kindTags(search.filters) }
                        }
                        .accessibilityElement(children: .combine)
                        AdaptiveRow {
                            if archived {
                                Button("Restaurer ce suivi") { model.archive(search) }
                                    .buttonStyle(ActionButtonStyle()).accessibilityIdentifier("restore-search-\(search.name)")
                            } else {
                                Button { Task { await model.apply(search.filters) } } label: { Label("Afficher le journal", systemImage: "text.alignleft") }
                                    .buttonStyle(ActionButtonStyle())
                            }
                            Menu {
                                if !archived {
                                    Button("Modifier la recherche", systemImage: "magnifyingglass") { model.openSearch(search.filters) }
                                }
                                Button(archived ? "Restaurer" : "Archiver", systemImage: archived ? "arrow.uturn.backward" : "archivebox") { model.archive(search) }
                                Button("Supprimer", systemImage: "trash", role: .destructive) { deleting = search }
                            } label: {
                                Label("Options", systemImage: "ellipsis").font(.subheadline.weight(.medium))
                                    .fixedSize(horizontal: false, vertical: true).padding(.horizontal, 8).frame(minHeight: 52)
                            }.accessibilityLabel("Options de \(search.name)").accessibilityIdentifier("saved-actions-\(search.name)")
                        }
                    }
                    // A row on a hairline, like the feed, rather than a card.
                    .padding(.vertical, 20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .overlay(alignment: .bottom) { AppRule() }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button("Supprimer", role: .destructive) { deleting = search }
                            Button(archived ? "Restaurer" : "Archiver") { model.archive(search) }.tint(Brand.primary)
                        }
                }
                if !searches.isEmpty {
                    Text("Vos suivis sont enregistrés sur cet appareil, pour votre compte.")
                        .font(.footnote).foregroundStyle(Brand.secondary).padding(.vertical, 24)
                }
            }
            .listRowInsets(EdgeInsets(top: 0, leading: sizeClass == .regular ? AppLayout.wideMargin : AppLayout.margin, bottom: 0, trailing: sizeClass == .regular ? AppLayout.wideMargin : AppLayout.margin))
            .listRowBackground(Color.clear).listRowSeparator(.hidden)
        }
        .listStyle(.plain).scrollContentBackground(.hidden)
        .frame(maxWidth: AppLayout.readingWidth).frame(maxWidth: .infinity)
        .background(Brand.background)
        .navigationTitle("").navigationBarTitleDisplayMode(.inline)
        .toolbar(sizeClass == .regular ? .hidden : .visible, for: .navigationBar)
        .toolbarBackground(Brand.background, for: .navigationBar)
        .toolbar {
            if sizeClass != .regular {
                ToolbarItem(placement: .topBarLeading) { Wordmark(size: 21, scheme: colorScheme) }
                    .sharedBackgroundVisibility(.hidden)
            }
        }
        .task(id: model.savedSearches.filter { !$0.isArchived }.map(\.filters)) { await model.loadTrends() }
        .alert("Supprimer ce suivi ?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
            Button("Annuler", role: .cancel) { deleting = nil }
            Button("Supprimer", role: .destructive) { if let deleting { model.delete(deleting) }; deleting = nil }
        } message: { Text("« \(deleting?.name ?? "") » disparaîtra de cet appareil. Cette action est définitive.") }
    }
    @ViewBuilder private func kindTags(_ filters: SearchFilters) -> some View {
        if filters.interventions { KindTag(kind: "intervention", label: "Interventions") }
        if filters.citations { KindTag(kind: "citation", label: "Citations") }
        if filters.tweets { KindTag(kind: "tweet", label: "Publications X") }
    }
    private func category(_ title: String, archived value: Bool) -> some View {
        let selected = archived == value
        return Button { archived = value } label: {
            Text(title).font(.subheadline.weight(selected ? .semibold : .regular))
                .foregroundStyle(selected ? Brand.ink : Brand.secondary)
                .chip(selected: selected)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier(value ? "saved-archived" : "saved-active")
    }
}

/// A suivi's last 7 complete days: its total, then one small bar per day, its kinds stacked in their colors,
/// so the suivi that is stirring shows at a glance.
private struct SuiviTrend: View {
    let filters: SearchFilters
    let days: [DayCount]?
    @ScaledMetric(relativeTo: .footnote) private var barHeight = 32.0

    private var placeholder: [DayCount] {
        ParisDay.days(count: 7, before: Date()).enumerated().map { DayCount(day: $1, interventions: 2 + $0 % 3) }
    }
    private var shown: [DayCount] { days ?? placeholder }
    private var kinds: [String] { days == nil ? ["intervention"] : filters.selectedKinds }
    private var total: Int { shown.reduce(0) { $0 + $1.total(for: filters) } }

    var body: some View {
        HStack(alignment: .bottom, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(total.formatted()).font(.title3.weight(.bold).monospacedDigit()).foregroundStyle(Brand.ink)
                Text(total == 1 ? "passage sur 7 jours" : "passages sur 7 jours").font(.footnote).foregroundStyle(Brand.secondary)
            }
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            bars
        }
        .skeleton(days == nil)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(days == nil ? "Chargement de la tendance" : "\(total) passages sur les 7 derniers jours")
    }

    private var bars: some View {
        let peak = max(1, shown.map { $0.total(for: filters) }.max() ?? 1)
        return HStack(alignment: .bottom, spacing: 4) {
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
                .frame(width: 8, height: barHeight, alignment: .bottom)
                .background(alignment: .bottom) { Rectangle().fill(Brand.rule).frame(height: 1) }
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 2, topTrailingRadius: 2))
            }
        }
        .accessibilityHidden(true)
    }
}
