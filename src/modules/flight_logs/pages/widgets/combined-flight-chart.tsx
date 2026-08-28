import { useMemo } from 'react';
import type { EChartsOption } from 'echarts';
import { baseChartOption, EChart } from '../../../../core/widgets/common/echart';
import {
  type FlightChartEvent,
  type FlightChartEventType,
} from '../../services/flight-chart-events';
import {
  metricColor,
  type ChartMetric,
  type ChartMetricId,
} from './flight-chart-metrics';

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
} as const satisfies Record<
  FlightChartEventType,
  { light: string; dark: string }
>;

const EVENT_SYMBOL_OFFSETS = {
  // Keep the horizontal offset at zero: the marker must remain on the exact
  // event time selected by the axis tooltip. Separate simultaneous events
  // vertically instead, otherwise their icons appear beside the hover line.
  takeoff: [0, -18],
  flapsDeploy: [0, -34],
  flapsRetract: [0, -18],
  autopilotLateral: [0, -34],
  autopilotVertical: [0, -18],
  gearDown: [0, -34],
  gearUp: [0, -18],
  touchdown: [0, -34],
  finalTouchdown: [0, -18],
} as const satisfies Record<FlightChartEventType, readonly [number, number]>;

export interface CombinedFlightChartLabels {
  metrics: Record<ChartMetricId, string>;
  events: Record<FlightChartEventType, string>;
}

export interface CombinedFlightChartInput {
  metrics: readonly ChartMetric[];
  seriesByMetric: ReadonlyMap<ChartMetricId, [number, number][]>;
  events: readonly FlightChartEvent[];
  labels: CombinedFlightChartLabels;
  isDark: boolean;
  minuteUnit: string;
}

export type CombinedFlightChartProps = CombinedFlightChartInput;

export function eventColor(
  type: FlightChartEventType,
  isDark: boolean,
): string {
  return FLIGHT_CHART_EVENT_COLORS[type][isDark ? 'dark' : 'light'];
}

export function buildCombinedFlightChartOption(
  input: CombinedFlightChartInput,
): EChartsOption {
  const {
    metrics,
    seriesByMetric,
    events,
    labels,
    isDark,
    minuteUnit,
  } = input;
  const base = baseChartOption({
    isDark,
    showXAxisLabel: true,
    grid: { left: 18, right: 18, top: 40, bottom: 28 },
  });
  const firstMetricData =
    metrics.length > 0
      ? seriesByMetric.get(metrics[0].id) ?? []
      : [];

  const metricSeries = metrics.map((metric, index) => {
    const color = metricColor(metric, isDark);
    return {
      name: labels.metrics[metric.id],
      type: 'line' as const,
      data: seriesByMetric.get(metric.id) ?? [],
      yAxisIndex: index,
      showSymbol: false,
      smooth: 0.2,
      lineStyle: { width: 2, color },
      itemStyle: { color },
      emphasis: { focus: 'series' as const },
    };
  });

  const eventSeries = events.map((event) => {
    const color = eventColor(event.type, isDark);
    const anchor = nearestMetricValue(firstMetricData, event.timeMinutes);
    return {
      name: labels.events[event.type],
      type: 'scatter' as const,
      yAxisIndex: 0,
      data: [{
        value: [event.timeMinutes, anchor],
        eventType: event.type,
      }],
      symbol: event.type === 'finalTouchdown' ? 'diamond' : 'circle',
      symbolSize: event.type === 'finalTouchdown' ? 13 : 10,
      symbolOffset: [...EVENT_SYMBOL_OFFSETS[event.type]],
      itemStyle: {
        color,
        borderColor: isDark ? '#16213e' : '#ffffff',
        borderWidth: 1,
      },
      z: 10,
    };
  });

  return {
    ...base,
    xAxis: {
      ...(base.xAxis as object),
      axisLabel: {
        show: true,
        color: '#898781',
        fontSize: 10,
        fontFamily: 'inherit',
        formatter: (value: number) => value.toFixed(0) + minuteUnit,
      },
    },
    yAxis: metrics.map(() => ({
      type: 'value' as const,
      show: false,
      scale: true,
    })),
    tooltip: {
      ...(base.tooltip as object),
      trigger: 'axis',
      formatter: (params: unknown) =>
        formatCombinedTooltip(params, input),
    },
    series: [...metricSeries, ...eventSeries],
  };
}

export function CombinedFlightChart(props: CombinedFlightChartProps) {
  const option = useMemo(
    () => buildCombinedFlightChartOption(props),
    [props],
  );

  return <EChart option={option} height="100%" />;
}

function nearestMetricValue(
  data: readonly [number, number][],
  timeMinutes: number,
): number {
  if (data.length === 0) return 0;

  let nearestValue = data[0][1];
  let minimumDifference = Math.abs(data[0][0] - timeMinutes);
  for (let index = 1; index < data.length; index += 1) {
    const difference = Math.abs(data[index][0] - timeMinutes);
    if (difference < minimumDifference) {
      minimumDifference = difference;
      nearestValue = data[index][1];
    }
  }
  return nearestValue;
}

interface TooltipParameter {
  seriesIndex?: number;
  seriesType?: string;
  value?: unknown;
}

function formatCombinedTooltip(
  rawParams: unknown,
  input: CombinedFlightChartInput,
): string {
  const params = Array.isArray(rawParams)
    ? rawParams as TooltipParameter[]
    : [rawParams as TooltipParameter];
  const firstValue = params
    .map((param) => chartPair(param.value))
    .find((value) => value !== undefined);
  const lines = firstValue
    ? [escapeHtml(firstValue[0].toFixed(2) + input.minuteUnit)]
    : [];

  for (const param of params) {
    const value = chartPair(param.value);
    if (!value || param.seriesIndex === undefined) continue;

    if (param.seriesType === 'line') {
      const metric = input.metrics[param.seriesIndex];
      if (!metric) continue;
      const label = input.labels.metrics[metric.id];
      const formattedValue =
        value[1].toFixed(metric.precision) +
        (metric.unit ? ' ' + metric.unit : '');
      lines.push(
        colorBullet(metricColor(metric, input.isDark)) +
          escapeHtml(label + ': ' + formattedValue),
      );
      continue;
    }

    if (param.seriesType === 'scatter') {
      const eventIndex = param.seriesIndex - input.metrics.length;
      const event = input.events[eventIndex];
      if (!event) continue;
      lines.push(
        colorBullet(eventColor(event.type, input.isDark)) +
          escapeHtml(
            input.labels.events[event.type] + eventDetailSuffix(event),
          ),
      );
    }
  }

  return lines.join('<br/>');
}

function chartPair(value: unknown): [number, number] | undefined {
  if (
    !Array.isArray(value) ||
    value.length < 2 ||
    typeof value[0] !== 'number' ||
    typeof value[1] !== 'number'
  ) {
    return undefined;
  }
  return [value[0], value[1]];
}

function eventDetailSuffix(event: FlightChartEvent): string {
  if (event.detail) return ': ' + event.detail;
  if (event.type !== 'touchdown' && event.type !== 'finalTouchdown') {
    return '';
  }

  const gForce =
    event.gForce === undefined ? '' : ' (' + event.gForce.toFixed(2) + 'G)';
  if (event.type === 'touchdown') {
    return ': ' + String(event.sequence ?? '') + gForce;
  }
  if ((event.sequence ?? 1) > 1) {
    return ': ' + String(event.sequence) + gForce;
  }
  return gForce;
}

function colorBullet(color: string): string {
  return (
    '<span style="display:inline-block;margin-right:6px;border-radius:50%;' +
    'width:8px;height:8px;background:' +
    color +
    '"></span>'
  );
}

function escapeHtml(value: string): string {
  return value.replace(/[&<>"']/g, (character) => {
    const replacements: Record<string, string> = {
      '&': '&amp;',
      '<': '&lt;',
      '>': '&gt;',
      '"': '&quot;',
      "'": '&#39;',
    };
    return replacements[character];
  });
}
