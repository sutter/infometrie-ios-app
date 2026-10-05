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
- App icon: an "i" whose stem rises out of a sound wave, drawn by `scripts/make_app_icon.swift` in light (ink on paper), dark (paper on ink) and tinted (grayscale) variants, opaque 1024 px. `scripts/create_project.py` declares the three variants; change the drawing in the Swift script and rerun both, never edit the PNGs by hand.
- `AccentColor` mirrors `Brand.tint`. Change both together, and the asset through `scripts/create_project.py`. System alerts and menus ignore it on iOS 26 (label color only), so it is not a lever for their look.

## Components

- Shared in `Design.swift`: `ActionButtonStyle` (capsule, prominent or outlined), `AppSection`, `AppEmptyState`, `ErrorNotice`, `KindBadge`, `ChannelMark`, `PersonAvatar`, `PageHeading`, `AdaptiveRow` (turns into a column at accessibility sizes).
- Passage pages stay minimal: listening follows the text silently, and "Reprendre le suivi" appears below the text only after manual scrolling suspended it. The fullscreen text has no header line either; the listening position exists only for VoiceOver (`transcript-position`). No technical sync explanations (estimated or precise timings, retry); only feedback to a tapped word (`transcriptNotice`) is shown.
- `PlaybackDock` puts two buttons beside play: ±10 s on a single passage; in "Tout écouter" (`queue: true`), previous and next lead as prominent labelled buttons around a discreet round play button, stack past the XL text size so "Précédent" never splits, and stay beside "Réessayer l’écoute" so a failing passage never blocks the queue.
- Icon-only toolbar actions (the cross closing "Tout écouter") use the regular glass circle of the system back button: a plain `Button` with an SF Symbol in `.topBarTrailing`, default shared background. Labelled actions like "Filtrer" hide the background (`.sharedBackgroundVisibility(.hidden)`). Avoid `.confirmationAction` and `role: .close`: iOS 26 draws them as prominent white buttons.
- Motion: animate through `.motion(value:)` (`Motion.standard` 0.32 s smooth, `Motion.quick` 0.22 s snappy), which stays still with Reduce Motion. Tab rows (Actifs / Archivés), the feed's type checkboxes and the feed's cards never animate: the user asked for none, and the sliding underline glitched when the pinned row jumped; each `AppTabButton` draws its own static underline. The S / M / L pill slides (`matchedGeometryEffect`), other lists fade, play/pause morphs (`symbolEffect(.replace)`), times roll (`numericText`), buttons sink under the finger (`ActionButtonStyle`, `PressableStyle`). Never animate a container holding a pinned section header (the feed's type row): the header sticks, then snaps. Scope `.motion` to the rows elsewhere, and move a scroll view with pinned headers only by instant jumps (`Transaction.disablesAnimations`); the feed jumps to the top when its criteria change. Haptics follow user gestures only: `.sensoryFeedback(.selection)` on choices, a light impact on player presses.
- Passage metadata in `PassageMetadata.swift`: `PassageMetadataRow` (source, kind, date, duration on one line) is shared by the intervention and X cards and the sequence and podcast pages, so they always read the same. Citation cards follow the user's own model instead (`FeedCard`): kind badge and mention ("mention par …" or "mention à l’antenne") with the channel logo on the right; date, channel · medium and duration; person · party; role; title; no avatar. Every variant writes the date `25/09 14:39` through `PassageDate`, with no separator before the duration (`PassageDuration`). `ChannelSource` (broadcaster logo, or its name when no logo is bundled) is the one way to show a medium, in cards, passage pages and the fullscreen text. `PassageByline` and `PassageHeading` complete the passage header.
- No spinners: loading states use `.skeleton()` (`Skeleton` in `Design.swift`), which draws the real layout redacted into pulsing shapes, static with Reduce Motion, and sets a VoiceOver label such as "Chargement du fil". `FeedSkeleton` renders stand-in `FeedCard`s, so it follows card changes. A control in progress (the login button) only pulses: `.skeleton(active, shapes: false)`.
- X appears everywhere as `MarkTile` in `Design.swift`: the `x.logo` custom symbol on an inverted-ink tile (`Brand.primary` behind, `Brand.primaryForeground` for the mark), at full contrast whatever the selection. The feed's X checkbox shows it alone, the cards and the passage pages through `ChannelMark`, which draws it for any tweet or `x` media or channel key. In feed cards the X tile stands alone: no kind icon next to it, and VoiceOver reads "Publication X" for the source. There is no `channel-x` image asset: `channelLogoAsset` still names it, and `ChannelMark` intercepts X before looking it up.
- The feed filters its types with checkboxes, not tabs (`FeedKindPicker` in `FeedView.swift`): Interventions, Citations and the X tile, combinable, with no "Tous" (all checked). The last checked box is disabled, so the feed never empties by mistake. No kind icons beside the labels: with them the row overflowed the iPhone width and hid X. VoiceOver reads "Coché" / "Non coché".
- Tab icons (Actifs / Archivés) sit one text style above their label (`subheadline` next to a `footnote` label) in semibold, whatever the selection.
- Custom symbols have a medium scale only: `.imageScale(.small)` or `.large` renders nothing. Size them with `.font(...)`.
- `x.logo.svg` is an SF Symbols template (v3) with a single Regular-M variant, generated by `scripts/make_x_logo_symbol.py`: never edit the SVG by hand, change the script's constants and rerun it. The mark is 90 units tall, the size of `square.grid.2x2` next to it, and centered on the cap height; at 78 units it looked smaller than the neighboring icons.
- The official mark is too thin at tab size, so the script thickens every stroke by `BOLDEN` (36 units of the 1200-unit logo; 24 was still too faint) while keeping its hollow stroke. `BOLDEN = 0` reproduces the official weight exactly.

## Accessibility

- Semantic Dynamic Type everywhere, never capped. The S / M / L reading size (default M) is relative to the system size: one step below, at, one step above (`ReadingSizeModifier`), so it works on devices already set to larger text. Accessibility sizes are never reduced, and a standard size never tips into them.
- Touch targets of at least 44 pt. Main buttons are 52 pt high, the ±10 s skip buttons 56 pt.
- Secondary text at a contrast of at least 4.5:1 (`Brand.secondaryOnSurface` on shaded surfaces).
- Rows switch to a vertical layout at accessibility sizes. Interactive elements carry an `accessibilityIdentifier`, which the UI tests rely on.
- Check each visual change in light, dark and the largest text size, on iPhone and iPad.
