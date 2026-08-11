# PAPI 5 NM Limit and Flight Track Map Restoration

## Context

Two regressions need to be fixed without removing the current flight-log analysis features:

1. PAPI guidance remains visible for runway thresholds farther than 5 NM, which makes the associated airport and runway ambiguous when airports are close together.
2. The flight-log track tab still shows its phase legend, replay controls, and point readout, but the Leaflet basemap and track layers are no longer visible.

The existing phase-coloured track, replay slider, and per-point readout must remain intact. The separate flight-log UUID fix will be integrated after these regressions are repaired.

## PAPI Design

The PAPI visibility limit belongs in the pure guidance service, where runway-end candidates are evaluated. A runway end is eligible only when the aircraft is no more than 5.0 NM from its threshold. Exactly 5.0 NM remains visible; any finite distance greater than 5.0 NM is rejected.

This keeps candidate selection and rendering consistent: the UI never receives guidance for an out-of-range runway. The widget documentation will be updated from 10 NM to 5 NM.

Boundary tests will cover both sides of the requirement:

- 5.0 NM returns PAPI guidance.
- 5.1 NM returns no guidance.

## Flight Track Map Design

The track page will keep all current analysis features:

- Flight-phase legend and phase-coloured polylines.
- Start, end, and replay markers.
- Replay slider and playback controls.
- Per-point timestamp, altitude, speed, and phase readout.

The repair will be limited to map lifecycle and layout. The detail page, scroll region, track panel, and Leaflet host must form an explicit flex/min-height chain so the map receives a measurable, non-zero area. When the track tab becomes visible or its host changes size, Leaflet will invalidate its cached size before fitting the recorded track bounds. This restores both tiles and vector layers while retaining the responsive full-height layout.

A fixed pixel height is intentionally avoided because it would degrade desktop resizing and smaller screens. Reverting the feature commit wholesale is also avoided because that would remove the required replay and readout functionality.

## Testing

Implementation will follow test-driven development:

1. Add the PAPI 5.0/5.1 NM boundary tests and confirm the 5.1 NM case fails against the current 10 NM behavior.
2. Add a focused track-map regression test that proves the map host participates in the available-height layout and that a visible map refreshes Leaflet sizing before fitting bounds.
3. Apply the smallest service, component, and CSS changes needed to pass those tests.
4. Run focused tests, the complete frontend test suite, static checks, and the production build.

## Integration

Work is isolated on `codex/fix-papi-track-map`, based on the latest `dev-web-v1`. After the two UI regressions pass verification, the already-tested flight-log UUID changes will be replayed onto this branch, revalidated as a combined change set, committed, and fast-forward merged into `dev-web-v1`.
