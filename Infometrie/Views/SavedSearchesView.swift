import SwiftUI

struct SavedSearchesView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.horizontalSizeClass) private var sizeClass
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
                    Button { model.newSearch() } label: { Label("Créer un suivi", systemImage: "plus") }
                        .buttonStyle(ActionButtonStyle(prominent: true)).accessibilityIdentifier("new-search")
                    HStack(spacing: 12) {
                        category("Actifs", archived: false)
                        category("Archivés", archived: true)
                        Spacer(minLength: 0)
                    }.overlay(alignment: .bottom) { AppRule() }
                }.padding(.top, 16).padding(.bottom, 8)
                if searches.isEmpty {
                    AppEmptyState(
                        title: archived ? "Aucun suivi archivé" : "Retrouvez vos sujets de veille",
                        icon: archived ? "archivebox" : "bookmark",
                        message: archived ? "Un suivi archivé peut être restauré à tout moment." : "Choisissez des personnalités ou des partis, puis enregistrez vos filtres pour les retrouver ici."
                    )
                }
                ForEach(searches) { search in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(search.name).font(.headline)
                            .fixedSize(horizontal: false, vertical: true).accessibilityAddTraits(.isHeader)
                        Text(search.filters.isEmpty ? "Toutes les personnalités" : search.filters.summary)
                            .font(.subheadline).foregroundStyle(Brand.secondary)
                        Text(search.filters.kindSummary)
                            .font(.subheadline).foregroundStyle(Brand.secondary)
                        AdaptiveRow {
                            if archived {
                                Button("Restaurer ce suivi") { model.archive(search) }
                                    .buttonStyle(ActionButtonStyle()).accessibilityIdentifier("restore-search-\(search.name)")
                            } else {
                                Button { Task { await model.apply(search.filters) } } label: { Label("Afficher le fil", systemImage: "text.alignleft") }
                                    .buttonStyle(ActionButtonStyle())
                            }
                            Menu {
                                if !archived {
                                    Button("Ajuster les filtres", systemImage: "slider.horizontal.3") { model.openSearch(search.filters) }
                                }
                                Button(archived ? "Restaurer" : "Archiver", systemImage: archived ? "arrow.uturn.backward" : "archivebox") { model.archive(search) }
                                Button("Supprimer", systemImage: "trash", role: .destructive) { deleting = search }
                            } label: {
                                Label("Options", systemImage: "ellipsis").font(.subheadline.weight(.medium))
                                    .fixedSize(horizontal: false, vertical: true).padding(.horizontal, 8).frame(minHeight: 52)
                            }.accessibilityLabel("Options de \(search.name)").accessibilityIdentifier("saved-actions-\(search.name)")
                        }
                        AppRule().padding(.top, 8)
                    }.padding(.top, 16)
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
            .listRowInsets(EdgeInsets(top: 0, leading: sizeClass == .regular ? AppLayout.wideMargin : 20, bottom: 0, trailing: sizeClass == .regular ? AppLayout.wideMargin : 20))
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
                ToolbarItem(placement: .topBarLeading) { Wordmark(size: 21) }
                    .sharedBackgroundVisibility(.hidden)
            }
        }
        .alert("Supprimer ce suivi ?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
            Button("Annuler", role: .cancel) { deleting = nil }
            Button("Supprimer", role: .destructive) { if let deleting { model.delete(deleting) }; deleting = nil }
        } message: { Text("« \(deleting?.name ?? "") » disparaîtra de cet appareil. Cette action est définitive.") }
    }
    private func category(_ title: String, archived value: Bool) -> some View {
        AppTabButton(title: title, selected: archived == value, accent: Brand.primary) { archived = value }
            .accessibilityIdentifier(value ? "saved-archived" : "saved-active")
    }
}
