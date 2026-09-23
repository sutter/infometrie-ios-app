import SwiftUI

enum Brand {
    static let blue = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.76, green: 0.83, blue: 0.96, alpha: 1)
            : UIColor(red: 0.07, green: 0.12, blue: 0.21, alpha: 1)
    })
    static let citation = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.98, green: 0.60, blue: 0.65, alpha: 1)
            : UIColor(red: 0.59, green: 0.10, blue: 0.20, alpha: 1)
    })
    static let secondary = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.76, green: 0.78, blue: 0.83, alpha: 1)
            : UIColor(red: 0.30, green: 0.33, blue: 0.39, alpha: 1)
    })
    static let background = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.07, green: 0.08, blue: 0.10, alpha: 1)
            : UIColor(red: 0.995, green: 0.991, blue: 0.977, alpha: 1)
    })
    static let ink = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.94, green: 0.94, blue: 0.91, alpha: 1)
            : UIColor(red: 0.05, green: 0.09, blue: 0.16, alpha: 1)
    })
    static let rule = Brand.secondary.opacity(0.28)
}

struct Wordmark: View {
    var size: CGFloat = 27
    var body: some View {
        Text("InfoMétrie")
        .font(.system(size: size, weight: .bold, design: .serif))
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
            .foregroundStyle(prominent ? Brand.background : Brand.ink)
            .background(prominent ? Brand.ink : .clear, in: Capsule())
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
    var body: some View {
        Group {
            if let name = item.channelLogoAsset, let logo = UIImage(named: name) {
                Image(uiImage: logo).resizable().scaledToFit()
            } else if item.isTweet || item.media.lowercased() == "x" || item.channelKey.lowercased() == "x" {
                Text("𝕏").font(.system(size: 20, weight: .semibold, design: .monospaced))
            } else {
                Image(systemName: item.media.lowercased() == "tv" ? "tv" : item.media.lowercased() == "radio" ? "radio" : "newspaper")
                    .font(.system(size: 18, weight: .medium))
            }
        }.frame(width: 24, height: 24).foregroundStyle(Brand.citation).accessibilityHidden(true)
    }
}

struct PersonAvatar: View {
    let item: FeedItem
    var size: CGFloat = 42
    var body: some View {
        Text(item.initials).font(.system(size: size * 0.32, weight: .semibold))
            .foregroundStyle(Brand.citation)
            .frame(width: size, height: size)
            .background(Brand.citation.opacity(0.07), in: Circle())
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

enum EditorialLayout {
    static let maximumWidth: CGFloat = 1040
    static let readingWidth: CGFloat = 760
    static let wideMargin: CGFloat = 36
}

struct EditorialPageHeading: View {
    let title: String
    var subtitle: String?
    @Environment(\.horizontalSizeClass) private var sizeClass
    @ScaledMetric(relativeTo: .largeTitle) private var compactSize = 40.0
    @ScaledMetric(relativeTo: .largeTitle) private var wideSize = 56.0

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.system(size: sizeClass == .regular ? wideSize : compactSize, weight: .bold, design: .serif))
                .tracking(-0.6).foregroundStyle(Brand.ink)
                .fixedSize(horizontal: false, vertical: true).accessibilityAddTraits(.isHeader)
            Rectangle().fill(Brand.citation).frame(width: 40, height: 5).accessibilityHidden(true)
            if let subtitle {
                Text(subtitle).font(.body).foregroundStyle(Brand.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct EditorialSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            EditorialRule()
            Text(title).font(.system(.title2, design: .serif, weight: .semibold))
                .foregroundStyle(Brand.ink).fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            content()
        }
    }
}

struct EditorialEmptyState: View {
    let title: String
    let icon: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: icon).font(.title2).foregroundStyle(Brand.citation).accessibilityHidden(true)
            Text(title).font(.system(.title2, design: .serif, weight: .semibold))
                .foregroundStyle(Brand.ink).accessibilityAddTraits(.isHeader)
            Text(message).font(.body).foregroundStyle(Brand.secondary)
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 28)
    }
}

/// Retain native back and dismissal controls, with the same paper and serif as the pages.
private struct EditorialNavigationTitle: ViewModifier {
    let title: String
    func body(content: Content) -> some View {
        content.navigationTitle(title).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(title).font(.system(.headline, design: .serif, weight: .semibold))
                        .foregroundStyle(Brand.ink).accessibilityAddTraits(.isHeader)
                }
            }
            .toolbarBackground(Brand.background, for: .navigationBar)
    }
}

extension View {
    func editorialNavigationTitle(_ title: String) -> some View {
        modifier(EditorialNavigationTitle(title: title))
    }

    func editorialInput() -> some View {
        background(Brand.secondary.opacity(0.035), in: RoundedRectangle(cornerRadius: 6))
            .overlay(alignment: .bottom) { Rectangle().fill(Brand.secondary.opacity(0.5)).frame(height: 1) }
    }
}

struct EditorialRule: View {
    var body: some View {
        Rectangle().fill(Brand.rule).frame(height: 0.5).accessibilityHidden(true)
    }
}

/// A visible underline and a selected trait make the state independent of color.
struct EditorialTabButton: View {
    let title: String
    let selected: Bool
    var accent: Color = Brand.ink
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
                    if selected { Rectangle().fill(accent).frame(height: 3) }
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
            .background(Brand.citation.opacity(0.05))
            .overlay(alignment: .leading) { Rectangle().fill(Brand.citation).frame(width: 3) }
            .accessibilityElement(children: .contain)
    }
}
