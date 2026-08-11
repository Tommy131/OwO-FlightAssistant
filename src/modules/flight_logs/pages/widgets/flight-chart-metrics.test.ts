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

  it('uses the first point as the shared time origin and keeps the barometric fallback', () => {
    const series = buildMetricSeries(makeFlightLog([
      makeFlightLogPoint(60_000, { baroPressure: undefined }),
      makeFlightLogPoint(180_000, { baroPressure: 30.01 }),
    ]));

    expect(series.get('baro')).toEqual([[0, 29.92], [2, 30.01]]);
  });

  it('omits non-finite values from chart series', () => {
    const series = buildMetricSeries(makeFlightLog([
      makeFlightLogPoint(0, { altitude: Number.NaN }),
      makeFlightLogPoint(60_000, { altitude: Number.POSITIVE_INFINITY }),
      makeFlightLogPoint(120_000, { altitude: 500 }),
    ]));

    expect(series.get('altitude')).toEqual([[2, 500]]);
  });
});