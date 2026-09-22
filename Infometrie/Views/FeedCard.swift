import SwiftUI

/// One destination and one generous touch target, with a distinct reading area and action.
struct FeedCard: View {
    let item: FeedItem
    @Environment(\.dynamicTypeSize) private var dynamicType

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 16) {
                PassageSource(item: item)
                Text(item.title)
                    .font(.system(.title3, design: .serif, weight: .semibold))
                    .lineSpacing(3)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                PassageByline(item: item)
            }
            .padding(20)

            action
                .padding(.horizontal, 20).padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Brand.blue.opacity(0.06))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Brand.card)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay { RoundedRectangle(cornerRadius: 22).strokeBorder(.primary.opacity(0.06)) }
        .shadow(color: .black.opacity(0.035), radius: 10, x: 0, y: 4)
        .contentShape(RoundedRectangle(cornerRadius: 22))
        .accessibilityElement(children: .combine)
        .accessibilityHint(item.hasMedia ? "Ouvre le texte et le lecteur de ce passage" : "Ouvre le texte de ce passage")
    }

    private var action: some View {
        AdaptiveRow {
            HStack(spacing: 10) {
                Image(systemName: item.hasMedia ? "play.fill" : "text.alignleft")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(Brand.action, in: Circle())
                    .accessibilityHidden(true)
                Text(item.hasMedia ? "Lire et écouter" : "Lire le passage")
                    .font(.body.weight(.semibold)).foregroundStyle(Brand.blue)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !dynamicType.isAccessibilitySize { Spacer(minLength: 0) }
            if item.hasMedia && item.durationSec > 0 {
                Text(item.readableDuration).font(.subheadline.monospacedDigit()).foregroundStyle(Brand.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel("Durée : \(item.readableDuration)")
            }
        }
    }
}
