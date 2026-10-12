import SwiftUI

/// A compact timeline entry. Opening the row reveals the complete passage.
/// Every kind shares one order: what it is and where it was heard, then who, then the passage.
struct FeedCard: View {
    let item: FeedItem
    /// Seen passages step back: name and title turn secondary and "✓ Vu" follows the date.
    var seen = false
    /// A favorite shows a vermillon star at the end of the facts, so the journal says it without a long press.
    var favorite = false
    /// A favorite gone from the server's history steps back like a seen one and says "Plus disponible".
    var unavailable = false
    /// The Paris day the list is about: its passages show their time alone ("14:52", not "09/10 14:52").
    var day: String?
    @Environment(\.dynamicTypeSize) private var dynamicType
    /// 18 pt at the default size, between `headline` (17) and `title3` (20, until 2026-10-09: the user found it a
    /// little large); it scales with Dynamic Type and the S / M / L reading size like `title3`.
    @ScaledMetric(relativeTo: .title3) private var titleSize = 18.0

    var body: some View {
        // Two groups read faster than five evenly spaced lines: what and when, then who and what was said.
        VStack(alignment: .leading, spacing: 12) {
            header
            VStack(alignment: .leading, spacing: 4) {
                PassageSpeaker(item: item, dimmed: dimmed)
                title
            }
        }
        // Rows on a plain page, separated by a hairline, rather than cards: the Medium reading list.
        // A bar in the kind's color runs down the left edge, so the type reads while scrolling. It sits in the
        // page margin, 8 pt from the screen edge, clear of the text: hugging the text it read as part of it.
        .padding(.vertical, 16).padding(.leading, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .leading) {
            Capsule().fill(item.kindColor).frame(width: 6).padding(.vertical, 12)
                .offset(x: -8).accessibilityHidden(true)
        }
        .overlay(alignment: .bottom) { AppRule() }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityValue([unavailable ? "Plus disponible" : nil, seen ? "Déjà vu" : nil, favorite ? "Favori" : nil]
            .compactMap(\.self).joined(separator: ", "))
        .accessibilityHint(item.canPlay ? "Ouvre le texte et le lecteur de ce passage" : "Ouvre le texte de cette publication")
    }

    private var dimmed: Bool { seen || unavailable }

    private var title: some View {
        Text(item.displayTitle)
            .font(.system(size: titleSize, weight: dimmed ? .semibold : .bold)).foregroundStyle(dimmed ? Brand.secondary : Brand.ink)
            .lineLimit(dynamicType.isAccessibilitySize ? nil : 4)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// One line (the user, 2026-10-09; it took two): the kind, when, how long, then the channel logo on the right.
    /// A publication X shows no tile there: its tag and its bar already say X. Too long for the line, the facts move
    /// under the tag; at accessibility sizes everything stacks.
    @ViewBuilder private var header: some View {
        if dynamicType.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 6) {
                KindTag(item: item)
                facts
                logo
            }
        } else {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { KindTag(item: item); facts; Spacer(minLength: 0); logo }
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) { KindTag(item: item); Spacer(minLength: 0); logo }
                    facts
                }
            }
        }
    }

    /// "14:52 · 47 s", then "· Plus disponible", "· ✓ Vu", then "· ★" for a favorite, then the channel's name when no logo shows it, as one
    /// text: separate "·" glyphs and a fixed-size row failed the accessibility audit's contrast and clipping checks
    /// (2026-10-10).
    private var facts: some View {
        var parts: [Text] = []
        if let date = PassageDate.text(item, day: day) { parts.append(date) }
        if item.canPlay && item.durationSec > 0 { parts.append(Text(item.readableDuration)) }
        if unavailable { parts.append(Text("Plus disponible").fontWeight(.semibold)) }
        if seen { parts.append(Text("\(Image(systemName: "checkmark")) Vu").fontWeight(.semibold)) }
        if favorite { parts.append(Text(Image(systemName: "star.fill")).foregroundStyle(Brand.accent)) }
        if !channelLine.isEmpty { parts.append(Text(channelLine)) }
        let line = parts.dropFirst().reduce(parts.first ?? Text("")) { $0 + Text("  ·  ") + $1 }
        return line.font(.footnote).monospacedDigit().foregroundStyle(Brand.secondary).lineLimit(1)
            .accessibilityLabel(spokenFacts)
    }

    /// The date in full and the listening duration; "Plus disponible", "Déjà vu" and "Favori" are the row's value.
    private var spokenFacts: Text {
        var parts: [Text] = []
        if let date = item.date { parts.append(PassageDate.spoken(date)) }
        if item.canPlay && item.durationSec > 0 { parts.append(Text("durée d’écoute : \(item.readableDuration)")) }
        if !channelLine.isEmpty { parts.append(Text(channelLine)) }
        return parts.dropFirst().reduce(parts.first ?? Text("")) { $0 + Text(", ") + $1 }
    }

    /// Logos are the only color on the card: large enough to recognize at a glance.
    @ViewBuilder private var logo: some View {
        if !item.isTweet { ChannelMark(item: item, size: 24) }
    }

    /// The logo names the channel; its name shows in the facts only when no logo is bundled.
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
