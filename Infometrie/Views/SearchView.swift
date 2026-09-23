import SwiftUI

struct SearchView: View {
    @Environment(AppModel.self) private var model
    @State private var showSave = false
    @State private var name = ""
    @State private var saved = false
    private var kind: Int { model.draft.interventions && model.draft.citations ? 0 : model.draft.interventions ? 1 : 2 }

    var body: some View {
        @Bindable var model = model
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                EditorialPageHeading(title: "Filtrer", subtitle: "Composez le fil qui vous intéresse.")
                EditorialSection(title: "Qui suivre ?") {
                    VStack(spacing: 0) {
                        NavigationLink {
                            ChoicePicker(title: "Personnalités", allTitle: "Toutes les personnalités", choices: model.persons.map {
                                .init(value: $0.name, title: $0.name, subtitle: [$0.party, $0.role].filter { !$0.isEmpty }.joined(separator: " · "))
                            }, selected: $model.draft.persons)
                        } label: {
                            FilterSelectionRow(title: "Personnalités", icon: "person.2", summary: model.draft.persons.isEmpty ? "Toutes" : model.draft.persons.sorted().joined(separator: ", "), isSelected: !model.draft.persons.isEmpty)
                        }.accessibilityIdentifier("pick-persons")
                        Divider().padding(.horizontal, 20)
                        NavigationLink {
                            ChoicePicker(title: "Partis politiques", allTitle: "Tous les partis", choices: model.parties.map {
                                .init(value: $0.code, title: $0.name, subtitle: $0.code)
                            }, selected: $model.draft.parties)
                        } label: {
                            FilterSelectionRow(title: "Partis politiques", icon: "building.columns", summary: model.draft.parties.isEmpty ? "Tous" : partyNames(model.draft.parties, in: model.parties), isSelected: !model.draft.parties.isEmpty)
                        }.accessibilityIdentifier("pick-parties")
                        if !model.draft.persons.isEmpty && !model.draft.parties.isEmpty {
                            Text("Seules les personnalités choisies appartenant aux partis sélectionnés seront affichées.")
                                .font(.footnote).foregroundStyle(Brand.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                                .background(Brand.blue.opacity(0.04))
                        }
                    }.buttonStyle(.plain).overlay(alignment: .bottom) { EditorialRule() }
                }

                EditorialSection(title: "Quels passages ?") {
                    VStack(spacing: 0) {
                        ForEach(Array(passageKinds.enumerated()), id: \.offset) { index, option in
                            if index > 0 { Divider().padding(.horizontal, 20) }
                            Button {
                                model.draft.interventions = index != 2
                                model.draft.citations = index != 1
                            } label: {
                                FilterChoiceRow(title: option.title, subtitle: option.subtitle, selected: kind == index, multiple: false, accent: Brand.citation)
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(kind == index ? .isSelected : [])
                            .accessibilityIdentifier("filter-kind-\(index)")
                        }
                    }.overlay(alignment: .bottom) { EditorialRule() }
                }

                if let error = model.choicesError {
                    ErrorNotice(message: error) { Task { await model.loadChoices() } }
                }
                Button { name = ""; saved = false; showSave = true } label: {
                    FilterSelectionRow(title: "Enregistrer ce suivi", icon: "bookmark", summary: "Retrouvez ces filtres dans « Mes suivis ».", isSelected: false)
                }.buttonStyle(.plain).overlay(alignment: .bottom) { EditorialRule() }.accessibilityIdentifier("save-search")
                Button { model.draft = SearchFilters() } label: {
                    Label("Réinitialiser les filtres", systemImage: "arrow.counterclockwise")
                        .font(.body.weight(.medium)).frame(maxWidth: .infinity, minHeight: 52)
                        .fixedSize(horizontal: false, vertical: true).contentShape(Rectangle())
                }.buttonStyle(.plain).foregroundStyle(Brand.blue).accessibilityIdentifier("reset-search")
            }.padding(20).frame(maxWidth: EditorialLayout.readingWidth).frame(maxWidth: .infinity)
        }
        .background(Brand.background)
        .scrollEdgeEffectHidden(true, for: .bottom).scrollEdgeEffectStyle(.hard, for: .top)
        .editorialNavigationTitle("Filtrer le fil")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Annuler") { model.isSearchPresented = false } }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            FilterFooter {
                Button { Task { await model.apply(model.draft) } } label: { Text("Afficher les résultats") }
                    .buttonStyle(ActionButtonStyle(prominent: true)).accessibilityIdentifier("apply-search")
            }
        }
        .sheet(isPresented: $showSave, onDismiss: {
            if saved { model.isSearchPresented = false }
        }) {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        EditorialPageHeading(title: "Nouveau suivi")
                        EditorialSection(title: "Donnez-lui un nom") {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Nom du suivi").font(.headline)
                                TextField("Nom du suivi", text: $name, prompt: Text("Ex. Ma veille politique").foregroundStyle(Brand.secondary))
                                    .font(.body).autocorrectionDisabled().submitLabel(.done)
                                    .onSubmit { save() }.accessibilityIdentifier("search-name")
                                    .padding(16).editorialInput()
                                Text("Vous le retrouverez dans « Mes suivis ».")
                                    .font(.subheadline).foregroundStyle(Brand.secondary)
                            }
                        }
                        EditorialSection(title: "Les filtres de ce suivi") {
                            VStack(alignment: .leading, spacing: 16) {
                                recap("Personnalités", value: model.draft.persons.isEmpty ? "Toutes" : model.draft.persons.sorted().joined(separator: ", "))
                                Divider()
                                recap("Partis politiques", value: model.draft.parties.isEmpty ? "Tous" : partyNames(model.draft.parties, in: model.parties))
                                Divider()
                                recap("Passages", value: passageKinds[kind].title)
                            }.frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }.padding(20).frame(maxWidth: EditorialLayout.readingWidth).frame(maxWidth: .infinity)
                }
                .background(Brand.background)
                .scrollDismissesKeyboard(.interactively)
                .scrollEdgeEffectHidden(true, for: .bottom).scrollEdgeEffectStyle(.hard, for: .top)
                .editorialNavigationTitle("Enregistrer un suivi")
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Annuler") { showSave = false } } }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    FilterFooter {
                        Button("Enregistrer", action: save)
                            .buttonStyle(ActionButtonStyle(prominent: true))
                            .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .accessibilityIdentifier("confirm-save-search")
                    }
                }
            }
        }
    }

    private func save() {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        model.saveSearch(name: name)
        saved = true; model.tab = .saved; showSave = false
    }
    private func recap(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.subheadline).foregroundStyle(Brand.secondary)
            Text(value).font(.body.weight(.medium)).fixedSize(horizontal: false, vertical: true)
        }
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
    let allTitle: String
    let choices: [Choice]
    @Binding var selected: Set<String>
    @State private var query = ""
    private var filtered: [Choice] {
        choices.filter { query.isEmpty || "\($0.title) \($0.subtitle)".localizedStandardContains(query) }
            .sorted { $0.title.localizedCompare($1.title) == .orderedAscending }
    }
    var body: some View {
        List {
            EditorialPageHeading(title: title)
                .padding(.vertical, 20)
                .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
                .listRowBackground(Color.clear).listRowSeparator(.hidden)
            Button { selected.removeAll() } label: {
                FilterChoiceRow(title: allTitle, subtitle: "Sans restriction", selected: selected.isEmpty, multiple: false)
            }.buttonStyle(.plain).overlay(alignment: .bottom) { EditorialRule() }
                .accessibilityAddTraits(selected.isEmpty ? .isSelected : [])
                .accessibilityIdentifier("clear-choices")
                .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 20, trailing: 20))
                .listRowBackground(Color.clear).listRowSeparator(.hidden)
            if choices.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    EditorialEmptyState(title: "Liste indisponible", icon: "person.crop.circle.badge.questionmark", message: model.choicesError ?? "La liste est vide.")
                    Button("Réessayer") { Task { await model.loadChoices() } }.buttonStyle(ActionButtonStyle())
                }.listRowBackground(Color.clear).listRowSeparator(.hidden)
            } else if filtered.isEmpty {
                EditorialEmptyState(title: "Aucun résultat", icon: "magnifyingglass", message: "Aucun nom ne correspond à « \(query) ».").listRowBackground(Color.clear).listRowSeparator(.hidden)
            }
            ForEach(filtered) { choice in
                Button {
                    if selected.contains(choice.value) { selected.remove(choice.value) } else { selected.insert(choice.value) }
                } label: {
                    FilterChoiceRow(title: choice.title, subtitle: choice.subtitle, selected: selected.contains(choice.value), multiple: true)
                }.buttonStyle(.plain).overlay(alignment: .bottom) { EditorialRule() }
                    .accessibilityAddTraits(selected.contains(choice.value) ? .isSelected : [])
                    .accessibilityIdentifier("choice-\(choice.value)")
                    .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 12, trailing: 20))
                    .listRowBackground(Color.clear).listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain).scrollContentBackground(.hidden).background(Brand.background)
        .scrollEdgeEffectHidden(true, for: .bottom).scrollEdgeEffectStyle(.hard, for: .top)
        .editorialNavigationTitle(title)
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Rechercher un nom")
        .safeAreaInset(edge: .bottom, spacing: 0) {
            FilterFooter {
                Text(selected.isEmpty ? allTitle : "\(selected.count) \(selected.count == 1 ? "sélection" : "sélections")")
                    .font(.subheadline).foregroundStyle(Brand.secondary)
                    .fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("choice-count")
                Button("Terminé") { dismiss() }
                    .buttonStyle(ActionButtonStyle(prominent: true)).accessibilityIdentifier("confirm-choices")
            }
        }
    }
}

private let passageKinds = [
    (title: "Tous les passages", subtitle: "Interventions et citations"),
    (title: "Interventions", subtitle: "Les prises de parole"),
    (title: "Citations", subtitle: "Les personnes citées à l’antenne")
]

private func partyNames(_ codes: Set<String>, in parties: [Party]) -> String {
    codes.sorted().map { code in parties.first(where: { $0.code == code })?.name ?? code }.joined(separator: ", ")
}

private struct FilterSelectionRow: View {
    let title: String
    let icon: String
    let summary: String
    let isSelected: Bool
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 17, weight: .medium))
                .foregroundStyle(Brand.citation).frame(width: 34, height: 34)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.body.weight(.semibold)).foregroundStyle(Brand.ink)
                Text(summary).font(.subheadline).foregroundStyle(isSelected ? Brand.blue : Brand.secondary)
            }.fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Brand.secondary).accessibilityHidden(true)
        }
        .padding(16).frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
        .background(isSelected ? Brand.blue.opacity(0.04) : .clear)
        .contentShape(Rectangle())
    }
}

private struct FilterChoiceRow: View {
    let title: String
    let subtitle: String
    let selected: Bool
    let multiple: Bool
    var accent: Color = Brand.citation
    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.body.weight(.semibold)).foregroundStyle(Brand.ink)
                if !subtitle.isEmpty { Text(subtitle).font(.subheadline).foregroundStyle(Brand.secondary) }
            }.fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: selected ? (multiple ? "checkmark.square.fill" : "checkmark.circle.fill") : (multiple ? "square" : "circle"))
                .font(.title3).foregroundStyle(accent).accessibilityHidden(true)
        }
        .padding(16).frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
        .background(selected ? accent.opacity(0.07) : .clear)
        .contentShape(Rectangle())
    }
}

private struct FilterFooter<Content: View>: View {
    @ViewBuilder var content: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: 10, content: content)
            .padding(16).frame(maxWidth: EditorialLayout.readingWidth).frame(maxWidth: .infinity)
            .background(Brand.background).overlay(alignment: .top) { EditorialRule() }
    }
}
