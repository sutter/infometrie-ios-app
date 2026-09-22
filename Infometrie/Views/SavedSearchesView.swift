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
                Picker("Recherches", selection: $archived) {
                    Text("Actives").tag(false)
                    Text("Archivées").tag(true)
                }.pickerStyle(.segmented).accessibilityIdentifier("saved-segment")
            }.listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
            if searches.isEmpty {
                ContentUnavailableView {
                    Label(archived ? "Aucune recherche archivée" : "Votre veille commence ici", systemImage: archived ? "archivebox" : "bookmark")
                } description: {
                    Text(archived ? "Archivez une recherche pour la retirer de votre liste sans la perdre." : "Enregistrez vos critères pour retrouver les prises de parole qui vous intéressent.")
                } actions: {
                    if !archived { Button("Créer une recherche") { model.newSearch() }.buttonStyle(.glassProminent) }
                }.listRowBackground(Color.clear)
            }
            ForEach(searches) { search in
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top) {
                        Image(systemName: archived ? "archivebox" : "bookmark.fill").foregroundStyle(Brand.blue)
                            .padding(10).background(Brand.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 13))
                        VStack(alignment: .leading, spacing: 5) {
                            Text(search.name).font(.headline)
                            Text(search.filters.summary).font(.caption).foregroundStyle(.secondary).lineLimit(3)
                        }
                        Spacer(minLength: 0)
                        Menu {
                            if !archived {
                                Button("Modifier les critères", systemImage: "slider.horizontal.3") { model.draft = search.filters; model.tab = .search }
                            }
                            Button(archived ? "Restaurer" : "Archiver", systemImage: archived ? "arrow.uturn.backward" : "archivebox") { model.archive(search) }
                            Button("Supprimer", systemImage: "trash", role: .destructive) { deleting = search }
                        } label: { Image(systemName: "ellipsis").padding(10).contentShape(Rectangle()) }
                            .accessibilityLabel("Actions sur \(search.name)").accessibilityIdentifier("saved-actions-\(search.name)")
                    }
                    HStack {
                        Text([search.filters.interventions ? "Interventions" : nil, search.filters.citations ? "Citations" : nil].compactMap { $0 }.joined(separator: " · "))
                            .font(.caption2).foregroundStyle(.secondary)
                        Spacer()
                        if archived {
                            Button("Restaurer") { model.archive(search) }.font(.caption.weight(.semibold))
                                .accessibilityIdentifier("restore-search-\(search.name)")
                        } else {
                            Button { Task { await model.apply(search.filters) } } label: { Label("Voir le fil", systemImage: "arrow.up.right").font(.caption.weight(.semibold)) }
                        }
                    }
                }.padding(.vertical, 7)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button("Supprimer", role: .destructive) { deleting = search }
                        Button(archived ? "Restaurer" : "Archiver") { model.archive(search) }.tint(Brand.blue)
                    }
            }
            if !searches.isEmpty {
                Section { Text("Vos recherches restent sur cet appareil et sont séparées pour chaque compte.").font(.caption).foregroundStyle(.secondary) }.listRowBackground(Color.clear)
            }
        }
        .navigationTitle("Mes recherches")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Nouvelle recherche", systemImage: "plus") { model.newSearch() }.accessibilityIdentifier("new-search") } }
        .alert("Supprimer cette recherche ?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
            Button("Annuler", role: .cancel) { deleting = nil }
            Button("Supprimer", role: .destructive) { if let deleting { model.delete(deleting) }; deleting = nil }
        } message: { Text("« \(deleting?.name ?? "") » disparaîtra de cet appareil. Cette action est définitive.") }
    }
}
