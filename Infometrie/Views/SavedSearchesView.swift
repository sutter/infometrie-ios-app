import SwiftUI

struct SavedSearchesView: View {
    @Environment(AppModel.self) private var model
    @State private var archived = false
    @State private var deleting: SavedSearch?
    private var searches: [SavedSearch] {
        model.savedSearches.filter { $0.isArchived == archived }
            .sorted { ($0.lastUsedAt ?? $0.createdAt) > ($1.lastUsedAt ?? $1.createdAt) }
    }
    var body: some View {
        List {
            Section {
                AdaptiveRow {
                    category("Actifs", archived: false)
                    category("Archivés", archived: true)
                }
                Button { model.newSearch() } label: { Label("Créer un suivi", systemImage: "plus") }
                    .buttonStyle(ActionButtonStyle(prominent: true)).accessibilityIdentifier("new-search")
            }.listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0)).listRowBackground(Color.clear).listRowSeparator(.hidden)
            if searches.isEmpty {
                ContentUnavailableView {
                    Label(archived ? "Aucun suivi archivé" : "Retrouvez vos sujets de veille", systemImage: archived ? "archivebox" : "bookmark")
                } description: {
                    Text(archived ? "Un suivi archivé peut être restauré à tout moment." : "Choisissez des personnalités ou des partis, puis enregistrez vos filtres pour les retrouver ici.")
                }.listRowBackground(Color.clear)
            }
            ForEach(searches) { search in
                VStack(alignment: .leading, spacing: 16) {
                    Text(search.name).font(.title3.bold())
                    Text(search.filters.isEmpty ? "Toutes les personnalités" : search.filters.summary).font(.subheadline).foregroundStyle(Brand.secondary)
                    Text([search.filters.interventions ? "Interventions" : nil, search.filters.citations ? "Citations" : nil].compactMap { $0 }.joined(separator: " · "))
                        .font(.subheadline).foregroundStyle(Brand.secondary)
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
                    } label: { Label("Options", systemImage: "ellipsis.circle").frame(minHeight: 44) }
                        .accessibilityLabel("Options de \(search.name)").accessibilityIdentifier("saved-actions-\(search.name)")
                }.padding(.vertical, 12)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button("Supprimer", role: .destructive) { deleting = search }
                        Button(archived ? "Restaurer" : "Archiver") { model.archive(search) }.tint(Brand.blue)
                    }
            }
            if !searches.isEmpty {
                Section { Text("Vos suivis sont enregistrés sur cet appareil, pour votre compte.").font(.footnote).foregroundStyle(Brand.secondary) }.listRowBackground(Color.clear)
            }
        }
        .navigationTitle("Mes suivis")
        .alert("Supprimer ce suivi ?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
            Button("Annuler", role: .cancel) { deleting = nil }
            Button("Supprimer", role: .destructive) { if let deleting { model.delete(deleting) }; deleting = nil }
        } message: { Text("« \(deleting?.name ?? "") » disparaîtra de cet appareil. Cette action est définitive.") }
    }
    private func category(_ title: String, archived value: Bool) -> some View {
        Button { archived = value } label: {
            HStack { if archived == value { Image(systemName: "checkmark") }; Text(title) }
        }.buttonStyle(ActionButtonStyle(prominent: archived == value))
            .accessibilityAddTraits(archived == value ? .isSelected : [])
            .accessibilityIdentifier(value ? "saved-archived" : "saved-active")
    }
}
