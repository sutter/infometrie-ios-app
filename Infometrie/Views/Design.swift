import SwiftUI

enum Brand {
    static let blue = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.48, green: 0.59, blue: 1, alpha: 1)
            : UIColor(red: 0.19, green: 0.28, blue: 0.87, alpha: 1)
    })
    static let navy = Color(red: 0.075, green: 0.105, blue: 0.24)
    static let background = Color(uiColor: .systemGroupedBackground)
    static let card = Color(uiColor: .secondarySystemGroupedBackground)
}

struct Wordmark: View {
    var size: CGFloat = 27
    var body: some View {
        HStack(spacing: 0) {
            Text("Info").fontWeight(.bold)
            Text("Métrie").fontWeight(.regular).foregroundStyle(Brand.blue)
            Circle().fill(Brand.blue).frame(width: 6, height: 6).padding(.leading, 3).offset(y: -8)
        }
        .font(.system(size: size, design: .rounded))
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityElement(children: .ignore).accessibilityLabel("InfoMétrie")
    }
}

struct Eyebrow: View {
    let text: String
    var body: some View { Text(text.uppercased()).font(.system(.caption2, design: .monospaced, weight: .semibold)).tracking(1.4).foregroundStyle(.secondary) }
}

struct KindBadge: View {
    let item: FeedItem
    var body: some View {
        Label(item.kindLabel, systemImage: item.isCitation ? "quote.bubble" : "waveform")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(item.isCitation ? Color.purple : Brand.blue)
            .padding(.horizontal, 9).padding(.vertical, 5)
            .background((item.isCitation ? Color.purple : Brand.blue).opacity(0.08), in: Capsule())
    }
}

struct PersonAvatar: View {
    let item: FeedItem
    var size: CGFloat = 42
    var body: some View {
        Text(item.initials).font(.system(size: size * 0.32, weight: .semibold, design: .rounded))
            .foregroundStyle(item.isCitation ? .purple : Brand.blue)
            .frame(width: size, height: size)
            .background((item.isCitation ? Color.purple : Brand.blue).opacity(0.08), in: RoundedRectangle(cornerRadius: size * 0.34))
            .accessibilityHidden(true)
    }
}

struct WaveformArt: View {
    var color: Color = .white
    var body: some View {
        GeometryReader { geometry in
            HStack(alignment: .center, spacing: 3) {
                ForEach(0..<18, id: \.self) { index in
                    let value = 0.15 + abs(sin(Double(index) * 1.9)) * (0.22 + 0.6 * abs(sin(Double(index) * 0.18)))
                    Capsule().fill(color.opacity(0.30 + value * 0.6)).frame(height: geometry.size.height * value)
                }
            }.frame(maxHeight: .infinity)
        }.accessibilityHidden(true)
    }
}

struct DemoBanner: View {
    @Environment(\.dynamicTypeSize) private var dynamicType
    var body: some View {
        Group {
            if dynamicType.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Mode démo").fontWeight(.semibold)
                    Text("Données fictives")
                }.frame(maxWidth: .infinity, alignment: .leading)
            } else { Label("Démonstration · données fictives", systemImage: "sparkles") }
        }
            .font(.caption.weight(.medium)).foregroundStyle(Brand.blue)
            .padding(.horizontal, 12).padding(.vertical, 8)
            .frame(maxWidth: .infinity).background(Brand.blue.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
            .accessibilityIdentifier("demo-banner")
    }
}

struct ErrorNotice: View {
    let message: String
    var retry: (() -> Void)?
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(message, systemImage: "exclamationmark.circle").font(.subheadline)
            if let retry { Button("Réessayer", action: retry).font(.subheadline.weight(.semibold)) }
        }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 18))
            .accessibilityElement(children: .contain)
    }
}

struct FeedCard: View {
    let item: FeedItem
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(spacing: 10) {
                Label(item.channel, systemImage: item.media.lowercased() == "tv" ? "tv" : "radio")
                    .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Spacer()
                if let date = item.date { Text(date, style: .time).font(.caption.monospacedDigit()).foregroundStyle(.tertiary) }
            }
            HStack(alignment: .top, spacing: 12) {
                PersonAvatar(item: item)
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.person).font(.headline).foregroundStyle(.primary)
                    Text([item.party, item.role].filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
                Spacer(minLength: 0)
            }
            Text(item.title).font(.system(.title3, design: .default, weight: .semibold)).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
            HStack {
                KindBadge(item: item)
                Spacer()
                if item.hasMedia {
                    Text(item.durationLabel).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    Image(systemName: "play.circle.fill").font(.title2).foregroundStyle(Brand.blue)
                } else { Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary) }
            }
        }
        .padding(19).frame(maxWidth: .infinity, alignment: .leading)
        .background(Brand.card, in: RoundedRectangle(cornerRadius: 24))
        .overlay { RoundedRectangle(cornerRadius: 24).strokeBorder(.primary.opacity(0.035)) }
        .accessibilityElement(children: .combine)
    }
}
