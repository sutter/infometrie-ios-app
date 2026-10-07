import SwiftUI

/// The passage date as every variant writes it: `25/09 14:39`.
struct PassageDate: View {
    let item: FeedItem

    var body: some View {
        if let date = item.date {
            Text("\(date, format: .dateTime.day(.twoDigits).month(.twoDigits)) \(date, style: .time)")
                .foregroundStyle(Brand.secondary).monospacedDigit()
                .accessibilityLabel(Text(date, format: .dateTime.day().month(.wide).year().hour().minute()))
        }
    }
}

/// The listening duration, shown only for a playable passage.
struct PassageDuration: View {
    let item: FeedItem

    var body: some View {
        if item.canPlay && item.durationSec > 0 {
            // The duration alone: the headphones icon beside it added noise, not meaning.
            Text(item.readableDuration)
                .monospacedDigit()
                .foregroundStyle(Brand.secondary)
                .fixedSize()
                .accessibilityLabel("Durée d’écoute : \(item.readableDuration)")
        }
    }
}

/// The broadcaster logo, or its name when no logo is bundled; X gets its tile.
struct ChannelSource: View {
    let item: FeedItem
    var size: CGFloat = 20

    var body: some View {
        HStack(spacing: 7) {
            ChannelMark(item: item, size: size)
            if !ChannelMark.hasLogo(for: item) {
                Text(item.channel).foregroundStyle(Brand.secondary)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(item.isTweet ? item.kindLabel : item.channel)
    }
}

/// The passage kind as a tag in its kind color, on a pale wash of the same hue.
struct KindTag: View {
    let label: String
    let kind: String

    init(item: FeedItem) { label = item.kindLabel; kind = item.kind }
    /// A kind named on its own, as in a suivi: `kind` is an API kind (`intervention`, `citation`, `tweet`).
    init(kind: String, label: String) { self.kind = kind; self.label = label }

    var body: some View {
        Text(label)
            .font(.caption.weight(.semibold))
            .foregroundStyle(FeedItem.color(ofKind: kind))
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(FeedItem.wash(ofKind: kind), in: Capsule())
            .fixedSize()
    }
}

/// The small gray title of a section ("Apparence", "Votre abonnement"…): one style for every section label.
struct SectionLabel: View {
    let title: String

    var body: some View {
        Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(Brand.secondary)
            .accessibilityAddTraits(.isHeader)
    }
}

/// The person and their party on one line, then their role when it adds something.
struct PassageSpeaker: View {
    let item: FeedItem
    var nameFont: Font = .subheadline
    var lineLimit: Int? = 2
    /// A seen passage steps back: the name turns secondary like the title.
    var dimmed = false

    var body: some View {
        let party = item.party.trimmingCharacters(in: .whitespacesAndNewlines)
        let role = item.role.trimmingCharacters(in: .whitespacesAndNewlines)
        let repeatsParty = role.range(of: party, options: [.anchored, .caseInsensitive, .diacriticInsensitive]) != nil
            || party.range(of: role, options: [.anchored, .caseInsensitive, .diacriticInsensitive]) != nil
        let name = Text(item.person).font(nameFont.weight(.semibold)).foregroundStyle(dimmed ? Brand.secondary : Brand.ink)
        let partyText = Text(party).font(nameFont).foregroundStyle(Brand.secondary)
        VStack(alignment: .leading, spacing: 1) {
            // Name · party on one line when it fits; otherwise the party moves below, never leaving a lone "·".
            ViewThatFits(in: .horizontal) {
                (party.isEmpty ? name : name + Text(" · ").font(nameFont).foregroundStyle(Brand.secondary) + partyText)
                    .fixedSize(horizontal: true, vertical: false)
                VStack(alignment: .leading, spacing: 1) {
                    name.lineLimit(lineLimit)
                    if !party.isEmpty { partyText.lineLimit(lineLimit) }
                }
            }
            if !role.isEmpty && (party.isEmpty || !repeatsParty) {
                Text(role).font(.footnote).foregroundStyle(Brand.secondary).lineLimit(lineLimit)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// The top of a passage page, in the order of the user's reference: kind, date and duration with the
/// channel logo on the right; the person, party and role; then the title.
struct PassageHeading: View {
    let item: FeedItem
    let titleIdentifier: String
    @Environment(\.dynamicTypeSize) private var dynamicType

    var body: some View {
        // The context (12 inside), then the title, 24 apart on the 8 pt grid. The title speaks for
        // itself: no "Propos" label above it.
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 12) {
                facts
                PassageSpeaker(item: item, nameFont: .headline, lineLimit: nil)
            }
            Text(item.title)
                .font(.title2.weight(.bold))
                .foregroundStyle(Brand.ink)
                .fixedSize(horizontal: false, vertical: true).accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier(titleIdentifier)
        }
    }

    /// One line when it fits; otherwise kind and logo, then date and duration.
    @ViewBuilder private var facts: some View {
        let kind = KindTag(item: item)
        Group {
            if dynamicType.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 6) {
                    kind; PassageDate(item: item); channelName; PassageDuration(item: item); ChannelMark(item: item)
                }
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) {
                        kind; PassageDate(item: item); channelName; PassageDuration(item: item)
                        Spacer(minLength: 0); ChannelMark(item: item, size: 24)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 10) { kind; Spacer(minLength: 0); ChannelMark(item: item, size: 24) }
                        HStack(spacing: 10) { PassageDate(item: item); channelName; Spacer(minLength: 0); PassageDuration(item: item) }
                    }
                }
            }
        }
        .font(.footnote)
    }

    /// The logo names the channel; its name shows only when no logo is bundled.
    @ViewBuilder private var channelName: some View {
        if !ChannelMark.hasLogo(for: item) { Text(item.channel).foregroundStyle(Brand.secondary) }
    }
}

extension FeedItem {
    /// Teal for interventions, slate for citations, ink otherwise (X).
    static func color(ofKind kind: String) -> Color {
        kind == "intervention" ? Brand.intervention : kind == "citation" ? Brand.citation : Brand.ink
    }
    static func wash(ofKind kind: String) -> Color {
        kind == "intervention" ? Brand.interventionWash : kind == "citation" ? Brand.citationWash : Brand.surface
    }
    var kindColor: Color { Self.color(ofKind: kind) }
    var kindSymbol: String { isTweet ? "text.bubble" : isCitation ? "quote.bubble" : kind == "intervention" ? "waveform" : "doc.text" }

    var readableDuration: String {
        let seconds = max(0, durationSec)
        if seconds < 60 { return "\(seconds) s" }
        let remainder = seconds % 60
        return remainder == 0 ? "\(seconds / 60) min" : "\(seconds / 60) min \(remainder) s"
    }
}
