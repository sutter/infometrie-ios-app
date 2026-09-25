# Forms

How forms are built and validated across the UI.

## Approach

- No form or validation library, and no SwiftUI `Form`. Native `TextField` / `SecureField` in custom sections styled with the tokens in `Design.swift`.
- Server errors become French messages in `APIError.errorDescription` (`Infometrie/Core/APIClient.swift`), shown with `ErrorNotice`.

## Conventions

- Minimal client-side validation: submit stays disabled while a required field is empty or a request is running.
- Keyboard flow: `.focused` plus `submitLabel` (`.next`, then `.go` to submit). The password field has a visibility toggle.
- Editors work on a copy (`draft` for filters) and commit on apply. Cancel restores the applied state.
- Destructive actions ask first with a `confirmationDialog`: device replacement, logout, deleting a suivi.
