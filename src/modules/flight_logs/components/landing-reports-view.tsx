import { useEffect, useRef, useState, type RefObject } from 'react';

import { useTranslate } from '../../../core/localization/use-translate';
import { LocalizationKeys as CoreK } from '../../../core/localization/localization-keys';
import { Button, IconButton } from '../../../core/widgets/common/controls';
import { showAdvancedConfirmDialog } from '../../../core/widgets/common/dialog';
import { MaterialIcon } from '../../../core/widgets/common/icon';
import { SnackBarHelper } from '../../../core/widgets/common/snack-bar';
import {
  DataCard,
  EmptyState,
  InfoChip,
  SectionCard,
  StatusBadge,
} from '../../../core/widgets/common/surfaces';
import { FlightLogsLocalizationKeys as K } from '../localization/flight-logs-localization';
import type { FlightLog, FlightLogPoint, LandingData } from '../models/flight-log-models';
import {
  serializeLandingReport,
  type StoredLandingReport,
} from '../models/landing-report-models';
import type { RecordingEndReason, RecordingStatus } from '../models/recording-status';
import styles from '../pages/flight-logs-page.module.css';
import { AnalysisChart } from '../pages/widgets/analysis-chart';
import { AnalysisBlackBox, LANDING_RATING_COLOR } from '../pages/widgets/analysis-widgets';
import { LandingFlareAnalysis } from '../pages/widgets/landing-flare-analysis';
import { MetricCard } from '../pages/widgets/metric-card';

export interface LandingReportsViewProps {
  reports: StoredLandingReport[];
  selectedReport: StoredLandingReport | undefined;
  selectReport: (id: string | undefined) => void;
  deleteReport: (id: string) => Promise<void>;
  isLoading?: boolean;
  loadError?: string;
  retryLoad?: () => void;
}

const REASON_KEYS: Record<RecordingEndReason, string> = {
  stable_landing: K.landingReasonStableLanding,
  touch_and_go: K.landingReasonTouchAndGo,
  user_stopped: K.landingReasonUserStopped,
  simulator_disconnected: K.landingReasonSimulatorDisconnected,
  page_closed: K.landingReasonPageClosed,
  interrupted: K.landingReasonInterrupted,
};

function reasonKey(reason: RecordingEndReason | undefined): string {
  return reason === undefined ? K.landingReasonUnavailable : REASON_KEYS[reason];
}

const STATUS_KEYS: Record<RecordingStatus, string> = {
  completed: K.landingStatusCompleted,
  incomplete: K.landingStatusIncomplete,
};

export function LandingReportsView({
  reports,
  selectedReport,
  selectReport,
  deleteReport,
  isLoading = false,
  loadError,
  retryLoad,
}: LandingReportsViewProps) {
  const t = useTranslate();
  const [deletingIds, setDeletingIds] = useState<ReadonlySet<string>>(() => new Set());
  const pendingDeleteIds = useRef(new Set<string>());
  const [deleteError, setDeleteError] = useState<string>();
  const detailHeadingRef = useRef<HTMLHeadingElement>(null);
  const emptyStateRef = useRef<HTMLDivElement>(null);
  const reportButtonRefs = useRef(new Map<string, HTMLButtonElement>());
  const restoreFocusId = useRef<string | undefined>(undefined);
  const deletionFocusTarget = useRef<string | undefined>(undefined);
  const focusEmptyAfterDeletion = useRef(false);

  useEffect(() => {
    if (selectedReport) {
      detailHeadingRef.current?.focus();
      return;
    }

    const reportId = restoreFocusId.current;
    if (reportId) {
      reportButtonRefs.current.get(reportId)?.focus();
      restoreFocusId.current = undefined;
    }

    const target = deletionFocusTarget.current;
    if (focusEmptyAfterDeletion.current && reports.length === 0) {
      emptyStateRef.current?.focus();
      deletionFocusTarget.current = undefined;
      focusEmptyAfterDeletion.current = false;
    } else if (target && reports.some((report) => report.id === target)) {
      reportButtonRefs.current.get(target)?.focus();
      deletionFocusTarget.current = undefined;
    }
  }, [reports, selectedReport]);

  const handleDelete = async (report: StoredLandingReport) => {
    if (pendingDeleteIds.current.has(report.id)) return;
    pendingDeleteIds.current.add(report.id);
    setDeletingIds(new Set(pendingDeleteIds.current));

    try {
      const confirmed = await showAdvancedConfirmDialog({
        title: t(K.landingDeleteConfirmTitle),
        content: t(K.landingDeleteConfirmContent),
        icon: 'delete',
        confirmColor: 'var(--color-danger)',
        confirmText: t(K.landingDeleteConfirm),
        cancelText: t(K.cancel),
      });
      if (confirmed !== true) return;

      setDeleteError(undefined);
      const index = reports.findIndex((candidate) => candidate.id === report.id);
      deletionFocusTarget.current = reports[index + 1]?.id ?? reports[index - 1]?.id;
      focusEmptyAfterDeletion.current = deletionFocusTarget.current === undefined;
      await deleteReport(report.id);
      SnackBarHelper.showSuccess(t(K.landingDeleteSuccess));
    } catch {
      deletionFocusTarget.current = undefined;
      focusEmptyAfterDeletion.current = false;
      const message = t(K.landingDeleteError);
      setDeleteError(message);
      SnackBarHelper.showError(message);
    } finally {
      pendingDeleteIds.current.delete(report.id);
      setDeletingIds(new Set(pendingDeleteIds.current));
    }
  };

  if (isLoading) {
    return (
      <div
        className={styles.centered}
        role="status"
        aria-label={t(K.landingReportsLoading)}
      >
        <div className={`${styles.spinner} motion-essential`} aria-hidden="true" />
      </div>
    );
  }

  if (loadError) {
    return (
      <div className={styles.landingState} role="alert">
        <EmptyState
          icon="cloud_off"
          title={loadError}
          description={t(K.landingReportsLoadErrorHint)}
          action={
            retryLoad ? (
              <Button variant="outlined" icon="refresh" onClick={retryLoad}>
                {t(K.landingReportsRetry)}
              </Button>
            ) : undefined
          }
        />
      </div>
    );
  }

  if (selectedReport) {
    return (
      <LandingReportDetail
        report={selectedReport}
        headingRef={detailHeadingRef}
        onBack={() => {
          restoreFocusId.current = selectedReport.id;
          selectReport(undefined);
        }}
      />
    );
  }

  if (reports.length === 0) {
    return (
      <div ref={emptyStateRef} className={styles.landingState} tabIndex={-1}>
        <EmptyState
          icon="flight_land"
          title={t(K.landingReportsEmptyTitle)}
          description={t(K.landingReportsEmptySubtitle)}
        />
      </div>
    );
  }

  return (
    <div className={styles.landingReportsView}>
      {deleteError && (
        <div className={styles.landingErrorBanner} role="alert">
          <MaterialIcon name="error" size={17} />
          <span>{deleteError}</span>
          <IconButton
            icon="close"
            label={t(K.landingDismissError)}
            onClick={() => setDeleteError(undefined)}
          />
        </div>
      )}

      <ul className={styles.landingList} aria-label={t(K.logsLandingReportsTab)}>
        {reports.map((report) => (
          <LandingReportListItem
            key={report.id}
            report={report}
            deleting={deletingIds.has(report.id)}
            onOpen={() => selectReport(report.id)}
            onDelete={() => void handleDelete(report)}
            openButtonRef={(element) => {
              if (element) reportButtonRefs.current.set(report.id, element);
              else reportButtonRefs.current.delete(report.id);
            }}
          />
        ))}
      </ul>
    </div>
  );
}

function LandingReportListItem({
  report,
  deleting,
  onOpen,
  onDelete,
  openButtonRef,
}: {
  report: StoredLandingReport;
  deleting: boolean;
  onOpen: () => void;
  onDelete: () => void;
  openButtonRef: (element: HTMLButtonElement | null) => void;
}) {
  const t = useTranslate();
  const landing = report.landing;
  const touchdownAt = touchdownTimestamp(report);

  return (
    <li className={styles.landingListItem}>
      <div className={styles.touchdownRail} aria-hidden="true">
        <span>TD</span>
        <i />
      </div>

      <button
        ref={openButtonRef}
        type="button"
        className={styles.landingListMain}
        aria-label={t(K.landingReportOpen, { id: report.id })}
        onClick={onOpen}
      >
        <div className={styles.landingListHeadline}>
          {touchdownAt === undefined ? (
            <span className="text-mono">{t(K.landingReportTouchdownUnavailable)}</span>
          ) : (
            <time className="text-mono" dateTime={new Date(touchdownAt).toISOString()}>
              {formatTime(touchdownAt)}
            </time>
          )}
          <InfoChip label={simulatorLabel(report.simulator, t)} />
          <StatusBadge
            label={t(STATUS_KEYS[report.status])}
            tone={report.status === 'completed' ? 'success' : 'warning'}
          />
        </div>
        <span className={styles.landingReason}>{t(reasonKey(report.endReason))}</span>
        <span className={styles.landingListIdentity}>
          <span>{aircraftLabel(report)}</span>
          <span>{report.airport ?? '--'}</span>
        </span>
        <span className={styles.landingListMetrics}>
          <span>{landing ? `${landing.verticalSpeed.toFixed(0)} fpm` : '-- fpm'}</span>
          <span>{landing ? `${landing.gForce.toFixed(2)} G` : '-- G'}</span>
          <span>{landing ? `${landing.airspeed.toFixed(0)} kt` : '-- kt'}</span>
          <span>{landing ? t(landingRatingKey(landing.rating)) : '--'}</span>
          <span>
            {landing ? t(K.landingReportBounces, { count: landing.bounceCount ?? 0 }) : '--'}
          </span>
        </span>
      </button>

      <IconButton
        icon="delete"
        label={t(K.landingReportDelete, { id: report.id })}
        disabled={deleting}
        onClick={onDelete}
      />
    </li>
  );
}

function LandingReportDetail({
  report,
  headingRef,
  onBack,
}: {
  report: StoredLandingReport;
  headingRef: RefObject<HTMLHeadingElement | null>;
  onBack: () => void;
}) {
  const t = useTranslate();
  const log = landingReportAsFlightLog(report);
  const touchdownAt = touchdownTimestamp(report);
  const touchdownLabel =
    touchdownAt === undefined
      ? t(K.landingReportTouchdownUnavailable)
      : formatDateTime(touchdownAt);
  const landing = report.landing;
  const touchdownPoint = landing?.touchdownSequence[0] ?? report.points.at(-1);

  return (
    <article className={styles.landingDetail}>
      <header className={styles.landingDetailHeader}>
        <Button variant="text" size="sm" icon="arrow_back" onClick={onBack}>
          {t(K.landingReportBack)}
        </Button>
        <div className={styles.landingDetailTitle}>
          <span className={styles.landingDetailEyebrow}>TD / {report.id}</span>
          <h2 ref={headingRef} tabIndex={-1}>
            {touchdownLabel}
          </h2>
        </div>
        <StatusBadge
          label={t(STATUS_KEYS[report.status])}
          tone={report.status === 'completed' ? 'success' : 'warning'}
        />
        <Button variant="tonal" size="sm" icon="download" onClick={() => exportLandingReport(report)}>
          {t(K.landingReportExportJson)}
        </Button>
      </header>

      <div className={styles.landingDetailBody}>
        <section className={styles.landingFacts} aria-label={t(K.landingReportOverview)}>
          <DataCard
            label={t(K.landingReportTouchdownTime)}
            value={touchdownLabel}
            icon="schedule"
          />
          <DataCard
            label={t(K.landingReportSimulator)}
            value={simulatorLabel(report.simulator, t)}
            icon="flight"
          />
          <DataCard label={t(K.landingReportAircraft)} value={aircraftLabel(report)} icon="flight" />
          <DataCard label={t(K.landingReportAirport)} value={report.airport ?? '--'} icon="location_on" />
          <DataCard
            label={t(K.landingReportStatus)}
            value={t(STATUS_KEYS[report.status])}
            icon="task_alt"
          />
          <DataCard
            label={t(K.landingReportEndReason)}
            value={t(reasonKey(report.endReason))}
            icon="flag"
          />
          <DataCard
            label={t(K.landingReportHeightSource)}
            value={t(heightSourceKey(report.points))}
            icon="height"
          />
        </section>

        <LandingMetrics landing={landing} />
        <LandingConfiguration point={touchdownPoint} />
        <LandingWeather point={touchdownPoint} />
        <TouchdownSequence points={landing?.touchdownSequence ?? []} />
        <LandingFlareAnalysis log={log} />
        <AnalysisChart log={log} />
        <AnalysisBlackBox log={log} />
      </div>
    </article>
  );
}

function LandingConfiguration({ point }: { point: FlightLogPoint | undefined }) {
  const t = useTranslate();
  return (
    <SectionCard title={t(K.landingReportConfiguration)} icon="tune">
      <div className={styles.reportMetrics}>
        <DataCard label={t(K.landingReportFlaps)} value={point?.flapsLabel ?? formatMetric(point?.flapsPosition, 0)} />
        <DataCard label={t(K.landingReportGear)} value={onOff(point?.gearDown, t)} />
        <DataCard
          label={t(K.landingReportAutobrake)}
          value={point?.autoBrakeLabel ?? formatMetric(point?.autoBrakeLevel, 0)}
        />
        <DataCard label={t(K.landingReportSpoilers)} value={formatMetric(point?.speedBrakePosition, 0)} />
        <DataCard label={t(K.landingReportAutopilot)} value={onOff(point?.autopilotEngaged, t)} />
        <DataCard label={t(K.landingReportAutothrottle)} value={onOff(point?.autothrottleEngaged, t)} />
        <DataCard label={t(K.landingReportLandingLights)} value={onOff(point?.landingLights, t)} />
      </div>
    </SectionCard>
  );
}

function LandingWeather({ point }: { point: FlightLogPoint | undefined }) {
  const t = useTranslate();
  return (
    <SectionCard title={t(K.landingReportWeather)} icon="air">
      <div className={styles.reportMetrics}>
        <DataCard label={t(K.landingReportWind)} value={windLabel(point, t)} />
        <DataCard label={t(K.landingReportTemperature)} value={formatMetric(point?.outsideAirTemperature, 0)} unit="°C" />
        <DataCard label={t(K.landingReportPressure)} value={formatMetric(point?.baroPressure, 2)} unit="inHg" />
        <DataCard label={t(K.landingReportCrosswind)} value={formatMetric(point?.crosswindComponent, 0)} unit="kt" />
      </div>
    </SectionCard>
  );
}

function TouchdownSequence({ points }: { points: FlightLogPoint[] }) {
  const t = useTranslate();
  return (
    <SectionCard title={t(K.landingTouchdownSequence)} icon="format_list_numbered">
      {points.length === 0 ? (
        <span className={styles.landingSequenceEmpty}>--</span>
      ) : (
        <div className={styles.landingSequenceWrap}>
          <table className={styles.landingSequenceTable}>
            <thead><tr>
              <th>{t(K.landingReportTouchdownSequenceTime)}</th>
              <th>{t(K.landingReportTouchdownSequenceG)}</th>
              <th>{t(K.landingReportTouchdownSequenceSink)}</th>
              <th>{t(K.landingReportTouchdownSequenceHeight)}</th>
              <th>{t(K.landingReportHeightSource)}</th>
            </tr></thead>
            <tbody>{points.map((point, index) => (
              <tr key={`${point.timestamp.getTime()}-${index}`}>
                <td>{formatTime(point.timestamp.getTime())}</td>
                <td>{point.gForce.toFixed(2)} G</td>
                <td>{point.verticalSpeed.toFixed(0)} fpm</td>
                <td>{formatMetric(point.radioAltitude, 0)} ft</td>
                <td>{t(singleHeightSourceKey(point.radioAltitudeSource))}</td>
              </tr>
            ))}</tbody>
          </table>
        </div>
      )}
    </SectionCard>
  );
}

function LandingMetrics({ landing }: { landing: LandingData | undefined }) {
  const t = useTranslate();
  return (
    <SectionCard
      title={t(K.landingReportMetrics)}
      icon="flight_land"
      trailing={
        landing ? (
          <InfoChip
            label={t(landingRatingKey(landing.rating))}
            color={LANDING_RATING_COLOR[landing.rating]}
            solid
          />
        ) : undefined
      }
    >
      <div className={styles.reportMetrics}>
        <DataCard label={t(K.runway)} value={landing?.runway ?? '--'} />
        <DataCard label={t(K.gForce)} value={formatMetric(landing?.gForce, 2)} unit="G" />
        <DataCard
          label={t(K.verticalSpeed)}
          value={formatMetric(landing?.verticalSpeed, 0)}
          unit="fpm"
        />
        <DataCard label={t(K.airspeed)} value={formatMetric(landing?.airspeed, 0)} unit="kt" />
        <DataCard
          label={t(K.landingGroundSpeed)}
          value={formatMetric(landing?.groundSpeed, 0)}
          unit="kt"
        />
        <DataCard label={t(K.pitch)} value={formatMetric(landing?.pitch, 1)} unit="°" />
        <DataCard label={t(K.landingRoll)} value={formatMetric(landing?.roll, 1)} unit="°" />
        <MetricCard
          label={t(K.approachStability)}
          value={landing?.approachStabilityScore}
          digits={0}
          notes={landing?.metricNotes}
          field="approachStabilityScore"
        />
        <DataCard
          label={t(K.flareHeight)}
          value={formatMetric(landing?.flareHeightFt, 0)}
          unit="ft"
        />
        <DataCard
          label={t(K.sinkRateAt50)}
          value={formatMetric(landing?.sinkRateAt50FtFpm, 0)}
          unit="fpm"
        />
        <DataCard
          label={t(K.crosswindTouchdown)}
          value={formatMetric(landing?.crosswindAtTouchdownKt, 0)}
          unit="kt"
        />
        <DataCard
          label={t(K.bounceCount)}
          value={formatMetric(landing ? (landing.bounceCount ?? 0) : undefined, 0)}
        />
        <MetricCard
          label={t(K.remainingRunway)}
          value={landing?.remainingRunwayFt}
          digits={0}
          unit="ft"
          notes={landing?.metricNotes}
          field="remainingRunwayFt"
          accentColor={
            landing?.remainingRunwayFt !== undefined && landing.remainingRunwayFt < 1500
              ? 'var(--color-warning)'
              : undefined
          }
        />
        <DataCard
          label={t(K.landingTouchdownSequence)}
          value={
            landing && landing.touchdownGForces.length > 0
              ? landing.touchdownGForces.map((value) => value.toFixed(2)).join(' / ')
              : '--'
          }
        />
      </div>
    </SectionCard>
  );
}

function landingReportAsFlightLog(report: StoredLandingReport): FlightLog {
  const gValues = report.points.map((point) => point.gForce).filter(Number.isFinite);
  const altitudeValues = report.points.map((point) => point.altitude).filter(Number.isFinite);
  const airspeedValues = report.points.map((point) => point.airspeed).filter(Number.isFinite);
  const groundSpeedValues = report.points.map((point) => point.groundSpeed).filter(Number.isFinite);

  return {
    id: report.id,
    aircraftTitle: report.simulator,
    simulatorLabel: report.simulator,
    departureAirport: '',
    startTime: new Date(report.startedAt),
    endTime: new Date(report.endedAt),
    points: report.points,
    maxG: maximum(gValues, 1),
    minG: minimum(gValues, 1),
    maxAltitude: maximum(altitudeValues, 0),
    maxAirspeed: maximum(airspeedValues, 0),
    maxGroundSpeed: maximum(groundSpeedValues, 0),
    wasOnGroundAtStart: report.points[0]?.onGround ?? false,
    wasOnGroundAtEnd: report.points[report.points.length - 1]?.onGround ?? true,
    landingData: report.landing,
    status: report.status,
    endReason: report.endReason,
  };
}

function touchdownTimestamp(report: StoredLandingReport): number | undefined {
  const explicit = report.touchdownAt;
  if (explicit !== undefined && Number.isFinite(explicit)) return explicit;
  const derived = report.landing?.timestamp.getTime();
  return derived !== undefined && Number.isFinite(derived) ? derived : undefined;
}

function heightSourceKey(points: FlightLogPoint[]): string {
  const sources = new Set(
    points
      .filter((point) => point.radioAltitude !== undefined)
      .map((point) => point.radioAltitudeSource)
      .filter((source): source is NonNullable<FlightLogPoint['radioAltitudeSource']> => source !== undefined),
  );
  if (sources.size > 1) return K.landingReportMixedSources;
  return singleHeightSourceKey(sources.values().next().value);
}

function singleHeightSourceKey(source: FlightLogPoint['radioAltitudeSource']): string {
  if (source === 'radio') return K.landingHeightSourceRadio;
  if (source === 'agl_fallback') return K.landingHeightSourceAglFallback;
  return K.landingHeightSourceUnavailable;
}

function aircraftLabel(report: StoredLandingReport): string {
  const title = report.aircraftTitle?.trim();
  const type = report.aircraftType?.trim();
  if (title && type) return `${title} · ${type}`;
  return title ?? type ?? '--';
}

function onOff(value: boolean | undefined, t: (key: string) => string): string {
  if (value === undefined) return '--';
  return value ? t(CoreK.enabled) : t(CoreK.disabled);
}

function windLabel(
  point: FlightLogPoint | undefined,
  t: ReturnType<typeof useTranslate>,
): string {
  if (point?.windDirection === undefined || point.windSpeed === undefined) return '--';
  const gust = point.windGust === undefined
    ? ''
    : `, ${t(K.landingReportGust, { value: point.windGust.toFixed(0) })}`;
  return `${point.windDirection.toFixed(0)}° / ${point.windSpeed.toFixed(0)} kt${gust}`;
}

function exportLandingReport(report: StoredLandingReport): void {
  const blob = new Blob([JSON.stringify(serializeLandingReport(report), null, 2)], {
    type: 'application/json',
  });
  const url = URL.createObjectURL(blob);
  const anchor = document.createElement('a');
  anchor.href = url;
  anchor.download = `landing-report-${report.id}.json`;
  document.body.appendChild(anchor);
  anchor.click();
  anchor.remove();
  URL.revokeObjectURL(url);
}

function simulatorLabel(simulator: string, t: (key: string) => string): string {
  const normalized = simulator.trim().toLowerCase();
  if (normalized === 'msfs') return t(K.simulatorMsfs);
  if (normalized === 'x-plane' || normalized === 'xplane') return t(K.simulatorXplane);
  return simulator || t(K.simulatorUnknown);
}

function landingRatingKey(rating: LandingData['rating']): string {
  if (rating === 'butter') return K.ratingPerfect;
  if (rating === 'good') return K.ratingSoft;
  if (rating === 'firm') return K.ratingAcceptable;
  if (rating === 'hard') return K.ratingHard;
  return K.ratingRip;
}

function formatMetric(value: number | undefined, digits: number): string {
  return value !== undefined && Number.isFinite(value) ? value.toFixed(digits) : '--';
}

function formatTime(timestamp: number): string {
  const date = new Date(timestamp);
  return `${pad(date.getHours())}:${pad(date.getMinutes())}:${pad(date.getSeconds())}`;
}

function formatDateTime(timestamp: number): string {
  const date = new Date(timestamp);
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())} ${formatTime(timestamp)}`;
}

function pad(value: number): string {
  return String(value).padStart(2, '0');
}

function maximum(values: number[], fallback: number): number {
  return values.length > 0 ? Math.max(...values) : fallback;
}

function minimum(values: number[], fallback: number): number {
  return values.length > 0 ? Math.min(...values) : fallback;
}
