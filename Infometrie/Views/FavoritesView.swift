import SwiftUI

/// The passages the reader kept, the last added first. They live on the device; one gone from the server's history
/// stays, greyed and marked "Plus disponible".
struct FavoritesView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var opened: FeedItem?
    @State private var removing: Favorite?
    var body: some View {
        Group {
            if model.favorites.isEmpty { emptyPage } else { list }
        }
        .navigationTitle("").navigationBarTitleDisplayMode(.inline)
        .toolbar(sizeClass == .regular ? .hidden : .visible, for: .navigationBar)
        .toolbarBackground(Brand.background, for: .navigationBar)
        .toolbar {
            if sizeClass != .regular {
                ToolbarItem(placement: .topBarLeading) { Wordmark(size: 21, scheme: colorScheme) }
                    .sharedBackgroundVisibility(.hidden)
            }
        }
        // A button rather than a link: in a List, a link draws a chevron the journal's rows do not have.
        .navigationDestination(item: $opened) { item in
            SequenceView(item: item, list: model.favorites.map(\.item))
        }
        .confirmationDialog("Retirer ce favori ?", isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } }),
                            titleVisibility: .visible, presenting: removing) { favorite in
            Button("Retirer des favoris", role: .destructive) { model.removeFavorite(favorite); removing = nil }
            Button("Annuler", role: .cancel) { removing = nil }
        } message: { _ in
            // Short: at the largest text sizes the system dialog cut a longer message (iPhone 13 mini, 2026-10-12).
            Text("Il ne pourra plus être ajouté.")
        }
    }

    private var heading: some View {
        let count = model.favorites.count
        return PageHeading(title: "Favoris", subtitle: count == 0 ? nil
                           : "\(count) \(count == 1 ? "passage" : "passages"), les derniers ajoutés en premier")
            .padding(.top, 16).padding(.bottom, 16)
    }

    private var list: some View {
        PageList {
            heading
            ForEach(model.favorites) { favorite in row(favorite) }
        }
        // Rows scroll under the glass tab bar: soften them there, like the journal.
        .scrollEdgeEffectStyle(.soft, for: .bottom)
    }

    private func row(_ favorite: Favorite) -> some View {
        let unavailable = favorite.isUnavailable()
        return Button { opened = favorite.item } label: {
            // Every row is a favorite here: no star.
            FeedCard(item: favorite.item, seen: model.isSeen(favorite.item), unavailable: unavailable)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("favorite-item-\(favorite.id)")
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button("Retirer", role: .destructive) { remove(favorite) }
        }
        .contextMenu {
            Button("Retirer des favoris", systemImage: "star.slash", role: .destructive) { remove(favorite) }
        }
        .accessibilityAction(named: "Retirer des favoris") { remove(favorite) }
    }

    /// An available passage can be added again from the journal; one gone from the history cannot, so it asks first.
    private func remove(_ favorite: Favorite) {
        if favorite.isUnavailable() { removing = favorite } else { model.removeFavorite(favorite) }
    }

    /// No favorite: the empty state stands a little above the middle of the free height, like Mes suivis'.
    private var emptyPage: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    heading
                    Spacer(minLength: 24)
                    FavoritesEmptyState()
                    // Two spacers below for one above: the group sits a little above the middle.
                    Spacer(minLength: 24)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, sizeClass == .regular ? AppLayout.wideMargin : AppLayout.margin)
                .frame(minHeight: proxy.size.height)
                .frame(maxWidth: AppLayout.readingWidth).frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .background(Brand.background)
    }
}

private struct FavoritesEmptyState: View {
    @ScaledMetric(relativeTo: .largeTitle) private var starSize = 48.0
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "star").font(.system(size: starSize)).foregroundStyle(Brand.accent).accessibilityHidden(true)
            VStack(spacing: 8) {
                Text("Aucun favori pour l’instant")
                    .font(.title3.weight(.bold)).foregroundStyle(Brand.ink)
                    .accessibilityAddTraits(.isHeader)
                Text("Touchez \(Image(systemName: "star")) en haut d’un passage, ou restez appuyé sur une ligne du journal, pour le retrouver ici.")
                    .font(.body).foregroundStyle(Brand.secondary)
                    .accessibilityLabel("Touchez l’étoile en haut d’un passage, ou restez appuyé sur une ligne du journal, pour le retrouver ici.")
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("favorites-empty")
    }
}
