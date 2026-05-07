# Billbi Design Tokens

## Brand Color

Billbi uses one canonical purple/lavender product color: **Brand Color**.

Use `BillbiColor.brand` for branded interactive UI: primary actions, toolbar actions, app tint, branded icons, selected chips and filters, and single-series branded charts.

Use `BillbiColor.brandMuted` for subtle branded fills, including selected or active backgrounds that should stay calm.

Use `BillbiColor.brandBorder` for branded outlines, including focused inputs and selected branded rows.

Use `BillbiColor.primarySidebarSelection` only for the selected row treatment in the primary sidebar. It is a darker brand-family shade for navigation clarity, not the default Brand Color.

Focused input borders should use `BillbiColor.brandBorder` with `BillbiColor.inputFocusBorderWidth`.

The asset-catalog `AccentColor` exists for Apple platform integration, but its light and dark values must match `BillbiColor.brand`. Do not introduce another purple through the asset catalog.

## Rename Map

This cleanup was intentionally a hard rename. Do not add compatibility aliases for the old names.

| Old name | New name |
| --- | --- |
| `accent` | `brand` |
| `accentMuted` | `brandMuted` |
| `actionAccent` | `brand` |
| `actionAccentMuted` | `brandMuted` |
| `actionAccentBorder` | `brandBorder` |
| `sidebarSelection` | `primarySidebarSelection` |
| `focusedInputBorderWidth` | `inputFocusBorderWidth` |

## Acceptance Checks

- Swift source has no references to the old token names.
- Buttons, toolbar actions, selected chips and filters, branded icons, and single-series branded charts use `BillbiColor.brand`.
- Focused input borders use `BillbiColor.brandBorder` and `BillbiColor.inputFocusBorderWidth`.
- Subtle selected or active branded fills use `BillbiColor.brandMuted`.
- Primary sidebar selected rows use `BillbiColor.primarySidebarSelection`.
- `AccentColor.colorset` resolves to the same light and dark colors as `BillbiColor.brand`.
