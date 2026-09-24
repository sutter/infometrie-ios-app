import SwiftUI

/// shadcn/ui preset b37ZhrNVw: Nova, Neutral, Indigo (OKLCH → sRGB).
/// Original tokens: Docs/UX/SocialFeed/shadcn-indigo.json.
enum Brand {
    static let background = color(light: 0xFFFFFF, dark: 0x0A0A0A)
    static let card = color(light: 0xFFFFFF, dark: 0x171717)
    static let ink = color(light: 0x0A0A0A, dark: 0xFAFAFA)
    static let primary = color(light: 0x432DD7, dark: 0x372AAC)
    static let primaryForeground = color(light: 0xEEF2FF, dark: 0xEEF2FF)
    // Filled buttons retain the preset's primary. Inline actions use its lighter
    // chart-1 indigo in dark mode to stay readable on neutral surfaces.
    static let tint = color(light: 0x432DD7, dark: 0xA3B3FF)
    static let secondary = color(light: 0x737373, dark: 0xA1A1A1)
    static let surface = color(light: 0xF5F5F5, dark: 0x262626)
    static let inputBorder = color(light: 0xE5E5E5, dark: 0xFFFFFF, darkAlpha: 0.15)
    static let selection = color(light: 0xF5F5F5, dark: 0x262626)
    static let selectionForeground = color(light: 0x171717, dark: 0xFAFAFA)
    static let rule = color(light: 0xE5E5E5, dark: 0xFFFFFF, darkAlpha: 0.10)
    static let sidebar = color(light: 0xFAFAFA, dark: 0x171717)
    static let sidebarRule = color(light: 0xE5E5E5, dark: 0xFFFFFF, darkAlpha: 0.10)
    static let destructive = color(light: 0xE7000B, dark: 0xFF6467)

    // Strengthen small secondary labels on shaded surfaces (at least 4.5:1).
    static let secondaryOnSurface = color(light: 0x686868, dark: 0xB3B3B3)

    private static func color(light: UInt32, dark: UInt32, darkAlpha: CGFloat = 1) -> Color {
        Color(uiColor: UIColor { traits in
            let isDark = traits.userInterfaceStyle == .dark
            let value = isDark ? dark : light
            return UIColor(
                red: CGFloat((value >> 16) & 0xFF) / 255,
                green: CGFloat((value >> 8) & 0xFF) / 255,
                blue: CGFloat(value & 0xFF) / 255,
                alpha: isDark ? darkAlpha : 1
            )
        })
    }
}

struct Wordmark: View {
    var size: CGFloat = 22
    var body: some View {
        Text("InfoMétrie")
        .font(.system(size: size, weight: .bold))
        .tracking(-0.7)
        .foregroundStyle(Brand.ink)
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
            .foregroundStyle(prominent ? Brand.primaryForeground : Brand.ink)
            .background(prominent ? Brand.primary : .clear, in: Capsule())
            .overlay { if !prominent { Capsule().strokeBorder(Brand.rule) } }
            .contentShape(Capsule())
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
        Label(item.kindLabel, systemImage: item.kindSymbol)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(item.kindColor)
    }
}

/// The API names embedded logos; unknown keys retain a readable media identity.
struct ChannelMark: View {
    let item: FeedItem
    var size: CGFloat = 20
    private var logo: UIImage? { item.channelLogoAsset.flatMap { UIImage(named: $0) } }
    static func hasLogo(for item: FeedItem) -> Bool {
        item.channelLogoAsset.flatMap { UIImage(named: $0) } != nil
    }

    var body: some View {
        Group {
            if let logo {
                Image(uiImage: logo).resizable().scaledToFit()
                    .frame(width: logoWidth(for: logo), height: size)
            } else if item.isTweet || item.media.lowercased() == "x" || item.channelKey.lowercased() == "x" {
                Text("𝕏").font(.system(size: size * 0.75, weight: .semibold, design: .monospaced))
                    .frame(width: size, height: size)
            } else {
                Image(systemName: item.media.lowercased() == "tv" ? "tv" : item.media.lowercased() == "radio" ? "radio" : "newspaper")
                    .font(.system(size: size * 0.8, weight: .medium))
                    .frame(width: size, height: size)
            }
        }.fixedSize(horizontal: true, vertical: true).foregroundStyle(Brand.tint).accessibilityHidden(true)
    }

    private func logoWidth(for image: UIImage) -> CGFloat {
        let aspectRatio = image.size.height > 0 ? image.size.width / image.size.height : 1
        return size * min(max(aspectRatio, 1), 3.2)
    }
}

struct PersonAvatar: View {
    let item: FeedItem
    var size: CGFloat = 42
    var body: some View {
        Text(item.initials).font(.system(size: size * 0.32, weight: .semibold))
            .foregroundStyle(Brand.tint)
            .frame(width: size, height: size)
            .background(Brand.surface, in: Circle())
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
            } else { Text("Démonstration · données fictives") }
        }
            .font(.footnote).foregroundStyle(Brand.secondary)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier("demo-banner")
    }
}

enum AppLayout {
    static let maximumWidth: CGFloat = 1100
    static let readingWidth: CGFloat = 760
    static let wideMargin: CGFloat = 24
    static let controlRadius: CGFloat = 14
}

struct PageHeading: View {
    let title: String
    var subtitle: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.title2.bold()).foregroundStyle(Brand.ink)
                .fixedSize(horizontal: false, vertical: true).accessibilityAddTraits(.isHeader)
            if let subtitle {
                Text(subtitle).font(.subheadline).foregroundStyle(Brand.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct AppSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            AppRule()
            Text(title).font(.headline)
                .foregroundStyle(Brand.ink).fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            content()
        }
    }
}

struct AppEmptyState: View {
    let title: String
    let icon: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: icon).font(.title2).foregroundStyle(Brand.tint).accessibilityHidden(true)
            Text(title).font(.title3.bold())
                .foregroundStyle(Brand.ink).accessibilityAddTraits(.isHeader)
            Text(message).font(.body).foregroundStyle(Brand.secondary)
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 28)
    }
}

/// Keep native navigation controls and a consistent title across sheets and details.
private struct AppNavigationTitle: ViewModifier {
    let title: String
    func body(content: Content) -> some View {
        content.navigationTitle(title).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(title).font(.headline)
                        .foregroundStyle(Brand.ink).accessibilityAddTraits(.isHeader)
                }
            }
            .toolbarBackground(Brand.background, for: .navigationBar)
    }
}

extension View {
    func appNavigationTitle(_ title: String) -> some View {
        modifier(AppNavigationTitle(title: title))
    }

    func appInput() -> some View {
        background(Brand.surface, in: RoundedRectangle(cornerRadius: AppLayout.controlRadius))
            .overlay { RoundedRectangle(cornerRadius: AppLayout.controlRadius).strokeBorder(Brand.inputBorder) }
    }
}

struct AppRule: View {
    var body: some View {
        Rectangle().fill(Brand.rule).frame(height: 0.5).accessibilityHidden(true)
    }
}

/// A visible underline and a selected trait make the state independent of color.
struct AppTabButton: View {
    let title: String
    let selected: Bool
    var accent: Color = Brand.tint
    var compact = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font((compact ? Font.subheadline : .body).weight(selected ? .semibold : .regular))
                .foregroundStyle(selected ? Brand.ink : Brand.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, compact ? 8 : 12).padding(.vertical, 12)
                .frame(minWidth: 44, minHeight: 48)
                .overlay(alignment: .bottom) {
                    if selected { Capsule().fill(accent).frame(height: 3) }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct ErrorNotice: View {
    let message: String
    var retry: (() -> Void)?
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(message, systemImage: "exclamationmark.circle").font(.subheadline)
                .foregroundStyle(Brand.ink).fixedSize(horizontal: false, vertical: true)
            if let retry { Button("Réessayer", action: retry).buttonStyle(ActionButtonStyle()) }
        }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(Brand.surface)
            .overlay(alignment: .leading) { Rectangle().fill(Brand.destructive).frame(width: 3) }
            .accessibilityElement(children: .contain)
    }
}
