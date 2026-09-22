import SwiftUI

/// The whole card opens the passage; metadata describes it without a separate action.
struct FeedCard: View {
    let item: FeedItem
    @Environment(\.dynamicTypeSize) private var dynamicType

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PassageSource(item: item)
            Text(item.title)
                .font(.system(.title3, design: .serif, weight: .semibold))
                .lineSpacing(3)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            PassageByline(item: item, showsKind: false)
            metadata
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Brand.card)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay { RoundedRectangle(cornerRadius: 22).strokeBorder(.primary.opacity(0.06)) }
        .shadow(color: .black.opacity(0.035), radius: 10, x: 0, y: 4)
        .contentShape(RoundedRectangle(cornerRadius: 22))
        .accessibilityElement(children: .combine)
        .accessibilityHint(item.hasMedia ? "Ouvre le texte et le lecteur de ce passage" : "Ouvre le texte de ce passage")
    }

    private var metadata: some View {
        AdaptiveRow {
            Label(item.kindLabel, systemImage: item.isCitation ? "quote.bubble" : "waveform")
                .font(.subheadline.weight(.semibold)).foregroundStyle(item.kindColor)
                .fixedSize(horizontal: false, vertical: true)
            if !dynamicType.isAccessibilitySize { Spacer(minLength: 0) }
            if item.hasMedia && item.durationSec > 0 {
                Label(item.readableDuration, systemImage: "headphones")
                    .font(.subheadline.monospacedDigit()).foregroundStyle(Brand.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel("Durée d’écoute : \(item.readableDuration)")
            }
        }
    }
}
