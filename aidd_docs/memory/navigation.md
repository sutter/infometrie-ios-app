# Navigation

How the user moves through the app: routing and the page structure.

## Routing

- No router. `RootView` in `Infometrie/InfometrieApp.swift` switches between the restore spinner, `LoginView` and the signed-in shell. Everything past login needs `isAuthenticated` (a session).
- The signed-in shell is a `TabView` with three destinations, each in its own `NavigationStack`: Le journal, Mes suivis, Compte. Filtering is an action of the feed, not a fourth destination. The system tab bar is hidden: on iPhone a custom `MainTabBar` sits under each root page (none on pushed pages), on iPad the sidebar.
- At regular width (iPad), a custom `MainNavigation` replaces `MainTabBar`: a sidebar, or a horizontal strip at the top at accessibility text sizes.
- On the passage page, the speaker links to `PersonView` when they belong to the panel (`model.persons`). "Voir ses passages dans le journal" filters the journal on that person and pops its stack to the root: `AppModel.returnToFeedRoot()` changes `feedStackID`, the `.id` of the journal's `NavigationStack`.
- Filters open as a sheet (`SearchView`) that edits a `draft`: Cancel keeps the applied filters. The podcast is a sheet bound to `player.isPodcast`, and closing it stops playback.

## Structure

```mermaid
flowchart LR
    Login["Connexion"] --> Feed["Le journal"]
    Feed --> Sequence["Séquence"]
    Sequence --> Fullscreen["Texte plein écran"]
    Sequence --> Person["Fiche personnalité"]
    Person -->|Voir ses passages| Feed
    Feed --> Filters["Filtres · sheet"]
    Feed --> Podcast["Podcast · sheet"]
    Saved["Mes suivis"] --> Feed
    Account["Compte"]
```
