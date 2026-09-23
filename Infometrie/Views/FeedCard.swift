import SwiftUI

/// A compact timeline entry. Opening the row reveals the complete passage.
struct FeedCard: View {
    let item: FeedItem
    @Environment(\.dynamicTypeSize) private var dynamicType

    var body: some View {
        Group {
            if dynamicType.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 12) {
                        PersonAvatar(item: item, size: 44)
                        byline
                    }
                    content
                }
            } else {
                HStack(alignment: .top, spacing: 12) {
                    PersonAvatar(item: item, size: 44)
                    VStack(alignment: .leading, spacing: 6) {
                        byline
                        content
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint(item.canPlay ? "Ouvre le texte et le lecteur de ce passage" : "Ouvre le texte de cette publication")
    }

    private var byline: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(item.person).font(.headline).foregroundStyle(Brand.ink)
            let details = [item.role, item.party == item.role ? "" : item.party]
                .filter { !$0.isEmpty }.joined(separator: " · ")
            if !details.isEmpty {
                Text(details).font(.subheadline).foregroundStyle(Brand.secondary)
                    .lineLimit(dynamicType.isAccessibilitySize ? nil : 1)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(item.title)
                .font(.body).foregroundStyle(Brand.ink)
                .lineLimit(dynamicType.isAccessibilitySize ? nil : 5)
                .fixedSize(horizontal: false, vertical: true)
            provenance
        }
    }

    private var provenance: some View {
        VStack(alignment: .leading, spacing: 6) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    source.fixedSize(horizontal: true, vertical: false)
                    Spacer(minLength: 0)
                    date.fixedSize(horizontal: true, vertical: false)
                }
                VStack(alignment: .leading, spacing: 4) { source; date }
            }
            AdaptiveRow {
                Label(item.kindLabel, systemImage: item.kindSymbol)
                    .foregroundStyle(Brand.primary)
                    .fixedSize(horizontal: false, vertical: true)
                if !dynamicType.isAccessibilitySize { Spacer(minLength: 0) }
                if item.canPlay && item.durationSec > 0 {
                    Label(item.readableDuration, systemImage: "headphones")
                        .monospacedDigit().foregroundStyle(Brand.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityLabel("Durée d’écoute : \(item.readableDuration)")
                }
            }
        }
        .font(.footnote)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var source: some View {
        HStack(spacing: 4) {
            ChannelMark(item: item, size: 16)
            Text(item.channel).foregroundStyle(Brand.secondary)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder private var date: some View {
        if let date = item.date {
            Text("\(date, format: .dateTime.day(.twoDigits).month(.twoDigits)) · \(date, style: .time)")
                .foregroundStyle(Brand.secondary).monospacedDigit()
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(Text(date, format: .dateTime.day().month(.wide).year().hour().minute()))
        }
    }
}
