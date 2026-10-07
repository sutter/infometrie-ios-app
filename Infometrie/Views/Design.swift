import SwiftUI

/// Shared neutral palette and rounded surfaces adapted from the Stoic reference.
enum Brand {
    // Neutral, low-contrast surfaces inspired by Stoic. Color remains reserved
    // for actual media branding and destructive system feedback.
    /// A plain white page, after Medium: sections and rows sit on dividers rather than cards.
    static let background = color(light: 0xFFFFFF, dark: 0x101113)
    static let card = color(light: 0xFFFFFF, dark: 0x151719)
    static let ink = color(light: 0x111214, dark: 0xF5F5F4)
    static let primary = color(light: 0x151618, dark: 0xF1F1EF)
    static let primaryForeground = color(light: 0xFFFFFF, dark: 0x111214)
    static let tint = color(light: 0x292B2E, dark: 0xE6E6E4)
    static let secondary = color(light: 0x696B70, dark: 0xA0A2A6)
    static let surface = color(light: 0xE7E8EA, dark: 0x1D1F22)
    /// The selected segment of a capsule control: lifted from its `surface` track in both themes.
    static let raised = color(light: 0xFFFFFF, dark: 0x3A3C40)
    static let inputBorder = color(light: 0xDCDDDF, dark: 0xFFFFFF, darkAlpha: 0.08)
    static let selection = color(light: 0xE7E8EA, dark: 0x292B2E)
    static let selectionForeground = color(light: 0x151618, dark: 0xF5F5F4)
    static let rule = color(light: 0xDCDDDF, dark: 0xFFFFFF, darkAlpha: 0.09)
    static let sidebar = color(light: 0xFFFFFF, dark: 0x101113)
    static let sidebarRule = color(light: 0xDCDDDF, dark: 0xFFFFFF, darkAlpha: 0.08)
    static let destructive = color(light: 0xE7000B, dark: 0xFF6467)
    /// `color` fixed to one appearance. The navigation bar of a tab that is off screen during a theme
    /// change keeps resolving adaptive colors with the old theme; colors fixed by the page do not.
    static func fixed(_ color: Color, for scheme: ColorScheme?) -> Color {
        guard let scheme else { return color }
        let style: UIUserInterfaceStyle = scheme == .dark ? .dark : .light
        return Color(uiColor: UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: style)))
    }

    /// Color tells the passage kind: cobalt interventions, lilac citations, ink for X. The logo and the calls
    /// to action stay ink. Hues no major French party owns, never paired like the flag; the coming Instagram
    /// type will take raspberry (0xB3326F / 0xF28DBE on 0xFBEAF2 / 0x3A1A2C). Text reaches 5.2:1 or more on its wash.
    static let intervention = color(light: 0x2959C9, dark: 0x8DB0FF)
    static let interventionWash = color(light: 0xEAF0FC, dark: 0x16264A)
    static let citation = color(light: 0x6E4DBF, dark: 0xB9A2F5)
    static let citationWash = color(light: 0xF1ECFB, dark: 0x272042)

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

/// The brand lockup: an "i" on a green speech bubble, then "info" heavy in ink
/// and "métrie" regular in ink: the weights alone set them apart, green stays in the tile. `size` is the text size; the tile scales with it.
struct Wordmark: View {
    var size: CGFloat = 22
    /// Set in navigation bars, which may not follow a theme change (`Brand.fixed`).
    var scheme: ColorScheme? = nil

    var body: some View {
        let ink = Brand.fixed(Brand.ink, for: scheme)
        HStack(spacing: size * 0.38) {
            BrandTile(side: size * 1.45, scheme: scheme)
            (Text("info").font(.system(size: size * 1.05, weight: .heavy)).foregroundStyle(ink)
                + Text("métrie").font(.system(size: size * 1.05, weight: .regular)).foregroundStyle(ink))
                .tracking(-size * 0.03)
        }
        .fixedSize()
        .accessibilityElement(children: .ignore).accessibilityLabel("InfoMétrie")
    }
}

/// The brand pictogram: an "i" (stem and dot) on a green speech bubble, its sharp corner bottom left.
struct BrandTile: View {
    let side: CGFloat
    var scheme: ColorScheme? = nil

    var body: some View {
        UnevenRoundedRectangle(topLeadingRadius: side * 0.3, bottomLeadingRadius: side * 0.04,
                               bottomTrailingRadius: side * 0.3, topTrailingRadius: side * 0.3, style: .continuous)
            .fill(Brand.fixed(Brand.primary, for: scheme))
            .frame(width: side, height: side)
            .overlay {
                VStack(spacing: side * 0.064) {
                    Circle().frame(width: side * 0.157, height: side * 0.157)
                    Capsule().frame(width: side * 0.128, height: side * 0.36)
                }
                .foregroundStyle(Brand.fixed(Brand.primaryForeground, for: scheme))
            }
            .accessibilityHidden(true)
    }
}

/// Shared controls grow with Dynamic Type and retain a generous hit area.
struct ActionButtonStyle: ButtonStyle {
    var prominent = false
    var horizontalPadding: CGFloat = 16
    /// Primary calls to action are filled ink; secondary ones are outlined in ink.
    var fill = Brand.primary
    var foreground = Brand.primaryForeground
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, horizontalPadding).padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 52)
            .foregroundStyle(prominent ? foreground : Brand.ink)
            .background(prominent ? fill : Brand.card, in: Capsule())
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
            .foregroundStyle(Brand.ink)
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
    /// Side margin of every page on iPhone: iOS's standard 16 pt, the inset of the navigation bar items too.
    static let margin: CGFloat = 16
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
        // A title over its content on the plain page: whitespace separates sections, not cards or extra rules.
        VStack(alignment: .leading, spacing: 12) {
            // The small gray section title: one section style across the app.
            SectionLabel(title: title).fixedSize(horizontal: false, vertical: true)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
    @Environment(\.colorScheme) private var colorScheme
    func body(content: Content) -> some View {
        content.navigationTitle(title).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(title).font(.headline)
                        .foregroundStyle(Brand.fixed(Brand.ink, for: colorScheme)).accessibilityAddTraits(.isHeader)
                }
            }
            // An opaque bar in the page color, with no scroll edge effect under it (the pages hide it):
            // on iOS 27 the hard effect drew a hairline and a different tint under the bar at rest.
            .toolbarBackground(Brand.background, for: .navigationBar)
            .toolbarBackgroundVisibility(.visible, for: .navigationBar)
    }
}

extension View {
    func appNavigationTitle(_ title: String) -> some View {
        modifier(AppNavigationTitle(title: title))
    }

    /// A capsule chip: filled when selected (`wash`, the kind's color for a passage type), outlined
    /// otherwise; 40 pt drawn, 48 pt to touch.
    func chip(selected: Bool, wash: Color = Brand.surface) -> some View {
        padding(.horizontal, 12).frame(minHeight: 40)
            .background(selected ? wash : .clear, in: Capsule())
            .overlay { Capsule().strokeBorder(selected ? .clear : Brand.rule) }
            .frame(minWidth: 44, minHeight: 48)
            .contentShape(Rectangle())
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
                            image.font((compact ? Font.body : .title3).weight(.semibold))
                        }
                    }
                    .accessibilityLabel(title)
                    .accessibilityHidden(!iconOnly)
                }
                if !iconOnly || image == nil { Text(title) }
            }
            // Compact tabs (the feed's period row) read at 15 pt, medium even when unselected:
            // 13 pt regular was too faint for the app's older readers.
            .font((compact ? Font.subheadline : .body).weight(selected ? .semibold : (compact ? .medium : .regular)))
            .foregroundStyle(selected ? Brand.ink : Brand.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, compact ? 6 : 12).padding(.vertical, 12)
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
