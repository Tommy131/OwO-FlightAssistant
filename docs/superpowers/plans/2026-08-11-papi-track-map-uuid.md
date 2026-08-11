# PAPI Range, Track Map, and Flight Log UUID Implementation Plan

> **For Codex:** Execute this plan task by task with `superpowers:test-driven-development`, then use `superpowers:verification-before-completion` before committing or merging.

**Goal:** Limit PAPI guidance to runway thresholds within 5 NM, restore the responsive Leaflet flight-track map without removing its analysis controls, and integrate UUID-based flight-log identity.

**Architecture:** Keep runway eligibility in the pure PAPI service. Add an explicit fill mode to the shared Leaflet wrapper so an absolutely positioned map canvas fills a flex-sized host whose minimum height is definite. Reapply the isolated UUID change in the flight-log store and cover same-millisecond recordings with a regression test.

**Tech Stack:** React 19, TypeScript, Leaflet 1.9, CSS Modules, Vitest, Testing Library, IndexedDB persistence.

---

## Task 1: Lock the PAPI Boundary with a Failing Test

**Files:**
- Modify: `src/modules/map/services/papi-guidance.test.ts`

1. Use the shared `destination()` geometry helper in `aircraftAtAngle()` so requested test distances are exact great-circle distances.
2. Replace the broad 20 NM test with two boundary cases: guidance exists at 5.0 NM and is absent at 5.1 NM.
3. Run `npm test -- src/modules/map/services/papi-guidance.test.ts`.
4. Confirm RED: the 5.1 NM assertion fails because the current service accepts distances up to 10 NM.

## Task 2: Implement the 5 NM PAPI Limit

**Files:**
- Modify: `src/modules/map/services/papi-guidance.ts`
- Modify: `src/modules/map/widgets/papi-indicator.tsx`

1. Change the service maximum from 10 NM to 5 NM while preserving the inclusive `distanceNm <= MAX_DISTANCE_NM` behavior.
2. Update the widget comment/documentation from 10 NM to 5 NM.
3. Re-run `npm test -- src/modules/map/services/papi-guidance.test.ts` and confirm GREEN.

## Task 3: Reproduce the Collapsed Leaflet Canvas

**Files:**
- Create: `src/core/widgets/common/leaflet-map.test.tsx`

1. Add a jsdom component test with Leaflet and `ResizeObserver` mocked at the lifecycle boundary.
2. Render `<LeafletMap fill />` inside a positioned host.
3. Assert the map canvas uses absolute positioning with all four insets set to zero instead of relying on percentage height.
4. Assert a resize notification invalidates Leaflet's cached size.
5. Run `npm test -- src/core/widgets/common/leaflet-map.test.tsx`.
6. Confirm RED: `fill` is not yet a supported prop and the expected fill geometry is absent.

## Task 4: Restore the Responsive Track Map

**Files:**
- Modify: `src/core/widgets/common/leaflet-map.tsx`
- Modify: `src/modules/flight_logs/pages/widgets/analysis-widgets.tsx`
- Modify: `src/modules/flight_logs/pages/widgets/flight-logs-widgets.module.css` only if the host needs an explicit overflow/border adjustment.

1. Add an optional `fill` prop to `LeafletMap`.
2. In fill mode, render the Leaflet canvas as `position: absolute` with `inset: 0` and no percentage height dependency; preserve the numeric/string `height` API for all existing callers.
3. Keep the existing `ResizeObserver` invalidation behavior.
4. Switch `AnalysisTrackMap` from `height="100%"` to fill mode inside the existing `trackMapFill` positioned host.
5. Preserve phase polylines, hit lines, markers, replay controls, and point details unchanged.
6. Run `npm test -- src/core/widgets/common/leaflet-map.test.tsx` and confirm GREEN.
7. Run `npm test -- src/modules/flight_logs/services/track-phases.test.ts` to ensure phase segmentation remains intact.

## Task 5: Integrate UUID Flight-Log Identity

**Files:**
- Modify: `src/modules/flight_logs/providers/flight-logs-store.ts`
- Modify: `src/modules/flight_logs/providers/active-log-recovery.test.ts`
- Modify: `README.md`
- Modify: `docs/DESIGN.md`

1. Add the same-millisecond circuit-recording regression test from the isolated UUID worktree.
2. Run `npm test -- src/modules/flight_logs/providers/active-log-recovery.test.ts` and confirm RED against timestamp IDs.
3. Generate new flight-log IDs with `crypto.randomUUID()` at recording start; do not mutate IDs during save, recovery, or replay.
4. Update the flight-log identity documentation to specify UUID v4 uniqueness.
5. Re-run the focused recovery test and confirm GREEN.

## Task 6: Combined Verification and Review

**Files:**
- Review every changed source, test, and documentation file.

1. Run focused tests:
   - `npm test -- src/modules/map/services/papi-guidance.test.ts`
   - `npm test -- src/core/widgets/common/leaflet-map.test.tsx`
   - `npm test -- src/modules/flight_logs/providers/active-log-recovery.test.ts`
2. Run `npm run check` and require all lint, type, architecture, i18n, version, and test checks to pass.
3. Run `npm run build` and require a successful production bundle.
4. Inspect `git diff --check`, `git status --short`, and the final diff for unintended changes.
5. Perform a browser smoke test of the flight-log track tab if the local app can be launched with representative log data; verify tiles, coloured track layers, replay controls, and point readouts are simultaneously visible.

## Task 7: Commit and Fast-Forward Merge

1. Commit the verified implementation on `codex/fix-papi-track-map` with a focused conventional commit message.
2. Confirm `dev-web-v1` has not moved since the worktree was created. If it moved, stop and reconcile without discarding others' changes.
3. Fast-forward merge `codex/fix-papi-track-map` into `dev-web-v1`.
4. Re-run `git status --short` on the target checkout and report the resulting commit IDs.
