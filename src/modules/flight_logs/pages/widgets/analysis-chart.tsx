import { useMemo, useState } from 'react';
import { useTranslate } from '../../../../core/localization/use-translate';
import { useIsDarkMode } from '../../../../core/theme/theme-store';
import { baseChartOption, EChart, lineSeries } from '../../../../core/widgets/common/echart';
import { EmptyState, InfoChip, SectionCard } from '../../../../core/widgets/common/surfaces';
import { FlightLogsLocalizationKeys as K } from '../../localization/flight-logs-localization';
import type { FlightLog, FlightLogPoint } from '../../models/flight-log-models';
import styles from './flight-logs-widgets.module.css';

/**
 * 飞行数据分析图
 *
 * 对应 Flutter 版 `modules/flight_logs/pages/widgets/analysis_chart.dart`。
 * 22 个可选指标、共享时间轴。
 *
 * ⚠️ 与桌面版的一处差异：桌面版把所有选中指标叠在**同一个 Y 轴**上
 * （`_resolveMinY/_resolveMaxY` 取全体极值）。这样一来同时选高度（0–40000 ft）
 * 和 G 值（0–3）时，G 值会被压成贴底的直线，图等于白画。
 * 这里改成**小倍数**：每个指标一行、各自的 Y 轴，共享 X（时间）轴 ——
 * 多选能力一点没少，但混合量纲的组合终于可读了。
 */

/** 指标定义：取值函数 + 单位 + 文案 key */
interface ChartMetric {
  id: string;
  labelKey: string;
  unit: string;
  /** 从采样点取值；返回 undefined 表示该点无此数据 */
  select: (point: FlightLogPoint) => number | undefined;
}

const CHART_METRICS: ChartMetric[] = [
  { id: 'altitude', labelKey: K.chartAltitude, unit: 'ft', select: (p) => p.altitude },
  { id: 'speed', labelKey: K.chartSpeed, unit: 'kt', select: (p) => p.groundSpeed },
  { id: 'pitch', labelKey: K.chartPitch, unit: '°', select: (p) => p.pitch },
  {
    id: 'verticalSpeed',
    labelKey: K.chartVerticalSpeed,
    unit: 'fpm',
    select: (p) => p.verticalSpeed,
  },
  { id: 'gForce', labelKey: K.chartGForce, unit: 'G', select: (p) => p.gForce },
  { id: 'baro', labelKey: K.chartBaro, unit: 'inHg', select: (p) => p.baroPressure ?? 29.92 },
  { id: 'aoa', labelKey: K.chartAoa, unit: '°', select: (p) => p.angleOfAttack },
  { id: 'engine1N1', labelKey: K.chartEngine1N1, unit: '%', select: (p) => p.engine1N1 },
  { id: 'engine2N1', labelKey: K.chartEngine2N1, unit: '%', select: (p) => p.engine2N1 },
  { id: 'engine1N2', labelKey: K.chartEngine1N2, unit: '%', select: (p) => p.engine1N2 },
  { id: 'engine2N2', labelKey: K.chartEngine2N2, unit: '%', select: (p) => p.engine2N2 },
  { id: 'engine1Egt', labelKey: K.chartEngine1Egt, unit: '°C', select: (p) => p.engine1Egt },
  { id: 'engine2Egt', labelKey: K.chartEngine2Egt, unit: '°C', select: (p) => p.engine2Egt },
  { id: 'aileronInput', labelKey: K.chartAileronInput, unit: '', select: (p) => p.aileronInput },
  { id: 'elevatorInput', labelKey: K.chartElevatorInput, unit: '', select: (p) => p.elevatorInput },
  { id: 'rudderInput', labelKey: K.chartRudderInput, unit: '', select: (p) => p.rudderInput },
  { id: 'aileronTrim', labelKey: K.chartAileronTrim, unit: '', select: (p) => p.aileronTrim },
  { id: 'elevatorTrim', labelKey: K.chartElevatorTrim, unit: '', select: (p) => p.elevatorTrim },
  { id: 'rudderTrim', labelKey: K.chartRudderTrim, unit: '', select: (p) => p.rudderTrim },
  {
    id: 'crosswind',
    labelKey: K.chartCrosswind,
    unit: 'kt',
    select: (p) => p.crosswindComponent,
  },
  {
    id: 'radioAltitude',
    labelKey: K.chartRadioAltitude,
    unit: 'ft',
    select: (p) => p.radioAltitude,
  },
  { id: 'gustDelta', labelKey: K.chartGustDelta, unit: 'kt', select: (p) => p.gustDelta },
];

/** 默认选中的四项，与桌面版一致 */
const DEFAULT_METRIC_IDS = ['altitude', 'speed', 'verticalSpeed', 'gForce'];

export function AnalysisChart({ log }: { log: FlightLog }) {
  const t = useTranslate();
  const isDark = useIsDarkMode();
  const [selectedIds, setSelectedIds] = useState<string[]>(DEFAULT_METRIC_IDS);

  // 时间轴统一用「距起点的分钟数」
  const startMs = log.points[0]?.timestamp.getTime() ?? 0;

  const seriesByMetric = useMemo(() => {
    const result = new Map<string, [number, number][]>();
    for (const metric of CHART_METRICS) {
      const points: [number, number][] = [];
      for (const point of log.points) {
        const value = metric.select(point);
        if (value === undefined || !Number.isFinite(value)) continue;
        points.push([(point.timestamp.getTime() - startMs) / 60_000, value]);
      }
      result.set(metric.id, points);
    }
    return result;
  }, [log, startMs]);

  const toggleMetric = (id: string) => {
    setSelectedIds((prev) =>
      prev.includes(id) ? prev.filter((item) => item !== id) : [...prev, id],
    );
  };

  const activeMetrics = CHART_METRICS.filter((metric) => selectedIds.includes(metric.id));

  return (
    <SectionCard title={t(K.chartAltitude)} icon="show_chart">
      <div className={styles.metricPicker}>
        {CHART_METRICS.map((metric) => {
          const hasData = (seriesByMetric.get(metric.id)?.length ?? 0) > 0;
          return (
            <InfoChip
              key={metric.id}
              label={t(metric.labelKey)}
              solid={selectedIds.includes(metric.id)}
              color={hasData ? 'var(--color-primary)' : 'var(--color-text-secondary)'}
              onClick={hasData ? () => toggleMetric(metric.id) : undefined}
              title={hasData ? undefined : t(K.chartNoData)}
            />
          );
        })}
      </div>

      {activeMetrics.length === 0 ? (
        <EmptyState icon="show_chart" title={t(K.chartNoData)} />
      ) : (
        <div className={styles.smallMultiples}>
          {activeMetrics.map((metric) => (
            <MetricRow
              key={metric.id}
              label={t(metric.labelKey)}
              unit={metric.unit}
              minuteUnit={t(K.chartMinuteUnit)}
              data={seriesByMetric.get(metric.id) ?? []}
              isDark={isDark}
            />
          ))}
        </div>
      )}
    </SectionCard>
  );
}

/**
 * 单指标图
 * 每行一个独立 Y 轴 —— 这正是小倍数相对单轴叠加的关键
 */
function MetricRow({
  label,
  unit,
  minuteUnit,
  data,
  isDark,
}: {
  label: string;
  unit: string;
  minuteUnit: string;
  data: [number, number][];
  isDark: boolean;
}) {
  const option = useMemo(() => {
    const base = baseChartOption({
      isDark,
      showXAxisLabel: true,
      showYAxisLabel: true,
      grid: { left: 54, right: 12, top: 10, bottom: 22 },
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
          formatter: (value: number) => `${value.toFixed(0)}${minuteUnit}`,
        },
      },
      tooltip: {
        ...(base.tooltip as object),
        valueFormatter: (value: unknown) =>
          typeof value === 'number' ? `${value.toFixed(2)}${unit ? ` ${unit}` : ''}` : '--',
      },
      // 单系列不需要图例：行首标签已经指明身份
      series: lineSeries({
        name: label,
        data,
        color: isDark ? '#3987e5' : '#2a78d6',
      }),
    };
  }, [data, isDark, label, unit, minuteUnit]);

  return (
    <div className={styles.metricRow}>
      <div className={styles.metricRowHead}>
        <span className={styles.metricRowLabel}>{label}</span>
        {unit && <span className={styles.metricRowUnit}>{unit}</span>}
      </div>
      <EChart option={option} height={116} />
    </div>
  );
}
