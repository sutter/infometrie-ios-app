import SwiftUI

/// S, M and L sit one step below, at, and one step above the system text size, so each
/// choice always shows, including on devices already set to larger text. At the default
/// system size this gives Apple's medium, large and xLarge. An accessibility size is never
/// reduced, and a standard size never tips into the accessibility range.
struct ReadingSizeModifier: ViewModifier {
    let selection: ReadingSize
    @Environment(\.dynamicTypeSize) private var systemSize

    private var preferredSize: DynamicTypeSize {
        let sizes = DynamicTypeSize.allCases
        let offset = selection == .small ? -1 : selection == .large ? 1 : 0
        let index = sizes.firstIndex(of: systemSize) ?? sizes.firstIndex(of: .large) ?? 0
        let last = systemSize.isAccessibilitySize ? sizes.count - 1 : sizes.firstIndex(of: .xxxLarge) ?? sizes.count - 1
        let target = sizes[min(max(index + offset, 0), last)]
        return systemSize.isAccessibilitySize ? max(target, systemSize) : target
    }

    func body(content: Content) -> some View {
        content.dynamicTypeSize(preferredSize)
    }
}
