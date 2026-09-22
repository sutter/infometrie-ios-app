import SwiftUI

enum Brand {
    static let blue = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.48, green: 0.59, blue: 1, alpha: 1)
            : UIColor(red: 0.19, green: 0.28, blue: 0.87, alpha: 1)
    })
    static let citation = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 1, green: 0.52, blue: 0.56, alpha: 1)
            : UIColor(red: 0.72, green: 0.13, blue: 0.19, alpha: 1)
    })
    static let secondary = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.76, green: 0.78, blue: 0.83, alpha: 1)
            : UIColor(red: 0.30, green: 0.33, blue: 0.39, alpha: 1)
    })
    static let action = Color(red: 0.19, green: 0.28, blue: 0.78)
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

/// Shared controls grow with Dynamic Type and retain a generous hit area.
struct ActionButtonStyle: ButtonStyle {
    var prominent = false
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 16).padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 52)
            .foregroundStyle(prominent ? Color.white : Brand.blue)
            .background(prominent ? Brand.action : Brand.card, in: RoundedRectangle(cornerRadius: 16))
            .overlay { if !prominent { RoundedRectangle(cornerRadius: 16).strokeBorder(Brand.blue.opacity(0.35)) } }
            .contentShape(RoundedRectangle(cornerRadius: 16))
            .opacity(isEnabled ? (configuration.isPressed ? 0.75 : 1) : 0.45)
    }
}

/// A row at regular sizes becomes a column before labels become cramped.
struct AdaptiveRow<Content: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicType
    @ViewBuilder var content: () -> Content
    var body: some View {
        let layout = dynamicType.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(spacing: 12))
        layout { content() }
    }
}

struct KindBadge: View {
    let item: FeedItem
    var body: some View {
        Label(item.kindLabel, systemImage: item.isCitation ? "quote.bubble" : "waveform")
            .font(.subheadline.weight(.medium))
            .foregroundStyle(item.kindColor)
    }
}

struct PersonAvatar: View {
    let item: FeedItem
    var size: CGFloat = 42
    var body: some View {
        Text(item.initials).font(.system(size: size * 0.32, weight: .semibold, design: .rounded))
            .foregroundStyle(Brand.blue)
            .frame(width: size, height: size)
            .background(Brand.blue.opacity(0.06), in: RoundedRectangle(cornerRadius: size * 0.34))
            .accessibilityHidden(true)
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
            .font(.footnote.weight(.medium)).foregroundStyle(Brand.blue)
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
            if let retry { Button("Réessayer", action: retry).buttonStyle(ActionButtonStyle()) }
        }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 18))
            .accessibilityElement(children: .contain)
    }
}
