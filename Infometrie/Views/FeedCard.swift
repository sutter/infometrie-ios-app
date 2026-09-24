import SwiftUI

/// A compact timeline entry. Opening the row reveals the complete passage.
struct FeedCard: View {
    let item: FeedItem
    @Environment(\.dynamicTypeSize) private var dynamicType

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            byline
            Text(displayTitle)
                .font(.body).foregroundStyle(Brand.ink)
                .lineLimit(dynamicType.isAccessibilitySize ? nil : 4)
                .fixedSize(horizontal: false, vertical: true)
            metadata
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint(item.canPlay ? "Ouvre le texte et le lecteur de ce passage" : "Ouvre le texte de cette publication")
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
            .foregroundStyle(Brand.tint)
            .frame(width: 36, height: 36)
            .background(Brand.surface, in: Circle())
            .accessibilityHidden(true)
    }

    private var speaker: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(item.person)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Brand.ink)
                .lineLimit(1)
            let role = item.role.trimmingCharacters(in: .whitespacesAndNewlines)
            let party = item.party.trimmingCharacters(in: .whitespacesAndNewlines)
            let overlaps = role.range(of: party, options: [.anchored, .caseInsensitive, .diacriticInsensitive]) != nil
                || party.range(of: role, options: [.anchored, .caseInsensitive, .diacriticInsensitive]) != nil
            let details = role.isEmpty ? party : party.isEmpty || overlaps ? role : "\(role) · \(party)"
            if !details.isEmpty {
                Text(details)
                    .font(.footnote)
                    .foregroundStyle(Brand.secondary)
                    .lineLimit(1)
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
            kindMark
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

    private var sourceAndKind: some View {
        HStack(spacing: 8) {
            source
            kindMark
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
        HStack(spacing: 8) {
            date
            if item.canPlay && item.durationSec > 0 {
                Rectangle()
                    .fill(Brand.rule)
                    .frame(width: 1, height: 14)
                    .accessibilityHidden(true)
                duration
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    @ViewBuilder private var duration: some View {
        if item.canPlay && item.durationSec > 0 {
            Label(item.readableDuration, systemImage: "headphones")
                .monospacedDigit()
                .foregroundStyle(Brand.secondary)
                .fixedSize()
                .accessibilityLabel("Durée d’écoute : \(item.readableDuration)")
        }
    }

    private var source: some View {
        HStack(spacing: 7) {
            ChannelMark(item: item, size: 20)
            if !ChannelMark.hasLogo(for: item) {
                Text(item.channel).foregroundStyle(Brand.secondary)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(item.channel)
    }

    @ViewBuilder private var date: some View {
        if let date = item.date {
            Text("\(date, format: .dateTime.day(.twoDigits).month(.twoDigits)) · \(date, style: .time)")
                .foregroundStyle(Brand.secondary).monospacedDigit()
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(Text(date, format: .dateTime.day().month(.wide).year().hour().minute()))
        }
    }

    @ViewBuilder private var compactDate: some View {
        if let date = item.date {
            Text("\(date, format: .dateTime.day(.twoDigits).month(.twoDigits)) \(date, style: .time)")
                .foregroundStyle(Brand.secondary)
                .monospacedDigit()
                .fixedSize(horizontal: true, vertical: false)
                .accessibilityLabel(Text(date, format: .dateTime.day().month(.wide).year().hour().minute()))
        }
    }
}
