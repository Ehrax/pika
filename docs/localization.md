# Localization Policy

Billbi uses English as its source language. App UI strings live in the single app-wide string catalog at `billbi/Localizable.xcstrings`.

SwiftUI text, labels, buttons, section titles, alerts, dialogs, help text, prompts, placeholders, and accessibility labels should stay as direct SwiftUI literals when SwiftUI treats them as localized keys. When user-facing copy must be passed as a plain `String`, use Apple's native localized string APIs such as `String(localized:)`.

Keep telemetry names, logging text, analytics identifiers, storage keys, persistence identifiers, debug identifiers, and user-entered workspace content nonlocalized. Client names, project names, bucket names, invoice descriptions, notes, addresses, business profile values, and seed/development business content are workspace data, not app UI copy.

Do not add generated localization wrappers, SwiftGen-style constants, custom hardcoded-string scanners, CI localization lint, pre-commit hooks, or an in-app language picker without a separate product decision.

Invoice PDF rendering, invoice templates, generated Info.plist metadata, bundle display names, permission prompts, document type names, and invoice legal/customer-facing wording are intentionally deferred to focused localization passes.
