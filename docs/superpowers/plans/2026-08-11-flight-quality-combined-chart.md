# Flight Quality Combined Chart Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a default-visible, user-collapsible combined flight-quality chart with independently scaled colored metrics and nine filterable flight-event marker types, while preserving all existing individual charts.

**Architecture:** Move the 22 metric definitions into one registry, detect flight events in a pure service, and render a dedicated combined ECharts component with one hidden Y axis per active metric. `AnalysisChart` remains the state orchestrator so the existing metric selector drives both combined and individual views.

**Tech Stack:** React 19, TypeScript, ECharts 5, CSS Modules, Vitest, Testing Library.

## Global Constraints

- Existing individual charts remain present and keep independent Y axes.
- Metric selection defaults to altitude, ground speed, vertical speed, and G-force and controls both views.
- Combined-chart visibility is local state, defaults to visible, and is not persisted.
- All 22 metric colors are unique within each light/dark palette.
- All nine event controls are always rendered and default selected; unavailable event types are disabled.
- Each combined metric uses a separate hidden Y axis; stored and tooltip values remain unnormalized.
- Do not change backend schemas, persistence, telemetry fields, or the Flutter project.

---

### Task 1: Shared Metric Registry

**Files:**
- Create: `src/modules/flight_logs/test/flight-log-fixtures.ts`
- Create: `src/modules/flight_logs/pages/widgets/flight-chart-metrics.ts`
- Create: `src/modules/flight_logs/pages/widgets/flight-chart-metrics.test.ts`
- Modify: `src/modules/flight_logs/pages/widgets/analysis-chart.tsx`

**Interfaces:**
- Produces: `makeFlightLogPoint()`, `makeFlightLog()`, `ChartMetricId`, `ChartMetric`, `CHART_METRICS`, `DEFAULT_METRIC_IDS`, `buildMetricSeries(log)` and `metricColor(metric, isDark)`.
- Consumes: `FlightLog` and `FlightLogPoint` from `flight-log-models.ts` and localization keys from `flight-logs-localization.ts`.

- [ ] **Step 1: Add reusable typed test fixtures**

```ts
import type { FlightLog, FlightLogPoint } from '../models/flight-log-models';

export const FLIGHT_LOG_TEST_START = new Date('2026-08-11T10:00:00.000Z');

export function makeFlightLogPoint(
  offsetMs = 0,
  overrides: Partial<FlightLogPoint> = {},
): FlightLogPoint {
  return {
    latitude: 40,
    longitude: 116,
    altitude: 0,
    airspeed: 0,
    groundSpeed: 0,
    verticalSpeed: 0,
    heading: 0,
    pitch: 0,
    roll: 0,
    gForce: 1,
    gForceSource: 'body',
    fuelQuantity: 100,
    timestamp: new Date(FLIGHT_LOG_TEST_START.getTime() + offsetMs),
    anomalyAlerts: [],
    ...overrides,
  };
}

export function makeFlightLog(
  points: FlightLogPoint[],
  overrides: Partial<FlightLog> = {},
): FlightLog {
  return {
    id: 'test-flight-log',
    aircraftTitle: 'Test Aircraft',
    departureAirport: 'TEST',
    startTime: points[0]?.timestamp ?? FLIGHT_LOG_TEST_START,
    points,
    maxG: 1,
    minG: 1,
    maxAltitude: 0,
    maxAirspeed: 0,
    maxGroundSpeed: 0,
    wasOnGroundAtStart: true,
    wasOnGroundAtEnd: false,
    ...overrides,
  };
}
```

- [ ] **Step 2: Write the failing registry tests**

```ts
import { describe, expect, it } from 'vitest';
import { makeFlightLog, makeFlightLogPoint } from '../../test/flight-log-fixtures';
import {
  CHART_METRICS,
  DEFAULT_METRIC_IDS,
  buildMetricSeries,
  metricColor,
} from './flight-chart-metrics';

describe('flight chart metric registry', () => {
  it('defines 22 unique metrics and the established four defaults', () => {
    expect(CHART_METRICS).toHaveLength(22);
    expect(new Set(CHART_METRICS.map((metric) => metric.id)).size).toBe(22);
    expect(DEFAULT_METRIC_IDS).toEqual(['altitude', 'speed', 'verticalSpeed', 'gForce']);
  });

  it.each([false, true])('uses a unique color for every metric (dark=%s)', (isDark) => {
    const colors = CHART_METRICS.map((metric) => metricColor(metric, isDark));
    expect(new Set(colors).size).toBe(CHART_METRICS.length);
  });

  it('keeps real values and skips optional values that are absent', () => {
    const series = buildMetricSeries(makeFlightLog([
      makeFlightLogPoint(0, { altitude: 1000, angleOfAttack: undefined }),
      makeFlightLogPoint(60_000, { altitude: 2000, angleOfAttack: 4.25 }),
    ]));
    expect(series.get('altitude')).toEqual([[0, 1000], [1, 2000]]);
    expect(series.get('aoa')).toEqual([[1, 4.25]]);
  });
});
```

- [ ] **Step 3: Run the test and confirm RED**

Run: `npm test -- src/modules/flight_logs/pages/widgets/flight-chart-metrics.test.ts`

Expected: FAIL because `flight-chart-metrics.ts` does not exist.

- [ ] **Step 4: Implement the metric registry**

Define this public shape:

```ts
export type ChartMetricId =
  | 'altitude' | 'speed' | 'pitch' | 'verticalSpeed' | 'gForce' | 'baro' | 'aoa'
  | 'engine1N1' | 'engine2N1' | 'engine1N2' | 'engine2N2' | 'engine1Egt'
  | 'engine2Egt' | 'aileronInput' | 'elevatorInput' | 'rudderInput'
  | 'aileronTrim' | 'elevatorTrim' | 'rudderTrim' | 'crosswind'
  | 'radioAltitude' | 'gustDelta';

export interface ChartMetric {
  id: ChartMetricId;
  labelKey: string;
  unit: string;
  precision: number;
  colors: { light: string; dark: string };
  select: (point: FlightLogPoint) => number | undefined;
}

export const DEFAULT_METRIC_IDS: readonly ChartMetricId[] =
  ['altitude', 'speed', 'verticalSpeed', 'gForce'];
```

Use these ordered light/dark color pairs for the 22 registry entries:

```ts
[
  ['#2563eb', '#60a5fa'], ['#d97706', '#f59e0b'], ['#7c3aed', '#a78bfa'],
  ['#0f766e', '#2dd4bf'], ['#dc2626', '#f87171'], ['#4338ca', '#818cf8'],
  ['#15803d', '#4ade80'], ['#a16207', '#facc15'], ['#c2410c', '#fb923c'],
  ['#92400e', '#d97706'], ['#be123c', '#fb7185'], ['#c026d3', '#e879f9'],
  ['#9d174d', '#f472b6'], ['#0e7490', '#22d3ee'], ['#0369a1', '#38bdf8'],
  ['#047857', '#34d399'], ['#4d7c0f', '#a3e635'], ['#3f6212', '#84cc16'],
  ['#166534', '#86efac'], ['#1d4ed8', '#93c5fd'], ['#6d28d9', '#c4b5fd'],
  ['#b45309', '#fbbf24'],
] as const;
```

`buildMetricSeries(log)` returns `Map<ChartMetricId, [number, number][]>`, using minutes from `log.points[0].timestamp`, retaining the existing `29.92` barometric fallback and skipping other `undefined` or non-finite values.

- [ ] **Step 5: Refactor `AnalysisChart` and `MetricRow` to consume the registry**

Remove the local `ChartMetric`, `CHART_METRICS`, and `DEFAULT_METRIC_IDS`. Use `metricColor(metric, isDark)` for each selected `InfoChip` and individual line instead of the shared blue constant. Preserve current selected-metric and no-data behavior.

- [ ] **Step 6: Run focused tests and confirm GREEN**

Run: `npm test -- src/modules/flight_logs/pages/widgets/flight-chart-metrics.test.ts`

Expected: PASS.

- [ ] **Step 7: Commit Task 1**

```powershell
git add src/modules/flight_logs/test/flight-log-fixtures.ts src/modules/flight_logs/pages/widgets/flight-chart-metrics.ts src/modules/flight_logs/pages/widgets/flight-chart-metrics.test.ts src/modules/flight_logs/pages/widgets/analysis-chart.tsx
git commit -m "refactor(flight-logs): share flight chart metric definitions"
```

### Task 2: Pure Flight Event Detection

**Files:**
- Create: `src/modules/flight_logs/services/flight-chart-events.ts`
- Create: `src/modules/flight_logs/services/flight-chart-events.test.ts`

**Interfaces:**
- Produces: `FlightChartEventType`, `FlightChartEvent`, `FLIGHT_CHART_EVENT_TYPES`, `detectFlightChartEvents(log)`.
- Consumes: `FlightLog` and `FlightLogPoint` only; no React, localization, ECharts, or theme imports.

- [ ] **Step 1: Write failing tests for all event families**

```ts
import type { FlightLog, FlightLogPoint } from '../models/flight-log-models';
import { makeFlightLog, makeFlightLogPoint } from '../test/flight-log-fixtures';
import {
  detectFlightChartEvents,
  type FlightChartEvent,
} from './flight-chart-events';

function contactAt(offsetMs: number, gForce: number): FlightLogPoint {
  return makeFlightLogPoint(offsetMs, { gForce, touchdownGearG: gForce, onGround: true });
}

function landingLogWithContacts(
  contacts: FlightLogPoint[],
  overrides: Partial<FlightLog> = {},
): FlightLog {
  const points = overrides.points ?? contacts;
  const finalContact = contacts.at(-1) ?? makeFlightLogPoint();
  return makeFlightLog(points, {
    ...overrides,
    landingData: {
      latitude: finalContact.latitude,
      longitude: finalContact.longitude,
      gForce: finalContact.touchdownGearG ?? finalContact.gForce,
      gForceSource: finalContact.gForceSource,
      verticalSpeed: finalContact.verticalSpeed,
      airspeed: finalContact.airspeed,
      groundSpeed: finalContact.groundSpeed,
      pitch: finalContact.pitch,
      roll: finalContact.roll,
      rating: 'good',
      timestamp: finalContact.timestamp,
      touchdownSequence: contacts,
      touchdownGForces: contacts.map((point) => point.touchdownGearG ?? point.gForce),
    },
  });
}

function isTouchdown(event: FlightChartEvent): boolean {
  return event.type === 'touchdown' || event.type === 'finalTouchdown';
}

describe('detectFlightChartEvents', () => {
  it('detects takeoff, flap direction, AP mode changes and gear transitions', () => {
    const events = detectFlightChartEvents(makeFlightLog([
      makeFlightLogPoint(0, { onGround: true, flapsPosition: 0, gearDown: true }),
      makeFlightLogPoint(1_000, { onGround: false, flapsPosition: 5, gearDown: true,
        autopilotLateralMode: 'LNAV', autopilotVerticalMode: 'VNAV' }),
      makeFlightLogPoint(2_000, { onGround: false, flapsPosition: 0, gearDown: false,
        autopilotLateralMode: 'HDG', autopilotVerticalMode: 'ALT' }),
      makeFlightLogPoint(3_000, { onGround: false, flapsPosition: 0, gearDown: true,
        autopilotLateralMode: 'HDG', autopilotVerticalMode: 'ALT' }),
    ]));
    expect(events.map((event) => event.type)).toEqual([
      'takeoff', 'flapsDeploy', 'autopilotLateral', 'autopilotVertical',
      'flapsRetract', 'autopilotLateral', 'autopilotVertical', 'gearUp', 'gearDown',
    ]);
  });

  it('emits only finalTouchdown for a single landing contact', () => {
    const log = landingLogWithContacts([contactAt(5_000, 1.12)]);
    expect(detectFlightChartEvents(log).filter(isTouchdown).map((event) => event.type))
      .toEqual(['finalTouchdown']);
  });

  it('emits each contact and a final marker for multiple contacts', () => {
    const log = landingLogWithContacts([contactAt(5_000, 1.34), contactAt(7_000, 1.08)]);
    expect(detectFlightChartEvents(log).filter(isTouchdown).map((event) => event.type))
      .toEqual(['touchdown', 'touchdown', 'finalTouchdown']);
  });
});
```

Add these concrete normalization and ordering cases in the same file:

```ts
it('parses flap labels and ignores inactive AP tokens', () => {
  const events = detectFlightChartEvents(makeFlightLog([
    makeFlightLogPoint(0, { flapsLabel: 'UP', autopilotLateralMode: '--' }),
    makeFlightLogPoint(1_000, { flapsLabel: '5°', autopilotLateralMode: ' lnav ' }),
    makeFlightLogPoint(2_000, { flapsLabel: '0', autopilotLateralMode: 'N/A' }),
  ]));
  expect(events.filter((event) => event.type.startsWith('flaps')).map((event) =>
    [event.type, event.detail],
  )).toEqual([['flapsDeploy', '5°'], ['flapsRetract', '0°']]);
  expect(events.filter((event) => event.type === 'autopilotLateral').map((event) =>
    event.detail,
  )).toEqual(['LNAV']);
});

it('matches landing timestamps to the nearest point and sorts simultaneous types', () => {
  const log = landingLogWithContacts([contactAt(1_450, 1.31), contactAt(2_450, 1.07)], {
    points: [makeFlightLogPoint(0), makeFlightLogPoint(1_000), makeFlightLogPoint(2_000), makeFlightLogPoint(3_000)],
  });
  const events = detectFlightChartEvents(log).filter(isTouchdown);
  expect(events.map((event) => event.pointIndex)).toEqual([1, 2, 2]);
  expect(events.map((event) => event.type)).toEqual([
    'touchdown', 'touchdown', 'finalTouchdown',
  ]);
});
```

- [ ] **Step 2: Run the event test and confirm RED**

Run: `npm test -- src/modules/flight_logs/services/flight-chart-events.test.ts`

Expected: FAIL because the detector does not exist.

- [ ] **Step 3: Implement event types and structured details**

```ts
export const FLIGHT_CHART_EVENT_TYPES = [
  'takeoff', 'flapsDeploy', 'flapsRetract', 'autopilotLateral',
  'autopilotVertical', 'gearDown', 'gearUp', 'touchdown', 'finalTouchdown',
] as const;

export type FlightChartEventType = (typeof FLIGHT_CHART_EVENT_TYPES)[number];

export interface FlightChartEvent {
  type: FlightChartEventType;
  timestamp: Date;
  pointIndex: number;
  timeMinutes: number;
  detail?: string;
  sequence?: number;
  gForce?: number;
}

export function detectFlightChartEvents(log: FlightLog): FlightChartEvent[];
```

Port the confirmed Flutter transition rules. Normalize AP modes with `trim().toUpperCase()` and treat empty, `OFF`, `--`, and `N/A` as inactive. Parse flap labels using `/-?\d+(\.\d+)?/`, with `UP` and `0` resolving to zero. Sort markers by timestamp, then by `FLIGHT_CHART_EVENT_TYPES` order for deterministic simultaneous events.

Measure `timeMinutes` from `log.points[0]?.timestamp ?? log.startTime`, exactly matching `buildMetricSeries()`.

- [ ] **Step 4: Run focused tests and confirm GREEN**

Run: `npm test -- src/modules/flight_logs/services/flight-chart-events.test.ts`

Expected: PASS.

- [ ] **Step 5: Commit Task 2**

```powershell
git add src/modules/flight_logs/services/flight-chart-events.ts src/modules/flight_logs/services/flight-chart-events.test.ts
git commit -m "feat(flight-logs): detect flight chart events"
```

### Task 3: Independently Scaled Combined Chart

**Files:**
- Create: `src/modules/flight_logs/pages/widgets/combined-flight-chart.tsx`
- Create: `src/modules/flight_logs/pages/widgets/combined-flight-chart.test.ts`

**Interfaces:**
- Consumes: active `ChartMetric[]`, `Map<ChartMetricId, [number, number][]>`, localized event labels, selected `FlightChartEvent[]`, `isDark`, and minute-unit text.
- Produces: `CombinedFlightChart` and exported pure `buildCombinedFlightChartOption(input): EChartsOption` for tests.

- [ ] **Step 1: Write the failing chart-option tests**

```ts
function inputWithMetrics(ids: ChartMetricId[]): CombinedFlightChartInput {
  const metrics = ids.map((id) => CHART_METRICS.find((metric) => metric.id === id)!);
  return {
    metrics,
    seriesByMetric: new Map([
      ['altitude', [[0, 3000], [1, 4000]]],
      ['gForce', [[0, 1], [1, 1.08]]],
    ]),
    events: [],
    labels: {
      metrics: Object.fromEntries(CHART_METRICS.map((metric) => [metric.id, metric.id])),
      events: Object.fromEntries(FLIGHT_CHART_EVENT_TYPES.map((type) => [type, type])),
    },
    isDark: false,
    minuteUnit: 'min',
  };
}

function inputWithSimultaneousEvents(): CombinedFlightChartInput {
  return {
    ...inputWithMetrics(['altitude']),
    events: FLIGHT_CHART_EVENT_TYPES.map((type, index) => ({
      type,
      timestamp: new Date('2026-08-11T10:01:00.000Z'),
      pointIndex: 1,
      timeMinutes: 1,
      detail: String(index),
    })),
  };
}

it('binds every metric to its own hidden scaled Y axis without normalizing values', () => {
  const option = buildCombinedFlightChartOption(inputWithMetrics(['altitude', 'gForce']));
  const axes = option.yAxis as YAXisComponentOption[];
  const series = option.series as LineSeriesOption[];
  expect(axes).toHaveLength(2);
  expect(axes.every((axis) => axis.show === false && axis.scale === true)).toBe(true);
  expect(series[0].yAxisIndex).toBe(0);
  expect(series[1].yAxisIndex).toBe(1);
  expect(series[0].data).toContainEqual([1, 4000]);
  expect(series[1].data).toContainEqual([1, 1.08]);
});

it('uses deterministic offsets for simultaneous event markers', () => {
  const option = buildCombinedFlightChartOption(inputWithSimultaneousEvents());
  const eventSeries = (option.series as ScatterSeriesOption[]).filter(
    (series) => series.type === 'scatter',
  );
  expect(new Set(eventSeries.map((series) => JSON.stringify(series.symbolOffset))).size)
    .toBe(eventSeries.length);
});

it.each([false, true])('uses nine unique event colors (dark=%s)', (isDark) => {
  const colors = FLIGHT_CHART_EVENT_TYPES.map((type) => eventColor(type, isDark));
  expect(new Set(colors).size).toBe(FLIGHT_CHART_EVENT_TYPES.length);
});
```

- [ ] **Step 2: Run the option test and confirm RED**

Run: `npm test -- src/modules/flight_logs/pages/widgets/combined-flight-chart.test.ts`

Expected: FAIL because the combined chart builder does not exist.

- [ ] **Step 3: Implement the combined option builder**

Build on `baseChartOption()` and create:

```ts
yAxis: metrics.map(() => ({ type: 'value', show: false, scale: true })),
series: [
  ...metrics.map((metric, index) => ({
    name: labels.metrics[metric.id],
    type: 'line',
    data: seriesByMetric.get(metric.id) ?? [],
    yAxisIndex: index,
    showSymbol: false,
    smooth: 0.2,
    lineStyle: { width: 2, color: metricColor(metric, isDark) },
    itemStyle: { color: metricColor(metric, isDark) },
  })),
  ...eventSeries,
],
```

Anchor event scatter data to the first active metric's nearest X value. Use a stable `EVENT_SYMBOL_OFFSETS` record indexed by event type. The custom tooltip distinguishes line and event params, formats metric precision and units, and emits localized event text unchanged.

Define the event palette in this module so filters and scatter markers share one source:

```ts
export const FLIGHT_CHART_EVENT_COLORS = {
  takeoff: { light: '#0284c7', dark: '#38bdf8' },
  flapsDeploy: { light: '#7c3aed', dark: '#a78bfa' },
  flapsRetract: { light: '#a21caf', dark: '#e879f9' },
  autopilotLateral: { light: '#0891b2', dark: '#22d3ee' },
  autopilotVertical: { light: '#15803d', dark: '#4ade80' },
  gearDown: { light: '#047857', dark: '#34d399' },
  gearUp: { light: '#c2410c', dark: '#fb923c' },
  touchdown: { light: '#ea580c', dark: '#f97316' },
  finalTouchdown: { light: '#dc2626', dark: '#f87171' },
} as const satisfies Record<FlightChartEventType, { light: string; dark: string }>;

export function eventColor(type: FlightChartEventType, isDark: boolean): string {
  return FLIGHT_CHART_EVENT_COLORS[type][isDark ? 'dark' : 'light'];
}
```

The shared ECharts wrapper already registers both `LineChart` and `ScatterChart`; no wrapper or bundle registration change is required.

- [ ] **Step 4: Render the chart host**

`CombinedFlightChart` memoizes the option and renders `<EChart option={option} height="100%" />` inside a CSS-sized host supplied by the parent.

- [ ] **Step 5: Run focused tests and confirm GREEN**

Run: `npm test -- src/modules/flight_logs/pages/widgets/combined-flight-chart.test.ts`

Expected: PASS.

- [ ] **Step 6: Commit Task 3**

```powershell
git add src/modules/flight_logs/pages/widgets/combined-flight-chart.tsx src/modules/flight_logs/pages/widgets/combined-flight-chart.test.ts
git commit -m "feat(flight-logs): add independently scaled combined chart"
```

### Task 4: Filters, Visibility, Localization, and Responsive Layout

**Files:**
- Modify: `src/modules/flight_logs/pages/widgets/analysis-chart.tsx`
- Create: `src/modules/flight_logs/pages/widgets/analysis-chart.test.tsx`
- Modify: `src/modules/flight_logs/pages/widgets/flight-logs-widgets.module.css`
- Modify: `src/modules/flight_logs/localization/flight-logs-localization.ts`

**Interfaces:**
- Consumes: registry, detected events, and `CombinedFlightChart` from Tasks 1-3.
- Produces: the complete user interaction described by the approved design.

- [ ] **Step 1: Add failing jsdom component tests**

Mock `CombinedFlightChart` and `EChart`, render a representative log, then assert:

```tsx
vi.mock('./combined-flight-chart', () => ({
  CombinedFlightChart: vi.fn(() => null),
}));

function latestCombinedChartProps(): CombinedFlightChartProps {
  const props = vi.mocked(CombinedFlightChart).mock.calls.at(-1)?.[0];
  if (!props) throw new Error('CombinedFlightChart was not rendered');
  return props;
}

expect(screen.getByRole('region', { name: 'Combined chart' })).toBeVisible();
expect(screen.getAllByRole('button', { pressed: true })).toHaveLength(13); // 4 metrics + 9 events
expect(screen.getByRole('button', { name: 'Gear up' })).toBeDisabled();

await user.click(screen.getByRole('button', { name: 'Hide combined chart' }));
expect(screen.queryByRole('region', { name: 'Combined chart' })).not.toBeInTheDocument();
expect(screen.getByText('Altitude (ft)')).toBeInTheDocument();

await user.click(screen.getByRole('button', { name: 'Pitch (°)' }));
expect(latestCombinedChartProps().metrics.map((metric) => metric.id)).toContain('pitch');
expect(screen.getByTestId('metric-row-pitch')).toBeInTheDocument();
```

- [ ] **Step 2: Run the component test and confirm RED**

Run: `npm test -- src/modules/flight_logs/pages/widgets/analysis-chart.test.tsx`

Expected: FAIL because the combined region and event controls do not exist.

- [ ] **Step 3: Add localization keys and translations**

Add these keys to both `zh_CN` and `en_US` maps:

```ts
chartCombined: 'flight_logs.chart.combined',
chartShowCombined: 'flight_logs.chart.show_combined',
chartHideCombined: 'flight_logs.chart.hide_combined',
chartEvents: 'flight_logs.chart.events',
```

Chinese values: `合并图表`, `显示合并图表`, `隐藏合并图表`, `飞行事件`.

English values: `Combined Chart`, `Show Combined Chart`, `Hide Combined Chart`, `Flight Events`.

Reuse the existing nine event label keys for event controls and formatted markers.

- [ ] **Step 4: Implement local chart filter buttons**

Use a local semantic `<button type="button">` component with `aria-pressed`, `disabled`, a visible check icon when selected, and the registry/event color applied to border, text, and selected background. Do not change the shared `InfoChip` API.

- [ ] **Step 5: Integrate state and data flow**

```ts
const [selectedIds, setSelectedIds] = useState<ChartMetricId[]>([...DEFAULT_METRIC_IDS]);
const [showCombined, setShowCombined] = useState(true);
const [selectedEvents, setSelectedEvents] = useState<FlightChartEventType[]>([
  ...FLIGHT_CHART_EVENT_TYPES,
]);

const detectedEvents = useMemo(() => detectFlightChartEvents(log), [log]);
const availableEvents = useMemo(
  () => new Set(detectedEvents.map((event) => event.type)),
  [detectedEvents],
);
```

Render the metric controls, all nine event controls, visibility control, combined region, then the existing `smallMultiples`. Pass only selected and available events to `CombinedFlightChart`. Keep unavailable event controls selected but disabled so availability changes do not silently rewrite user state.

- [ ] **Step 6: Add responsive styles**

Add `.chartToolbar`, `.filterGroup`, `.filterGroupLabel`, `.chartFilter`, `.chartFilterSelected`, `.chartFilterDisabled`, `.combinedChartPanel`, and `.combinedChartHost`. Set the host to `height: clamp(320px, 46vh, 460px)` and reduce the minimum to `280px` below 650 px. Use existing theme variables for surfaces and borders.

- [ ] **Step 7: Run component, i18n, and focused feature tests**

Run:

```powershell
npm test -- src/modules/flight_logs/pages/widgets/analysis-chart.test.tsx src/modules/flight_logs/pages/widgets/combined-flight-chart.test.ts src/modules/flight_logs/services/flight-chart-events.test.ts src/modules/flight_logs/pages/widgets/flight-chart-metrics.test.ts
npm run check:i18n
```

Expected: all PASS.

- [ ] **Step 8: Commit Task 4**

```powershell
git add src/modules/flight_logs/pages/widgets/analysis-chart.tsx src/modules/flight_logs/pages/widgets/analysis-chart.test.tsx src/modules/flight_logs/pages/widgets/flight-logs-widgets.module.css src/modules/flight_logs/localization/flight-logs-localization.ts
git commit -m "feat(flight-logs): integrate combined quality chart controls"
```

### Task 5: Full Verification and Integration Readiness

**Files:**
- Review all files changed since `33f1743`.

- [ ] **Step 1: Run all focused tests again**

```powershell
npm test -- src/modules/flight_logs/pages/widgets/flight-chart-metrics.test.ts src/modules/flight_logs/services/flight-chart-events.test.ts src/modules/flight_logs/pages/widgets/combined-flight-chart.test.ts src/modules/flight_logs/pages/widgets/analysis-chart.test.tsx
```

Expected: all PASS.

- [ ] **Step 2: Run complete quality verification**

```powershell
npm run check
npm run build
git diff --check dev-web-v1...HEAD
```

Expected: version, architecture, i18n, lint, typecheck, all Vitest files, and production build pass; no whitespace errors.

- [ ] **Step 3: Perform browser smoke testing when available**

Verify on desktop and a narrow viewport:

1. The combined chart is visible by default with four differently colored lines.
2. Metric selection updates the combined and individual views together.
3. Hiding the combined chart leaves individual rows visible.
4. All nine event filters remain present; unavailable filters are disabled.
5. Available event markers and tooltips use matching colors and detailed labels.
6. Light and dark themes resize without overflow or stale ECharts layout.

- [ ] **Step 4: Review final history and worktree state**

Run `git status --short` and `git log --oneline dev-web-v1..HEAD`. The worktree must be clean and contain only the design plus the focused feature commits before requesting integration.
