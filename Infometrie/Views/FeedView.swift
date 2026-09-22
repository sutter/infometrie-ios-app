import SwiftUI

struct FeedView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dynamicTypeSize) private var dynamicType
    private var playable: [FeedItem] { model.visibleItems.filter(\.hasMedia).sorted { $0.at < $1.at } }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                if model.isDemo { DemoBanner() }
                hero
                VStack(alignment: .leading, spacing: 14) {
                    adaptiveHeader {
                        Eyebrow(text: "Les dernières 24 heures")
                        if !dynamicType.isAccessibilitySize { Spacer() }
                        if model.isRefreshing { ProgressView().controlSize(.mini) }
                        else { Text("\(model.visibleItems.count) résultats").font(.caption).foregroundStyle(.secondary) }
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 9) {
                            Button {
                                model.draft = model.filters; model.tab = .search
                            } label: { Label(model.filters.isEmpty ? "Tout le panel" : model.filters.summary, systemImage: "slider.horizontal.3").lineLimit(1) }
                                .buttonStyle(.glass).accessibilityIdentifier("edit-filters")
                            kindButton("Interventions", selected: model.filters.interventions, citation: false)
                            kindButton("Citations", selected: model.filters.citations, citation: true)
                        }.font(.caption.weight(.semibold)).padding(.vertical, 3)
                    }.contentMargins(.trailing, 4)
                }
                if let error = model.feedError { ErrorNotice(message: error) { Task { await model.refresh(reset: true) } } }
                if !model.filters.hasKinds {
                    ContentUnavailableView("Aucun type sélectionné", systemImage: "line.3.horizontal.decrease", description: Text("Activez Interventions, Citations, ou les deux pour afficher le fil."))
                } else if model.isRefreshing && model.items.isEmpty {
                    ProgressView("Chargement du fil…").frame(maxWidth: .infinity).padding(.vertical, 70)
                } else if model.visibleItems.isEmpty && model.feedError == nil {
                    ContentUnavailableView {
                        Label("Aucun résultat", systemImage: "text.magnifyingglass")
                    } description: { Text("Rien pour ces critères sur les dernières 24 heures.") } actions: {
                        Button("Modifier la recherche") { model.draft = model.filters; model.tab = .search }.buttonStyle(.glass)
                    }
                } else {
                    ForEach(model.visibleItems) { item in
                        NavigationLink { SequenceView(item: item) } label: { FeedCard(item: item) }
                            .buttonStyle(.plain).accessibilityIdentifier("feed-item-\(item.id)")
                    }
                }
                if let date = model.lastRefresh {
                    HStack(spacing: 5) {
                        Circle().fill(.green).frame(width: 5, height: 5)
                        Text("Actualisé à \(date.formatted(date: .omitted, time: .shortened))")
                    }.font(.caption2).foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(.vertical, 6)
                }
            }.padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 24).frame(maxWidth: 720).frame(maxWidth: .infinity)
        }
        .background(Brand.background).navigationTitle("Le fil")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { Wordmark(size: 19) }.sharedBackgroundVisibility(.hidden)
            ToolbarItem(placement: .topBarTrailing) {
                Button { Task { await model.refresh(reset: true) } } label: { Image(systemName: "arrow.clockwise") }
                    .disabled(model.isRefreshing).accessibilityLabel("Rafraîchir le fil")
            }
        }
        .refreshable { await model.refresh(reset: true) }
    }
    @ViewBuilder private var hero: some View {
        if dynamicType.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 16) {
                Text("Votre podcast").font(.headline)
                Text("\(playable.count) séquences").font(.caption).foregroundStyle(.white.opacity(0.75))
                Button {
                    model.player.start(items: playable, app: model, podcast: true)
                } label: {
                    Label("Écouter", systemImage: "play.fill").frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass).tint(.white).disabled(playable.isEmpty)
                .accessibilityLabel("Écouter le fil en podcast").accessibilityIdentifier("start-podcast")
            }.foregroundStyle(.white).padding(23).frame(maxWidth: .infinity, alignment: .leading)
                .background(Brand.navy.gradient, in: RoundedRectangle(cornerRadius: 28))
        } else { standardHero }
    }
    private func adaptiveHeader<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        let layout = dynamicType.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout())
        return layout { content() }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private var standardHero: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 9) {
                    Text("L’ACTUALITÉ À L’ÉCOUTE").font(.system(.caption2, design: .monospaced, weight: .medium)).tracking(1.5).foregroundStyle(.white.opacity(0.62))
                    Text("Votre boussole\npolitique.").font(.system(.title, design: .rounded, weight: .semibold)).tracking(-0.5)
                }
                Spacer(minLength: 8)
                WaveformArt().frame(width: 92, height: 86).rotationEffect(.degrees(-5))
            }
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Le podcast de votre veille").font(.subheadline.weight(.medium))
                    Text("\(playable.count) séquences à écouter").font(.caption).foregroundStyle(.white.opacity(0.65))
                }
                Spacer(minLength: 8)
                Button {
                    model.player.start(items: playable, app: model, podcast: true)
                } label: { Image(systemName: "play.fill").font(.title3).frame(width: 48, height: 48) }
                    .buttonStyle(.glass).tint(.white).disabled(playable.isEmpty)
                    .accessibilityLabel("Écouter le fil en podcast").accessibilityIdentifier("start-podcast")
            }
        }.foregroundStyle(.white).padding(23)
            .background(LinearGradient(colors: [Brand.navy, Color(red: 0.16, green: 0.23, blue: 0.53)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 28))
    }
    private func kindButton(_ title: String, selected: Bool, citation: Bool) -> some View {
        Button {
            var filters = model.filters
            if citation { filters.citations.toggle() } else { filters.interventions.toggle() }
            Task { await model.apply(filters) }
        } label: {
            HStack(spacing: 5) { if selected { Image(systemName: "checkmark") }; Text(title) }
                .padding(.horizontal, 13).padding(.vertical, 10)
                .foregroundStyle(selected ? Brand.blue : .secondary)
                .background(selected ? Brand.blue.opacity(0.09) : Color.primary.opacity(0.04), in: Capsule())
        }.buttonStyle(.plain).accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}
