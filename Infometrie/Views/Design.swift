import SwiftUI

/// The brand palette: vermillon for actions, accent and identity; mineral taupe for interface marks; noir chaud for
/// text and icons; blanc cassé for the page; gris clair for secondary surfaces. Chosen by the client on 2026-10-07.
enum Brand {
    /// Blanc cassé in light, noir chaud in dark: sections and rows sit on dividers rather than cards.
    static let background = color(light: 0xFAF9F6, dark: 0x121110)
    static let card = color(light: 0xFAF9F6, dark: 0x1A1817)
    /// Noir chaud: text and icons.
    static let ink = color(light: 0x121110, dark: 0xF5F3F0)
    static let primary = color(light: 0x121110, dark: 0xF5F3F0)
    static let primaryForeground = color(light: 0xFFFFFF, dark: 0x121110)
    static let tint = color(light: 0x121110, dark: 0xF5F3F0)
    static let secondary = color(light: 0x6B6560, dark: 0xA8A29E)
    /// Gris clair: secondary surfaces, fields and control tracks.
    static let surface = color(light: 0xF2F0ED, dark: 0x1E1C1A)
    /// The selected segment of a capsule control: lifted from its `surface` track in both themes.
    static let raised = color(light: 0xFFFFFF, dark: 0x34302C)
    static let inputBorder = color(light: 0xDEDAD5, dark: 0x36322E)
    static let selection = color(light: 0xF2F0ED, dark: 0x1E1C1A)
    static let selectionForeground = color(light: 0x121110, dark: 0xF5F3F0)
    static let rule = color(light: 0xDEDAD5, dark: 0x36322E)
    static let sidebar = color(light: 0xFAF9F6, dark: 0x121110)
    static let sidebarRule = color(light: 0xDEDAD5, dark: 0x36322E)
    static let destructive = color(light: 0xE7000B, dark: 0xFF6467)
    /// `color` fixed to one appearance. The navigation bar of a tab that is off screen during a theme
    /// change keeps resolving adaptive colors with the old theme; colors fixed by the page do not.
    static func fixed(_ color: Color, for scheme: ColorScheme?) -> Color {
        guard let scheme else { return color }
        let style: UIUserInterfaceStyle = scheme == .dark ? .dark : .light
        return Color(uiColor: UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: style)))
    }

    /// Vermillon: primary actions, the playback timeline, the logo, the active tab and selections.
    static let accent = color(light: 0xE74732, dark: 0xF05A49)
    /// Mineral taupe: interface marks such as the account avatar.
    static let taupe = color(light: 0x91857B, dark: 0xA2958C)

    /// Color tells the passage kind at a glance: vermillon interventions, taupe citations, noir chaud for X.
    /// `intervention` and `citation` draw the bars and the tags' light tint (3:1 or more); `…Label` the tags' small
    /// text, deeper for 4.5:1 on that tint; `…Fill` the solid chips under white text, the same in both themes.
    /// The coming Instagram type will need a hue of its own.
    static let intervention = accent
    static let interventionLabel = color(light: 0xBB3520, dark: 0xF05A49)
    static let interventionFill = color(light: 0xC93A26, dark: 0xC93A26)
    static let interventionWash = color(light: 0xFCE8E4, dark: 0x3A1C16)
    static let citation = taupe
    static let citationLabel = color(light: 0x6B6159, dark: 0xA2958C)
    static let citationFill = color(light: 0x7A6F66, dark: 0x7A6F66)
    static let citationWash = color(light: 0xEEEAE6, dark: 0x2A2623)

    /// Secondary actions: gris clair under noir chaud text.
    static let actionWash = surface
    static let actionText = ink

    // Strengthen small secondary labels on shaded surfaces (at least 4.5:1).
    static let secondaryOnSurface = color(light: 0x6B6560, dark: 0xA8A29E)

    private static func color(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            let value = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: CGFloat((value >> 16) & 0xFF) / 255,
                green: CGFloat((value >> 8) & 0xFF) / 255,
                blue: CGFloat(value & 0xFF) / 255,
                alpha: 1
            )
        })
    }
}

/// The brand lockup: "info" heavy and "métrie" regular in noir chaud, the weights alone setting them apart, with the
/// acute accent of "métrie" in vermillon, a small mark of measure. No pictogram: a vermillon tile beside the name read
/// as one more type checkbox above the journal's chips. `size` is the text size.
struct Wordmark: View {
    var size: CGFloat = 22
    /// Set in navigation bars, which may not follow a theme change (`Brand.fixed`).
    var scheme: ColorScheme? = nil

    var body: some View {
        let ink = Brand.fixed(Brand.ink, for: scheme)
        // Two identical layouts: the name in ink, and over it the same name with only the "é" in vermillon, masked
        // to the band above the lowercase letters, so the accent alone takes the color.
        name(ink: ink, accent: ink)
            .overlay(alignment: .top) {
                name(ink: .clear, accent: Brand.fixed(Brand.accent, for: scheme))
                    .mask(alignment: .top) { Rectangle().frame(height: accentBand) }
            }
            .fixedSize()
            .accessibilityElement(children: .ignore).accessibilityLabel("InfoMétrie")
    }

    private func name(ink: Color, accent: Color) -> some View {
        let regular = Font.system(size: size * 1.05, weight: .regular)
        return (Text("info").font(.system(size: size * 1.05, weight: .heavy)).foregroundStyle(ink)
            + Text("m").font(regular).foregroundStyle(ink)
            + Text("é").font(regular).foregroundStyle(accent)
            + Text("trie").font(regular).foregroundStyle(ink))
            .tracking(-size * 0.03)
    }

    /// From the top of the line to just above the lowercase letters: where the accent sits.
    private var accentBand: CGFloat {
        let font = UIFont.systemFont(ofSize: size * 1.05, weight: .regular)
        return font.ascender - font.xHeight - size * 0.02
    }
}

/// Shared controls grow with Dynamic Type and retain a generous hit area.
/// Primary calls to action fill with vermillon; secondary ones sit on gris clair.
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
            .foregroundStyle(foreground)
            .background(background, in: Capsule())
            .contentShape(Capsule())
            .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : (prominent ? 1 : 0.45))
            // The button sinks slightly under the finger and springs back.
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }

    /// A disabled primary action turns plain gray, so it never reads as available.
    private var foreground: AnyShapeStyle {
        guard prominent else { return AnyShapeStyle(Brand.actionText) }
        return isEnabled ? AnyShapeStyle(Color.white) : AnyShapeStyle(Brand.secondary)
    }

    private var background: AnyShapeStyle {
        guard prominent else { return AnyShapeStyle(Brand.actionWash) }
        return isEnabled ? AnyShapeStyle(Brand.accent) : AnyShapeStyle(Brand.surface)
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
    var accent: Color = Brand.accent
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
