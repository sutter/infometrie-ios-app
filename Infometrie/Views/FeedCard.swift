import SwiftUI

/// A compact timeline entry. Opening the row reveals the complete passage.
/// Every kind shares one order: what it is and where it was heard, then who, then the passage.
struct FeedCard: View {
    let item: FeedItem
    @Environment(\.dynamicTypeSize) private var dynamicType

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            header
            source
            speaker
            title
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Brand.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint(item.canPlay ? "Ouvre le texte et le lecteur de ce passage" : "Ouvre le texte de cette publication")
    }

    private var title: some View {
        Text(displayTitle)
            .font(.body).foregroundStyle(Brand.ink)
            .lineLimit(dynamicType.isAccessibilitySize ? nil : 4)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// The kind, how a citation was heard, and the channel logo on the right.
    /// A mention too long for the line moves below the badge instead of squeezing beside it.
    @ViewBuilder private var header: some View {
        let badge = Text(item.kindLabel).font(.footnote.weight(.semibold)).foregroundStyle(item.kindColor)
        if dynamicType.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 6) { badge; mention; ChannelMark(item: item) }
        } else {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { badge; mention; Spacer(minLength: 0); ChannelMark(item: item) }
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) { badge; Spacer(minLength: 0); ChannelMark(item: item) }
                    mention
                }
            }
        }
    }

    @ViewBuilder private var mention: some View {
        if item.isCitation {
            Text(item.citedBy.isEmpty ? "mention à l’antenne" : "mention par \(item.citedBy)")
                .font(.footnote).foregroundStyle(Brand.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Date, channel and medium on the left, listening duration on the right.
    /// A channel too long for the line moves below the date instead of squeezing beside it.
    @ViewBuilder private var source: some View {
        let channel = Text(channelLine).foregroundStyle(Brand.secondary).fixedSize(horizontal: false, vertical: true)
        Group {
            if dynamicType.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 6) { PassageDate(item: item); channel; PassageDuration(item: item) }
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) { PassageDate(item: item); channel; Spacer(minLength: 0); PassageDuration(item: item) }
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) { PassageDate(item: item); Spacer(minLength: 0); PassageDuration(item: item) }
                        channel
                    }
                }
            }
        }
        .font(.footnote)
    }

    /// The channel and its medium, without repeating a medium the channel name already gives ("BFM TV").
    private var channelLine: String {
        let medium = item.mediaLabel
        guard !medium.isEmpty, item.channel.range(of: medium, options: [.caseInsensitive, .diacriticInsensitive]) == nil else { return item.channel }
        return "\(item.channel) · \(medium)"
    }

    /// The person and their party on one line, then their role when it adds something.
    private var speaker: some View {
        let party = item.party.trimmingCharacters(in: .whitespacesAndNewlines)
        let role = item.role.trimmingCharacters(in: .whitespacesAndNewlines)
        let repeatsParty = role.range(of: party, options: [.anchored, .caseInsensitive, .diacriticInsensitive]) != nil
            || party.range(of: role, options: [.anchored, .caseInsensitive, .diacriticInsensitive]) != nil
        return VStack(alignment: .leading, spacing: 1) {
            (Text(item.person).font(.subheadline.weight(.semibold)).foregroundStyle(Brand.ink)
                + Text(party.isEmpty ? "" : " · \(party)").font(.subheadline).foregroundStyle(Brand.secondary))
                .lineLimit(2)
            if !role.isEmpty && (party.isEmpty || !repeatsParty) {
                Text(role).font(.footnote).foregroundStyle(Brand.secondary).lineLimit(2)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var displayTitle: String {
        let prefix = "(\(item.person))"
        let trimmedTitle = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedTitle.range(of: prefix, options: [.anchored, .caseInsensitive]) != nil else {
            return item.title
        }
        return String(trimmedTitle.dropFirst(prefix.count))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// Placeholder cards while the feed loads, drawn from the real card layout so they follow its changes.
struct FeedSkeleton: View {
    var label = "Chargement du fil"

    var body: some View {
        VStack(spacing: 10) {
            ForEach(FeedItem.skeletons) { FeedCard(item: $0) }
        }
        .skeleton()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityIdentifier("feed-skeleton")
    }
}

private extension FeedItem {
    /// Stand-in entries whose text lengths give the skeleton the rhythm of a real feed.
    static let skeletons = [
        FeedItem(id: -1, at: "2026-01-01T12:00:00Z", kind: "intervention", media: "tv", channel: "Média",
                 person: "Nom de la personnalité", role: "Fonction de la personnalité", party: "",
                 title: "Un titre de passage qui tient sur un peu plus d’une ligne", durationSec: 30, hasMedia: true),
        FeedItem(id: -2, at: "2026-01-01T12:00:00Z", kind: "citation", media: "radio", channel: "Média",
                 person: "Nom de personnalité", role: "Fonction", party: "",
                 title: "Un titre plus court", durationSec: 30, hasMedia: true),
        FeedItem(id: -3, at: "2026-01-01T12:00:00Z", kind: "intervention", media: "radio", channel: "Média",
                 person: "Nom de la personnalité", role: "Fonction de la personnalité", party: "",
                 title: "Un titre de passage plus long, qui occupe deux lignes pleines dans la carte du fil", durationSec: 30, hasMedia: true),
        FeedItem(id: -4, at: "2026-01-01T12:00:00Z", kind: "intervention", media: "tv", channel: "Média",
                 person: "Nom de personnalité", role: "Fonction de la personnalité", party: "",
                 title: "Un titre de passage de longueur moyenne", durationSec: 30, hasMedia: true),
    ]
}
