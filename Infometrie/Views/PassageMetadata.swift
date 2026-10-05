import SwiftUI

/// Source, kind, date and duration on one line, shared by the feed cards and the passage page
/// so both read the same way; it wraps only when the line does not fit.
struct PassageMetadataRow: View {
    let item: FeedItem
    @Environment(\.dynamicTypeSize) private var dynamicType

    var body: some View { metadata }

    private var metadata: some View {
        Group {
            if dynamicType.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 6) {
                    sourceAndKind
                    date
                    duration
                }
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) {
                        sourceAndKind
                        Spacer(minLength: 4)
                        timeAndDuration
                    }
                    HStack(spacing: 6) {
                        compactSourceAndKind
                        Spacer(minLength: 2)
                        compactTimeAndDuration
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        sourceAndKind
                        HStack(spacing: 8) {
                            date
                            Spacer(minLength: 4)
                            duration
                        }
                    }
                }
            }
        }
        .font(.footnote)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var compactSourceAndKind: some View {
        HStack(spacing: 6) {
            ChannelMark(item: item, size: 16)
            if !ChannelMark.hasLogo(for: item) {
                Text(item.channel)
                    .foregroundStyle(Brand.secondary)
                    .lineLimit(1)
            }
            if !item.isTweet { kindMark }
        }
        .font(.caption)
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(item.channel), \(item.kindLabel)")
    }

    private var compactTimeAndDuration: some View {
        HStack(spacing: 6) {
            compactDate
            if item.canPlay && item.durationSec > 0 {
                duration
            }
        }
        .font(.caption)
        .fixedSize(horizontal: true, vertical: false)
    }

    /// The X tile already says what a publication is, so it gets no kind icon.
    private var sourceAndKind: some View {
        HStack(spacing: 8) {
            source
            if !item.isTweet { kindMark }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var kindMark: some View {
        Label(item.kindLabel, systemImage: item.kindSymbol)
            .labelStyle(.iconOnly)
            .foregroundStyle(Brand.secondary)
            .frame(width: 24, height: 24)
            .accessibilityLabel(item.kindLabel)
    }

    private var timeAndDuration: some View {
        HStack(spacing: 6) {
            date
            duration
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var duration: some View { PassageDuration(item: item) }

    private var source: some View { ChannelSource(item: item) }

    private var date: some View { PassageDate(item: item).fixedSize(horizontal: false, vertical: true) }

    private var compactDate: some View { PassageDate(item: item).fixedSize(horizontal: true, vertical: false) }
}

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
            Label(item.readableDuration, systemImage: "headphones")
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
            PassageMetadataRow(item: item)
        }
    }
}

extension FeedItem {
    var kindColor: Color { Brand.ink }
    /// The broadcast medium as readers name it, empty when unknown.
    var mediaLabel: String {
        switch media.lowercased() {
        case "tv": "TV"
        case "radio": "Radio"
        default: ""
        }
    }
    var kindSymbol: String { isTweet ? "text.bubble" : isCitation ? "quote.bubble" : kind == "intervention" ? "waveform" : "doc.text" }

    var readableDuration: String {
        let seconds = max(0, durationSec)
        if seconds < 60 { return "\(seconds) s" }
        let remainder = seconds % 60
        return remainder == 0 ? "\(seconds / 60) min" : "\(seconds / 60) min \(remainder) s"
    }
}
