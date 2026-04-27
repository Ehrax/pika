# Dashboard Revenue Range Picker Design

## Goal

Add a simple segmented range picker to the dashboard revenue panel so the chart can switch between common financial windows: 7D, 14D, 1M, 3M, 6M, and 12M.

## Scope

- Keep the interaction limited to segmented range selection.
- Do not add trackpad zoom, freeform panning, or a draggable timeline in this pass.
- Keep the chart inside the existing dashboard revenue panel and preserve the current dashboard stacking order.

## User Experience

The revenue panel shows a compact segmented control near the section header. The default selection is 12M to match the current dashboard. Selecting another range updates the chart title context, date detail, total amount, and plotted points for that visible range.

The chart remains readable on macOS, iPadOS, and iOS by using the same surface and height policy already defined for the dashboard. The selected range is accessible as a picker control, and each segment uses short labels that fit in narrow layouts.

## Data Model

Introduce a small `DashboardRevenueRange` value that owns:

- the display label (`7D`, `14D`, `1M`, `3M`, `6M`, `12M`)
- the number of visible points to show from the trailing edge of the available revenue history

The current sample revenue history contains twelve monthly points, so short ranges initially select the trailing subset of the available sample series. This keeps the feature honest about today's data while leaving room for real daily invoice-derived history later.

## SwiftUI Structure

`DashboardView` owns the selected range with local `@State`, because this is presentation state for one screen. A small picker view or local helper renders the segmented control. `RevenueSparkline` continues to receive plain `[RevenuePoint]`, so the chart drawing stays decoupled from range selection.

## Telemetry

Log range changes through `AppTelemetry` with the selected range label and visible point count. This is useful during simulator verification and remains lightweight enough to keep.

## Testing

Add unit coverage for the range policy: available ranges, default range, and trailing point selection. Keep UI tests focused on launch/runtime verification unless the existing test suite already has a stable dashboard interaction harness.

## Self Review

- No placeholders remain.
- The design intentionally excludes gestures and panning for this pass.
- The range behavior is explicit for the current monthly sample data and future daily data.
- The implementation stays local to the dashboard and model/support layer.
