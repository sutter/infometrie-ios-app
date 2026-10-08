import SwiftUI

/// A person of the panel over the last 7 or 30 complete days (`/rest/v1/profile`): what they did, day by day,
/// for how long and where, then a way to read their passages in the journal.
struct PersonView: View {
    @Environment(AppModel.self) private var model
    let name: String
    @State private var period: FeedPeriod = .week
    @State private var profile: PersonProfile?
    @State private var error: String?
    @State private var reload = 0
    @State private var selectedDay: String?
    @State private var dayPage: HistoryResponse?
    @State private var dayError: String?

    private var days: [String] { period.days() }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                heading
                VStack(alignment: .leading, spacing: 16) {
                    periods
                    if let error {
                        ErrorNotice(message: error) { reload += 1 }
                    } else {
                        totals
                        DayChart(days: days, counts: profile?.days ?? [], kinds: ["intervention", "citation", "tweet"],
                                 loading: profile == nil, selectedDay: selectedDay, identifier: "person-day") { day in
                            selectedDay = selectedDay == day ? nil : day
                        }
                        if let day = selectedDay { dayPassages(day) }
                    }
                }
                if let channels = profile?.topChannels, !channels.isEmpty {
                    AppSection(title: "Chaînes principales") {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(channels) { channel in ChannelRow(channel: channel) }
                        }
                    }
                }
                Button("Voir ses passages dans le journal", systemImage: "list.bullet") { showPassages() }
                    .buttonStyle(ActionButtonStyle(prominent: true))
                    .accessibilityIdentifier("person-show-passages")
                Text("Durées calculées sur les interventions du journal, pas sur le temps de parole officiel.")
                    .font(.footnote).foregroundStyle(Brand.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, AppLayout.margin).padding(.vertical, 20)
            .frame(maxWidth: AppLayout.readingWidth).frame(maxWidth: .infinity)
        }
        .background(Brand.background)
        .scrollEdgeEffectHidden(true)
        .navigationTitle("Personnalité").navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Brand.background, for: .navigationBar)
        .toolbarBackgroundVisibility(.visible, for: .navigationBar)
        .task(id: "\(period.rawValue)-\(reload)") { selectedDay = nil; await load() }
        .task(id: selectedDay) { await loadDay() }
    }

    private var heading: some View {
        let person = profile?.person ?? model.persons.first { $0.name == name }
        let details = [person?.party ?? "", person?.role ?? ""].filter { !$0.isEmpty }
        return VStack(alignment: .leading, spacing: 4) {
            Text(name).font(.title2.weight(.bold)).foregroundStyle(Brand.ink)
                .fixedSize(horizontal: false, vertical: true).accessibilityAddTraits(.isHeader)
            ForEach(details, id: \.self) { line in
                Text(line).font(.subheadline).foregroundStyle(Brand.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var periods: some View {
        HStack(spacing: 8) {
            tab(.week, title: "7 j", label: "7 derniers jours")
            tab(.month, title: "30 j", label: "30 derniers jours")
            Spacer(minLength: 0)
        }
        .padding(.leading, -4)
        .overlay(alignment: .bottom) { AppRule() }
        .sensoryFeedback(.selection, trigger: period)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Période")
    }

    private func tab(_ value: FeedPeriod, title: String, label: String) -> some View {
        AppTabButton(title: title, selected: period == value, compact: true) { period = value }
            .accessibilityLabel(label)
            .accessibilityIdentifier("person-period-\(value.rawValue)")
    }

    /// The three counts, then the time spent in interventions.
    private var totals: some View {
        let totals = profile?.totals ?? PersonProfile.Totals()
        return VStack(alignment: .leading, spacing: 8) {
            AdaptiveRow {
                stat(totals.interventions, one: "intervention", many: "interventions", kind: "intervention")
                stat(totals.citations, one: "citation", many: "citations", kind: "citation")
                stat(totals.tweets, one: "publication X", many: "publications X", kind: "tweet")
            }
            Text("\(SpokenDuration.label(seconds: totals.interventionSec)) d’interventions")
                .font(.subheadline).foregroundStyle(Brand.secondary)
                .accessibilityIdentifier("person-duration")
        }
        .skeleton(profile == nil)
    }

    private func stat(_ value: Int, one: String, many: String, kind: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value.formatted()).font(.title3.weight(.bold).monospacedDigit()).foregroundStyle(Brand.ink)
            Text(value == 1 ? one : many).font(.footnote).foregroundStyle(FeedItem.labelColor(ofKind: kind))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("person-total-\(kind)")
    }

    private func load() async {
        guard let token = model.session?.token else { return }
        error = nil
        do {
            profile = try await model.api.profile(token: token, person: name, days: period.rawValue)
        } catch is CancellationError {
        } catch APIError.notFound {
            profile = nil; error = "Cette personnalité ne fait pas partie du panel suivi."
        } catch {
            guard !Task.isCancelled else { return }
            model.handleSessionError(error)
            profile = nil; self.error = model.message(for: error)
        }
    }

    /// The chosen day: its date, a way back to the whole period, and the person's passages of that day.
    @ViewBuilder private func dayPassages(_ day: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(DayLabel.long(day)).font(.subheadline.weight(.semibold)).foregroundStyle(Brand.ink)
                Spacer(minLength: 8)
                Button { selectedDay = nil } label: {
                    Image(systemName: "xmark").font(.body.weight(.semibold)).frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain).foregroundStyle(Brand.ink)
                .accessibilityLabel("Toute la période")
                .accessibilityIdentifier("person-day-clear")
            }
            .accessibilityIdentifier("person-day-selection")
            if let dayError {
                ErrorNotice(message: dayError) { Task { await loadDay() } }
            } else if let page = dayPage {
                if page.items.isEmpty {
                    Text("Aucun passage ce jour-là.").font(.subheadline).foregroundStyle(Brand.secondary)
                        .padding(.vertical, 12)
                }
                ForEach(page.items) { item in
                    NavigationLink { SequenceView(item: item) } label: {
                        FeedCard(item: item, seen: model.isSeen(item)).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain).accessibilityIdentifier("person-item-\(item.id)")
                }
                if page.hasMore {
                    Text("Les \(page.items.count) passages les plus récents de la journée.")
                        .font(.footnote).foregroundStyle(Brand.secondary).padding(.top, 12)
                }
            } else {
                FeedSkeleton(label: "Chargement des passages du jour")
            }
        }
    }

    private func loadDay() async {
        dayPage = nil; dayError = nil
        guard let day = selectedDay, let token = model.session?.token else { return }
        do {
            let page = try await model.api.history(token: token, filters: SearchFilters(persons: [name]), from: day, to: day)
            guard selectedDay == day else { return }
            dayPage = page
        } catch is CancellationError {
        } catch {
            guard !Task.isCancelled, selectedDay == day else { return }
            model.handleSessionError(error)
            dayError = model.message(for: error)
        }
    }

    /// The journal filtered on this person, back at its root, with its period and types kept.
    private func showPassages() {
        var filters = model.filters
        filters.persons = [name]; filters.parties = []
        model.returnToFeedRoot()
        Task { await model.apply(filters) }
    }
}

/// One broadcaster of a profile: its logo (or name), its interventions and their duration.
private struct ChannelRow: View {
    let channel: PersonProfile.Channel

    var body: some View {
        // ChannelSource resolves logos from a passage; a bare one carries the key and the name.
        let source = FeedItem(id: 0, at: "", kind: "intervention", media: "", channel: channel.channel,
                              person: "", party: "", title: "", channelKey: channel.channelKey)
        VStack(alignment: .leading, spacing: 0) {
            AdaptiveRow {
                ChannelSource(item: source, size: 24)
                Spacer(minLength: 0)
                Text("\(channel.interventions.formatted()) interventions · \(SpokenDuration.label(seconds: channel.interventionSec))")
                    .font(.subheadline.monospacedDigit()).foregroundStyle(Brand.secondary)
            }
            .padding(.vertical, 12)
            AppRule()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(channel.channel), \(channel.interventions) interventions, \(SpokenDuration.label(seconds: channel.interventionSec))")
    }
}
