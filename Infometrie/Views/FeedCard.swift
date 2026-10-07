import SwiftUI

/// A compact timeline entry. Opening the row reveals the complete passage.
/// Every kind shares one order: what it is and where it was heard, then who, then the passage.
struct FeedCard: View {
    let item: FeedItem
    /// Seen passages step back: name and title turn secondary and "✓ Vu" follows the date.
    var seen = false
    @Environment(\.dynamicTypeSize) private var dynamicType

    var body: some View {
        // Two groups read faster than five evenly spaced lines: what and when, then who and what was said.
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                header
                source
            }
            VStack(alignment: .leading, spacing: 4) {
                PassageSpeaker(item: item, dimmed: seen)
                title
            }
        }
        // Rows on a plain page, separated by a hairline, rather than cards: the Medium reading list.
        // A bar in the kind's color runs down the left edge, so the type reads while scrolling.
        .padding(.vertical, 16).padding(.leading, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .leading) {
            Capsule().fill(item.kindColor).frame(width: 4).padding(.vertical, 12).accessibilityHidden(true)
        }
        .overlay(alignment: .bottom) { AppRule() }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityValue(seen ? "Déjà vu" : "")
        .accessibilityHint(item.canPlay ? "Ouvre le texte et le lecteur de ce passage" : "Ouvre le texte de cette publication")
    }

    private var title: some View {
        Text(item.displayTitle)
            .font(.title3.weight(seen ? .semibold : .bold)).foregroundStyle(seen ? Brand.secondary : Brand.ink)
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
                VStack(alignment: .leading, spacing: 6) { PassageDate(item: item); channel; seenMark; PassageDuration(item: item) }
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) { PassageDate(item: item); channel; seenMark; Spacer(minLength: 0); PassageDuration(item: item) }
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) { PassageDate(item: item); seenMark; Spacer(minLength: 0); PassageDuration(item: item) }
                        channel
                    }
                }
            }
        }
        .font(.footnote)
    }

    /// "· ✓ Vu" after the date (and the channel name when no logo shows it): the state never rests on color alone. VoiceOver reads the row's value instead.
    @ViewBuilder private var seenMark: some View {
        if seen {
            HStack(spacing: 8) {
                Text("·")
                Label("Vu", systemImage: "checkmark").fontWeight(.semibold)
            }
            .foregroundStyle(Brand.secondary)
            .fixedSize()
            .accessibilityHidden(true)
        }
    }

    @ViewBuilder private var channel: some View {
        if !channelLine.isEmpty {
            Text(channelLine).foregroundStyle(Brand.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }

    /// The logo at the top names the channel; its name shows here only when no logo is bundled.
    private var channelLine: String { ChannelMark.hasLogo(for: item) ? "" : item.channel }
}

/// Placeholder cards while the feed loads, drawn from the real card layout so they follow its changes.
struct FeedSkeleton: View {
    var label = "Chargement du journal"

    var body: some View {
        VStack(spacing: 0) {
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
                 title: "Un titre de passage plus long, qui occupe deux lignes pleines dans la carte du journal", durationSec: 30, hasMedia: true),
        FeedItem(id: -4, at: "2026-01-01T12:00:00Z", kind: "intervention", media: "tv", channel: "Média",
                 person: "Nom de personnalité", role: "Fonction de la personnalité", party: "",
                 title: "Un titre de passage de longueur moyenne", durationSec: 30, hasMedia: true),
    ]
}
