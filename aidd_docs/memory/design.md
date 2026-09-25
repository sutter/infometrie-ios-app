# Design

The visual language: the design system, tokens, and UI conventions. What it looks like, not how it is coded.

## System

- No mockups: design happens directly in the code. The visual reference is the Stoic iOS app on Mobbin (<https://mobbin.com/apps/stoic-ios-621f0be7-8046-45cd-b667-97add5f9c3c7/e20c833d-975b-401c-8601-74d135883e25/screens>, account required, so human only).
- Neutral, low-contrast rounded surfaces. Color is reserved for broadcaster logos and destructive feedback.
- Stoic is the source of truth. `Docs/UX/Stoic/README.md` records the direction and its palette. Earlier directions (editorial "Revue", Nova / Indigo) are history in `Docs/UX/`.
- A small in-house design system in SwiftUI, with system fonts and native controls.

## Tokens

- `Infometrie/Views/Design.swift`: `Brand` holds the light/dark color pairs, `AppLayout` the widths and corner radius.
- `Infometrie/Resources/Assets.xcassets`: `AccentColor`, app icon, and the `channel-<key>` broadcaster logos. Aliased keys are normalized in the model.
- `AccentColor` mirrors `Brand.tint`. Change both together, and the asset through `scripts/create_project.py`. System alerts and menus ignore it on iOS 26 (label color only), so it is not a lever for their look.

## Components

- Shared in `Design.swift`: `ActionButtonStyle` (capsule, prominent or outlined), `AppSection`, `AppEmptyState`, `ErrorNotice`, `KindBadge`, `ChannelMark`, `PersonAvatar`, `PageHeading`, `AdaptiveRow` (turns into a column at accessibility sizes), `DemoBanner`.
- Passage metadata (source, byline, heading) in `PassageMetadata.swift`, shared by the sequence and podcast screens.
- Brand marks shown as tab icons are custom SF Symbol templates in the asset catalog (`x.logo.symbolset`, the official X path), passed to `AppTabButton(assetIcon:iconOnly:iconTile:)`. The X tab sets it on an inverted-ink tile (`Brand.primary` behind, `Brand.primaryForeground` for the mark), at full contrast whatever the selection. `channel-x` is the broadcaster tile of the feed cards, not an icon.
- Custom symbols have a medium scale only: `.imageScale(.small)` or `.large` renders nothing. Size them with `.font(...)`.
- `x.logo.svg` is an SF Symbols template (v3) with a single Regular-M variant. The mark is 90 units tall, the size of `square.grid.2x2` next to it, and centered on the cap height. Keep these metrics when editing it (for example in the SF Symbols app); at 78 units it looked smaller than the neighboring icons.

## Accessibility

- Semantic Dynamic Type everywhere, never capped. The S / M / L reading size (default M) sits on top of it, and the system accessibility sizes take priority.
- Touch targets of at least 44 pt. Main buttons are 52 pt high, the ±10 s skip buttons 56 pt.
- Secondary text at a contrast of at least 4.5:1 (`Brand.secondaryOnSurface` on shaded surfaces).
- Rows switch to a vertical layout at accessibility sizes. Interactive elements carry an `accessibilityIdentifier`, which the UI tests rely on.
- Check each visual change in light, dark and the largest text size, on iPhone and iPad.
