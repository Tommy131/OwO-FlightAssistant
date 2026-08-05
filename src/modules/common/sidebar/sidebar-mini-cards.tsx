import { AppConstants } from '../../../core/constants/app-constants';
import type {
  SidebarMiniCard,
  SidebarTitleBadge,
} from '../../../core/module-registry/sidebar/sidebar-registries';
import { translate } from '../../../core/services/localization-service';
import { calculateDistanceNm } from '../../../core/utils/parse-utils';
import { MaterialIcon } from '../../../core/widgets/common/icon';
import { useFlightLogsStore } from '../../flight_logs/providers/flight-logs-store';
import { CommonLocalizationKeys as K } from '../localization/common-localization';
import type { FlightData, LiveMetarData } from '../models/common-models';
import { useFlightDataStore } from '../providers/flight-data-store';
import styles from './sidebar-mini-cards.module.css';

/**
 * 侧边栏迷你卡片与标题徽章
 *
 * 对应 Flutter 版：
 *   - `common/sidebar/backend_status_sidebar_title_badge.dart`
 *   - `common/sidebar/default_sidebar_mini_card.dart`
 *   - `common/sidebar/connected_flight_sidebar_mini_card.dart`
 *
 * ⚠️ `canDisplay()` / `render()` 在侧边栏 render 期间被调用，
 *    因此这里可以直接使用 hooks 订阅 store（等价于桌面版的 context.watch）。
 */

// ──────────────────────────────────────────────────────────────────────────
// 后端连接状态标题徽章
// ──────────────────────────────────────────────────────────────────────────

export function createBackendStatusTitleBadge(): SidebarTitleBadge {
  return {
    id: 'home_backend_status_title_badge',
    priority: 100,
    // Web 版飞行数据 store 恒定存在，等价于桌面版「Provider 已挂载」
    canDisplay: () => true,
    render: ({ isCollapsed }) => <BackendStatusBadge isCollapsed={isCollapsed} />,
  };
}

function BackendStatusBadge({ isCollapsed }: { isCollapsed: boolean }) {
  const reachable = useFlightDataStore((s) => s.snapshot.isBackendReachable);
  const color = reachable ? '#2E7D32' : 'var(--color-error)';
  const text = reachable
    ? translate(K.backendAvailableLabel)
    : translate(K.backendUnavailableTitle);

  if (isCollapsed) {
    return <span className={styles.statusDot} style={{ background: color }} title={text} />;
  }

  return (
    <span
      className={styles.statusPill}
      style={{
        color,
        background: 'color-mix(in srgb, currentColor 10%, transparent)',
        borderColor: 'color-mix(in srgb, currentColor 35%, transparent)',
      }}
      title={text}
    >
      {text}
    </span>
  );
}

// ──────────────────────────────────────────────────────────────────────────
// 默认迷你卡片（未连接模拟器时显示应用名与版本）
// ──────────────────────────────────────────────────────────────────────────

export function createDefaultMiniCard(): SidebarMiniCard {
  return {
    id: 'default_app_mini_card',
    priority: 1000,
    canDisplay: () => !useFlightDataStore((s) => s.snapshot.isConnected),
    render: ({ isCollapsed }) => <DefaultMiniCard isCollapsed={isCollapsed} />,
  };
}

function DefaultMiniCard({ isCollapsed }: { isCollapsed: boolean }) {
  const tooltip = `${AppConstants.appName} ${AppConstants.appVersion}`;

  if (isCollapsed) {
    return (
      <div className={`${styles.box} ${styles.boxCollapsed}`} title={tooltip}>
        <MaterialIcon name="info" size={16} color="var(--color-primary)" />
      </div>
    );
  }

  return (
    <div className={styles.box} title={tooltip}>
      <span className={styles.primaryLine}>{AppConstants.appName}</span>
      <span className={styles.secondaryLine}>v{AppConstants.appVersion}</span>
    </div>
  );
}

// ──────────────────────────────────────────────────────────────────────────
// 已连接飞行状态迷你卡片
// ──────────────────────────────────────────────────────────────────────────

export function createConnectedFlightMiniCard(): SidebarMiniCard {
  return {
    id: 'connected_flight_mini_card',
    priority: 10,
    canDisplay: () => useFlightDataStore((s) => s.snapshot.isConnected),
    render: ({ isCollapsed }) => <ConnectedFlightMiniCard isCollapsed={isCollapsed} />,
  };
}

/** 侧边栏显示用的简化飞行阶段 */
type FlightStage = 'ground' | 'climb' | 'cruise' | 'descent' | 'approach';

const STAGE_ICON: Record<FlightStage, string> = {
  ground: 'local_airport',
  climb: 'trending_up',
  cruise: 'flight',
  descent: 'trending_down',
  approach: 'flight_land',
};

const STAGE_LABEL_KEY: Record<FlightStage, string> = {
  ground: K.miniStageGround,
  climb: K.miniStageClimb,
  cruise: K.miniStageCruise,
  descent: K.miniStageDescent,
  approach: K.miniStageApproach,
};

function ConnectedFlightMiniCard({ isCollapsed }: { isCollapsed: boolean }) {
  const snapshot = useFlightDataStore((s) => s.snapshot);
  const isRecording = useFlightLogsStore((s) => s.isRecording);
  const info = buildStageInfo(snapshot);

  if (isCollapsed) {
    return (
      <div className={`${styles.box} ${styles.boxCollapsed}`} title={info.tooltip}>
        <span className={styles.collapsedIconWrap}>
          <MaterialIcon name={STAGE_ICON[info.stage]} size={16} color="var(--color-primary)" />
          {isRecording && <span className={styles.recordingDot} />}
        </span>
      </div>
    );
  }

  return (
    <div className={styles.box} title={info.tooltip}>
      <div className={styles.headRow}>
        <span className={styles.primaryLine}>{info.stageName}</span>
        {isRecording && (
          <span className={styles.recordingBadge}>
            <span className={styles.recordingDotInline} />
            {translate(K.miniRecording)}
          </span>
        )}
      </div>
      <span className={styles.secondaryLine}>{info.line2}</span>
    </div>
  );
}

interface StageInfo {
  stage: FlightStage;
  stageName: string;
  line2: string;
  tooltip: string;
}

/** 从飞行快照推导迷你卡片显示内容（逐行对应桌面版 _FlightStageResolver） */
function buildStageInfo(snapshot: {
  flightData: FlightData;
  nearestAirport?: { icaoCode: string; latitude: number; longitude: number };
  destinationAirport?: { icaoCode: string; latitude: number; longitude: number };
  metarsByIcao: Record<string, LiveMetarData>;
}): StageInfo {
  const data = snapshot.flightData;
  const stage = resolveStage(data);
  const nearest = snapshot.nearestAirport;
  const destination = snapshot.destinationAirport;

  let weather = '--';
  let visibility = '--';
  if (stage === 'ground' || stage === 'approach') {
    const currentIcao = nearest?.icaoCode;
    if (currentIcao && currentIcao.length > 0) {
      weather = weatherSummary(snapshot.metarsByIcao[currentIcao]);
    }
    visibility = visibilityLabel(data.visibility);
  }

  let distanceNm: number | undefined;
  let distanceTarget = translate(K.miniNearbyAirport);
  if (data.latitude !== undefined && data.longitude !== undefined) {
    const primaryTarget = destination ?? nearest;
    if (primaryTarget && primaryTarget.latitude !== 0 && primaryTarget.longitude !== 0) {
      distanceNm = calculateDistanceNm(
        data.latitude,
        data.longitude,
        primaryTarget.latitude,
        primaryTarget.longitude,
      );
      distanceTarget = destination
        ? translate(K.navDestination)
        : translate(K.miniNearbyAirport);
    }
  }

  const eta = etaLabel(distanceNm, data.groundSpeed);
  const distanceText = distanceNm === undefined ? '--' : `${Math.round(distanceNm)}nm`;
  const stageName = translate(STAGE_LABEL_KEY[stage]);
  const nearbyIcao = nearest && nearest.icaoCode.length > 0 ? nearest.icaoCode : '--';

  const phaseLabel = translate(K.miniLabelPhase);
  let tooltip: string;
  if (stage === 'ground') {
    tooltip =
      `${phaseLabel}: ${stageName}\n` +
      `${translate(K.miniLabelAirport)}: ${nearbyIcao}\n` +
      `${translate(K.miniLabelWeather)}: ${weather}\n` +
      `${translate(K.miniLabelVisibility)}: ${visibility}`;
  } else if (stage === 'approach') {
    tooltip =
      `${phaseLabel}: ${stageName}\n` +
      `${translate(K.miniLabelCurrentAirport)}: ${nearbyIcao}\n` +
      `${translate(K.miniLabelWeather)}: ${weather}`;
  } else {
    tooltip =
      `${phaseLabel}: ${stageName}\n` +
      `${translate(K.miniLabelNearbyAirport)}: ${nearbyIcao}\n` +
      `${distanceTarget} ${translate(K.miniLabelDistance)}: ${distanceText}\n` +
      `${translate(K.miniLabelEta)}: ${eta}`;
  }

  const line2 =
    stage === 'ground' || stage === 'approach'
      ? `${nearbyIcao} · ${weather}`
      : `${nearbyIcao} · ${distanceText} · ${eta}`;

  return { stage, stageName, line2, tooltip };
}

function resolveStage(data: FlightData): FlightStage {
  switch ((data.flightPhase ?? '').trim().toLowerCase()) {
    case 'ground':
    case 'parked':
    case 'standby':
    case 'taxi':
      return 'ground';
    case 'takeoff':
    case 'climb':
      return 'climb';
    case 'cruise':
      return 'cruise';
    case 'descent':
      return 'descent';
    case 'approach':
    case 'landing':
      return 'approach';
    default:
      return 'cruise';
  }
}

/** 从 METAR 报文粗提天气摘要（关键字优先级与桌面版一致） */
function weatherSummary(metar: LiveMetarData | undefined): string {
  if (!metar) return translate(K.miniWeatherUnknown);
  const source = `${metar.raw} ${metar.displayWind}`.toUpperCase();

  if (source.includes('TS') || source.includes('雷暴')) {
    return translate(K.miniWeatherThunderstorm);
  }
  if (source.includes('+RA') || source.includes('暴雨')) {
    return translate(K.miniWeatherHeavyRain);
  }
  if (
    source.includes('RA') ||
    source.includes('DZ') ||
    source.includes('SH') ||
    source.includes('阴雨') ||
    source.includes('小雨')
  ) {
    return translate(K.miniWeatherRain);
  }
  if (source.includes('SN') || source.includes('雪')) {
    return translate(K.miniWeatherSnow);
  }
  if (
    source.includes('FG') ||
    source.includes('BR') ||
    source.includes('HZ') ||
    source.includes('雾')
  ) {
    return translate(K.miniWeatherLowVisibility);
  }
  if (source.includes('OVC') || source.includes('BKN') || source.includes('阴')) {
    return translate(K.miniWeatherOvercast);
  }
  if (
    source.includes('CAVOK') ||
    source.includes('SKC') ||
    source.includes('CLR') ||
    source.includes('FEW') ||
    source.includes('SCT') ||
    source.includes('晴')
  ) {
    return translate(K.miniWeatherExcellent);
  }
  return translate(K.miniWeatherNormal);
}

export function visibilityLabel(visibilityMeter: number | undefined): string {
  if (visibilityMeter === undefined) return '--';
  if (visibilityMeter >= 10000) return '>10km';
  if (visibilityMeter >= 1000) return `${(visibilityMeter / 1000).toFixed(1)}km`;
  return `${Math.round(visibilityMeter)}m`;
}

/** 地速 ≤ 30kt 时不估算 ETA（与桌面版一致） */
function etaLabel(distanceNm: number | undefined, groundSpeed: number | undefined): string {
  if (distanceNm === undefined || groundSpeed === undefined || groundSpeed <= 30) return '--';
  const hours = distanceNm / groundSpeed;
  const eta = new Date(Date.now() + Math.round(hours * 60) * 60_000);
  return `${String(eta.getHours()).padStart(2, '0')}:${String(eta.getMinutes()).padStart(2, '0')}`;
}
