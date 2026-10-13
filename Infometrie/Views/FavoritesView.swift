import SwiftUI

/// The passages the reader kept, the last added first, then those gone from the server's history ("Plus
/// disponibles"), greyed, which no longer open. They live on the device. "Sélectionner" removes several at once and
/// "Tout retirer" clears the ones gone from the history (option B of sheet 08, 2026-10-13); every removal here offers
/// "Annuler" for a few seconds.
struct FavoritesView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.dynamicTypeSize) private var dynamicType
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var opened: FeedItem?
    /// A removal waiting for its answer: it includes a favorite gone from the history, which the journal cannot give
    /// back once "Annuler" is gone.
    @State private var confirming: Set<Int64>?
    @State private var isSelecting = false
    @State private var selection: Set<Int64> = []
    /// The last removal, for "Annuler", until it times out or another one replaces it.
    @State private var undo: Undo?

    private struct Undo: Identifiable {
        let id = UUID()
        let removed: RemovedFavorites
    }

    private var available: [Favorite] { model.favorites.filter { !$0.isUnavailable() } }
    private var unavailable: [Favorite] { model.favorites.filter { $0.isUnavailable() } }
    private var allSelected: Bool { !model.favorites.isEmpty && model.favorites.allSatisfy { selection.contains($0.id) } }
    private var margin: CGFloat { sizeClass == .regular ? AppLayout.wideMargin : AppLayout.margin }
    private var motion: Animation? { reduceMotion ? nil : Motion.standard }

    var body: some View {
        Group {
            if model.favorites.isEmpty { emptyPage } else { list }
        }
        .navigationTitle("").navigationBarTitleDisplayMode(.inline)
        .toolbar(sizeClass == .regular ? .hidden : .visible, for: .navigationBar)
        .toolbarBackground(Brand.background, for: .navigationBar)
        .toolbar {
            if sizeClass != .regular {
                if isSelecting {
                    ToolbarItem(placement: .topBarLeading) { cancelButton(scheme: colorScheme) }
                        .sharedBackgroundVisibility(.hidden)
                    ToolbarItem(placement: .topBarTrailing) { selectAllButton(scheme: colorScheme) }
                        .sharedBackgroundVisibility(.hidden)
                } else {
                    ToolbarItem(placement: .topBarLeading) { Wordmark(size: 21, scheme: colorScheme) }
                        .sharedBackgroundVisibility(.hidden)
                    if !model.favorites.isEmpty {
                        ToolbarItem(placement: .topBarTrailing) { selectButton(scheme: colorScheme) }
                            .sharedBackgroundVisibility(.hidden)
                    }
                }
            }
        }
        // While selecting, the removal button takes the tab bar's place.
        .toolbar(isSelecting ? .hidden : .automatic, for: .tabBar)
        .safeAreaInset(edge: .bottom, spacing: 0) { if isSelecting { removeBar } }
        .overlay(alignment: .bottom) { if let undo { banner(undo) } }
        // A button rather than a link: in a List, a link draws a chevron the journal's rows do not have.
        .navigationDestination(item: $opened) { item in
            SequenceView(item: item, list: (available + unavailable).map(\.item))
        }
        .confirmationDialog(confirmationTitle, isPresented: Binding(get: { confirming != nil }, set: { if !$0 { confirming = nil } }),
                            titleVisibility: .visible, presenting: confirming) { ids in
            // The title gives the count: "Retirer 2 favoris" broke into "favo- / ris" at the largest sizes (2026-10-13).
            Button("Retirer des favoris", role: .destructive) {
                remove(ids); confirming = nil
            }
            Button("Annuler", role: .cancel) { confirming = nil }
        } message: { ids in
            // Short: at the largest text sizes the system dialog cut a longer message (iPhone 13 mini, 2026-10-12).
            Text(confirmationMessage(ids))
        }
        // "Annuler" stays a few seconds, then the removal holds.
        .task(id: undo?.id) {
            guard undo != nil else { return }
            try? await Task.sleep(for: .seconds(6))
            guard !Task.isCancelled else { return }
            withAnimation(motion) { undo = nil }
        }
        .onChange(of: model.favorites.isEmpty) { _, empty in
            if empty { isSelecting = false; selection = [] }
        }
        .sensoryFeedback(.selection, trigger: selection)
    }

    private var heading: some View {
        AdaptiveRow {
            PageHeading(title: "Favoris", subtitle: subtitle)
            // On iPad the page has no navigation bar: the selection controls sit beside the title instead.
            if sizeClass == .regular && !model.favorites.isEmpty {
                if isSelecting {
                    cancelButton()
                    selectAllButton()
                } else {
                    selectButton()
                }
            }
        }
        .padding(.top, 16).padding(.bottom, 16)
    }

    private var subtitle: String? {
        let count = model.favorites.count
        guard count > 0 else { return nil }
        guard isSelecting else { return "\(count) \(count == 1 ? "passage" : "passages"), les derniers ajoutés en premier" }
        let selected = selection.count
        return selected == 0 ? "Touchez les favoris à retirer" : "\(selected) \(selected == 1 ? "sélectionné" : "sélectionnés")"
    }

    private var list: some View {
        PageList {
            heading
            ForEach(available) { row($0) }
            if !unavailable.isEmpty {
                unavailableHeader
                ForEach(unavailable) { row($0) }
            }
        }
        // Rows scroll under the glass tab bar: soften them there, like the journal.
        .scrollEdgeEffectStyle(.soft, for: .bottom)
    }

    /// The favorites gone from the history, after the others: they no longer open, and "Tout retirer" clears them.
    private var unavailableHeader: some View {
        AdaptiveRow {
            SectionLabel(title: "Plus disponibles")
            if !dynamicType.isAccessibilitySize { Spacer(minLength: 12) }
            if !isSelecting {
                Button("Tout retirer") { confirming = Set(unavailable.map(\.id)) }
                    .font(.subheadline.weight(.semibold)).foregroundStyle(Brand.interventionLabel)
                    .buttonStyle(.plain)
                    .frame(minHeight: 44).contentShape(Rectangle())
                    .accessibilityLabel("Retirer tous les favoris plus disponibles")
                    .accessibilityIdentifier("remove-unavailable-favorites")
            }
        }
        .padding(.top, 24)
    }

    @ViewBuilder private func row(_ favorite: Favorite) -> some View {
        let unavailable = favorite.isUnavailable()
        // Every row is a favorite here: no star.
        let card = FeedCard(item: favorite.item, seen: model.isSeen(favorite.item), unavailable: unavailable)
        if isSelecting {
            let selected = selection.contains(favorite.id)
            Button { toggle(favorite.id) } label: {
                // At accessibility sizes a row can outgrow the screen: the box sits by its top, where the reader looks.
                HStack(alignment: dynamicType.isAccessibilitySize ? .top : .center, spacing: 12) {
                    card
                    ChoiceMark(selected: selected, multiple: true)
                        .padding(.top, dynamicType.isAccessibilitySize ? 16 : 0)
                }
                .overlay(alignment: .bottom) { AppRule() }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(selected ? .isSelected : [])
            .accessibilityHint(selected ? "Retire ce favori de la sélection" : "Ajoute ce favori à la sélection")
            .accessibilityIdentifier("favorite-item-\(favorite.id)")
        } else {
            Button { opened = favorite.item } label: { card.contentShape(Rectangle()) }
                .buttonStyle(.plain)
                .accessibilityIdentifier("favorite-item-\(favorite.id)")
                // One full swipe removes, either way: to the right like the journal's star swipe, to the left like
                // any list. A favorite gone from the history asks first, so its button keeps the row until the answer.
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    Button("Retirer", systemImage: "star.slash.fill") { remove(favorite) }.tint(Brand.interventionFill)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button("Retirer", role: unavailable ? nil : .destructive) { remove(favorite) }.tint(Brand.destructive)
                }
                .contextMenu {
                    Button("Retirer des favoris", systemImage: "star.slash", role: .destructive) { remove(favorite) }
                }
                .accessibilityAction(named: "Retirer des favoris") { remove(favorite) }
        }
    }

    // MARK: Selection

    /// Navigation-bar items take colors fixed by the page: the bar may not follow a theme change (`Brand.fixed`).
    private func barButton(_ title: String, identifier: String, scheme: ColorScheme?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            // One line at its full width: the bar squeezed "Annuler" into "An / nu / ler" (2026-10-13).
            Text(title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1).fixedSize()
                .padding(.horizontal, 8).frame(minHeight: 48)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain).foregroundStyle(Brand.fixed(Brand.tint, for: scheme))
        .accessibilityIdentifier(identifier)
    }

    private func selectButton(scheme: ColorScheme? = nil) -> some View {
        barButton("Sélectionner", identifier: "select-favorites", scheme: scheme) {
            selection = []
            withAnimation(motion) { isSelecting = true; undo = nil }
        }
    }

    private func cancelButton(scheme: ColorScheme? = nil) -> some View {
        barButton("Annuler", identifier: "cancel-selection", scheme: scheme) {
            withAnimation(motion) { isSelecting = false }
            selection = []
        }
    }

    private func selectAllButton(scheme: ColorScheme? = nil) -> some View {
        barButton(allSelected ? "Tout désélectionner" : "Tout sélectionner", identifier: "select-all-favorites", scheme: scheme) {
            selection = allSelected ? [] : Set(model.favorites.map(\.id))
        }
    }

    private func toggle(_ id: Int64) {
        if selection.contains(id) { selection.remove(id) } else { selection.insert(id) }
    }

    /// One prominent button where the tab bar was, with what it removes: large and explicit for this audience.
    private var removeBar: some View {
        let count = selection.count
        return Button { request(selection) } label: {
            Text(count == 0 ? "Retirer" : "Retirer \(count) \(count == 1 ? "favori" : "favoris")")
        }
        .buttonStyle(ActionButtonStyle(prominent: true))
        .disabled(count == 0)
        .accessibilityIdentifier("remove-selected-favorites")
        .padding(.horizontal, margin).padding(.top, 12)
        .modifier(PassageBottomBar())
    }

    // MARK: Removal

    /// An available passage can be added again from the journal; one gone from the history cannot, so it asks first.
    private func remove(_ favorite: Favorite) { request([favorite.id]) }

    private func request(_ ids: Set<Int64>) {
        guard !ids.isEmpty else { return }
        if model.favorites.contains(where: { ids.contains($0.id) && $0.isUnavailable() }) { confirming = ids } else { remove(ids) }
    }

    private func remove(_ ids: Set<Int64>) {
        let removed = model.removeFavorites(ids)
        guard removed.count > 0 else { return }
        selection = []
        withAnimation(motion) { isSelecting = false; undo = Undo(removed: removed) }
    }

    private var confirmationTitle: String {
        let count = confirming?.count ?? 0
        return count == 1 ? "Retirer ce favori ?" : "Retirer ces \(count) favoris ?"
    }

    private func confirmationMessage(_ ids: Set<Int64>) -> String {
        let gone = model.favorites.filter { ids.contains($0.id) && $0.isUnavailable() }.count
        if ids.count == 1 { return "Il ne pourra plus être ajouté." }
        return gone == ids.count ? "Ils ne pourront plus être ajoutés." : "Certains ne pourront plus être ajoutés."
    }

    /// Above the tab bar, a few seconds after each removal here: an accidental full swipe costs nothing.
    private func banner(_ undo: Undo) -> some View {
        let count = undo.removed.count
        // Stacked at accessibility sizes: side by side, "Annuler" broke into "An- / nuler" (2026-10-13).
        let layout = dynamicType.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(spacing: 12))
        return layout {
            Text(count == 1 ? "Favori retiré" : "\(count) favoris retirés")
                .foregroundStyle(Brand.primaryForeground)
                .fixedSize(horizontal: false, vertical: true)
            if !dynamicType.isAccessibilitySize { Spacer(minLength: 8) }
            Button("Annuler") {
                model.restoreFavorites(undo.removed)
                withAnimation(motion) { self.undo = nil }
            }
            .fontWeight(.bold).foregroundStyle(Brand.inverseAccent)
            .lineLimit(1).fixedSize()
            .buttonStyle(.plain)
            .frame(minHeight: 44).contentShape(Rectangle())
            .accessibilityLabel(count == 1 ? "Annuler le retrait" : "Annuler le retrait des \(count) favoris")
            .accessibilityIdentifier("undo-remove-favorites")
        }
        .font(.subheadline)
        .padding(.horizontal, 20).padding(.vertical, dynamicType.isAccessibilitySize ? 12 : 4)
        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
        .background(Brand.primary, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .padding(.horizontal, margin).padding(.bottom, 12)
        .frame(maxWidth: AppLayout.readingWidth)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("favorites-undo")
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
