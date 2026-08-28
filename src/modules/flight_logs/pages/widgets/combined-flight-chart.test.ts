import { describe, expect, it } from 'vitest';
import {
  FLIGHT_CHART_EVENT_TYPES,
  type FlightChartEvent,
  type FlightChartEventType,
} from '../../services/flight-chart-events';
import {
  CHART_METRICS,
  type ChartMetricId,
} from './flight-chart-metrics';
import {
  buildCombinedFlightChartOption,
  eventColor,
  type CombinedFlightChartInput,
} from './combined-flight-chart';

function inputWithMetrics(ids: ChartMetricId[]): CombinedFlightChartInput {
  const metrics = ids.map((id) => {
    const metric = CHART_METRICS.find((candidate) => candidate.id === id);
    if (!metric) throw new Error('Unknown test metric: ' + id);
    return metric;
  });
  const seriesByMetric = new Map<ChartMetricId, [number, number][]>([
    ['altitude', [[0, 3000], [1, 4000]]],
    ['gForce', [[0, 1], [1, 1.08]]],
  ]);

  return {
    metrics,
    seriesByMetric,
    events: [],
    labels: {
      metrics: Object.fromEntries(
        CHART_METRICS.map((metric) => [metric.id, metric.id]),
      ) as Record<ChartMetricId, string>,
      events: Object.fromEntries(
        FLIGHT_CHART_EVENT_TYPES.map((type) => [type, type]),
      ) as Record<FlightChartEventType, string>,
    },
    isDark: false,
    minuteUnit: 'min',
  };
}

function inputWithSimultaneousEvents(): CombinedFlightChartInput {
  const events: FlightChartEvent[] = FLIGHT_CHART_EVENT_TYPES.map(
    (type, index) => ({
      type,
      timestamp: new Date('2026-08-11T10:01:00.000Z'),
      pointIndex: 1,
      timeMinutes: 1,
      detail: String(index),
    }),
  );
  return {
    ...inputWithMetrics(['altitude']),
    events,
  };
}

type AxisOption = {
  show?: boolean;
  scale?: boolean;
};

type SeriesOption = {
  type?: string;
  yAxisIndex?: number;
  data?: unknown[];
  symbolOffset?: unknown;
};

describe('buildCombinedFlightChartOption', () => {
  it('binds every metric to its own hidden scaled Y axis without normalizing values', () => {
    const option = buildCombinedFlightChartOption(
      inputWithMetrics(['altitude', 'gForce']),
    );
    const axes = option.yAxis as AxisOption[];
    const series = option.series as SeriesOption[];

    expect(axes).toHaveLength(2);
    expect(
      axes.every((axis) => axis.show === false && axis.scale === true),
    ).toBe(true);
    expect(series[0].yAxisIndex).toBe(0);
    expect(series[1].yAxisIndex).toBe(1);
    expect(series[0].data).toContainEqual([1, 4000]);
    expect(series[1].data).toContainEqual([1, 1.08]);
  });

  it('anchors event markers to the first active metric without changing its value', () => {
    const event: FlightChartEvent = {
      type: 'takeoff',
      timestamp: new Date('2026-08-11T10:00:50.000Z'),
      pointIndex: 1,
      timeMinutes: 0.8,
    };
    const option = buildCombinedFlightChartOption({
      ...inputWithMetrics(['altitude', 'gForce']),
      events: [event],
    });
    const eventSeries = (option.series as SeriesOption[]).find(
      (series) => series.type === 'scatter',
    );

    expect(eventSeries?.yAxisIndex).toBe(0);
    expect(eventSeries?.data).toEqual([
      expect.objectContaining({ value: [0.8, 4000] }),
    ]);
  });

  it('keeps event markers on their exact time while separating simultaneous events vertically', () => {
    const first = buildCombinedFlightChartOption(
      inputWithSimultaneousEvents(),
    );
    const second = buildCombinedFlightChartOption(
      inputWithSimultaneousEvents(),
    );
    const firstOffsets = (first.series as SeriesOption[])
      .filter((series) => series.type === 'scatter')
      .map((series) => series.symbolOffset);
    const secondOffsets = (second.series as SeriesOption[])
      .filter((series) => series.type === 'scatter')
      .map((series) => series.symbolOffset);

    expect(firstOffsets.every((offset) => (
      Array.isArray(offset) && offset[0] === 0
    ))).toBe(true);
    expect(new Set(firstOffsets.map((offset) => JSON.stringify(offset))).size)
      .toBeGreaterThan(1);
    expect(secondOffsets).toEqual(firstOffsets);
  });

  it('formats real metric values, units and event details in the tooltip', () => {
    const option = buildCombinedFlightChartOption({
      ...inputWithMetrics(['altitude', 'gForce']),
      events: [{
        type: 'autopilotLateral',
        timestamp: new Date('2026-08-11T10:01:00.000Z'),
        pointIndex: 1,
        timeMinutes: 1,
        detail: 'LNAV',
      }],
    });
    const tooltip = option.tooltip as {
      formatter: (params: unknown) => string;
    };
    const formatted = tooltip.formatter([
      { seriesIndex: 0, seriesType: 'line', value: [1, 4000] },
      { seriesIndex: 1, seriesType: 'line', value: [1, 1.08] },
      { seriesIndex: 2, seriesType: 'scatter', value: [1, 4000] },
    ]);

    expect(formatted).toContain('altitude: 4000 ft');
    expect(formatted).toContain('gForce: 1.08 G');
    expect(formatted).toContain('autopilotLateral: LNAV');
  });

  it.each([false, true])(
    'uses nine unique event colors (dark=%s)',
    (isDark) => {
      const colors = FLIGHT_CHART_EVENT_TYPES.map((type) =>
        eventColor(type, isDark),
      );
      expect(new Set(colors).size).toBe(FLIGHT_CHART_EVENT_TYPES.length);
    },
  );
});
