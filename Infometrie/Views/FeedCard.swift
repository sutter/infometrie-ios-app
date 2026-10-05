import SwiftUI

/// A compact timeline entry. Opening the row reveals the complete passage.
/// Every kind shares one order: what it is and where it was heard, then who, then the passage.
struct FeedCard: View {
    let item: FeedItem
    @Environment(\.dynamicTypeSize) private var dynamicType

    var body: some View {
        // Two groups read faster than five evenly spaced lines: what and when, then who and what was said.
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                header
                source
            }
            VStack(alignment: .leading, spacing: 6) {
                PassageSpeaker(item: item)
                title
            }
        }
        .padding(16)
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

    /// The kind, and the channel logo on the right.
    private var header: some View {
        AdaptiveRow {
            KindTag(item: item)
            if !dynamicType.isAccessibilitySize { Spacer(minLength: 0) }
            // Logos are the only color on the card: large enough to recognize at a glance.
            ChannelMark(item: item, size: 24)
        }
    }

    /// Date on the left, listening duration on the right.
    /// A channel too long for the line moves below the date instead of squeezing beside it.
    @ViewBuilder private var source: some View {
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

    @ViewBuilder private var channel: some View {
        if !channelLine.isEmpty {
            Text(channelLine).foregroundStyle(Brand.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }

    /// The logo at the top names the channel; its name shows here only when no logo is bundled.
    private var channelLine: String { ChannelMark.hasLogo(for: item) ? "" : item.channel }

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
