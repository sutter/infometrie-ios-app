import SwiftUI

struct FeedView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dynamicTypeSize) private var dynamicType
    private var playable: [FeedItem] { model.visibleItems.filter(\.hasMedia).sorted { $0.at < $1.at } }
    private var isFiltered: Bool { model.filters != SearchFilters() }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                AdaptiveRow {
                    Button { model.openSearch(model.filters) } label: {
                        Label(isFiltered ? "Filtres actifs" : "Filtrer", systemImage: "line.3.horizontal.decrease")
                    }.accessibilityIdentifier("edit-filters")
                    Button { model.player.start(items: playable, app: model, podcast: true) } label: {
                        Text("Tout écouter")
                    }.disabled(playable.isEmpty).accessibilityIdentifier("start-podcast")
                }.buttonStyle(ActionButtonStyle())
                if isFiltered {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(model.filters.isEmpty ? "Toutes les personnalités" : model.filters.summary)
                            .font(.subheadline)
                        if !model.filters.interventions || !model.filters.citations {
                            Text(model.filters.citations ? "Citations uniquement" : "Interventions uniquement")
                                .font(.subheadline).foregroundStyle(Brand.secondary)
                        }
                        Button("Tout afficher") { Task { await model.apply(SearchFilters()) } }
                            .frame(minHeight: 44).accessibilityIdentifier("clear-filters")
                    }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Brand.card, in: RoundedRectangle(cornerRadius: 16))
                }
                if model.isDemo { DemoBanner() }
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
                    AdaptiveRow {
                        Text("Les dernières 24 h").font(.subheadline.weight(.semibold))
                        if !dynamicType.isAccessibilitySize { Spacer(minLength: 0) }
                        Text(model.visibleItems.count == 1 ? "1 passage" : "\(model.visibleItems.count) passages")
                            .font(.subheadline)
                    }
                    .foregroundStyle(Brand.secondary)
                    .padding(.top, 4)
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
        .background(Brand.background).navigationTitle("Le fil")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { Wordmark(size: 19) }.sharedBackgroundVisibility(.hidden)
            ToolbarItem(placement: .topBarTrailing) {
                Button(model.isRefreshing ? "Actualisation…" : "Actualiser") { Task { await model.refresh(reset: true) } }
                    .disabled(model.isRefreshing).accessibilityLabel("Actualiser le fil")
            }
        }
        .refreshable { await model.refresh(reset: true) }
    }
}
