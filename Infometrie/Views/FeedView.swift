import SwiftUI

struct FeedView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicType
    @ScaledMetric(relativeTo: .largeTitle) private var wideTitleSize = 112.0
    @ScaledMetric(relativeTo: .largeTitle) private var compactTitleSize = 52.0
    private var playable: [FeedItem] { model.visibleItems.filter(\.hasMedia).sorted { $0.at < $1.at } }
    private var hasAudienceFilters: Bool { !model.filters.isEmpty }
    private var usesWideLayout: Bool { horizontalSizeClass == .regular }

    var body: some View {
        GeometryReader { geometry in
            let usesColumns = usesWideLayout && geometry.size.width >= 650 && dynamicType <= .xxLarge
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    feedHeading.padding(.bottom, 20)
                    filterControls
                    if hasAudienceFilters { selectionSummary.padding(.top, 20) }
                    if model.isDemo { DemoBanner().padding(.top, 8) }
                    if let error = model.feedError {
                        ErrorNotice(message: error) { Task { await model.refresh(reset: true) } }
                            .padding(.top, 20)
                    }
                    if model.isRefreshing && model.items.isEmpty {
                        ProgressView("Chargement du fil…").frame(maxWidth: .infinity).padding(.vertical, 60)
                    } else if model.visibleItems.isEmpty && model.feedError == nil {
                        VStack(alignment: .leading, spacing: 12) {
                            EditorialEmptyState(title: "Aucun passage pour le moment", icon: "text.magnifyingglass", message: "Aucun résultat sur les dernières 24 heures avec ces critères.")
                            Button("Modifier les filtres") { model.openSearch(model.filters) }
                                .buttonStyle(ActionButtonStyle())
                        }
                    } else {
                        passages(inColumns: usesColumns)
                    }
                    if let date = model.lastRefresh {
                        Text("Mis à jour à \(date.formatted(date: .omitted, time: .shortened))")
                            .font(.footnote).foregroundStyle(Brand.secondary)
                            .frame(maxWidth: .infinity).padding(.vertical, 24)
                    }
                }
                .padding(.horizontal, usesWideLayout ? EditorialLayout.wideMargin : 20)
                .padding(.top, usesWideLayout ? 28 : 12).padding(.bottom, 24)
                .frame(maxWidth: EditorialLayout.maximumWidth).frame(maxWidth: .infinity)
            }
            .refreshable { await model.refresh(reset: true) }
        }
        .scrollEdgeEffectStyle(.soft, for: .bottom)
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
        VStack(alignment: .leading, spacing: 14) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 20) {
                    title.fixedSize(horizontal: true, vertical: true)
                    Spacer(minLength: 0)
                    listenButton.fixedSize(horizontal: true, vertical: true)
                }
                VStack(alignment: .leading, spacing: 16) {
                    title
                    listenButton
                }
            }
            Rectangle().fill(Brand.citation).frame(width: 48, height: 8).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(Date.now, format: .dateTime.weekday(.wide).day().month(.wide).year())
                    .textCase(.none)
                    .font(.system(.body, design: .serif))
                    .accessibilityIdentifier("feed-date")
                HStack(spacing: 6) {
                    Text("24 h").accessibilityHint("Passages des dernières 24 heures")
                    Text("·").accessibilityHidden(true)
                    Text(model.visibleItems.count == 1 ? "1 passage" : "\(model.visibleItems.count) passages")
                }.font(.subheadline)
            }
            .foregroundStyle(Brand.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var title: some View {
        Text("Le fil")
            .font(.system(size: usesWideLayout ? wideTitleSize : compactTitleSize, weight: .bold, design: .serif))
            .tracking(-2)
            .foregroundStyle(Brand.ink)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
    }

    private var filterControls: some View {
        VStack(spacing: 0) {
            if usesWideLayout {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .bottom, spacing: 12) {
                        FeedKindPicker().fixedSize(horizontal: true, vertical: false)
                        Spacer(minLength: 0)
                        filtersButton
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        FeedKindPicker()
                        filtersButton
                    }
                }
            } else { FeedKindPicker() }
            EditorialRule()
        }
    }

    private var selectionSummary: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Votre sélection").font(.system(.title3, design: .serif, weight: .semibold))
                .foregroundStyle(Brand.ink).accessibilityAddTraits(.isHeader)
            Text(model.filters.summary).font(.body).foregroundStyle(Brand.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button { Task { await model.apply(SearchFilters()) } } label: {
                Label("Tout afficher", systemImage: "arrow.counterclockwise")
                    .font(.body.weight(.semibold)).frame(minHeight: 48)
            }
            .buttonStyle(.plain).foregroundStyle(Brand.blue)
            .accessibilityIdentifier("clear-filters")
            EditorialRule()
        }
    }

    @ViewBuilder private func passages(inColumns: Bool) -> some View {
        let items = model.visibleItems
        if let first = items.first {
            passage(first, prominent: usesWideLayout && !dynamicType.isAccessibilitySize)
                .padding(.vertical, 24)
            EditorialRule()
            if inColumns {
                ForEach(Array(stride(from: 1, to: items.count, by: 2)), id: \.self) { index in
                    HStack(alignment: .top, spacing: 40) {
                        passage(items[index]).frame(maxWidth: .infinity, alignment: .topLeading)
                        if index + 1 < items.count {
                            passage(items[index + 1]).frame(maxWidth: .infinity, alignment: .topLeading)
                        } else {
                            Color.clear.frame(maxWidth: .infinity, maxHeight: 0).accessibilityHidden(true)
                        }
                    }
                    .overlay {
                        if index + 1 < items.count {
                            Rectangle().fill(Brand.rule).frame(width: 0.5).accessibilityHidden(true)
                        }
                    }
                    .padding(.vertical, 28)
                    EditorialRule()
                }
            } else {
                ForEach(Array(items.dropFirst())) { item in
                    passage(item).padding(.vertical, 24)
                    EditorialRule()
                }
            }
        }
    }

    private func passage(_ item: FeedItem, prominent: Bool = false) -> some View {
        NavigationLink { SequenceView(item: item) } label: {
            FeedCard(item: item, prominent: prominent)
        }
        .buttonStyle(.plain).accessibilityIdentifier("feed-item-\(item.id)")
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
        .buttonStyle(.plain).foregroundStyle(Brand.blue)
        .accessibilityIdentifier("edit-filters")
        .accessibilityValue(hasAudienceFilters ? "Filtres actifs" : "")
    }

    private var listenButton: some View {
        Button { model.player.start(items: playable, app: model, podcast: true) } label: {
            Label("Tout écouter", systemImage: "play.fill")
                .font(.subheadline.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 20).padding(.vertical, 14)
                .frame(minHeight: 48)
                .foregroundStyle(Brand.background)
                .background(Brand.ink, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(playable.isEmpty).opacity(playable.isEmpty ? 0.45 : 1)
        .accessibilityIdentifier("start-podcast")
    }
}

/// Applies only the passage type through the same filters as the full editor.
private struct FeedKindPicker: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dynamicTypeSize) private var dynamicType

    private enum Kind: Int, CaseIterable {
        case all, interventions, citations
        var title: String {
            switch self {
            case .all: "Tous"
            case .interventions: "Interventions"
            case .citations: "Citations"
            }
        }
        var accessibilityLabel: String { self == .all ? "Tous les passages" : title }
    }

    private var selection: Binding<Kind> {
        Binding {
            if model.filters.interventions && model.filters.citations { return .all }
            return model.filters.interventions ? .interventions : .citations
        } set: { kind in
            var filters = model.filters
            filters.interventions = kind != .citations
            filters.citations = kind != .interventions
            guard filters != model.filters else { return }
            Task { await model.apply(filters) }
        }
    }

    var body: some View {
        Group {
            if dynamicType.isAccessibilitySize { verticalChoices }
            else {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 4) {
                        ForEach(Kind.allCases, id: \.self) { kind in
                            choice(kind).fixedSize(horizontal: true, vertical: false)
                        }
                    }
                    verticalChoices
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Types de passages")
        .accessibilityIdentifier("feed-kind-picker")
    }

    private var verticalChoices: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Kind.allCases, id: \.self) { choice($0) }
        }
    }

    private func choice(_ kind: Kind) -> some View {
        EditorialTabButton(title: kind.title, selected: selection.wrappedValue == kind) {
            selection.wrappedValue = kind
        }
        .accessibilityLabel(kind.accessibilityLabel)
        .accessibilityIdentifier("feed-kind-\(kind.rawValue)")
    }
}
