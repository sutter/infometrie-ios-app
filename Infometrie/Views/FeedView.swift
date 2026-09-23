import SwiftUI

struct FeedView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private var playable: [FeedItem] { model.visibleItems.filter(\.hasMedia).sorted { $0.at < $1.at } }
    private var hasAudienceFilters: Bool { !model.filters.isEmpty }
    private var usesWideLayout: Bool { horizontalSizeClass == .regular }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                if usesWideLayout {
                    feedHeading
                    filterControls
                } else {
                    FeedKindPicker()
                }
                if hasAudienceFilters {
                    VStack(alignment: .leading, spacing: 0) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Votre sélection")
                                .font(.system(.title3, design: .serif, weight: .semibold))
                                .accessibilityAddTraits(.isHeader)
                            Text(model.filters.summary)
                                .font(.body).fixedSize(horizontal: false, vertical: true)
                        }.padding(20)
                        Divider().padding(.horizontal, 20)
                        Button { Task { await model.apply(SearchFilters()) } } label: {
                            Label("Tout afficher", systemImage: "arrow.counterclockwise")
                                .font(.body.weight(.semibold)).foregroundStyle(Brand.blue)
                                .padding(.horizontal, 20).padding(.vertical, 12)
                                .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain).background(Brand.blue.opacity(0.04))
                        .accessibilityIdentifier("clear-filters")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading).background(Brand.card)
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                    .overlay { RoundedRectangle(cornerRadius: 22).strokeBorder(.primary.opacity(0.06)) }
                }
                if model.isDemo { DemoBanner() }
                if !usesWideLayout { resultsHeader }
                if let error = model.feedError { ErrorNotice(message: error) { Task { await model.refresh(reset: true) } } }
                if model.isRefreshing && model.items.isEmpty {
                    ProgressView("Chargement du fil…").frame(maxWidth: .infinity).padding(.vertical, 60)
                } else if model.visibleItems.isEmpty && model.feedError == nil {
                    ContentUnavailableView {
                        Label("Aucun passage pour le moment", systemImage: "text.magnifyingglass")
                    } description: { Text("Aucun résultat sur les dernières 24 heures avec ces critères.") } actions: {
                        Button("Modifier les filtres") { model.openSearch(model.filters) }.buttonStyle(ActionButtonStyle())
                    }
                } else {
                    ForEach(model.visibleItems) { item in
                        NavigationLink { SequenceView(item: item) } label: { FeedCard(item: item) }
                            .buttonStyle(.plain).accessibilityIdentifier("feed-item-\(item.id)")
                    }
                }
                if let date = model.lastRefresh {
                    Text("Mis à jour à \(date.formatted(date: .omitted, time: .shortened))")
                        .font(.footnote).foregroundStyle(Brand.secondary).frame(maxWidth: .infinity).padding(.vertical, 8)
                }
            }
            .padding(.horizontal, 20).padding(.top, usesWideLayout ? 24 : 8).padding(.bottom, 24)
            .frame(maxWidth: 720).frame(maxWidth: .infinity)
        }
        .scrollEdgeEffectHidden(true, for: .bottom)
        .scrollEdgeEffectStyle(.hard, for: .top)
        .background(Brand.background).navigationTitle("Le fil").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !usesWideLayout {
                ToolbarItem(placement: .topBarTrailing) {
                    filtersButton
                }.sharedBackgroundVisibility(.hidden)
            }
        }
        .refreshable { await model.refresh(reset: true) }
    }

    private var feedHeading: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 20) {
                feedTitle(horizontal: true)
                Spacer(minLength: 0)
                listenButton(horizontal: true)
            }
            VStack(alignment: .leading, spacing: 8) {
                feedTitle(horizontal: false)
                listenButton(horizontal: false)
            }
        }
        .padding(.bottom, 8)
    }

    private func feedTitle(horizontal: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Le fil")
                .font(.largeTitle.bold())
                .accessibilityAddTraits(.isHeader)
            resultCount(horizontal: horizontal)
        }
    }

    private var filterControls: some View {
        AdaptiveRow {
            FeedKindPicker()
            filtersButton
        }
        .padding(.bottom, 8)
    }

    private var filtersButton: some View {
        Button { model.openSearch(model.filters) } label: {
            Label("Filtrer", systemImage: hasAudienceFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease")
                .font(.subheadline.weight(.semibold))
                .fixedSize(horizontal: true, vertical: true)
                .padding(.horizontal, 10).frame(minHeight: 44)
                .background(usesWideLayout ? Color.clear : Brand.card, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain).foregroundStyle(Brand.blue)
        .accessibilityIdentifier("edit-filters")
        .accessibilityValue(hasAudienceFilters ? "Filtres actifs" : "")
    }

    private var resultsHeader: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                resultCount(horizontal: true)
                Spacer(minLength: 0)
                listenButton(horizontal: true)
            }
            VStack(alignment: .leading, spacing: 4) {
                resultCount(horizontal: false)
                listenButton(horizontal: false)
            }
        }
    }

    private func resultCount(horizontal: Bool) -> some View {
        HStack(spacing: 6) {
            Text("24 h").foregroundStyle(Brand.secondary).accessibilityHint("Passages des dernières 24 heures")
            Text("·").foregroundStyle(Brand.secondary).accessibilityHidden(true)
            Text(model.visibleItems.count == 1 ? "1 passage" : "\(model.visibleItems.count) passages")
                .foregroundStyle(Color.primary)
        }
        .font(.subheadline)
        .fixedSize(horizontal: horizontal, vertical: true)
    }

    private func listenButton(horizontal: Bool) -> some View {
        Button { model.player.start(items: playable, app: model, podcast: true) } label: {
            Label("Tout écouter", systemImage: "play.fill")
                .font(.subheadline.weight(.semibold))
                .fixedSize(horizontal: horizontal, vertical: true)
                .padding(.horizontal, 8).padding(.vertical, 8)
                .frame(minHeight: 48)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain).foregroundStyle(Brand.blue)
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
        var identifier: String { "feed-kind-\(rawValue)" }
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
            if dynamicType.isAccessibilitySize {
                accessibleChoices
            } else {
                ViewThatFits(in: .horizontal) {
                    nativePicker.fixedSize(horizontal: true, vertical: false)
                    accessibleChoices
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .tint(Brand.blue)
    }

    @ViewBuilder private var nativePicker: some View {
        if #available(iOS 27.0, *) {
            picker.pickerStyle(.tabs)
        } else {
            picker.pickerStyle(.segmented)
        }
    }

    private var picker: some View {
        Picker("Types de passages", selection: selection) {
            ForEach(Kind.allCases, id: \.self) { kind in
                Text(kind.title)
                    .tag(kind)
                    .accessibilityLabel(kind.accessibilityLabel)
                    .accessibilityIdentifier(kind.identifier)
            }
        }
        .controlSize(.large)
        .accessibilityIdentifier("feed-kind-picker")
    }

    /// Keep every label readable when a single row no longer fits.
    private var accessibleChoices: some View {
        VStack(spacing: 4) {
            ForEach(Kind.allCases, id: \.self) { kind in
                let selected = selection.wrappedValue == kind
                Button { selection.wrappedValue = kind } label: {
                    HStack(spacing: 12) {
                        Text(kind.title)
                            .font(.body.weight(selected ? .semibold : .regular))
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                        Image(systemName: "checkmark")
                            .opacity(selected ? 1 : 0)
                            .accessibilityHidden(true)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 10)
                    .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                    .foregroundStyle(selected ? Brand.blue : .primary)
                    .background(selected ? Brand.blue.opacity(0.08) : .clear, in: RoundedRectangle(cornerRadius: 12))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(kind.accessibilityLabel)
                .accessibilityAddTraits(selected ? .isSelected : [])
                .accessibilityIdentifier(kind.identifier)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Types de passages")
    }
}
