import SwiftUI

/// The three reading sizes use Apple's type scale. Larger system preferences
/// (including every accessibility category) always take precedence.
struct ReadingSizeModifier: ViewModifier {
    let selection: ReadingSize
    @Environment(\.dynamicTypeSize) private var systemSize

    private var preferredSize: DynamicTypeSize {
        switch selection {
        case .small: .medium
        case .medium: .large
        case .large: .xLarge
        }
    }

    func body(content: Content) -> some View {
        content.dynamicTypeSize(systemSize > .large ? max(systemSize, preferredSize) : preferredSize)
    }
}
