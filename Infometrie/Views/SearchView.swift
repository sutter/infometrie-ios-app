import SwiftUI

struct SearchView: View {
    @Environment(AppModel.self) private var model
    @State private var showSave = false
    @State private var name = ""
    @State private var saved = false
    private var kind: Binding<Int> {
        Binding(get: { model.draft.interventions && model.draft.citations ? 0 : model.draft.interventions ? 1 : 2 }, set: {
            model.draft.interventions = $0 != 2
            model.draft.citations = $0 != 1
        })
    }

    var body: some View {
        @Bindable var model = model
        Form {
            Section {
                NavigationLink {
                    ChoicePicker(title: "Personnalités", choices: model.persons.map { .init(value: $0.name, title: $0.name, subtitle: [$0.party, $0.role].filter { !$0.isEmpty }.joined(separator: " · ")) }, selected: $model.draft.persons)
                } label: {
                    selectionRow("Personnalités", symbol: "person.2", selections: model.draft.persons)
                }.accessibilityIdentifier("pick-persons")
                NavigationLink {
                    ChoicePicker(title: "Partis politiques", choices: model.parties.map { .init(value: $0.code, title: $0.name, subtitle: $0.code) }, selected: $model.draft.parties)
                } label: {
                    selectionRow("Partis politiques", symbol: "building.columns", selections: model.draft.parties)
                }.accessibilityIdentifier("pick-parties")
            } header: { Text("Qui souhaitez-vous suivre ?") } footer: {
                Text(model.draft.persons.isEmpty && model.draft.parties.isEmpty
                     ? "Sans sélection, toutes les personnalités sont affichées."
                     : !model.draft.persons.isEmpty && !model.draft.parties.isEmpty
                         ? "Seules les personnalités choisies appartenant aux partis sélectionnés seront affichées."
                         : "Le fil affichera les passages correspondant à votre sélection.")
            }
            Section("Quels passages ?") {
                ForEach(Array(["Tous les passages", "Interventions uniquement", "Citations uniquement"].enumerated()), id: \.offset) { index, title in
                    Button { kind.wrappedValue = index } label: {
                        HStack {
                            Text(title).foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: kind.wrappedValue == index ? "checkmark.circle.fill" : "circle").foregroundStyle(Brand.blue)
                        }.frame(minHeight: 44).contentShape(Rectangle())
                    }.accessibilityAddTraits(kind.wrappedValue == index ? .isSelected : [])
                        .accessibilityIdentifier("filter-kind-\(index)")
                }
            }
            if let error = model.choicesError {
                Section { ErrorNotice(message: error) { Task { await model.loadChoices() } } }
            }
            Section {
                Button { name = ""; showSave = true } label: {
                    Label("Enregistrer ce suivi", systemImage: "bookmark")
                }.frame(minHeight: 44).accessibilityIdentifier("save-search")
                Button("Réinitialiser les filtres") { model.draft = SearchFilters() }
                    .frame(minHeight: 44).accessibilityIdentifier("reset-search")
            } footer: { Text("Un suivi enregistré se retrouve dans « Mes suivis ».") }
        }
        .navigationTitle("Filtrer le fil").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Annuler") { model.isSearchPresented = false } }
        }
        .safeAreaInset(edge: .bottom) {
            Button { Task { await model.apply(model.draft) } } label: { Text("Afficher les résultats") }
                .buttonStyle(ActionButtonStyle(prominent: true)).accessibilityIdentifier("apply-search")
                .padding(16).background(Brand.background)
        }
        .sheet(isPresented: $showSave, onDismiss: {
            if saved { model.isSearchPresented = false }
        }) {
            NavigationStack {
                Form {
                    Section {
                        TextField("Ex. Ma veille politique", text: $name).accessibilityIdentifier("search-name")
                        Text(model.draft.isEmpty ? "Toutes les personnalités" : model.draft.summary).font(.subheadline).foregroundStyle(Brand.secondary)
                    } header: { Text("Nom du suivi") } footer: { Text("Ce suivi reste enregistré sur cet appareil.") }
                }
                .navigationTitle("Enregistrer un suivi").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Annuler") { showSave = false } } }
                .safeAreaInset(edge: .bottom) {
                    Button("Enregistrer") {
                        model.saveSearch(name: name)
                        saved = true
                        model.tab = .saved
                        showSave = false
                    }.buttonStyle(ActionButtonStyle(prominent: true))
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityIdentifier("confirm-save-search")
                        .padding(16).background(Brand.background)
                }
            }
        }
    }
    private func selectionRow(_ title: String, symbol: String, selections: Set<String>) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                Text(selections.isEmpty ? "Tous" : selections.sorted().joined(separator: ", "))
                    .font(.subheadline).foregroundStyle(Brand.secondary).fixedSize(horizontal: false, vertical: true)
            }
        } icon: { Image(systemName: symbol).foregroundStyle(Brand.blue) }
            .padding(.vertical, 8)
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
    @Environment(\.dismiss) private var dismiss
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
            Section {
                if !selected.isEmpty {
                    Text(selected.sorted().joined(separator: ", ")).font(.subheadline)
                    Button("Tout effacer") { selected.removeAll() }.frame(minHeight: 44)
                } else { Text("Tous sont inclus").foregroundStyle(Brand.secondary) }
            } header: { Text("\(selected.count) sélectionné(s)") }
            if choices.isEmpty {
                ContentUnavailableView {
                    Label("Liste indisponible", systemImage: "person.crop.circle.badge.questionmark")
                } description: { Text(model.choicesError ?? "La liste est vide.") } actions: {
                    Button("Réessayer") { Task { await model.loadChoices() } }
                }
            } else if filtered.isEmpty { ContentUnavailableView.search(text: query) }
            ForEach(filtered) { choice in
                Button {
                    if selected.contains(choice.value) { selected.remove(choice.value) } else { selected.insert(choice.value) }
                } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(choice.title).foregroundStyle(.primary)
                            if !choice.subtitle.isEmpty { Text(choice.subtitle).font(.subheadline).foregroundStyle(Brand.secondary) }
                        }
                        Spacer()
                        Image(systemName: selected.contains(choice.value) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(Brand.blue).font(.title3)
                    }.padding(.vertical, 8).frame(minHeight: 52).contentShape(Rectangle())
                }.accessibilityAddTraits(selected.contains(choice.value) ? .isSelected : [])
                    .accessibilityIdentifier("choice-\(choice.value)")
            }
        }
        .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, prompt: "Nom, prénom ou parti")
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Terminé") { dismiss() }.accessibilityIdentifier("confirm-choices") } }
    }
}
