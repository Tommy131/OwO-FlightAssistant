# Flight Quality Combined Chart Design

## Context

The Web flight-quality report currently exposes 22 selectable metrics, but renders every selected metric only as an individual small-multiple chart. It does not provide the combined overview or the flight-event filters and markers shown by the legacy Flutter implementation.

The new combined view must be additive. Existing individual charts remain available and continue to use independent axes. The design follows the current Web visual language while restoring the useful overview and event context from Flutter.

## Confirmed Behavior

- Add a combined chart above the existing individual charts.
- Show the combined chart by default. A local visibility control can collapse it without hiding the individual charts.
- Do not persist the combined-chart visibility setting. Reopening a log restores the required default-visible state.
- The existing metric selector controls both the combined chart and the individual charts.
- Keep the existing default metric selection: altitude, ground speed, vertical speed, and G-force.
- Give every metric its own fixed color in both light and dark themes. The selector, combined series, individual chart, and tooltip must use the same color.
- Overlay selected metrics in one chart, but bind each metric to its own hidden Y axis. This preserves the real values while keeping differently scaled trends visible.
- Display all nine event filters at all times. They default to selected; filters with no matching event are disabled and visually muted.
- Preserve the existing responsive, wrapping selector layout.

## Architecture

### Metric Registry

Extract the 22 metric definitions from `analysis-chart.tsx` into a focused registry. Each definition owns:

- Stable metric ID and localization key.
- Unit and display precision.
- Point-value selector.
- Unique light-theme and dark-theme colors.

The combined chart, metric chips, individual rows, and tooltips all consume this registry. There must be no second color or value mapping that can drift.

### Event Detection Service

Add a pure flight-chart event service that consumes a `FlightLog` and returns ordered markers. Each marker contains a stable event type, timestamp, nearest point index, and structured detail needed for localization.

The service detects:

1. Takeoff: the logged takeoff timestamp, falling back to the first transition to airborne.
2. Flaps deploy and retract: changes in numeric flap position or a parsed flap label, with the resulting flap setting.
3. Autopilot lateral mode: initial non-OFF mode and subsequent normalized mode changes.
4. Autopilot vertical mode: initial non-OFF mode and subsequent normalized mode changes.
5. Gear down and gear up: transitions between known gear states.
6. Touchdowns: individual entries in a multi-touchdown sequence, including sequence number and G-force.
7. Final touchdown: the landing record timestamp, matched to the nearest recorded point.

A single-touchdown landing emits only the final-touchdown marker to avoid duplicate dots with identical meaning. A multi-touchdown landing emits the individual touchdown markers and an additional final-touchdown marker, matching the Flutter behavior.

Detection stays independent of React, ECharts, translation, and theme state so it can be tested directly.

### Combined Chart Component

Create a focused combined-chart component that receives active metric definitions, their series, active event markers, theme state, and localized labels.

- Use one shared minute-based X axis.
- Create one hidden, scaled Y axis per active metric and bind each line to its own axis index.
- Keep actual data values unchanged; do not normalize stored or tooltip values.
- Use a custom tooltip to show each selected metric in its fixed color with its real value and unit.
- Render events as colored scatter markers at their timestamps. Anchor their Y value to the first active metric's nearest value.
- Apply a small deterministic symbol offset per event type so simultaneous events remain individually visible.
- Event tooltips include details such as `Flaps Deploy 10°`, `AP Lateral Mode LNAV`, and `Touchdown 1 (1.18G)`.
- Use a responsive chart host, approximately 420 px on desktop and shorter on narrow screens, without horizontal overflow.

### Analysis Chart Orchestrator

`AnalysisChart` retains ownership of three local interaction states:

- Selected metric IDs.
- Combined-chart visibility, initially `true`.
- Selected event types, initially all nine types.

It computes metric series and detected events once per log, derives event availability, and passes the same data to the combined and individual views. Changing a metric updates both views. Hiding the combined chart does not alter metric or event selection.

## Visual and Accessibility Rules

- Use the existing flight-log section, chip, border, radius, spacing, and theme variables.
- Provide a clearly labelled combined-chart visibility control with `aria-expanded`.
- Metric and event filters use selected state, check indication, `aria-pressed`, text labels, and disabled state; color is not the only state cue.
- All 22 metric colors are unique within each theme palette. All nine event colors are stable and distinct from their labels and selector states.
- Event filters appear in this order: takeoff, flaps deploy, flaps retract, AP lateral, AP vertical, gear down, gear up, touchdown, final touchdown.
- Missing metric values are skipped rather than replaced with misleading zeroes. Existing barometric-pressure fallback behavior remains unchanged for compatibility.

## Empty and Edge States

- Logs with no usable selected metric data keep the existing no-data state.
- A metric with no usable values remains disabled in the metric selector.
- An event type with no markers remains visible but disabled.
- Event timestamps that do not exactly match a sampled point use the nearest point.
- The combined chart may be hidden even when active metrics exist; individual charts remain unchanged.

## Testing

Implementation follows test-driven development.

Pure tests cover:

- All 22 metric definitions, unique IDs, unique per-theme colors, units, precision, and missing-value behavior.
- All nine event types, event ordering, flap direction, AP normalization, gear transitions, nearest-point matching, and single-versus-multiple touchdown behavior.
- Combined-series configuration: one hidden Y axis per active metric, correct `yAxisIndex`, unchanged real values, and event offsets.

Component tests cover:

- Default four metrics.
- Combined chart visible by default and collapsible without removing individual charts.
- Metric selection updating both combined and individual views.
- All nine event controls always rendered, default selected, and disabled when unavailable.
- Theme-aware metric and event colors and accessible selector state.

Final verification requires focused tests, the complete `npm run check`, `npm run build`, `git diff --check`, and a browser smoke test when the local browser harness is available.

## Out of Scope

- Persisting combined-chart visibility or filter choices.
- Changing flight-log persistence or backend schemas.
- Removing or replacing individual charts.
- Modifying the Flutter application.
- Adding new telemetry fields beyond the 22 metrics and nine event types already represented by the current Web model and Flutter reference.
