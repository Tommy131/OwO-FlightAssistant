import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import L from 'leaflet';
import { useTranslate } from '../../../../core/localization/use-translate';
import { LeafletMap } from '../../../../core/widgets/common/leaflet-map';
import { Button, IconButton, TextField } from '../../../../core/widgets/common/controls';
import { MaterialIcon } from '../../../../core/widgets/common/icon';
import {
  DataCard,
  EmptyState,
  InfoChip,
  SectionCard,
} from '../../../../core/widgets/common/surfaces';
import { FlightLogsLocalizationKeys as K } from '../../localization/flight-logs-localization';
import {
  flightLogAirborneDurationMs,
  flightLogDurationMs,
  type FlightLog,
  type FlightLogAlertLevel,
  type LandingRating,
} from '../../models/flight-log-models';
import styles from './flight-logs-widgets.module.css';

/**
 * 飞行日志分析组件
 *
 * 对应 Flutter 版 `modules/flight_logs/pages/widgets/`：
 * analysis_summary_card / analysis_track_map / analysis_black_box
 */

// ──────────────────────────────────────────────────────────────────────────
// 概要卡片
// ──────────────────────────────────────────────────────────────────────────

export function AnalysisSummaryCard({ log }: { log: FlightLog }) {
  const t = useTranslate();

  const durationMs = flightLogDurationMs(log);
  const airborneMs = flightLogAirborneDurationMs(log);
  const landing = log.landingData;

  return (
    <SectionCard title={t(K.summaryTitle)} icon="summarize">
      <div className={styles.summaryGrid}>
        <DataCard label={t(K.summaryDuration)} value={formatDuration(durationMs)} icon="schedule" />
        <DataCard
          label={t(K.summaryAirborneDuration)}
          value={formatDuration(airborneMs)}
          icon="flight"
        />
        <DataCard
          label={t(K.summaryMaxAlt)}
          value={log.maxAltitude.toFixed(0)}
          unit="ft"
          icon="height"
        />
        <DataCard
          label={t(K.summaryMaxGs)}
          value={log.maxGroundSpeed.toFixed(0)}
          unit="kt"
          icon="speed"
        />
        <DataCard
          label={t(K.summaryFuel)}
          value={log.totalFuelUsed !== undefined ? log.totalFuelUsed.toFixed(0) : '--'}
          unit="kg"
          icon="local_gas_station"
        />
        <DataCard
          label={t(K.summaryMaxG)}
          value={log.maxG.toFixed(2)}
          unit="G"
          icon="arrow_upward"
          accentColor={log.maxG >= 2.5 ? 'var(--color-danger)' : undefined}
        />
        <DataCard
          label={t(K.summaryMinG)}
          value={log.minG.toFixed(2)}
          unit="G"
          icon="arrow_downward"
          accentColor={log.minG <= 0.3 ? 'var(--color-danger)' : undefined}
        />
        <DataCard
          label={t(K.summaryTouchdownG)}
          value={landing ? landing.gForce.toFixed(2) : '--'}
          unit="G"
          icon="flight_land"
          accentColor={landing ? LANDING_RATING_COLOR[landing.rating] : undefined}
          hint={landing ? `${landing.verticalSpeed.toFixed(0)} fpm` : undefined}
        />
      </div>
    </SectionCard>
  );
}

/** 落地评级配色：butter/good 为正向绿，hard/crash 为告警红 */
export const LANDING_RATING_COLOR: Record<LandingRating, string> = {
  butter: '#0ca30c',
  good: '#0ca30c',
  firm: '#fab219',
  hard: '#ec835a',
  crash: '#d03b3b',
};

// ──────────────────────────────────────────────────────────────────────────
// 航迹地图
// ──────────────────────────────────────────────────────────────────────────

/** 回放倍速档位 */
const REPLAY_SPEEDS = [1, 2, 4, 8] as const;
/** 一倍速下每帧的间隔 */
const REPLAY_TICK_MS = 120;

export function AnalysisTrackMap({ log }: { log: FlightLog }) {
  const t = useTranslate();

  // 过滤掉 (0,0) 这类无效坐标。回放要按下标回查原始读数，
  // 所以这里保留过滤后的**点对象**，坐标对另外派生
  const points = useMemo(
    () =>
      log.points.filter(
        (point) =>
          Number.isFinite(point.latitude) &&
          Number.isFinite(point.longitude) &&
          !(point.latitude === 0 && point.longitude === 0),
      ),
    [log],
  );

  const track = useMemo(
    () => points.map((point) => [point.latitude, point.longitude] as [number, number]),
    [points],
  );

  /** null = 未进入回放（看全程）；否则为当前回放到的下标 */
  const [cursor, setCursor] = useState<number | null>(null);
  const [playing, setPlaying] = useState(false);
  const [speed, setSpeed] = useState<(typeof REPLAY_SPEEDS)[number]>(1);
  // 回放光标标记走 Leaflet 命令式 API，放 ref 里避免拖动时重建地图
  const replayRef = useRef<{ map?: L.Map; marker?: L.CircleMarker }>({});

  const handleReady = useCallback(
    (map: L.Map) => {
      if (track.length === 0) return;
      replayRef.current.map = map;

      const polyline = L.polyline(track, {
        color: '#2a78d6',
        weight: 3,
        opacity: 0.9,
      }).addTo(map);

      // 起点/终点标记
      const startMarker = L.circleMarker(track[0], {
        radius: 6,
        color: '#ffffff',
        weight: 2,
        fillColor: '#0ca30c',
        fillOpacity: 1,
      })
        .addTo(map)
        .bindTooltip(log.departureAirport);

      const endMarker = L.circleMarker(track[track.length - 1], {
        radius: 6,
        color: '#ffffff',
        weight: 2,
        fillColor: '#d03b3b',
        fillOpacity: 1,
      })
        .addTo(map)
        .bindTooltip(log.arrivalAirport ?? '--');

      // 回放光标：先建好，未进入回放时隐藏（半径 0）
      const cursorMarker = L.circleMarker(track[0], {
        radius: 0,
        color: '#ffffff',
        weight: 2,
        fillColor: '#f5a524',
        fillOpacity: 1,
      }).addTo(map);
      replayRef.current.marker = cursorMarker;

      map.fitBounds(polyline.getBounds(), { padding: [24, 24] });

      return () => {
        polyline.remove();
        startMarker.remove();
        endMarker.remove();
        cursorMarker.remove();
        replayRef.current = {};
      };
    },
    [track, log.departureAirport, log.arrivalAirport],
  );

  // 拖动/播放时移动光标标记
  useEffect(() => {
    const marker = replayRef.current.marker;
    if (!marker) return;
    if (cursor === null || !track[cursor]) {
      marker.setRadius(0);
      return;
    }
    marker.setRadius(7);
    marker.setLatLng(track[cursor]);
  }, [cursor, track]);

  // 播放：按倍速推进下标，到头自动停
  useEffect(() => {
    if (!playing) return;
    const timer = setInterval(() => {
      setCursor((current) => {
        const next = (current ?? -1) + 1;
        if (next >= track.length - 1) {
          setPlaying(false);
          return track.length - 1;
        }
        return next;
      });
    }, REPLAY_TICK_MS / speed);
    return () => clearInterval(timer);
  }, [playing, speed, track.length]);

  const active = cursor !== null ? points[cursor] : undefined;

  return (
    <SectionCard
      title={t(K.detailTrack)}
      icon="route"
      trailing={<span className={styles.countBadge}>{track.length}</span>}
      flush
    >
      {track.length === 0 ? (
        <EmptyState icon="wrong_location" title={t(K.chartNoData)} />
      ) : (
        <>
          <LeafletMap
            center={track[0]}
            zoom={8}
            tileLayer="cartoDark"
            height={320}
            onReady={handleReady}
          />

          <div className={styles.replayBar}>
            <IconButton
              icon={playing ? 'pause' : 'play_arrow'}
              label={t(playing ? K.replayPause : K.replayPlay)}
              onClick={() => {
                // 从「看全程」直接点播放时，从头开始
                if (cursor === null) setCursor(0);
                setPlaying((value) => !value);
              }}
            />
            <IconButton
              icon="replay"
              label={t(K.replayReset)}
              onClick={() => {
                setPlaying(false);
                setCursor(0);
              }}
            />

            <input
              className={styles.replaySlider}
              type="range"
              min={0}
              max={Math.max(0, track.length - 1)}
              value={cursor ?? 0}
              aria-label={t(K.detailTrack)}
              onChange={(event) => {
                setPlaying(false);
                setCursor(Number(event.target.value));
              }}
            />

            <select
              className={styles.replaySpeed}
              value={speed}
              aria-label={t(K.replaySpeed)}
              onChange={(event) =>
                setSpeed(Number(event.target.value) as (typeof REPLAY_SPEEDS)[number])
              }
            >
              {REPLAY_SPEEDS.map((value) => (
                <option key={value} value={value}>
                  {value}×
                </option>
              ))}
            </select>

            {/* 退出回放，回到「看全程」 */}
            <Button
              variant="text"
              size="sm"
              onClick={() => {
                setPlaying(false);
                setCursor(null);
              }}
            >
              {t(K.replayLive)}
            </Button>
          </div>

          {active && (
            <div className={styles.replayReadout}>
              <span className={styles.replayTime}>{formatClock(active.timestamp)}</span>
              <span>
                {t(K.chartAltitude)} <b>{active.altitude.toFixed(0)}</b>
              </span>
              <span>
                {t(K.chartSpeed)} <b>{active.groundSpeed.toFixed(0)}</b>
              </span>
              <span>
                {t(K.chartVerticalSpeed)} <b>{active.verticalSpeed.toFixed(0)}</b>
              </span>
              <span>
                {t(K.replayHeading)} <b>{active.heading.toFixed(0)}°</b>
              </span>
            </div>
          )}
        </>
      )}
    </SectionCard>
  );
}

/** 回放读数用的时分秒 */
function formatClock(date: Date): string {
  const pad = (value: number) => String(value).padStart(2, '0');
  return `${pad(date.getHours())}:${pad(date.getMinutes())}:${pad(date.getSeconds())}`;
}

// ──────────────────────────────────────────────────────────────────────────
// 黑匣子数据表
// ──────────────────────────────────────────────────────────────────────────

/** 表格列：桌面版展示的核心字段子集 */
const BLACK_BOX_COLUMNS: {
  labelKey: string;
  select: (point: FlightLog['points'][number]) => string;
}[] = [
  { labelKey: K.chartAltitude, select: (p) => p.altitude.toFixed(0) },
  { labelKey: K.chartSpeed, select: (p) => p.groundSpeed.toFixed(0) },
  { labelKey: K.chartVerticalSpeed, select: (p) => p.verticalSpeed.toFixed(0) },
  { labelKey: K.chartGForce, select: (p) => p.gForce.toFixed(2) },
  { labelKey: K.chartPitch, select: (p) => p.pitch.toFixed(1) },
  { labelKey: K.chartBaro, select: (p) => (p.baroPressure ?? 29.92).toFixed(2) },
];

/** 每页行数，与桌面版的分页粒度一致 */
const BLACK_BOX_PAGE_SIZE = 100;

export function AnalysisBlackBox({ log }: { log: FlightLog }) {
  const t = useTranslate();
  const [page, setPage] = useState(0);
  const [showAlertsOnly, setShowAlertsOnly] = useState(false);
  const [pageInput, setPageInput] = useState('');

  const startMs = log.points[0]?.timestamp.getTime() ?? 0;

  // 先过滤再分页：全量数据都可达，不做截断
  const filtered = useMemo(
    () =>
      log.points
        .map((point, index) => ({ point, index }))
        .filter(({ point }) => !showAlertsOnly || point.anomalyAlerts.length > 0),
    [log, showAlertsOnly],
  );

  const pageCount = Math.max(1, Math.ceil(filtered.length / BLACK_BOX_PAGE_SIZE));
  const safePage = Math.min(page, pageCount - 1);
  const rows = filtered.slice(
    safePage * BLACK_BOX_PAGE_SIZE,
    (safePage + 1) * BLACK_BOX_PAGE_SIZE,
  );

  const alertCount = log.points.reduce((sum, point) => sum + point.anomalyAlerts.length, 0);

  const jumpToPage = () => {
    const target = Number.parseInt(pageInput, 10);
    if (!Number.isFinite(target)) return;
    setPage(Math.min(Math.max(target - 1, 0), pageCount - 1));
    setPageInput('');
  };

  return (
    <SectionCard
      title={t(K.blackBoxTitle)}
      icon="table_rows"
      trailing={
        <span className={styles.countBadge}>
          {log.points.length} {t(K.blackBoxRows)}
        </span>
      }
    >
      <div className={styles.blackBoxControls}>
        <InfoChip
          icon="warning"
          label={`${t(K.blackBoxAnomalyAlert)} (${alertCount})`}
          solid={showAlertsOnly}
          color="var(--color-warning)"
          onClick={() => {
            setShowAlertsOnly((prev) => !prev);
            setPage(0);
          }}
        />
      </div>

      {rows.length === 0 ? (
        <EmptyState icon="search_off" title={t(K.chartNoData)} />
      ) : (
        <>
          <div className={styles.blackBoxTableWrap}>
            <table className={styles.blackBoxTable}>
              <thead>
                <tr>
                  <th>{t(K.blackBoxTime)}</th>
                  {BLACK_BOX_COLUMNS.map((column) => (
                    <th key={column.labelKey}>{t(column.labelKey)}</th>
                  ))}
                  <th>{t(K.blackBoxAlert)}</th>
                </tr>
              </thead>
              <tbody>
                {rows.map(({ point, index }) => (
                  <tr
                    key={index}
                    className={
                      point.anomalyAlerts.length > 0 ? styles.blackBoxRowAlert : undefined
                    }
                  >
                    <td className="text-mono">
                      {formatElapsed(point.timestamp.getTime() - startMs)}
                    </td>
                    {BLACK_BOX_COLUMNS.map((column) => (
                      <td key={column.labelKey} className="text-mono">
                        {column.select(point)}
                      </td>
                    ))}
                    <td>
                      {point.anomalyAlerts.length === 0 ? (
                        <span className={styles.blackBoxNoAlert}>--</span>
                      ) : (
                        <div className={styles.blackBoxAlerts}>
                          {point.anomalyAlerts.map((alert) => (
                            <span
                              key={alert.id + alert.message}
                              className={styles.blackBoxAlert}
                              style={{ color: ALERT_LEVEL_COLOR[alert.level] }}
                            >
                              <MaterialIcon name="warning" size={12} filled />
                              {alert.message}
                            </span>
                          ))}
                        </div>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          <div className={styles.blackBoxPager}>
            <IconButton
              icon="chevron_left"
              label={t(K.blackBoxJumpAction)}
              disabled={safePage === 0}
              onClick={() => setPage(safePage - 1)}
            />
            <span className={styles.blackBoxPageInfo}>
              {safePage + 1} / {pageCount} {t(K.blackBoxPageUnit)}
            </span>
            <IconButton
              icon="chevron_right"
              label={t(K.blackBoxJumpAction)}
              disabled={safePage >= pageCount - 1}
              onClick={() => setPage(safePage + 1)}
            />

            <div className={styles.blackBoxJump}>
              <TextField
                value={pageInput}
                onChange={setPageInput}
                placeholder={t(K.blackBoxJumpToPage)}
                type="number"
                onSubmit={jumpToPage}
                className={styles.blackBoxJumpInput}
              />
              <Button variant="tonal" size="sm" onClick={jumpToPage}>
                {t(K.blackBoxJumpAction)}
              </Button>
            </div>
          </div>
        </>
      )}
    </SectionCard>
  );
}

export const ALERT_LEVEL_COLOR: Record<FlightLogAlertLevel, string> = {
  caution: '#fab219',
  warning: '#ec835a',
  danger: '#d03b3b',
};

// ──────────────────────────────────────────────────────────────────────────
// 工具
// ──────────────────────────────────────────────────────────────────────────

export function formatDuration(ms: number): string {
  const totalMinutes = Math.floor(ms / 60_000);
  const hours = Math.floor(totalMinutes / 60);
  const minutes = totalMinutes % 60;
  return `${hours}h ${String(minutes).padStart(2, '0')}m`;
}

function formatElapsed(ms: number): string {
  const totalSeconds = Math.floor(ms / 1000);
  const minutes = Math.floor(totalSeconds / 60);
  const seconds = totalSeconds % 60;
  return `${String(minutes).padStart(2, '0')}:${String(seconds).padStart(2, '0')}`;
}
