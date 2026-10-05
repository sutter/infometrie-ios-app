import SwiftUI

/// Shared neutral palette and rounded surfaces adapted from the Stoic reference.
enum Brand {
    // Neutral, low-contrast surfaces inspired by Stoic. Color remains reserved
    // for actual media branding and destructive system feedback.
    static let background = color(light: 0xF1F2F3, dark: 0x08090A)
    static let card = color(light: 0xFFFFFF, dark: 0x151719)
    /// Reading pages (feed, passage): a plain white page with rows on dividers, after Medium.
    static let page = color(light: 0xFFFFFF, dark: 0x101113)
    static let ink = color(light: 0x111214, dark: 0xF5F5F4)
    static let primary = color(light: 0x151618, dark: 0xF1F1EF)
    static let primaryForeground = color(light: 0xFFFFFF, dark: 0x111214)
    static let tint = color(light: 0x292B2E, dark: 0xE6E6E4)
    static let secondary = color(light: 0x696B70, dark: 0xA0A2A6)
    static let surface = color(light: 0xE7E8EA, dark: 0x1D1F22)
    static let inputBorder = color(light: 0xDCDDDF, dark: 0xFFFFFF, darkAlpha: 0.08)
    static let selection = color(light: 0xE7E8EA, dark: 0x292B2E)
    static let selectionForeground = color(light: 0x151618, dark: 0xF5F5F4)
    static let rule = color(light: 0xDCDDDF, dark: 0xFFFFFF, darkAlpha: 0.09)
    static let sidebar = color(light: 0xF1F2F3, dark: 0x0D0E10)
    static let sidebarRule = color(light: 0xDCDDDF, dark: 0xFFFFFF, darkAlpha: 0.08)
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
    var horizontalPadding: CGFloat = 16
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, horizontalPadding).padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 52)
            .foregroundStyle(prominent ? Brand.primaryForeground : Brand.ink)
            .background(prominent ? Brand.primary : Brand.card, in: Capsule())
            .overlay { if !prominent { Capsule().strokeBorder(Brand.rule) } }
            .contentShape(Capsule())
            .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.45)
            // The button sinks slightly under the finger and springs back.
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// Icon controls without a capsule of their own (player skips, round play button) that sink under the finger.
struct PressableStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(isEnabled ? (configuration.isPressed ? 0.7 : 1) : 0.35)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.92 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
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

/// App motion: short, soft springs that make changes feel continuous without drawing attention.
enum Motion {
    static let standard: Animation = .smooth(duration: 0.32)
    static let quick: Animation = .snappy(duration: 0.22)
}

/// `.animation(_:value:)` that stays still when Reduce Motion is on.
private struct MotionModifier<Value: Equatable>: ViewModifier {
    let animation: Animation
    let value: Value
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.animation(reduceMotion ? nil : animation, value: value)
    }
}

extension View {
    func motion<Value: Equatable>(_ animation: Animation = Motion.standard, value: Value) -> some View {
        modifier(MotionModifier(animation: animation, value: value))
    }
}

/// Loading placeholder instead of a spinner: the real layout, drawn as soft shapes that pulse.
/// The pulse stops with Reduce Motion. `shapes: false` only pulses, for a control that stays readable.
struct Skeleton: ViewModifier {
    var active = true
    var shapes = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dimmed = false

    func body(content: Content) -> some View {
        content
            .redacted(reason: active && shapes ? .placeholder : [])
            .opacity(active && dimmed ? 0.4 : 1)
            .allowsHitTesting(!active)
            .task(id: active && !reduceMotion) {
                guard active && !reduceMotion else { dimmed = false; return }
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { dimmed = true }
            }
    }
}

extension View {
    func skeleton(_ active: Bool = true, shapes: Bool = true) -> some View {
        modifier(Skeleton(active: active, shapes: shapes))
    }
}

/// A brand mark on an inverted-ink tile: X looks the same in the feed tabs, the cards and the passages.
struct MarkTile: View {
    let image: Image
    let size: CGFloat

    var body: some View {
        // Custom symbols ship a medium scale only: size them by font, never by imageScale.
        image.font(.system(size: size * 0.66))
            .foregroundStyle(Brand.primaryForeground)
            .frame(width: size, height: size)
            .background(Brand.primary, in: RoundedRectangle(cornerRadius: size * 0.25, style: .continuous))
    }
}

/// The API names embedded logos; unknown keys retain a readable media identity.
struct ChannelMark: View {
    let item: FeedItem
    var size: CGFloat = 20
    private var logo: UIImage? { item.channelLogoAsset.flatMap { UIImage(named: $0) } }
    static func hasLogo(for item: FeedItem) -> Bool {
        showsX(item) || item.channelLogoAsset.flatMap { UIImage(named: $0) } != nil
    }
    private static func showsX(_ item: FeedItem) -> Bool {
        item.isTweet || item.media.lowercased() == "x" || item.channelKey.lowercased() == "x"
    }

    var body: some View {
        Group {
            if Self.showsX(item) {
                MarkTile(image: Image("x.logo"), size: size)
            } else if let logo {
                Image(uiImage: logo).resizable().scaledToFit()
                    .frame(width: logoWidth(for: logo), height: size)
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
            Text(title).font(.headline)
                .foregroundStyle(Brand.ink).fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Brand.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
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
    let background: Color
    func body(content: Content) -> some View {
        content.navigationTitle(title).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(title).font(.headline)
                        .foregroundStyle(Brand.ink).accessibilityAddTraits(.isHeader)
                }
            }
            .toolbarBackground(background, for: .navigationBar)
    }
}

extension View {
    func appNavigationTitle(_ title: String, background: Color = Brand.background) -> some View {
        modifier(AppNavigationTitle(title: title, background: background))
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
    var icon: String? = nil
    /// A symbol from the asset catalog, used instead of `icon` for brand marks.
    var assetIcon: String? = nil
    /// Shows the icon alone; `title` still names the button for VoiceOver.
    var iconOnly = false
    /// Sets the icon on an inverted-ink tile, like the broadcaster logos in the feed cards.
    var iconTile = false
    var accent: Color = Brand.tint
    var compact = false
    let action: () -> Void
    @ScaledMetric(relativeTo: .footnote) private var tileSize = 20.0

    private var image: Image? {
        if let assetIcon { return Image(assetIcon) }
        return icon.map { Image(systemName: $0) }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: image == nil || iconOnly ? 0 : 4) {
                if let image {
                    Group {
                        if iconTile {
                            MarkTile(image: image, size: tileSize)
                        } else {
                            // One step above the label, with a heavier stroke, so the icons read at a glance.
                            image.font((compact ? Font.subheadline : .title3).weight(.semibold))
                        }
                    }
                    .accessibilityLabel(title)
                    .accessibilityHidden(!iconOnly)
                }
                if !iconOnly || image == nil { Text(title) }
            }
            .font((compact ? Font.footnote : .body).weight(selected ? .semibold : .regular))
            .foregroundStyle(selected ? Brand.ink : Brand.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, compact ? 4 : 12).padding(.vertical, 12)
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
            .background(Brand.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .accessibilityElement(children: .contain)
    }
}
