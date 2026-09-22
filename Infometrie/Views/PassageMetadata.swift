import SwiftUI

/// Consistent source and byline across the feed and the passage.
struct PassageSource: View {
    let item: FeedItem
    @Environment(\.dynamicTypeSize) private var dynamicType

    var body: some View {
        AdaptiveRow {
            HStack(spacing: 8) {
                Image(systemName: item.media.lowercased() == "tv" ? "tv" : "radio")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(item.kindColor)
                    .frame(width: 30, height: 30)
                    .background(item.kindColor.opacity(0.07), in: RoundedRectangle(cornerRadius: 9))
                    .accessibilityHidden(true)
                Text(item.channel)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
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
    var showsKind = true
    private var details: String {
        [item.party, showsKind ? item.kindLabel : ""].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.person).font(.body.weight(.medium)).foregroundStyle(.primary)
            if !details.isEmpty {
                Text(details).font(.subheadline).foregroundStyle(Brand.secondary)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.leading, 12)
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2)
                .fill(item.kindColor.opacity(0.3)).frame(width: 3)
                .accessibilityHidden(true)
        }
    }
}

extension FeedItem {
    var kindColor: Color { isCitation ? Brand.citation : Brand.blue }

    var readableDuration: String {
        let seconds = max(0, durationSec)
        if seconds < 60 { return "\(seconds) s" }
        let remainder = seconds % 60
        return remainder == 0 ? "\(seconds / 60) min" : "\(seconds / 60) min \(remainder) s"
    }
}
