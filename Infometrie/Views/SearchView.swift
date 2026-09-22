import SwiftUI

struct SearchView: View {
    @Environment(AppModel.self) private var model
    @State private var showSave = false
    @State private var name = ""

    var body: some View {
        @Bindable var model = model
        Form {
            if model.isDemo { Section { DemoBanner().listRowInsets(EdgeInsets()) }.listRowBackground(Color.clear) }
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: "scope").font(.largeTitle).foregroundStyle(Brand.blue).padding(.bottom, 4)
                    Text("Une veille qui vous ressemble.").font(.title2.weight(.bold))
                    Text("Choisissez les voix et les sujets politiques que vous souhaitez suivre.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }.padding(.vertical, 12)
            }.listRowBackground(Color.clear).listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 10, trailing: 0))

            Section("Types de passage") {
                Toggle(isOn: $model.draft.interventions) { Label("Interventions", systemImage: "waveform") }
                    .accessibilityIdentifier("filter-interventions")
                Toggle(isOn: $model.draft.citations) { Label("Citations", systemImage: "quote.bubble") }
                    .accessibilityIdentifier("filter-citations")
            }
            Section {
                NavigationLink {
                    ChoicePicker(title: "Personnalités", choices: model.persons.map { .init(value: $0.name, title: $0.name, subtitle: [$0.party, $0.role].filter { !$0.isEmpty }.joined(separator: " · ")) }, selected: $model.draft.persons)
                } label: {
                    selectionRow("Personnalités", symbol: "person.2", selections: model.draft.persons)
                }.accessibilityIdentifier("pick-persons")
            } footer: { Text("Le fil garde les interventions et citations de ces personnalités.") }
            Section {
                NavigationLink {
                    ChoicePicker(title: "Partis politiques", choices: model.parties.map { .init(value: $0.code, title: $0.name, subtitle: $0.code) }, selected: $model.draft.parties)
                } label: {
                    selectionRow("Partis politiques", symbol: "building.columns", selections: model.draft.parties)
                }.accessibilityIdentifier("pick-parties")
            } footer: {
                Text(model.draft.persons.isEmpty || model.draft.parties.isEmpty
                     ? "Sans personnalité ni parti, le fil couvre tout le panel InfoMétrie."
                     : "Avec les deux listes, seules les personnalités choisies appartenant aux partis sélectionnés sont conservées.")
            }
            if let error = model.choicesError {
                Section { ErrorNotice(message: error) { Task { await model.loadChoices() } }.listRowInsets(EdgeInsets()) }
                    .listRowBackground(Color.clear)
            }
            Section {
                Button { Task { await model.apply(model.draft) } } label: {
                    Label("Voir les résultats", systemImage: "arrow.right").fontWeight(.semibold).frame(maxWidth: .infinity).padding(.vertical, 9)
                }.buttonStyle(.glassProminent).disabled(!model.draft.hasKinds).accessibilityIdentifier("apply-search")
                Button { name = ""; showSave = true } label: {
                    Label("Sauvegarder ma recherche", systemImage: "bookmark").frame(maxWidth: .infinity).padding(.vertical, 7)
                }.buttonStyle(.glass).disabled(!model.draft.hasKinds).accessibilityIdentifier("save-search")
                if !model.draft.hasKinds { Text("Sélectionnez au moins un type de passage.").font(.caption).foregroundStyle(.secondary) }
            }.listRowBackground(Color.clear).listRowSeparator(.hidden).listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
        }
        .navigationTitle("Explorer")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Effacer", systemImage: "arrow.counterclockwise") { model.draft = SearchFilters() } } }
        .sheet(isPresented: $showSave) {
            NavigationStack {
                Form {
                    Section {
                        TextField("Ex. Ma veille politique", text: $name).accessibilityIdentifier("search-name")
                        Text(model.draft.summary).font(.subheadline).foregroundStyle(.secondary)
                    } header: { Text("Nom de la recherche") } footer: { Text("Retrouvez ce fil en un geste dans vos recherches. Il reste enregistré sur cet appareil.") }
                }
                .navigationTitle("Enregistrer la recherche").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Annuler") { showSave = false } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Enregistrer") { model.saveSearch(name: name); showSave = false; model.tab = .saved }
                            .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .accessibilityIdentifier("confirm-save-search")
                    }
                }
            }.presentationDetents([.medium]).presentationDragIndicator(.visible)
        }
    }
    private func selectionRow(_ title: String, symbol: String, selections: Set<String>) -> some View {
        HStack(spacing: 13) {
            Image(systemName: symbol).foregroundStyle(Brand.blue).frame(width: 25)
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                Text(selections.isEmpty ? "Tout le panel" : selections.sorted().joined(separator: ", "))
                    .font(.caption).foregroundStyle(.secondary).lineLimit(3)
            }
            Spacer()
            if !selections.isEmpty { Text("\(selections.count)").font(.caption.weight(.semibold)).foregroundStyle(Brand.blue) }
        }.padding(.vertical, 5)
    }
}

struct ChoicePicker: View {
    struct Choice: Identifiable {
        var id: String { value }
        let value: String
        let title: String
        let subtitle: String
    }
    @Environment(AppModel.self) private var model
    let title: String
    let choices: [Choice]
    @Binding var selected: Set<String>
    @State private var query = ""
    private var filtered: [Choice] {
        choices.filter { query.isEmpty || "\($0.title) \($0.subtitle)".localizedStandardContains(query) }
            .sorted { $0.title.localizedCompare($1.title) == .orderedAscending }
    }
    var body: some View {
        List {
            if choices.isEmpty {
                ContentUnavailableView {
                    Label("Liste indisponible", systemImage: "person.crop.circle.badge.questionmark")
                } description: { Text(model.choicesError ?? "Le référentiel ne contient aucun élément.") } actions: {
                    Button("Réessayer") { Task { await model.loadChoices() } }
                }
            } else if filtered.isEmpty {
                ContentUnavailableView.search(text: query)
            }
            ForEach(filtered) { choice in
                Button {
                    if selected.contains(choice.value) { selected.remove(choice.value) } else { selected.insert(choice.value) }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(choice.title).foregroundStyle(.primary)
                            if !choice.subtitle.isEmpty { Text(choice.subtitle).font(.caption).foregroundStyle(.secondary) }
                        }
                        Spacer()
                        Image(systemName: selected.contains(choice.value) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(selected.contains(choice.value) ? Brand.blue : .secondary.opacity(0.4)).font(.title3)
                    }.padding(.vertical, 5)
                }.accessibilityAddTraits(selected.contains(choice.value) ? .isSelected : [])
                    .accessibilityIdentifier("choice-\(choice.value)")
            }
        }
        .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, prompt: "Nom, prénom ou parti")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Tout effacer") { selected.removeAll() }.disabled(selected.isEmpty) } }
    }
}
