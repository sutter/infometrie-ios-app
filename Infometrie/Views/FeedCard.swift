import SwiftUI

/// An open editorial entry; the entire surface opens the passage.
struct FeedCard: View {
    let item: FeedItem
    var prominent = false
    @Environment(\.dynamicTypeSize) private var dynamicType
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @ScaledMetric(relativeTo: .title) private var headlineSize = 29.0
    @ScaledMetric(relativeTo: .title) private var columnSize = 35.0
    @ScaledMetric(relativeTo: .largeTitle) private var leadSize = 52.0
    @ScaledMetric(relativeTo: .headline) private var nameSize = 20.0
    @ScaledMetric(relativeTo: .body) private var avatarSize = 60.0

    var body: some View {
        VStack(alignment: .leading, spacing: prominent ? 22 : 18) {
            HStack(alignment: .top, spacing: 14) {
                PersonAvatar(item: item, size: min(avatarSize, 64))
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.person)
                        .font(.system(size: nameSize, weight: .semibold)).foregroundStyle(Brand.ink)
                    let details = [item.role, item.party == item.role ? "" : item.party]
                        .filter { !$0.isEmpty }.joined(separator: " · ")
                    if !details.isEmpty {
                        Text(details).font(.subheadline).foregroundStyle(Brand.secondary)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            }
            Text(item.title)
                .font(.system(size: prominent ? leadSize : horizontalSizeClass == .regular ? columnSize : headlineSize, weight: .semibold, design: .serif))
                .tracking(prominent ? -0.7 : -0.3).lineSpacing(2)
                .foregroundStyle(Brand.ink)
                .fixedSize(horizontal: false, vertical: true)
            provenance
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint(item.canPlay ? "Ouvre le texte et le lecteur de ce passage" : "Ouvre le texte de cette publication")
    }

    private var provenance: some View {
        ViewThatFits(in: .horizontal) {
            if !dynamicType.isAccessibilitySize {
                HStack(spacing: 16) {
                    source.fixedSize(horizontal: true, vertical: false)
                    separator
                    date.fixedSize(horizontal: true, vertical: false)
                    separator
                    kind.fixedSize(horizontal: true, vertical: false)
                    Spacer(minLength: 0)
                    duration.fixedSize(horizontal: true, vertical: false)
                }
            }
            VStack(alignment: .leading, spacing: 10) {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) {
                        source.fixedSize(horizontal: true, vertical: false)
                        Spacer(minLength: 0)
                        date.fixedSize(horizontal: true, vertical: false)
                    }
                    VStack(alignment: .leading, spacing: 6) { source; date }
                }
                AdaptiveRow {
                    kind
                    if !dynamicType.isAccessibilitySize { Spacer(minLength: 0) }
                    duration
                }
            }
        }
        .font(.subheadline)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var source: some View {
        Label {
            Text(item.channel).foregroundStyle(Brand.ink)
        } icon: {
            ChannelMark(item: item)
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

    private var kind: some View {
        Label(item.kindLabel, systemImage: item.kindSymbol)
            .foregroundStyle(Brand.citation)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder private var duration: some View {
        if item.canPlay && item.durationSec > 0 {
            Label(item.readableDuration, systemImage: "headphones")
                .monospacedDigit().foregroundStyle(Brand.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel("Durée d’écoute : \(item.readableDuration)")
        }
    }

    private var separator: some View {
        Rectangle().fill(Brand.rule).frame(width: 0.5, height: 22).accessibilityHidden(true)
    }
}
