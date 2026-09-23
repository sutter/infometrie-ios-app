import SwiftUI

/// Consistent source and byline across the feed and the passage.
struct PassageSource: View {
    let item: FeedItem
    @Environment(\.dynamicTypeSize) private var dynamicType

    var body: some View {
        AdaptiveRow {
            HStack(spacing: 8) {
                ChannelMark(item: item)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Brand.primary)
                    .frame(width: 30, height: 30)
                    .accessibilityHidden(true)
                Text(item.channel)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Brand.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !dynamicType.isAccessibilitySize { Spacer(minLength: 0) }
            if let date = item.date {
                Text("\(date, format: .dateTime.day(.twoDigits).month(.twoDigits)) · \(date, style: .time)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(Brand.secondary)
                    .fixedSize(horizontal: !dynamicType.isAccessibilitySize, vertical: true)
                    .accessibilityLabel(Text(date, format: .dateTime.day().month(.wide).year().hour().minute()))
            }
        }
    }
}

struct PassageByline: View {
    let item: FeedItem
    private var details: String {
        var values = [item.role, item.party].filter { !$0.isEmpty }
        if values.count == 2, values[0] == values[1] { values.removeLast() }
        return values.joined(separator: " · ")
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            PersonAvatar(item: item, size: 44)
            VStack(alignment: .leading, spacing: 5) {
                Text(item.person).font(.headline).foregroundStyle(Brand.ink)
                if !details.isEmpty { Text(details).font(.subheadline).foregroundStyle(Brand.secondary) }
            }.fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct PassageHeading: View {
    let item: FeedItem
    let titleIdentifier: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PassageByline(item: item)
            Text(item.title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Brand.ink)
                .fixedSize(horizontal: false, vertical: true).accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier(titleIdentifier)
            VStack(alignment: .leading, spacing: 8) {
                PassageSource(item: item)
                AdaptiveRow {
                    KindBadge(item: item)
                    Spacer(minLength: 0)
                    if item.canPlay && item.durationSec > 0 {
                        Label(item.readableDuration, systemImage: "headphones")
                            .font(.subheadline).foregroundStyle(Brand.secondary)
                    }
                }
            }
        }
    }
}

extension FeedItem {
    var kindColor: Color { Brand.primary }
    var kindSymbol: String { isTweet ? "text.bubble" : isCitation ? "quote.bubble" : kind == "intervention" ? "waveform" : "doc.text" }

    var readableDuration: String {
        let seconds = max(0, durationSec)
        if seconds < 60 { return "\(seconds) s" }
        let remainder = seconds % 60
        return remainder == 0 ? "\(seconds / 60) min" : "\(seconds / 60) min \(remainder) s"
    }
}
