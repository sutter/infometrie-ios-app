import SwiftUI

struct FeedView: View {
    @Environment(AppModel.self) private var model
    private var playable: [FeedItem] { model.visibleItems.filter(\.hasMedia).sorted { $0.at < $1.at } }
    private var hasAudienceFilters: Bool { !model.filters.isEmpty }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                FeedKindPicker()
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
                resultsHeader
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
            }.padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 24).frame(maxWidth: 720).frame(maxWidth: .infinity)
        }
        .scrollEdgeEffectHidden(true, for: .bottom)
        .scrollEdgeEffectStyle(.hard, for: .top)
        .background(Brand.background).navigationTitle("Le fil").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { model.openSearch(model.filters) } label: {
                    HStack(spacing: 6) {
                        Image(systemName: hasAudienceFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease")
                        Text("Filtrer")
                    }
                    .font(.subheadline.weight(.semibold))
                    .fixedSize(horizontal: true, vertical: true)
                    .padding(.horizontal, 10).frame(minHeight: 44)
                    .background(Brand.card, in: Capsule())
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain).foregroundStyle(Brand.blue)
                .accessibilityIdentifier("edit-filters")
                .accessibilityValue(hasAudienceFilters ? "Filtres actifs" : "")
            }.sharedBackgroundVisibility(.hidden)
        }
        .refreshable { await model.refresh(reset: true) }
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

    var body: some View {
        Group {
            if dynamicType.isAccessibilitySize {
                VStack(spacing: 4) { choices(horizontal: false) }
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 4) { choices(horizontal: true) }
                    VStack(spacing: 4) { choices(horizontal: false) }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Types de passages")
    }

    @ViewBuilder private func choices(horizontal: Bool) -> some View {
        choice("Tous", id: 0, interventions: true, citations: true, accent: .primary, horizontal: horizontal)
        choice("Interventions", id: 1, interventions: true, citations: false, accent: Brand.blue, horizontal: horizontal)
        choice("Citations", id: 2, interventions: false, citations: true, accent: Brand.citation, horizontal: horizontal)
    }

    private func choice(_ title: String, id: Int, interventions: Bool, citations: Bool, accent: Color, horizontal: Bool) -> some View {
        let selected = model.filters.interventions == interventions && model.filters.citations == citations
        return Button {
            guard !selected else { return }
            var filters = model.filters
            filters.interventions = interventions
            filters.citations = citations
            Task { await model.apply(filters) }
        } label: {
            Text(title)
                .font(.subheadline.weight(selected ? .semibold : .medium))
                .fixedSize(horizontal: horizontal, vertical: true)
                .padding(.horizontal, 8).padding(.vertical, 10)
                .frame(maxWidth: .infinity, minHeight: 48)
                .foregroundStyle(selected ? accent : Brand.secondary)
                .overlay(alignment: .bottom) {
                    if selected { Capsule().fill(accent).frame(height: 3).padding(.horizontal, 8) }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(id == 0 ? "Tous les passages" : title)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("feed-kind-\(id)")
    }
}
