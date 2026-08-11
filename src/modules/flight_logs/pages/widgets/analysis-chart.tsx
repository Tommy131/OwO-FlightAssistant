import { useMemo, useState } from 'react';
import { useTranslate } from '../../../../core/localization/use-translate';
import { useIsDarkMode } from '../../../../core/theme/theme-store';
import { baseChartOption, EChart, lineSeries } from '../../../../core/widgets/common/echart';
import { EmptyState, InfoChip } from '../../../../core/widgets/common/surfaces';
import { FlightLogsLocalizationKeys as K } from '../../localization/flight-logs-localization';
import type { FlightLog } from '../../models/flight-log-models';
import { AnalysisSection } from './analysis-widgets';
import {
  CHART_METRICS,
  DEFAULT_METRIC_IDS,
  buildMetricSeries,
  metricColor,
  type ChartMetricId,
} from './flight-chart-metrics';
import styles from './flight-logs-widgets.module.css';

export function AnalysisChart({ log }: { log: FlightLog }) {
  const t = useTranslate();
  const isDark = useIsDarkMode();
  const [selectedIds, setSelectedIds] = useState<ChartMetricId[]>([
    ...DEFAULT_METRIC_IDS,
  ]);

  const seriesByMetric = useMemo(() => buildMetricSeries(log), [log]);

  const toggleMetric = (id: ChartMetricId) => {
    setSelectedIds((previous) =>
      previous.includes(id)
        ? previous.filter((item) => item !== id)
        : [...previous, id],
    );
  };

  const activeMetrics = CHART_METRICS.filter((metric) =>
    selectedIds.includes(metric.id),
  );

  return (
    <AnalysisSection title={t(K.chartAltitude)} icon="show_chart">
      <div className={styles.metricPicker}>
        {CHART_METRICS.map((metric) => {
          const hasData = (seriesByMetric.get(metric.id)?.length ?? 0) > 0;
          return (
            <InfoChip
              key={metric.id}
              label={t(metric.labelKey)}
              solid={selectedIds.includes(metric.id)}
              color={
                hasData
                  ? metricColor(metric, isDark)
                  : 'var(--color-text-secondary)'
              }
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
              color={metricColor(metric, isDark)}
              isDark={isDark}
            />
          ))}
        </div>
      )}
    </AnalysisSection>
  );
}

function MetricRow({
  label,
  unit,
  minuteUnit,
  data,
  color,
  isDark,
}: {
  label: string;
  unit: string;
  minuteUnit: string;
  data: [number, number][];
  color: string;
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
          formatter: (value: number) => value.toFixed(0) + minuteUnit,
        },
      },
      tooltip: {
        ...(base.tooltip as object),
        valueFormatter: (value: unknown) =>
          typeof value === 'number'
            ? value.toFixed(2) + (unit ? ' ' + unit : '')
            : '--',
      },
      series: lineSeries({
        name: label,
        data,
        color,
      }),
    };
  }, [color, data, isDark, label, minuteUnit, unit]);

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