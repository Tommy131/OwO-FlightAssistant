import { useCallback, useEffect, useMemo, useRef, useState, type ReactNode } from 'react';
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
import { useIsDarkMode } from '../../../../core/theme/theme-store';
import { resolveAlertMessageKey } from '../../../map/services/flight-alerts';
import { FlightLogsLocalizationKeys as K } from '../../localization/flight-logs-localization';
import {
  buildTrackSegments,
  classifyTrackPhases,
  TRACK_PHASE_ORDER,
  type TrackPhase,
} from '../../services/track-phases';
import {
  flightLogAirborneDurationMs,
  flightLogDurationMs,
  type FlightLog,
  type FlightLogAlertLevel,
  type FlightLogPoint,
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

/**
 * 各阶段的航迹配色，沿用桌面版那一套。
 *
 * 五个色相拉得比较开，且深浅底图上都还认得出来 —— 航迹是画在瓦片上的，
 * 只在深色底图上挑好看的颜色，换成浅色底图就糊成一片。
 */
const TRACK_PHASE_COLOR: Record<TrackPhase, string> = {
  taxiOut: '#f5a524',
  climb: '#12b8b0',
  cruise: '#8b5cf6',
  approach: '#f5533d',
  taxiIn: '#3ddc84',
};

/** 阶段 → 图例文案 */
const TRACK_PHASE_LABEL_KEY: Record<TrackPhase, string> = {
  taxiOut: K.trackPhaseTaxiOut,
  climb: K.trackPhaseClimb,
  cruise: K.trackPhaseCruise,
  approach: K.trackPhaseApproach,
  taxiIn: K.trackPhaseTaxiIn,
};

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

  // 阶段划分是纯计算，跟着点数组走即可（见 services/track-phases.ts）
  const phases = useMemo(() => classifyTrackPhases(points), [points]);
  const segments = useMemo(() => buildTrackSegments(phases), [phases]);
  /** 图例只列这条航迹里真正出现过的阶段，没飞到的不占地方 */
  const presentPhases = useMemo(
    () => TRACK_PHASE_ORDER.filter((phase) => phases.includes(phase)),
    [phases],
  );

  const isDark = useIsDarkMode();

  /** null = 未进入回放（看全程）；否则为当前回放到的下标 */
  const [cursor, setCursor] = useState<number | null>(null);
  /** 鼠标悬停到的航迹点下标；离开时回到 null */
  const [hovered, setHovered] = useState<number | null>(null);
  const [playing, setPlaying] = useState(false);
  const [speed, setSpeed] = useState<(typeof REPLAY_SPEEDS)[number]>(1);
  // 回放光标标记走 Leaflet 命令式 API，放 ref 里避免拖动时重建地图
  const replayRef = useRef<{ map?: L.Map; marker?: L.CircleMarker }>({});

  const handleReady = useCallback(
    (map: L.Map) => {
      if (track.length === 0) return;
      replayRef.current.map = map;

      /*
       * 一段一条折线：Leaflet 的 polyline 只能整条一个颜色，
       * 想按阶段着色就得拆开画。段与段共享一个端点（见 buildTrackSegments），
       * 所以视觉上仍是连续的一条线。
       */
      const phaseLines = segments.map((segment) =>
        L.polyline(track.slice(segment.startIndex, segment.endIndex + 1), {
          color: TRACK_PHASE_COLOR[segment.phase],
          weight: 3,
          opacity: 0.95,
        }).addTo(map),
      );
      /*
       * 命中线：与航迹重合但完全透明、笔宽 14px 的一条线，只用来接鼠标。
       *
       * 直接在 3px 的可见折线上接 hover 太难点了 —— 鼠标得压在几个像素上，
       * 稍微一抖就掉。加粗可见线又会把航迹画得很糊，所以分成两条：
       * 一条负责好看，一条负责好点。
       */
      const hitLines = segments.map((segment) => {
        const slice = track.slice(segment.startIndex, segment.endIndex + 1);
        return L.polyline(slice, { color: '#000', weight: 14, opacity: 0 })
          .addTo(map)
          .on('mousemove', (event: L.LeafletMouseEvent) => {
            setHovered(nearestTrackIndex(slice, event.latlng) + segment.startIndex);
          })
          .on('mouseout', () => setHovered(null));
      });

      // 取全程范围用的辅助线，不加进地图，只为算 bounds
      const polyline = L.polyline(track);

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
        phaseLines.forEach((line) => line.remove());
        hitLines.forEach((line) => line.remove());
        startMarker.remove();
        endMarker.remove();
        cursorMarker.remove();
        replayRef.current = {};
      };
    },
    [track, segments, log.departureAirport, log.arrivalAirport],
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

  /*
   * 详情卡看哪一点：悬停优先于回放光标。
   * 回放播着的时候把鼠标挪到别处，用户想看的显然是鼠标底下那一点。
   */
  const detailIndex = hovered ?? cursor;
  const detailPoint = detailIndex !== null ? points[detailIndex] : undefined;
  const detailPhase = detailIndex !== null ? phases[detailIndex] : undefined;

  return (
    <AnalysisSection
      title={t(K.detailTrack)}
      icon="route"
      fill
      trailing={<span className={styles.countBadge}>{track.length}</span>}
    >
      {track.length === 0 ? (
        <EmptyState icon="wrong_location" title={t(K.chartNoData)} />
      ) : (
        <>
          {/* 图例：只列这条航迹真正飞到过的阶段 */}
          <div className={styles.trackLegend}>
            {presentPhases.map((phase) => (
              <span key={phase} className={styles.trackLegendItem}>
                <span
                  className={styles.trackLegendDot}
                  style={{ background: TRACK_PHASE_COLOR[phase] }}
                />
                {t(TRACK_PHASE_LABEL_KEY[phase])}
              </span>
            ))}
          </div>

          {/*
            底图跟着主题走：深色主题配深色瓦片，浅色主题配浅色瓦片。
            写死 cartoDark 的话，浅色主题下整块地图是一坨黑，
            和周围的卡片完全脱节。

            外面套一层 flex:1 的壳把剩余高度全吃掉，地图再填满这层壳 ——
            原来写死 320px，屏幕再高也只有那么一条，下面全是空白。
          */}
          <div className={styles.trackMapFill}>
            <LeafletMap
              center={track[0]}
              zoom={8}
              tileLayer={isDark ? 'cartoDark' : 'cartoLight'}
              height="100%"
              onReady={handleReady}
            />

            {/* 悬停某个航迹点、或回放时，显示该点的详细读数 */}
            {detailPoint && (
              <TrackPointDetailCard point={detailPoint} phase={detailPhase} />
            )}
          </div>

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

        </>
      )}
    </AnalysisSection>
  );
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
    <AnalysisSection
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
                              {alertText(alert, t)}
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
    </AnalysisSection>
  );
}

export const ALERT_LEVEL_COLOR: Record<FlightLogAlertLevel, string> = {
  caution: '#fab219',
  warning: '#ec835a',
  danger: '#d03b3b',
};

/**
 * 黑匣子里一条告警该显示的文案。
 *
 * 记录下来的 `message` 是后端的令牌（`push_over_danger` 这种），
 * 早先直接渲染它，明细表里就是一列裸 id。这里走与地图告警同一张映射表，
 * 保证两处叫法一致；实在认不出的令牌退回原文，至少不是空白。
 */
export function alertText(
  alert: { readonly message: string },
  translate: (key: string) => string,
): string {
  const key = resolveAlertMessageKey(alert.message);
  return key === undefined ? alert.message : translate(key);
}

/**
 * 航迹点详情卡
 *
 * 悬停到航迹上、或回放到某一点时贴在地图左下角。
 * 字段与「图表」页的曲线一一对应，两处看到的是同一套读数。
 *
 * 缺的字段（老日志没记 AOA / 气压高度）显示 `--` 而不是整行藏掉 ——
 * 行数固定，卡片高度才不会随着鼠标移动一直跳。
 */
function TrackPointDetailCard({
  point,
  phase,
}: {
  point: FlightLogPoint;
  phase?: TrackPhase;
}) {
  const t = useTranslate();

  const rows: { label: string; value: string }[] = [
    { label: t(K.trackPointTimeUtc), value: formatUtcClock(point.timestamp) },
    { label: t(K.chartAltitude), value: `${point.altitude.toFixed(0)} ft` },
    { label: t(K.chartSpeed), value: `${point.groundSpeed.toFixed(0)} kts` },
    { label: t(K.chartPitch), value: `${point.pitch.toFixed(1)}°` },
    { label: t(K.chartVerticalSpeed), value: `${point.verticalSpeed.toFixed(0)} fpm` },
    { label: t(K.chartGForce), value: point.gForce.toFixed(2) },
    {
      label: t(K.chartBaro),
      value: point.baroPressure === undefined ? '--' : `${point.baroPressure.toFixed(2)} inHg`,
    },
    {
      label: t(K.chartAoa),
      value: point.angleOfAttack === undefined ? '--' : `${point.angleOfAttack.toFixed(2)}°`,
    },
  ];

  return (
    <div className={styles.trackPointCard}>
      {phase && (
        <div className={styles.trackPointPhase}>
          <span
            className={styles.trackLegendDot}
            style={{ background: TRACK_PHASE_COLOR[phase] }}
          />
          {t(TRACK_PHASE_LABEL_KEY[phase])}
        </div>
      )}
      {rows.map((row) => (
        <div key={row.label} className={styles.trackPointRow}>
          <span className={styles.trackPointLabel}>{row.label}</span>
          <span className={`${styles.trackPointValue} text-mono`}>{row.value}</span>
        </div>
      ))}
    </div>
  );
}

/**
 * 折线上离鼠标最近的那个顶点下标。
 *
 * 用平方距离比大小即可 —— 只是选最近点，开根号不影响排序，白算一遍。
 * 经纬度直接当平面坐标够用：命中线只有十几像素宽，那点尺度上的投影畸变
 * 不足以选错顶点。
 */
function nearestTrackIndex(slice: readonly [number, number][], at: L.LatLng): number {
  let best = 0;
  let bestDistance = Infinity;
  for (let index = 0; index < slice.length; index++) {
    const dLat = slice[index][0] - at.lat;
    const dLon = slice[index][1] - at.lng;
    const distance = dLat * dLat + dLon * dLon;
    if (distance < bestDistance) {
      bestDistance = distance;
      best = index;
    }
  }
  return best;
}

/** UTC 时钟：航迹点的时间戳按 UTC 显示，与图表页一致 */
function formatUtcClock(at: Date): string {
  return [at.getUTCHours(), at.getUTCMinutes(), at.getUTCSeconds()]
    .map((part) => String(part).padStart(2, '0'))
    .join(':');
}

// ──────────────────────────────────────────────────────────────────────────
// 嵌入式分区
// ──────────────────────────────────────────────────────────────────────────

/**
 * 直接嵌进父容器的分区（不套卡片）
 *
 * 轨迹图 / 质量报告 / 黑匣子明细原先各自套了一层 `SectionCard`：
 * 卡片有自己的圆角、边框和内边距，父容器又有一层 padding，
 * 两头一夹，真正能用的宽度少了近 60px —— 地图和宽表格首当其冲，
 * 航迹显示不全、表格横向挤成一团。
 *
 * 这三块本来就各自独占一个页签，外面再包一层「窗口」既没有分组意义，
 * 也没有并列的兄弟需要区隔。改成贴边嵌入，把宽度全让给内容。
 */
export function AnalysisSection({
  title,
  icon,
  trailing,
  children,
  /** 撑满父容器剩余高度（轨迹页要让地图占满） */
  fill = false,
}: {
  title: string;
  icon: string;
  trailing?: ReactNode;
  children: ReactNode;
  fill?: boolean;
}) {
  return (
    <section
      className={`${styles.embeddedSection}${fill ? ` ${styles.embeddedSectionFill}` : ''}`}
    >
      <header className={styles.embeddedHeader}>
        <MaterialIcon name={icon} size={16} color="var(--color-primary)" />
        <h3 className={styles.embeddedTitle}>{title}</h3>
        {trailing && <div className={styles.embeddedTrailing}>{trailing}</div>}
      </header>
      <div className={styles.embeddedBody}>{children}</div>
    </section>
  );
}

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
