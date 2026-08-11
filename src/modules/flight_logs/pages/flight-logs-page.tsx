import { useEffect, useRef, useState } from 'react';
import { useTranslate } from '../../../core/localization/use-translate';
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
import { useFlightDataStore } from '../../common/providers/flight-data-store';
import { FlightLogsLocalizationKeys as K } from '../localization/flight-logs-localization';
import {
  flightLogAirborneDurationMs,
  flightLogDurationMs,
  flightLogIsCompleted,
  type FlightLog,
  type LandingRating,
} from '../models/flight-log-models';
import { useFlightLogsStore } from '../providers/flight-logs-store';
import { AnalysisChart } from './widgets/analysis-chart';
import {
  AnalysisBlackBox,
  AnalysisSummaryCard,
  AnalysisTrackMap,
  formatDuration,
  LANDING_RATING_COLOR,
} from './widgets/analysis-widgets';
import styles from './flight-logs-page.module.css';

/**
 * 飞行日志页面
 *
 * 对应 Flutter 版 `modules/flight_logs/pages/{flight_logs_page,flight_log_detail_page}.dart`：
 * 列表视图 → 点击进入详情（概要 / 起降报告 / 分析图 / 航迹图 / 黑匣子）。
 */
export function FlightLogsPage() {
  const t = useTranslate();
  const logs = useFlightLogsStore((s) => s.logs);
  const isLoading = useFlightLogsStore((s) => s.isLoading);
  const selectedLog = useFlightLogsStore((s) => s.selectedLog);
  const selectLog = useFlightLogsStore((s) => s.selectLog);
  const refreshLogs = useFlightLogsStore((s) => s.refreshLogs);
  const initialized = useRef(false);

  useEffect(() => {
    if (initialized.current) return;
    initialized.current = true;
    void refreshLogs();
  }, [refreshLogs]);

  if (selectedLog) {
    return <FlightLogDetail log={selectedLog} onBack={() => selectLog(null)} />;
  }

  return (
    <div className={styles.page}>
      <FlightLogsToolbar />

      <div className={`${styles.scroll} scroll-area`}>
        {isLoading ? (
          <div className={styles.centered}>
            {/* motion-essential：加载转圈同理，见 global.css 的说明 */}
            <div className={`${styles.spinner} motion-essential`} />
          </div>
        ) : logs.length === 0 ? (
          <EmptyState
            icon="receipt_long"
            title={t(K.emptyTitle)}
            description={t(K.emptySubtitle)}
          />
        ) : (
          <div className={styles.list}>
            {logs.map((log) => (
              <FlightLogListItem key={log.id} log={log} onOpen={() => selectLog(log)} />
            ))}
          </div>
        )}
      </div>
    </div>
  );
}

// ──────────────────────────────────────────────────────────────────────────
// 工具栏：录制控制 + 导入
// ──────────────────────────────────────────────────────────────────────────

function FlightLogsToolbar() {
  const t = useTranslate();
  const isRecording = useFlightLogsStore((s) => s.isRecording);
  const isRecordingPaused = useFlightLogsStore((s) => s.isRecordingPaused);
  const startRecording = useFlightLogsStore((s) => s.startRecording);
  const stopRecording = useFlightLogsStore((s) => s.stopRecording);
  const importLogs = useFlightLogsStore((s) => s.importLogs);
  const snapshot = useFlightDataStore((s) => s.snapshot);
  const fileInputRef = useRef<HTMLInputElement>(null);

  const handleToggleRecording = async () => {
    if (isRecording) {
      const saved = await stopRecording(snapshot);
      // 不足 1 分钟的记录会被丢弃，这里如实告知
      SnackBarHelper.showInfo(saved ? t(K.stopRecordSaved) : t(K.stopRecordDiscarded));
      return;
    }
    if (!snapshot.isConnected) {
      SnackBarHelper.showWarning(t(K.notConnected));
      return;
    }
    startRecording(snapshot, snapshot.flightNumber);
    SnackBarHelper.showSuccess(t(K.startRecordStarted));
  };

  const handleImport = async (file: File) => {
    try {
      const count = await importLogs(file);
      if (count > 0) SnackBarHelper.showSuccess(t(K.importSuccess));
      else SnackBarHelper.showError(t(K.importSuccess));
    } catch {
      SnackBarHelper.showError(t(K.importSuccess));
    }
  };

  return (
    <div className={styles.toolbar}>
      <h2 className={styles.pageTitle}>{t(K.pageTitle)}</h2>

      {isRecording && (
        <StatusBadge
          label={isRecordingPaused ? t(K.startRecordStarted) : t(K.stopRecord)}
          tone={isRecordingPaused ? 'warning' : 'danger'}
          pulsing={!isRecordingPaused}
        />
      )}

      <div className={styles.toolbarSpacer} />

      <Button
        variant={isRecording ? 'danger' : 'elevated'}
        size="sm"
        icon={isRecording ? 'stop_circle' : 'fiber_manual_record'}
        onClick={() => void handleToggleRecording()}
      >
        {isRecording ? t(K.stopRecord) : t(K.startRecord)}
      </Button>

      <IconButton
        icon="upload_file"
        label={t(K.importLog)}
        onClick={() => fileInputRef.current?.click()}
      />

      <input
        ref={fileInputRef}
        type="file"
        accept=".json"
        className="sr-only"
        onChange={(event) => {
          const file = event.target.files?.[0];
          event.target.value = '';
          if (file) void handleImport(file);
        }}
      />
    </div>
  );
}

// ──────────────────────────────────────────────────────────────────────────
// 列表项
// ──────────────────────────────────────────────────────────────────────────

function FlightLogListItem({ log, onOpen }: { log: FlightLog; onOpen: () => void }) {
  const t = useTranslate();
  const deleteLog = useFlightLogsStore((s) => s.deleteLog);
  const exportLog = useFlightLogsStore((s) => s.exportLog);

  const completed = flightLogIsCompleted(log);
  const landing = log.landingData;

  const handleDelete = async () => {
    const confirmed = await showAdvancedConfirmDialog({
      title: t(K.deleteConfirmTitle),
      content: t(K.deleteConfirmContent),
      icon: 'delete',
      confirmColor: 'var(--color-danger)',
      confirmText: t(K.deleteConfirm),
      cancelText: t(K.cancel),
    });
    if (confirmed !== true) return;
    await deleteLog(log.id);
    SnackBarHelper.showSuccess(t(K.deleteSuccess));
  };

  return (
    <div className={styles.listItem}>
      <button type="button" className={styles.listMain} onClick={onOpen}>
        <div className={styles.listRoute}>
          <span className={`${styles.listIcao} text-mono`}>
            {log.departureAirport || t(K.listUnknownAirport)}
          </span>
          <MaterialIcon name="arrow_forward" size={15} color="var(--color-on-surface-a40)" />
          <span className={`${styles.listIcao} text-mono`}>
            {log.arrivalAirport || t(K.listUnknownAirport)}
          </span>
          {!completed && (
            <InfoChip
              icon="pending"
              label={t(K.listIncompleteFlight)}
              color="var(--color-warning)"
            />
          )}
        </div>

        <div className={styles.listMeta}>
          <span className={styles.listAircraft}>{log.aircraftTitle}</span>
          {log.flightNumber && <span className={styles.listFlightNo}>{log.flightNumber}</span>}
          {log.simulatorLabel && <span className={styles.listSim}>{log.simulatorLabel}</span>}
        </div>

        <div className={styles.listStats}>
          <span className={styles.listStat}>
            <MaterialIcon name="schedule" size={13} />
            {formatDuration(flightLogDurationMs(log))}
          </span>
          <span className={styles.listStat}>
            <MaterialIcon name="flight" size={13} />
            {formatDuration(flightLogAirborneDurationMs(log))}
          </span>
          <span className={styles.listStat}>
            <MaterialIcon name="height" size={13} />
            {log.maxAltitude.toFixed(0)} ft
          </span>
          {landing && (
            <span
              className={styles.listStat}
              style={{ color: LANDING_RATING_COLOR[landing.rating] }}
            >
              <MaterialIcon name="flight_land" size={13} filled />
              {landing.gForce.toFixed(2)}G · {t(LANDING_RATING_KEY[landing.rating])}
            </span>
          )}
        </div>

        <span className={styles.listTime}>{formatDateTime(log.startTime)}</span>
      </button>

      <div className={styles.listActions}>
        <IconButton icon="download" label={t(K.exportLog)} onClick={() => exportLog(log)} />
        <IconButton icon="delete" label={t(K.deleteLog)} onClick={() => void handleDelete()} />
      </div>
    </div>
  );
}

/** 落地评级 → 文案 key（与桌面版 rating 命名对应） */
const LANDING_RATING_KEY: Record<LandingRating, string> = {
  butter: K.ratingPerfect,
  good: K.ratingSoft,
  firm: K.ratingAcceptable,
  hard: K.ratingHard,
  crash: K.ratingRip,
};

// ──────────────────────────────────────────────────────────────────────────
// 详情页
// ──────────────────────────────────────────────────────────────────────────

type DetailTab = 'summary' | 'chart' | 'track' | 'blackBox';

function FlightLogDetail({ log, onBack }: { log: FlightLog; onBack: () => void }) {
  const t = useTranslate();
  const [tab, setTab] = useState<DetailTab>('summary');
  const exportLog = useFlightLogsStore((s) => s.exportLog);

  const tabs: { id: DetailTab; label: string; icon: string }[] = [
    { id: 'summary', label: t(K.summaryTitle), icon: 'summarize' },
    { id: 'chart', label: t(K.detailProfile), icon: 'show_chart' },
    { id: 'track', label: t(K.detailTrack), icon: 'route' },
    { id: 'blackBox', label: t(K.blackBoxTitle), icon: 'table_rows' },
  ];

  return (
    <div className={styles.page}>
      <div className={styles.toolbar}>
        <IconButton icon="arrow_back" label={t(K.detailTitle)} onClick={onBack} />
        <div className={styles.detailTitleWrap}>
          <span className={`${styles.detailRoute} text-mono`}>
            {log.departureAirport} → {log.arrivalAirport ?? '--'}
          </span>
          <span className={styles.detailSubtitle}>
            {log.aircraftTitle} · {formatDateTime(log.startTime)}
          </span>
        </div>
        <div className={styles.toolbarSpacer} />
        <IconButton icon="download" label={t(K.exportLog)} onClick={() => exportLog(log)} />
      </div>

      <div className={styles.detailTabs}>
        {tabs.map((item) => (
          <button
            key={item.id}
            type="button"
            role="tab"
            aria-selected={tab === item.id}
            className={`${styles.detailTab}${tab === item.id ? ` ${styles.detailTabActive}` : ''}`}
            onClick={() => setTab(item.id)}
          >
            <MaterialIcon name={item.icon} size={15} filled={tab === item.id} />
            {item.label}
          </button>
        ))}
      </div>

      <div className={`${styles.scroll} scroll-area`}>
        {/*
          概要页是一组并列卡片，保留常规内边距；
          其余三页各自只有一块内容，改用窄内边距铺满宽度 ——
          地图和黑匣子宽表格原先被父 padding + 卡片边框两头夹掉近 60px。
        */}
        <div
          className={
            tab === 'summary' ? styles.detailContent : styles.detailContentWide
          }
        >
          {tab === 'summary' && (
            <>
              <AnalysisSummaryCard log={log} />
              <TakeoffLandingReport log={log} />
            </>
          )}
          {tab === 'chart' && <AnalysisChart log={log} />}
          {tab === 'track' && <AnalysisTrackMap log={log} />}
          {tab === 'blackBox' && <AnalysisBlackBox log={log} />}
        </div>
      </div>
    </div>
  );
}

// ──────────────────────────────────────────────────────────────────────────
// 起降质量报告
// ──────────────────────────────────────────────────────────────────────────

function TakeoffLandingReport({ log }: { log: FlightLog }) {
  const t = useTranslate();
  const takeoff = log.takeoffData;
  const landing = log.landingData;

  if (!takeoff && !landing) return null;

  return (
    <div className={styles.reportGrid}>
      {takeoff && (
        <SectionCard title={t(K.eventTakeoff)} icon="flight_takeoff">
          <div className={styles.reportMetrics}>
            <DataCard label={t(K.runway)} value={takeoff.runway ?? '--'} />
            <DataCard label={t(K.airspeed)} value={takeoff.airspeed.toFixed(0)} unit="kt" />
            <DataCard
              label={t(K.verticalSpeed)}
              value={takeoff.verticalSpeed.toFixed(0)}
              unit="fpm"
            />
            <DataCard label={t(K.pitch)} value={takeoff.pitch.toFixed(1)} unit="°" />
            <DataCard label={t(K.heading)} value={takeoff.heading.toFixed(0)} unit="°" />
            <MetricCard
              label={t(K.rotationSpeed)}
              value={takeoff.rotationSpeedKt}
              digits={0}
              unit="kt"
              notes={takeoff.metricNotes}
              field="rotationSpeedKt"
            />
            <MetricCard
              label={t(K.rotationToLiftoff)}
              value={takeoff.rotationToLiftoffSec}
              digits={1}
              unit="s"
              notes={takeoff.metricNotes}
              field="rotationToLiftoffSec"
            />
            <DataCard
              label={t(K.crosswindLiftoff)}
              value={takeoff.crosswindAtLiftoffKt?.toFixed(0) ?? '--'}
              unit="kt"
            />
            <MetricCard
              label={t(K.pitchAt35Ft)}
              value={takeoff.pitchAt35FtDeg}
              digits={1}
              unit="°"
              notes={takeoff.metricNotes}
              field="pitchAt35FtDeg"
            />
            <MetricCard
              label={t(K.takeoffStability)}
              value={takeoff.takeoffStabilityScore}
              digits={0}
              notes={takeoff.metricNotes}
              field="takeoffStabilityScore"
            />
            <MetricCard
              label={t(K.remainingRunway)}
              value={takeoff.remainingRunwayFt}
              digits={0}
              unit="ft"
              notes={takeoff.metricNotes}
              field="remainingRunwayFt"
            />
          </div>
        </SectionCard>
      )}

      {landing && (
        <SectionCard
          title={t(K.eventLanding)}
          icon="flight_land"
          trailing={
            <InfoChip
              label={t(LANDING_RATING_KEY[landing.rating])}
              color={LANDING_RATING_COLOR[landing.rating]}
              solid
            />
          }
        >
          <div className={styles.reportMetrics}>
            <DataCard label={t(K.runway)} value={landing.runway ?? '--'} />
            <DataCard
              label={t(K.gForce)}
              value={landing.gForce.toFixed(2)}
              unit="G"
              accentColor={LANDING_RATING_COLOR[landing.rating]}
              // G 值来源：起落架传感器 vs 机身 G 回退，影响读数可信度
              hint={landing.gForceSource}
            />
            <DataCard
              label={t(K.verticalSpeed)}
              value={landing.verticalSpeed.toFixed(0)}
              unit="fpm"
            />
            <DataCard label={t(K.airspeed)} value={landing.airspeed.toFixed(0)} unit="kt" />
            <DataCard label={t(K.pitch)} value={landing.pitch.toFixed(1)} unit="°" />
            <DataCard
              label={t(K.sinkRateAt50)}
              value={landing.sinkRateAt50FtFpm?.toFixed(0) ?? '--'}
              unit="fpm"
            />
            <DataCard
              label={t(K.flareHeight)}
              value={landing.flareHeightFt?.toFixed(0) ?? '--'}
              unit="ft"
            />
            <DataCard
              label={t(K.crosswindTouchdown)}
              value={landing.crosswindAtTouchdownKt?.toFixed(0) ?? '--'}
              unit="kt"
            />
            <DataCard
              label={t(K.bounceCount)}
              value={landing.bounceCount?.toFixed(0) ?? '0'}
              accentColor={
                (landing.bounceCount ?? 0) > 0 ? 'var(--color-warning)' : undefined
              }
            />
            <MetricCard
              label={t(K.approachStability)}
              value={landing.approachStabilityScore}
              digits={0}
              notes={landing.metricNotes}
              field="approachStabilityScore"
            />
            <MetricCard
              label={t(K.remainingRunway)}
              value={landing.remainingRunwayFt}
              digits={0}
              unit="ft"
              notes={landing.metricNotes}
              field="remainingRunwayFt"
              accentColor={
                landing.remainingRunwayFt !== undefined && landing.remainingRunwayFt < 1500
                  ? 'var(--color-warning)'
                  : undefined
              }
            />
            <DataCard
              label={t(K.landingTouchdownSequence)}
              // 多次接地时把每次的 G 值都列出来，弹跳落地一眼可见
              value={
                landing.touchdownGForces.length > 0
                  ? landing.touchdownGForces.map((g) => g.toFixed(2)).join(' / ')
                  : '--'
              }
              hint={
                landing.touchdownSequence.length > 1
                  ? `${landing.touchdownSequence.length} ${t(K.blackBoxRows)}`
                  : undefined
              }
            />
          </div>
        </SectionCard>
      )}
    </div>
  );
}

function formatDateTime(date: Date): string {
  const pad = (n: number) => String(n).padStart(2, '0');
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())} ${pad(date.getHours())}:${pad(date.getMinutes())}`;
}


// ──────────────────────────────────────────────────────────────────────────
// 派生指标卡片
// ──────────────────────────────────────────────────────────────────────────

/** 原因码 → 文案 key */
const METRIC_REASON_KEY: Record<string, string> = {
  no_takeoff: K.metricUnavailableNoTakeoff,
  no_landing: K.metricUnavailableNoLanding,
  no_rotation: K.metricUnavailableNoRotation,
  no_agl: K.metricUnavailableNoAgl,
  insufficient_samples: K.metricUnavailableFewSamples,
  no_runway_geometry: K.metricUnavailableNoRunway,
};

/**
 * 派生指标卡片：取不到值时**说明原因**，而不是统一一个 `--`。
 *
 * 「这架飞机不提供离地高度」和「这次飞行压根没走完这个阶段」，
 * 对用户该做什么是完全不同的两件事 —— 都显示 `--` 等于什么都没说。
 */
function MetricCard({
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
