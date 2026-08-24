import { useTranslate } from '../../../../core/localization/use-translate';
import { DataCard } from '../../../../core/widgets/common/surfaces';
import { FlightLogsLocalizationKeys as K } from '../../localization/flight-logs-localization';

const METRIC_REASON_KEY: Record<string, string> = {
  no_takeoff: K.metricUnavailableNoTakeoff,
  no_landing: K.metricUnavailableNoLanding,
  no_rotation: K.metricUnavailableNoRotation,
  no_agl: K.metricUnavailableNoAgl,
  insufficient_samples: K.metricUnavailableFewSamples,
  no_runway_geometry: K.metricUnavailableNoRunway,
};

/**
 * Shared derived-metric card. When a metric cannot be computed, it preserves
 * the recorded reason instead of collapsing every data-quality case into `--`.
 */
export function MetricCard({
  label,
  value,
  digits,
  unit,
  notes,
  field,
  accentColor,
}: {
  label: string;
  value: number | undefined;
  digits: number;
  unit?: string;
  notes: Record<string, string> | undefined;
  field: string;
  accentColor?: string;
}) {
  const t = useTranslate();
  if (value !== undefined && Number.isFinite(value)) {
    return (
      <DataCard
        label={label}
        value={value.toFixed(digits)}
        unit={unit}
        accentColor={accentColor}
      />
    );
  }
  const reason = notes?.[field];
  const reasonKey = reason ? METRIC_REASON_KEY[reason] : undefined;
  return <DataCard label={label} value="--" hint={reasonKey ? t(reasonKey) : undefined} />;
}
