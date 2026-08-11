import { FlightLogsLocalizationKeys as K } from '../../localization/flight-logs-localization';
import type { FlightLog, FlightLogPoint } from '../../models/flight-log-models';

export type ChartMetricId =
  | 'altitude'
  | 'speed'
  | 'pitch'
  | 'verticalSpeed'
  | 'gForce'
  | 'baro'
  | 'aoa'
  | 'engine1N1'
  | 'engine2N1'
  | 'engine1N2'
  | 'engine2N2'
  | 'engine1Egt'
  | 'engine2Egt'
  | 'aileronInput'
  | 'elevatorInput'
  | 'rudderInput'
  | 'aileronTrim'
  | 'elevatorTrim'
  | 'rudderTrim'
  | 'crosswind'
  | 'radioAltitude'
  | 'gustDelta';

export interface ChartMetric {
  id: ChartMetricId;
  labelKey: string;
  unit: string;
  precision: number;
  colors: { light: string; dark: string };
  select: (point: FlightLogPoint) => number | undefined;
}

export const DEFAULT_METRIC_IDS: readonly ChartMetricId[] = [
  'altitude',
  'speed',
  'verticalSpeed',
  'gForce',
];

export const CHART_METRICS: readonly ChartMetric[] = [
  {
    id: 'altitude',
    labelKey: K.chartAltitude,
    unit: 'ft',
    precision: 0,
    colors: { light: '#2563eb', dark: '#60a5fa' },
    select: (point) => point.altitude,
  },
  {
    id: 'speed',
    labelKey: K.chartSpeed,
    unit: 'kt',
    precision: 1,
    colors: { light: '#d97706', dark: '#f59e0b' },
    select: (point) => point.groundSpeed,
  },
  {
    id: 'pitch',
    labelKey: K.chartPitch,
    unit: '\u00b0',
    precision: 1,
    colors: { light: '#7c3aed', dark: '#a78bfa' },
    select: (point) => point.pitch,
  },
  {
    id: 'verticalSpeed',
    labelKey: K.chartVerticalSpeed,
    unit: 'fpm',
    precision: 0,
    colors: { light: '#0f766e', dark: '#2dd4bf' },
    select: (point) => point.verticalSpeed,
  },
  {
    id: 'gForce',
    labelKey: K.chartGForce,
    unit: 'G',
    precision: 2,
    colors: { light: '#dc2626', dark: '#f87171' },
    select: (point) => point.gForce,
  },
  {
    id: 'baro',
    labelKey: K.chartBaro,
    unit: 'inHg',
    precision: 2,
    colors: { light: '#4338ca', dark: '#818cf8' },
    select: (point) => point.baroPressure ?? 29.92,
  },
  {
    id: 'aoa',
    labelKey: K.chartAoa,
    unit: '\u00b0',
    precision: 2,
    colors: { light: '#15803d', dark: '#4ade80' },
    select: (point) => point.angleOfAttack,
  },
  {
    id: 'engine1N1',
    labelKey: K.chartEngine1N1,
    unit: '%',
    precision: 1,
    colors: { light: '#a16207', dark: '#facc15' },
    select: (point) => point.engine1N1,
  },
  {
    id: 'engine2N1',
    labelKey: K.chartEngine2N1,
    unit: '%',
    precision: 1,
    colors: { light: '#c2410c', dark: '#fb923c' },
    select: (point) => point.engine2N1,
  },
  {
    id: 'engine1N2',
    labelKey: K.chartEngine1N2,
    unit: '%',
    precision: 1,
    colors: { light: '#92400e', dark: '#d97706' },
    select: (point) => point.engine1N2,
  },
  {
    id: 'engine2N2',
    labelKey: K.chartEngine2N2,
    unit: '%',
    precision: 1,
    colors: { light: '#be123c', dark: '#fb7185' },
    select: (point) => point.engine2N2,
  },
  {
    id: 'engine1Egt',
    labelKey: K.chartEngine1Egt,
    unit: '\u00b0C',
    precision: 0,
    colors: { light: '#c026d3', dark: '#e879f9' },
    select: (point) => point.engine1Egt,
  },
  {
    id: 'engine2Egt',
    labelKey: K.chartEngine2Egt,
    unit: '\u00b0C',
    precision: 0,
    colors: { light: '#9d174d', dark: '#f472b6' },
    select: (point) => point.engine2Egt,
  },
  {
    id: 'aileronInput',
    labelKey: K.chartAileronInput,
    unit: '',
    precision: 2,
    colors: { light: '#0e7490', dark: '#22d3ee' },
    select: (point) => point.aileronInput,
  },
  {
    id: 'elevatorInput',
    labelKey: K.chartElevatorInput,
    unit: '',
    precision: 2,
    colors: { light: '#0369a1', dark: '#38bdf8' },
    select: (point) => point.elevatorInput,
  },
  {
    id: 'rudderInput',
    labelKey: K.chartRudderInput,
    unit: '',
    precision: 2,
    colors: { light: '#047857', dark: '#34d399' },
    select: (point) => point.rudderInput,
  },
  {
    id: 'aileronTrim',
    labelKey: K.chartAileronTrim,
    unit: '',
    precision: 2,
    colors: { light: '#4d7c0f', dark: '#a3e635' },
    select: (point) => point.aileronTrim,
  },
  {
    id: 'elevatorTrim',
    labelKey: K.chartElevatorTrim,
    unit: '',
    precision: 2,
    colors: { light: '#3f6212', dark: '#84cc16' },
    select: (point) => point.elevatorTrim,
  },
  {
    id: 'rudderTrim',
    labelKey: K.chartRudderTrim,
    unit: '',
    precision: 2,
    colors: { light: '#166534', dark: '#86efac' },
    select: (point) => point.rudderTrim,
  },
  {
    id: 'crosswind',
    labelKey: K.chartCrosswind,
    unit: 'kt',
    precision: 1,
    colors: { light: '#1d4ed8', dark: '#93c5fd' },
    select: (point) => point.crosswindComponent,
  },
  {
    id: 'radioAltitude',
    labelKey: K.chartRadioAltitude,
    unit: 'ft',
    precision: 0,
    colors: { light: '#6d28d9', dark: '#c4b5fd' },
    select: (point) => point.radioAltitude,
  },
  {
    id: 'gustDelta',
    labelKey: K.chartGustDelta,
    unit: 'kt',
    precision: 1,
    colors: { light: '#b45309', dark: '#fbbf24' },
    select: (point) => point.gustDelta,
  },
];

export function metricColor(metric: ChartMetric, isDark: boolean): string {
  return metric.colors[isDark ? 'dark' : 'light'];
}

export function buildMetricSeries(
  log: FlightLog,
): Map<ChartMetricId, [number, number][]> {
  const startMs = (log.points[0]?.timestamp ?? log.startTime).getTime();
  const result = new Map<ChartMetricId, [number, number][]>();

  for (const metric of CHART_METRICS) {
    const values: [number, number][] = [];
    for (const point of log.points) {
      const value = metric.select(point);
      if (value === undefined || !Number.isFinite(value)) continue;
      values.push([(point.timestamp.getTime() - startMs) / 60_000, value]);
    }
    result.set(metric.id, values);
  }

  return result;
}