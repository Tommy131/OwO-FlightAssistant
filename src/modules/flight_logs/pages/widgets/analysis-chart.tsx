import {
  useMemo,
  useState,
  type CSSProperties,
} from 'react';
import { useTranslate } from '../../../../core/localization/use-translate';
import { useIsDarkMode } from '../../../../core/theme/theme-store';
import { baseChartOption, EChart, lineSeries } from '../../../../core/widgets/common/echart';
import { MaterialIcon } from '../../../../core/widgets/common/icon';
import { EmptyState } from '../../../../core/widgets/common/surfaces';
import { FlightLogsLocalizationKeys as K } from '../../localization/flight-logs-localization';
import type { FlightLog } from '../../models/flight-log-models';
import {
  detectFlightChartEvents,
  FLIGHT_CHART_EVENT_TYPES,
  type FlightChartEventType,
} from '../../services/flight-chart-events';
import { AnalysisSection } from './analysis-widgets';
import {
  CombinedFlightChart,
  eventColor,
  type CombinedFlightChartLabels,
} from './combined-flight-chart';
import {
  CHART_METRICS,
  DEFAULT_METRIC_IDS,
  buildMetricSeries,
  metricColor,
  type ChartMetricId,
} from './flight-chart-metrics';
import styles from './flight-logs-widgets.module.css';

const EVENT_LABEL_KEYS: Record<FlightChartEventType, string> = {
  takeoff: K.chartEventTakeoff,
  flapsDeploy: K.chartEventFlapsDeploy,
  flapsRetract: K.chartEventFlapsRetract,
  autopilotLateral: K.chartEventAutopilotLateral,
  autopilotVertical: K.chartEventAutopilotVertical,
  gearDown: K.chartEventGearDown,
  gearUp: K.chartEventGearUp,
  touchdown: K.chartEventTouchdown,
  finalTouchdown: K.chartEventFinalTouchdown,
};

export function AnalysisChart({ log }: { log: FlightLog }) {
  const t = useTranslate();
  const isDark = useIsDarkMode();
  const [selectedIds, setSelectedIds] = useState<ChartMetricId[]>([
    ...DEFAULT_METRIC_IDS,
  ]);
  const [showCombined, setShowCombined] = useState(true);
  const [selectedEvents, setSelectedEvents] = useState<
    FlightChartEventType[]
  >([...FLIGHT_CHART_EVENT_TYPES]);

  const seriesByMetric = useMemo(() => buildMetricSeries(log), [log]);
  const detectedEvents = useMemo(
    () => detectFlightChartEvents(log),
    [log],
  );
  const availableEvents = useMemo(
    () => new Set(detectedEvents.map((event) => event.type)),
    [detectedEvents],
  );

  const activeMetrics = CHART_METRICS.filter((metric) =>
    selectedIds.includes(metric.id),
  );
  const visibleEvents = detectedEvents.filter((event) =>
    selectedEvents.includes(event.type),
  );
  const labels: CombinedFlightChartLabels = {
    metrics: Object.fromEntries(
      CHART_METRICS.map((metric) => [metric.id, t(metric.labelKey)]),
    ) as CombinedFlightChartLabels['metrics'],
    events: Object.fromEntries(
      FLIGHT_CHART_EVENT_TYPES.map((type) => [
        type,
        t(EVENT_LABEL_KEYS[type]),
      ]),
    ) as CombinedFlightChartLabels['events'],
  };

  const toggleMetric = (id: ChartMetricId) => {
    setSelectedIds((previous) =>
      previous.includes(id)
        ? previous.filter((item) => item !== id)
        : [...previous, id],
    );
  };

  const toggleEvent = (type: FlightChartEventType) => {
    setSelectedEvents((previous) =>
      previous.includes(type)
        ? previous.filter((item) => item !== type)
        : [...previous, type],
    );
  };

  return (
    <AnalysisSection title={t(K.chartAltitude)} icon="show_chart">
      <div className={styles.chartToolbar}>
        <div className={styles.filterGroup}>
          <div className={styles.metricPicker}>
            {CHART_METRICS.map((metric) => {
              const hasData =
                (seriesByMetric.get(metric.id)?.length ?? 0) > 0;
              return (
                <ChartFilterButton
                  key={metric.id}
                  label={t(metric.labelKey)}
                  color={metricColor(metric, isDark)}
                  selected={selectedIds.includes(metric.id)}
                  disabled={!hasData}
                  title={!hasData ? t(K.chartNoData) : undefined}
                  onClick={() => toggleMetric(metric.id)}
                />
              );
            })}
          </div>
        </div>

        <div className={styles.filterGroup}>
          <span className={styles.filterGroupLabel}>
            {t(K.chartEvents)}
          </span>
          <div className={styles.metricPicker}>
            {FLIGHT_CHART_EVENT_TYPES.map((type) => {
              const isAvailable = availableEvents.has(type);
              return (
                <ChartFilterButton
                  key={type}
                  label={t(EVENT_LABEL_KEYS[type])}
                  color={eventColor(type, isDark)}
                  selected={selectedEvents.includes(type)}
                  disabled={!isAvailable}
                  title={!isAvailable ? t(K.chartNoData) : undefined}
                  onClick={() => toggleEvent(type)}
                />
              );
            })}
          </div>
        </div>

        <button
          type="button"
          className={styles.combinedVisibility}
          onClick={() => setShowCombined((visible) => !visible)}
        >
          <MaterialIcon
            name={showCombined ? 'visibility_off' : 'visibility'}
            size={15}
          />
          {t(
            showCombined
              ? K.chartHideCombined
              : K.chartShowCombined,
          )}
        </button>
      </div>

      {activeMetrics.length === 0 ? (
        <EmptyState icon="show_chart" title={t(K.chartNoData)} />
      ) : (
        <>
          {showCombined && (
            <section
              className={styles.combinedChartPanel}
              role="region"
              aria-label={t(K.chartCombined)}
            >
              <div className={styles.combinedChartHeader}>
                <span>{t(K.chartCombined)}</span>
                <span>
                  {activeMetrics.length} / {CHART_METRICS.length}
                </span>
              </div>
              <div className={styles.combinedChartHost}>
                <CombinedFlightChart
                  metrics={activeMetrics}
                  seriesByMetric={seriesByMetric}
                  events={visibleEvents}
                  labels={labels}
                  isDark={isDark}
                  minuteUnit={t(K.chartMinuteUnit)}
                />
              </div>
            </section>
          )}

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
        </>
      )}
    </AnalysisSection>
  );
}

function ChartFilterButton({
  label,
  color,
  selected,
  disabled,
  title,
  onClick,
}: {
  label: string;
  color: string;
  selected: boolean;
  disabled: boolean;
  title?: string;
  onClick: () => void;
}) {
  const className = [
    styles.chartFilter,
    selected ? styles.chartFilterSelected : '',
    disabled ? styles.chartFilterDisabled : '',
  ]
    .filter(Boolean)
    .join(' ');

  return (
    <button
      type="button"
      className={className}
      style={{ '--chart-filter-color': color } as CSSProperties}
      aria-pressed={selected}
      disabled={disabled}
      title={title}
      onClick={onClick}
    >
      <MaterialIcon
        name={selected ? 'check' : 'add'}
        size={13}
      />
      <span>{label}</span>
    </button>
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