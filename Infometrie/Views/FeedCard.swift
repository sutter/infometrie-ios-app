import SwiftUI

/// A compact timeline entry. Opening the row reveals the complete passage.
struct FeedCard: View {
    let item: FeedItem
    @Environment(\.dynamicTypeSize) private var dynamicType

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            if item.isCitation {
                citationHeader
                citationSource
                citationSpeaker
                title
            } else {
                byline
                title
                PassageMetadataRow(item: item)
            }
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

    /// A citation leads with what it is and where it was heard, then who is mentioned, then the passage.
    private var citationHeader: some View {
        AdaptiveRow {
            HStack(spacing: 8) {
                KindBadge(item: item)
                Text(item.citedBy.isEmpty ? "mention à l’antenne" : "mention par \(item.citedBy)")
                    .font(.footnote).foregroundStyle(Brand.secondary)
            }
            .fixedSize(horizontal: false, vertical: true)
            if !dynamicType.isAccessibilitySize { Spacer(minLength: 0) }
            ChannelMark(item: item)
        }
    }

    private var citationSource: some View {
        AdaptiveRow {
            HStack(spacing: 8) {
                PassageDate(item: item)
                Text([item.channel, item.mediaLabel].filter { !$0.isEmpty }.joined(separator: " · "))
                    .foregroundStyle(Brand.secondary)
            }
            .fixedSize(horizontal: false, vertical: true)
            if !dynamicType.isAccessibilitySize { Spacer(minLength: 0) }
            PassageDuration(item: item)
        }
        .font(.footnote)
    }

    private var citationSpeaker: some View {
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

    private var byline: some View {
        HStack(spacing: 9) {
            initialsAvatar
            speaker
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var initialsAvatar: some View {
        Text(item.initials)
            .font(.system(size: 12, weight: .semibold))
            // Small text on the shaded circle needs the reinforced secondary to reach 4.5:1.
            .foregroundStyle(Brand.secondaryOnSurface)
            .frame(width: 36, height: 36)
            .background(Brand.surface, in: Circle())
            .accessibilityHidden(true)
    }

    private var speaker: some View {
        VStack(alignment: .leading, spacing: 1) {
            // Two lines at most: a long name or role wraps at large sizes instead of being cut.
            Text(item.person)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Brand.ink)
                .lineLimit(2)
            let role = item.role.trimmingCharacters(in: .whitespacesAndNewlines)
            let party = item.party.trimmingCharacters(in: .whitespacesAndNewlines)
            let overlaps = role.range(of: party, options: [.anchored, .caseInsensitive, .diacriticInsensitive]) != nil
                || party.range(of: role, options: [.anchored, .caseInsensitive, .diacriticInsensitive]) != nil
            let details = role.isEmpty ? party : party.isEmpty || overlaps ? role : "\(role) · \(party)"
            if !details.isEmpty {
                Text(details)
                    .font(.footnote)
                    .foregroundStyle(Brand.secondary)
                    .lineLimit(2)
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
