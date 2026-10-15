import SwiftUI

struct SearchView: View {
    @Environment(AppModel.self) private var model
    private var kind: Int? { model.draft.kindSelection }
    /// Opened from "Créer un suivi", the sheet says so and saves: a search shown first and saved later was forgotten.
    private var creating: Bool { model.isCreatingSuivi }

    var body: some View {
        @Bindable var model = model
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                PageHeading(title: creating ? "Nouveau suivi" : "Rechercher",
                            subtitle: creating ? "Choisissez qui suivre ; il sera enregistré dans Mes suivis." : "Composez le journal qui vous intéresse.")
                AppSection(title: "Qui suivre ?") {
                    VStack(spacing: 0) {
                        NavigationLink {
                            ChoicePicker(title: "Personnalités", allTitle: "Toutes les personnalités", othersTitle: "Autres personnalités", choices: model.persons.map {
                                .init(value: $0.name, title: $0.name, subtitle: [$0.party, $0.role].filter { !$0.isEmpty }.joined(separator: " · "))
                            }, selected: $model.draft.persons)
                        } label: {
                            FilterSelectionRow(title: "Personnalités", icon: "person.2", summary: model.draft.persons.isEmpty ? "Toutes" : nil)
                        }
                        .accessibilityValue(model.draft.persons.isEmpty ? "" : selectionCount(model.draft.persons.count))
                        .accessibilityIdentifier("pick-persons")
                        if !model.draft.persons.isEmpty {
                            SelectionPills(items: model.draft.persons.sorted().map { (value: $0, title: $0) }, icon: "person",
                                           identifier: "person", clearLabel: "Effacer toutes les personnalités",
                                           remove: { model.draft.persons.remove($0) }, clearAll: { model.draft.persons.removeAll() })
                        }
                        AppRule()
                        NavigationLink {
                            ChoicePicker(title: "Partis politiques", allTitle: "Tous les partis", othersTitle: "Autres partis", choices: model.parties.map {
                                .init(value: $0.code, title: $0.name, subtitle: $0.code)
                            }, selected: $model.draft.parties)
                        } label: {
                            FilterSelectionRow(title: "Partis politiques", icon: "building.columns", summary: model.draft.parties.isEmpty ? "Tous" : nil)
                        }
                        .accessibilityValue(model.draft.parties.isEmpty ? "" : selectionCount(model.draft.parties.count))
                        .accessibilityIdentifier("pick-parties")
                        if !model.draft.parties.isEmpty {
                            SelectionPills(items: model.draft.parties.sorted().map { code in (value: code, title: model.parties.first { $0.code == code }?.name ?? code) },
                                           icon: "building.columns", identifier: "party", clearLabel: "Effacer tous les partis",
                                           remove: { model.draft.parties.remove($0) }, clearAll: { model.draft.parties.removeAll() })
                        }
                        if !model.draft.persons.isEmpty && !model.draft.parties.isEmpty {
                            Text("Seules les personnalités choisies appartenant aux partis sélectionnés seront affichées.")
                                .font(.footnote).foregroundStyle(Brand.secondaryOnSurface)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                                .background(Brand.surface)
                        }
                    }.buttonStyle(.plain).overlay(alignment: .bottom) { AppRule() }
                }

                AppSection(title: "Quels contenus ?") {
                    VStack(spacing: 0) {
                        if kind == nil {
                            FilterChoiceRow(title: model.draft.kindSummary, subtitle: "Types conservés dans ce suivi", selected: true, multiple: false)
                                .accessibilityAddTraits(.isSelected)
                            AppRule()
                        }
                        ForEach(Array(passageKinds.enumerated()), id: \.offset) { index, option in
                            if index > 0 { AppRule() }
                            Button {
                                model.draft.selectKind(index)
                            } label: {
                                FilterChoiceRow(title: option.title, subtitle: option.subtitle, selected: kind == index, multiple: false)
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(kind == index ? .isSelected : [])
                            .accessibilityIdentifier("filter-kind-\(index)")
                        }
                    }.overlay(alignment: .bottom) { AppRule() }
                }

                if let error = model.choicesError {
                    ErrorNotice(message: error) { Task { await model.loadChoices() } }
                }
                Button { model.draft = SearchFilters() } label: {
                    Label("Réinitialiser la recherche", systemImage: "arrow.counterclockwise")
                        .font(.body.weight(.medium)).frame(maxWidth: .infinity, minHeight: 52)
                        .fixedSize(horizontal: false, vertical: true).contentShape(Rectangle())
                }.buttonStyle(.plain).foregroundStyle(Brand.tint).accessibilityIdentifier("reset-search")
            }.padding(.horizontal, AppLayout.margin).padding(.vertical, 20).frame(maxWidth: AppLayout.readingWidth).frame(maxWidth: .infinity)
        }
        .background(Brand.background)
        .scrollEdgeEffectHidden(true)
        .appNavigationTitle(creating ? "Nouveau suivi" : "Recherche")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Annuler") { model.isSearchPresented = false } }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            FilterFooter {
                if creating {
                    Button { Task { await model.createSuivi() } } label: { Text("Enregistrer et afficher") }
                        .buttonStyle(ActionButtonStyle(prominent: true)).accessibilityIdentifier("create-suivi")
                } else {
                    Button { Task { await model.apply(model.draft) } } label: { Text("Afficher les résultats") }
                        .buttonStyle(ActionButtonStyle(prominent: true)).accessibilityIdentifier("apply-search")
                }
            }
        }
    }
}

struct ChoicePicker: View {
    struct Choice: Identifiable {
        /// What the row shows. The value alone is not unique: the panel holds homonyms (two « Alexandra Martin »
        /// on 2026-10-15), which share the name the search filters on, so checking one checks the other.
        var id: String { "\(value)\n\(title)\n\(subtitle)" }
        let value: String
        let title: String
        let subtitle: String
    }
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let title: String
    let allTitle: String
    /// Heads the names not chosen when the list opened, under "Votre sélection".
    let othersTitle: String
    let choices: [Choice]
    @Binding var selected: Set<String>
    @State private var query = ""
    /// The selection when the list opened, listed first until the next opening: a name checked or unchecked
    /// meanwhile keeps its place, so no row jumps under the finger (option 1 of sheet 10, 2026-10-15).
    @State private var pinned: Set<String>

    init(title: String, allTitle: String, othersTitle: String, choices: [Choice], selected: Binding<Set<String>>) {
        self.title = title
        self.allTitle = allTitle
        self.othersTitle = othersTitle
        // A row repeated as is would repeat its id, so it shows once.
        var shown = Set<String>()
        self.choices = choices.filter { shown.insert($0.id).inserted }
        _selected = selected
        _pinned = State(initialValue: selected.wrappedValue)
    }

    private var filtered: [Choice] {
        choices.filter { query.isEmpty || "\($0.title) \($0.subtitle)".localizedStandardContains(query) }
            .sorted { $0.title.localizedCompare($1.title) == .orderedAscending }
    }

    // No heading of its own: the bar already names the list, and a search shows its results only, which leaves
    // the room above the keyboard to them (the client's iPhone 13 mini showed a single result).
    var body: some View {
        List {
            if choices.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    AppEmptyState(title: "Liste indisponible", icon: "person.crop.circle.badge.questionmark", message: model.choicesError ?? "La liste est vide.")
                    Button("Réessayer") { Task { await model.loadChoices() } }.buttonStyle(ActionButtonStyle())
                }.listRowBackground(Color.clear).listRowSeparator(.hidden)
            } else if filtered.isEmpty {
                AppEmptyState(title: "Aucun résultat", icon: "magnifyingglass", message: "Aucun nom ne correspond à « \(query) ».").listRowBackground(Color.clear).listRowSeparator(.hidden)
            }
            let first = query.isEmpty ? filtered.filter { pinned.contains($0.value) } : []
            if first.isEmpty {
                ForEach(filtered, content: row)
            } else {
                let others = filtered.filter { !pinned.contains($0.value) }
                sectionLabel("Votre sélection", top: 16)
                ForEach(first, content: row)
                if !others.isEmpty {
                    sectionLabel(othersTitle, top: 24)
                    ForEach(others, content: row)
                }
            }
        }
        .listStyle(.plain).scrollContentBackground(.hidden).background(Brand.background)
        .scrollEdgeEffectHidden(true)
        .appNavigationTitle(title)
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Rechercher un nom")
        .safeAreaInset(edge: .bottom, spacing: 0) {
            // The count row is a touch target tall, with less padding above it, so "Tout effacer" leaves the
            // footer at its former height and the results keep their room.
            FilterFooter(top: 4, spacing: 0) {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) { countLabel; Spacer(minLength: 0); clearButton }
                    VStack(alignment: .leading, spacing: 0) { countLabel; clearButton }
                }
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                Button("Terminé") { dismiss() }
                    .buttonStyle(ActionButtonStyle(prominent: true)).accessibilityIdentifier("confirm-choices")
            }
        }
    }

    private var countLabel: some View {
        Text(selected.isEmpty ? allTitle : selectionCount(selected.count))
            .font(.subheadline).foregroundStyle(Brand.secondary)
            .fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("choice-count")
    }

    /// Unchecks every name: the former "Toutes les personnalités · Sans restriction" radio did not read as clearing.
    @ViewBuilder private var clearButton: some View {
        if !selected.isEmpty {
            Button("Tout effacer") { selected.removeAll() }
                .font(.subheadline.weight(.semibold)).foregroundStyle(Brand.tint)
                .buttonStyle(.plain).frame(minHeight: 44).contentShape(Rectangle())
                .accessibilityIdentifier("clear-choices")
        }
    }

    private func sectionLabel(_ title: String, top: CGFloat) -> some View {
        SectionLabel(title: title)
            .listRowInsets(EdgeInsets(top: top, leading: AppLayout.margin, bottom: 4, trailing: AppLayout.margin))
            .listRowBackground(Color.clear).listRowSeparator(.hidden)
    }

    private func row(_ choice: Choice) -> some View {
        Button {
            if selected.contains(choice.value) { selected.remove(choice.value) } else { selected.insert(choice.value) }
        } label: {
            FilterChoiceRow(title: choice.title, subtitle: choice.subtitle, selected: selected.contains(choice.value), multiple: true)
        }.buttonStyle(.plain).overlay(alignment: .bottom) { AppRule() }
            .accessibilityAddTraits(selected.contains(choice.value) ? .isSelected : [])
            .accessibilityIdentifier("choice-\(choice.value)")
            .listRowInsets(EdgeInsets(top: 0, leading: AppLayout.margin, bottom: 12, trailing: AppLayout.margin))
            .listRowBackground(Color.clear).listRowSeparator(.hidden)
    }
}

private let passageKinds = [
    (title: "Tous les contenus", subtitle: "Interventions, citations et publications X"),
    (title: "Interventions", subtitle: "Les prises de parole"),
    (title: "Citations", subtitle: "Les personnes citées à l’antenne"),
    (title: "Publications X", subtitle: "Les publications sur X")
]

private func selectionCount(_ count: Int) -> String {
    "\(count) \(count == 1 ? "sélection" : "sélections")"
}

private struct FilterSelectionRow: View {
    let title: String
    let icon: String
    /// What no choice means ("Toutes"); once names are chosen, the pills under the row list them.
    let summary: String?
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 17, weight: .medium))
                .foregroundStyle(Brand.tint).frame(width: 34, height: 34)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.body.weight(.semibold)).foregroundStyle(Brand.ink)
                if let summary { Text(summary).font(.subheadline).foregroundStyle(Brand.secondary) }
            }.fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Brand.secondary).accessibilityHidden(true)
        }
        .padding(.vertical, 14).frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
        .contentShape(Rectangle())
    }
}

/// The chosen names of one criterion, each with its cross, then "Tout effacer" from two on: removing several
/// no longer means finding each one in the list (the client's request on 2026-10-15, option B of sheet 09).
private struct SelectionPills: View {
    let items: [(value: String, title: String)]
    let icon: String
    let identifier: String
    let clearLabel: String
    let remove: (String) -> Void
    let clearAll: () -> Void

    var body: some View {
        WrappingLayout {
            ForEach(items, id: \.value) { item in
                CriterionPill(title: item.title, icon: icon) { remove(item.value) }
                    .accessibilityIdentifier("remove-\(identifier)-\(item.value)")
            }
            if items.count > 1 {
                Button("Tout effacer", action: clearAll)
                    .font(.subheadline.weight(.semibold)).foregroundStyle(Brand.tint)
                    .buttonStyle(.plain).frame(minHeight: 44).padding(.horizontal, 4)
                    .accessibilityLabel(clearLabel)
                    .accessibilityIdentifier("clear-\(identifier)-selection")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 14)
    }
}

private struct FilterChoiceRow: View {
    let title: String
    let subtitle: String
    let selected: Bool
    let multiple: Bool
    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.body.weight(.semibold)).foregroundStyle(Brand.ink)
                if !subtitle.isEmpty { Text(subtitle).font(.subheadline).foregroundStyle(Brand.secondary) }
            }.fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading)
            ChoiceMark(selected: selected, multiple: multiple)
        }
        .padding(.vertical, 14).frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
        .contentShape(Rectangle())
    }
}

/// A radio (one choice) or checkbox (several) in vermillon: a ring holding a dot, or a box holding a check.
/// Unchecked, a plain secondary ring, at more than 3:1 on the page.
struct ChoiceMark: View {
    let selected: Bool
    let multiple: Bool
    @ScaledMetric(relativeTo: .title3) private var side = 26.0

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: multiple ? side * 0.3 : side / 2, style: .continuous)
        ZStack {
            if selected {
                shape.strokeBorder(Brand.accent, lineWidth: 2)
                if multiple {
                    Image(systemName: "checkmark").font(.system(size: side * 0.5, weight: .bold)).foregroundStyle(Brand.accent)
                } else {
                    Circle().fill(Brand.accent).frame(width: side * 0.46, height: side * 0.46)
                }
            } else {
                shape.strokeBorder(Brand.secondary, lineWidth: 1.5)
            }
        }
        .frame(width: side, height: side)
        .accessibilityHidden(true)
    }
}

private struct FilterFooter<Content: View>: View {
    var top: CGFloat = 16
    var spacing: CGFloat = 10
    @ViewBuilder var content: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: spacing, content: content)
            .padding(.horizontal, 16).padding(.top, top).padding(.bottom, 16).frame(maxWidth: AppLayout.readingWidth).frame(maxWidth: .infinity)
            .background(Brand.background).overlay(alignment: .top) { AppRule() }
    }
}
