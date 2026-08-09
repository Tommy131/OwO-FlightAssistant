import { create } from 'zustand';
import { PersistenceService } from '../../../core/services/persistence-service';
import { AppLogger } from '../../../core/utils/logger';
import {
  pickString,
  toJsonMap,
} from '../../../core/utils/parse-utils';
import type { FlightData, FlightDataSnapshot } from '../../common/models/common-models';
import { MiddlewareHttpService } from '../../http/services/middleware-http-service';
import {
  type MapAerowayFeature,
  type MapAircraftState,
  type MapAIAircraftState,
  type MapAirportMarker,
  type MapCoordinate,
  type MapFlightAlert,
  type MapLayerStyle,
  type MapProcedure,
  type MapRestrictedZone,
  type MapRoutePoint,
  type MapHoldingPattern,
  type MapRunwayNavaid,
  type MapSelectedAirportDetail,
  type MapTaxiwayFileData,
  type MapTaxiwayNode,
  type MapTaxiwaySegment,
  type MapAutoTimerStartMode,
  type MapAutoTimerStopMode,
} from '../models/map-models';
import { computeAirportOutline } from '../services/airport-outline';
import {
  extractRadarFrames,
  isValidCoordinate,
  isDefined,
  parseAerowayFeature,
  parseHoldingPattern,
  parseNearbyAirport,
  parseRestrictedZone,
  parseRunwayNavaid,
  parseTaxiwayFile,
} from '../services/map-response-parsers';
import {
  addNode,
  insertNodeBetween,
  moveNode,
  pushUndo,
  rebuildSegments,
  removeNode,
  updateNodeInfo,
  updateSegmentInfo,
  type TaxiwayRoute,
} from '../services/taxiway-route-editor';
import { evaluateFlightAlerts } from '../services/flight-alerts';
import { resolveHudTimerAction } from '../services/hud-timer-rules';
import {
  appendRoutePoint,
  buildAirportsFromSnapshot,
  distanceInMeters,
} from '../services/map-telemetry';
import { fetchAirportWeather } from '../services/airport-weather';
import { parseAirportDetail } from '../services/map-airport-parser';
import { parseProcedureList } from '../services/procedure-parser';

/**
 * 地图模块状态管理
 *
 * 对应 Flutter 版 `modules/map/providers/map_provider.dart`（2893 行）+ 4 个 component。
 * 涵盖：图层开关、天气叠加、飞行告警、HUD 计时器（含自动启停）、
 * 航迹累积、滑行道绘制（撤销/重做/导入导出）、本场机场。
 */

const MODULE_NAME = 'map';

// ── 持久化键 ──
const HOME_AIRPORT_KEY = 'home_airport';
const AUTO_TIMER_ENABLED_KEY = 'auto_hud_timer_enabled';
const AUTO_TIMER_START_MODE_KEY = 'auto_timer_start_mode';
const AUTO_TIMER_STOP_MODE_KEY = 'auto_timer_stop_mode';
const ALERTS_ENABLED_KEY = 'alerts_enabled';
const DISABLED_ALERT_IDS_KEY = 'disabled_alert_ids';
const CLIMB_WARNING_KEY = 'climb_rate_warning_fpm';
const CLIMB_DANGER_KEY = 'climb_rate_danger_fpm';
const DESCENT_WARNING_KEY = 'descent_rate_warning_fpm';
const DESCENT_DANGER_KEY = 'descent_rate_danger_fpm';
const LAYER_STYLE_KEY = 'layer_style';

// ── 默认阈值，与桌面版一致 ──
const DEFAULT_CLIMB_WARNING_FPM = 3000;
const DEFAULT_CLIMB_DANGER_FPM = 5000;
const DEFAULT_DESCENT_WARNING_FPM = -3000;
const DEFAULT_DESCENT_DANGER_FPM = -5000;

/** 航迹最多保留的点数，避免长航班无限增长 */
/** 相邻航迹点最小间隔（米），低于此值不记点 */
/** 判定「移动中」的地速门槛（kt） */
const MOVING_GROUND_SPEED_KT = 1.5;
/** UI 刷新限流间隔（ms）—— 地图重绘开销大 */
const UI_REFRESH_INTERVAL_MS = 250;
/** 雷达帧刷新间隔（ms） */
const RADAR_REFRESH_INTERVAL_MS = 5 * 60 * 1000;

/** 可配置的告警 ID，与桌面版一致 */
export const CONFIGURABLE_ALERT_IDS = [
  'stall_warning',
  'overspeed',
  'excessive_climb_rate',
  'excessive_descent_rate',
  'terrain_warning',
  'restricted_airspace',
  'bank_angle',
  'high_aoa',
] as const;


interface MapState {
  // ── 图层开关 ──
  layerStyle: MapLayerStyle;
  followAircraft: boolean;
  showRoute: boolean;
  showPlannedRoute: boolean;
  showAirports: boolean;
  showRunways: boolean;
  showParkings: boolean;
  /** 滑行道/停机坪地面结构（OSM aeroway 矢量） */
  showAeroway: boolean;
  /** 跑道进近设施（CAT/频率/下滑道）是否画在地图上 */
  showRunwayNavaids: boolean;
  /** 等待航线是否显示 */
  showHoldings: boolean;
  /** 是否显示公布程序（SID/STAR/进近） */
  showProcedures: boolean;
  /** 当前机场的全部程序 */
  procedures: MapProcedure[];
  /** 选中的程序键（`类型|名称|转换`）；null 表示未选 */
  selectedProcedureKey: string | null;
  isLoadingProcedures: boolean;
  /** 当前机场的等待航线 */
  holdings: MapHoldingPattern[];
  /** 点开了哪条跑道的进近波束（跑道 ident，如 `18L/36R`）；null=没展开 */
  beamRunwayIdent: string | null;
  /** 下滑道信息是否显示；卡片与地图共用这一个开关 */
  showGlideslope: boolean;
  showCompass: boolean;
  showWeather: boolean;
  showWeatherRainfall: boolean;
  showWeatherWind: boolean;
  showWeatherPressure: boolean;
  showWeatherTemperature: boolean;
  showRestrictedAirspace: boolean;
  showTerrainWarning: boolean;
  showCustomTaxiwayRoute: boolean;

  // ── 实时状态 ──
  isConnected: boolean;
  isPaused: boolean;
  isLoading: boolean;
  connectionEpoch: number;
  lastReconnectPromptEpoch: number;
  aircraft: MapAircraftState | null;
  aiAircraft: MapAIAircraftState[];
  route: MapRoutePoint[];
  airports: MapAirportMarker[];
  /** 当前视野内的机场（按边界从后端拉取，与航线上的 airports 分开存） */
  nearbyAirports: MapAirportMarker[];
  /** ICAO → 机场轮廓；只在缩放足够近时才逐个补，远景不拉明细 */
  nearbyOutlines: Record<string, MapCoordinate[]>;
  /** 选中机场的跑道/滑行道/停机坪矢量 */
  aerowayFeatures: MapAerowayFeature[];
  isAerowayLoading: boolean;
  activeAlerts: MapFlightAlert[];
  homeAirport: MapAirportMarker | null;
  currentNearestAirportIcao: string | null;
  selectedAirport: MapSelectedAirportDetail | null;
  takeoffPoint: MapCoordinate | null;
  landingPoint: MapCoordinate | null;
  isAircraftMoving: boolean;

  // ── HUD 计时器 ──
  hudElapsedMs: number;
  isHudTimerRunning: boolean;
  hasHudTimerStarted: boolean;
  autoHudTimerEnabled: boolean;
  autoTimerStartMode: MapAutoTimerStartMode;
  autoTimerStopMode: MapAutoTimerStopMode;

  // ── 告警设置 ──
  alertsEnabled: boolean;
  disabledAlertIds: string[];
  climbRateWarningFpm: number;
  climbRateDangerFpm: number;
  descentRateWarningFpm: number;
  descentRateDangerFpm: number;

  // ── 天气雷达 ──
  weatherRadarTimestamp: number | null;
  weatherRadarHost: string | null;
  weatherRadarPath: string | null;

  // ── 限制空域 ──
  restrictedZones: MapRestrictedZone[];

  // ── 滑行道 ──
  taxiwayNodes: MapTaxiwayNode[];
  taxiwaySegments: MapTaxiwaySegment[];
  isTaxiwayDrawingActive: boolean;
  hasUnsavedTaxiwayChanges: boolean;
  loadedTaxiwayAirportIcao: string | null;
  completedTaxiwaySegmentIndexes: number[];

  // ── 动作 ──
  init: () => Promise<void>;
  updateFromFlightSnapshot: (snapshot: FlightDataSnapshot) => void;

  setLayerStyle: (style: MapLayerStyle) => Promise<void>;
  toggleFollowAircraft: () => void;
  toggleRoute: () => void;
  togglePlannedRoute: () => void;
  toggleAirports: () => void;
  toggleRunways: () => void;
  toggleParkings: () => void;
  toggleAeroway: () => void;
  toggleRunwayNavaids: () => void;
  toggleHoldings: () => void;
  toggleProcedures: () => void;
  loadProcedures: (icao: string) => Promise<void>;
  selectProcedure: (key: string | null) => void;
  setBeamRunway: (ident: string | null) => void;
  loadHoldings: (detail: MapSelectedAirportDetail) => Promise<void>;
  toggleGlideslope: () => void;
  toggleCompass: () => void;
  toggleWeather: () => void;
  toggleWeatherRainfall: () => void;
  toggleWeatherWind: () => void;
  toggleWeatherPressure: () => void;
  toggleWeatherTemperature: () => void;
  toggleRestrictedAirspace: () => void;
  toggleTerrainWarning: () => void;
  toggleCustomTaxiway: () => void;

  setSelectedAirport: (detail: MapSelectedAirportDetail | null) => void;
  setHomeAirport: (airport: MapAirportMarker) => Promise<void>;
  clearHomeAirport: () => Promise<void>;

  // HUD 计时器
  toggleHudTimer: () => void;
  startHudTimer: () => void;
  pauseHudTimer: () => void;
  resetHudTimer: () => void;
  setAutoHudTimerEnabled: (value: boolean) => Promise<void>;
  setAutoTimerStartMode: (mode: MapAutoTimerStartMode) => Promise<void>;
  setAutoTimerStopMode: (mode: MapAutoTimerStopMode) => Promise<void>;

  // 告警
  setAlertsEnabled: (value: boolean) => Promise<void>;
  setAlertEnabled: (alertId: string, enabled: boolean) => Promise<void>;
  isAlertEnabled: (alertId: string) => boolean;
  setVerticalRateThresholds: (thresholds: {
    climbWarning?: number;
    climbDanger?: number;
    descentWarning?: number;
    descentDanger?: number;
  }) => Promise<void>;

  // 滑行道绘制
  toggleTaxiwayDrawing: () => void;
  addTaxiwayNode: (point: MapCoordinate) => void;
  updateTaxiwayNodePosition: (index: number, point: MapCoordinate) => void;
  updateTaxiwayNodeInfo: (index: number, info: { name?: string; note?: string }) => void;
  removeTaxiwayNodeAt: (index: number) => void;
  insertTaxiwayNodeBetween: (segmentIndex: number, coordinate?: MapCoordinate) => void;
  updateTaxiwaySegmentInfo: (
    index: number,
    info: { name?: string; note?: string; speedLimitKt?: number },
  ) => void;
  undoTaxiwayRoute: () => void;
  redoTaxiwayRoute: () => void;
  canUndoTaxiwayRoute: () => boolean;
  canRedoTaxiwayRoute: () => boolean;
  clearTaxiwayRoute: () => void;
  exportTaxiwayRoute: () => number;
  importTaxiwayRoute: (file: File) => Promise<number>;

  clearRoute: () => void;
  shouldShowReconnectPrompt: () => boolean;
  markReconnectPromptHandled: () => void;
  refreshWeatherRadarTimestamp: (force?: boolean) => Promise<void>;
  /** 按当前视野拉取限制空域（地图 moveend 时调用） */
  refreshRestrictedAirspace: (bounds: {
    minLat: number;
    maxLat: number;
    minLon: number;
    maxLon: number;
  }) => Promise<void>;
  /**
   * 按当前视野拉取机场（地图 moveend 时调用）
   *
   * `withOutlines` 为真时再逐个补机场轮廓 —— 轮廓要拉机场明细
   * （首都机场一次就是 340 个停机位），只在缩放够近、屏幕上机场没几个时才做。
   */
  refreshNearbyAirports: (
    bounds: { minLat: number; maxLat: number; minLon: number; maxLon: number },
    options?: { withOutlines?: boolean },
  ) => Promise<void>;
  /** 拉取选中机场的跑道/滑行道/停机坪矢量 */
  loadAerowayFeatures: (detail: MapSelectedAirportDetail) => Promise<void>;
  /** 拉取选中机场的 METAR（原文 + 解读 + 飞行等级） */
  loadAirportWeather: (detail: MapSelectedAirportDetail) => Promise<void>;
  loadRunwayNavaids: (detail: MapSelectedAirportDetail) => Promise<void>;
  /**
   * 拉取视野内若干机场的地面结构
   *
   * 滑行道不该只有「选中机场」才画 —— 缩放到场面级别时，
   * 屏幕上的机场就应该直接显示滑行道网络。
   */
  loadNearbyAeroway: (icaos: string[]) => Promise<void>;
}

// ── 不参与渲染的可变上下文 ──
const ctx = {
  lastUiNotifyAt: null as number | null,
  hudTimerHandle: null as ReturnType<typeof setInterval> | null,
  hudStartedAt: null as number | null,
  radarTimerHandle: null as ReturnType<typeof setInterval> | null,
  lastRoutePoint: null as MapCoordinate | null,
  lastOnGround: undefined as boolean | undefined,
  /** 撤销/重做栈（存的是整条路线的快照） */
  undoStack: [] as TaxiwayRoute[],
  redoStack: [] as TaxiwayRoute[],
};

/** 从 store 状态取出当前路线（编辑器只认这两个字段） */
function currentRoute(state: MapState): TaxiwayRoute {
  return { nodes: state.taxiwayNodes, segments: state.taxiwaySegments };
}

/** 记录一次可撤销操作；任何新操作都会作废重做栈 */
function recordUndo(route: TaxiwayRoute): void {
  ctx.undoStack = pushUndo(ctx.undoStack, route);
  ctx.redoStack = [];
}

/** 把编辑结果写回 store */
function applyRoute(setState: (patch: Partial<MapState>) => void, route: TaxiwayRoute): void {
  setState({
    taxiwayNodes: route.nodes,
    taxiwaySegments: route.segments,
    hasUnsavedTaxiwayChanges: true,
  });
}

export const useMapStore = create<MapState>((set, get) => ({
  layerStyle: 'dark',
  followAircraft: true,
  showRoute: true,
  showPlannedRoute: false,
  showAirports: true,
  showRunways: true,
  showParkings: false,
  showAeroway: true,
  showRunwayNavaids: true,
  showHoldings: false,
  showProcedures: false,
  procedures: [],
  selectedProcedureKey: null,
  isLoadingProcedures: false,
  holdings: [],
  beamRunwayIdent: null,
  showGlideslope: true,
  showCompass: true,
  showWeather: false,
  showWeatherRainfall: false,
  showWeatherWind: false,
  showWeatherPressure: false,
  showWeatherTemperature: false,
  showRestrictedAirspace: false,
  showTerrainWarning: false,
  showCustomTaxiwayRoute: false,

  isConnected: false,
  isPaused: false,
  isLoading: false,
  connectionEpoch: 0,
  lastReconnectPromptEpoch: 0,
  aircraft: null,
  aiAircraft: [],
  route: [],
  airports: [],
  nearbyAirports: [],
  nearbyOutlines: {},
  aerowayFeatures: [],
  isAerowayLoading: false,
  activeAlerts: [],
  homeAirport: null,
  currentNearestAirportIcao: null,
  selectedAirport: null,
  takeoffPoint: null,
  landingPoint: null,
  isAircraftMoving: false,

  hudElapsedMs: 0,
  isHudTimerRunning: false,
  hasHudTimerStarted: false,
  autoHudTimerEnabled: false,
  autoTimerStartMode: 'runwayMovement',
  autoTimerStopMode: 'stableLanding',

  alertsEnabled: true,
  disabledAlertIds: [],
  climbRateWarningFpm: DEFAULT_CLIMB_WARNING_FPM,
  climbRateDangerFpm: DEFAULT_CLIMB_DANGER_FPM,
  descentRateWarningFpm: DEFAULT_DESCENT_WARNING_FPM,
  descentRateDangerFpm: DEFAULT_DESCENT_DANGER_FPM,

  weatherRadarTimestamp: null,
  weatherRadarHost: null,
  weatherRadarPath: null,

  restrictedZones: [],

  taxiwayNodes: [],
  taxiwaySegments: [],
  isTaxiwayDrawingActive: false,
  hasUnsavedTaxiwayChanges: false,
  loadedTaxiwayAirportIcao: null,
  completedTaxiwaySegmentIndexes: [],

  // ────────────────────────────────────────────────────────────────────────
  // 初始化
  // ────────────────────────────────────────────────────────────────────────

  async init() {
    await PersistenceService.ensureReady();
    const read = <T>(key: string): T | undefined =>
      PersistenceService.getModuleData<T>(MODULE_NAME, key);

    const storedLayer = read<string>(LAYER_STYLE_KEY);
    const storedHome = read<{ code: string; name?: string; lat: number; lon: number }>(
      HOME_AIRPORT_KEY,
    );

    set({
      layerStyle: isLayerStyle(storedLayer) ? storedLayer : 'dark',
      autoHudTimerEnabled: read<boolean>(AUTO_TIMER_ENABLED_KEY) ?? false,
      autoTimerStartMode:
        (read<MapAutoTimerStartMode>(AUTO_TIMER_START_MODE_KEY) ?? 'runwayMovement'),
      autoTimerStopMode: read<MapAutoTimerStopMode>(AUTO_TIMER_STOP_MODE_KEY) ?? 'stableLanding',
      alertsEnabled: read<boolean>(ALERTS_ENABLED_KEY) ?? true,
      disabledAlertIds: read<string[]>(DISABLED_ALERT_IDS_KEY) ?? [],
      climbRateWarningFpm: read<number>(CLIMB_WARNING_KEY) ?? DEFAULT_CLIMB_WARNING_FPM,
      climbRateDangerFpm: read<number>(CLIMB_DANGER_KEY) ?? DEFAULT_CLIMB_DANGER_FPM,
      descentRateWarningFpm: read<number>(DESCENT_WARNING_KEY) ?? DEFAULT_DESCENT_WARNING_FPM,
      descentRateDangerFpm: read<number>(DESCENT_DANGER_KEY) ?? DEFAULT_DESCENT_DANGER_FPM,
      homeAirport: storedHome
        ? {
            code: storedHome.code,
            name: storedHome.name,
            position: { latitude: storedHome.lat, longitude: storedHome.lon },
            isPrimary: true,
          }
        : null,
    });

    await get().refreshWeatherRadarTimestamp(true);
  },

  // ────────────────────────────────────────────────────────────────────────
  // 飞行数据 → 地图状态
  // ────────────────────────────────────────────────────────────────────────

  updateFromFlightSnapshot(snapshot) {
    const state = get();
    const wasConnected = state.isConnected;
    const isConnected = snapshot.isConnected;

    const patch: Partial<MapState> = { isConnected };

    if (!wasConnected && isConnected) {
      patch.connectionEpoch = state.connectionEpoch + 1;
    } else if (wasConnected && !isConnected) {
      // 断线时关掉依赖实时遥测的叠加层，避免显示过期数据
      if (state.showWeatherWind) patch.showWeatherWind = false;
      if (state.showTerrainWarning) patch.showTerrainWarning = false;
    }

    const isPaused = snapshot.isPaused === true && isConnected;
    patch.isPaused = isPaused;
    if (!state.isPaused && isPaused && state.isHudTimerRunning) {
      stopHudInterval();
      patch.isHudTimerRunning = false;
    }

    patch.airports = buildAirportsFromSnapshot(snapshot);

    const nearestIcao = snapshot.nearestAirport?.icaoCode.trim().toUpperCase();
    patch.currentNearestAirportIcao =
      nearestIcao && nearestIcao.length > 0 ? nearestIcao : null;

    const flightData = snapshot.flightData;
    const lat = flightData.latitude;
    const lon = flightData.longitude;

    // AI 机：过滤无效坐标，并剔除与本机重合（<8m）的条目
    patch.aiAircraft = flightData.aiAircraft
      .filter(
        (item) =>
          isValidCoordinate(item.latitude, item.longitude) &&
          (lat === undefined ||
            lon === undefined ||
            distanceInMeters(lat, lon, item.latitude, item.longitude) > 8),
      )
      .map((item) => ({
        id: item.id,
        type: item.type,
        position: { latitude: item.latitude, longitude: item.longitude },
        altitude: item.altitude,
        heading: item.heading,
        groundSpeed: item.groundSpeed,
        onGround: item.onGround,
      }));

    const hasValidPosition =
      lat !== undefined && lon !== undefined && isValidCoordinate(lat, lon);

    if (isConnected && hasValidPosition) {
      const aircraft: MapAircraftState = {
        position: { latitude: lat, longitude: lon },
        heading: flightData.heading,
        headingTarget: flightData.autopilotHeadingTarget,
        altitude: flightData.altitude,
        groundSpeed: flightData.groundSpeed,
        airspeed: flightData.airspeed,
        pitch: flightData.pitch,
        bank: flightData.bank,
        angleOfAttack: flightData.angleOfAttack,
        verticalSpeed: flightData.verticalSpeed,
        windSpeed: flightData.windSpeed,
        windDirection: flightData.windDirection,
        radioAltitude: flightData.radioAltitude,
        stallWarning: flightData.stallWarning,
        onGround: flightData.onGround,
        parkingBrake: flightData.parkingBrake,
      };
      patch.aircraft = aircraft;

      const isMoving = (flightData.groundSpeed ?? 0) > MOVING_GROUND_SPEED_KT;
      patch.isAircraftMoving = isMoving;

      // 航迹累积：与上一点距离足够才记
      const appended = appendRoutePoint(state.route, aircraft, ctx.lastRoutePoint);
      if (appended.appended) {
        patch.route = appended.route;
        ctx.lastRoutePoint = appended.lastPoint;
      }

      // 起降点标记：onGround 翻转时打点
      const onGround = flightData.onGround;
      if (ctx.lastOnGround === true && onGround === false) {
        patch.takeoffPoint = aircraft.position;
      } else if (ctx.lastOnGround === false && onGround === true) {
        patch.landingPoint = aircraft.position;
      }
      ctx.lastOnGround = onGround;

      // 判定是纯函数，副作用留在这里
      const timerAction = resolveHudTimerAction(state, aircraft, isMoving);
      if (timerAction === 'start') {
        useMapStore.getState().startHudTimer();
        patch.hasHudTimerStarted = true;
        patch.isHudTimerRunning = true;
      } else if (timerAction === 'stop') {
        useMapStore.getState().pauseHudTimer();
        patch.isHudTimerRunning = false;
      }
    } else if (!isConnected) {
      patch.aircraft = null;
      patch.aiAircraft = [];
      patch.isAircraftMoving = false;
      ctx.lastRoutePoint = null;
      ctx.lastOnGround = undefined;
    }

    patch.activeAlerts = evaluateFlightAlerts(state, flightData);

    // 新出现的地形告警上报给中间件（对应桌面版 _syncMiddlewareMapTelemetry）
    reportNewTerrainWarnings(state.activeAlerts, patch.activeAlerts, flightData);

    // 限流：地图重绘代价高，非关键帧丢弃
    const now = Date.now();
    const isCritical =
      patch.connectionEpoch !== undefined ||
      patch.isPaused !== state.isPaused ||
      (patch.activeAlerts?.length ?? 0) !== state.activeAlerts.length;

    if (!isCritical && ctx.lastUiNotifyAt !== null && now - ctx.lastUiNotifyAt < UI_REFRESH_INTERVAL_MS) {
      return;
    }
    ctx.lastUiNotifyAt = now;
    set(patch);
  },

  // ────────────────────────────────────────────────────────────────────────
  // 图层开关
  // ────────────────────────────────────────────────────────────────────────

  async setLayerStyle(style) {
    set({ layerStyle: style });
    await PersistenceService.setModuleData(MODULE_NAME, LAYER_STYLE_KEY, style);
  },

  toggleFollowAircraft: () => set((s) => ({ followAircraft: !s.followAircraft })),
  toggleRoute: () => set((s) => ({ showRoute: !s.showRoute })),
  togglePlannedRoute: () => set((s) => ({ showPlannedRoute: !s.showPlannedRoute })),

  toggleAirports: () => set((s) => ({ showAirports: !s.showAirports })),
  toggleRunways: () => set((s) => ({ showRunways: !s.showRunways })),
  toggleParkings: () => set((s) => ({ showParkings: !s.showParkings })),
  toggleAeroway: () => set((s) => ({ showAeroway: !s.showAeroway })),
  toggleRunwayNavaids: () => set((s) => ({ showRunwayNavaids: !s.showRunwayNavaids })),
  toggleHoldings: () => set((s) => ({ showHoldings: !s.showHoldings })),

  toggleProcedures: () => {
    const next = !get().showProcedures;
    set({ showProcedures: next });
    // 开关是懒加载的入口：打开时才去取当前机场的程序
    const airport = get().selectedAirport;
    if (next && airport && get().procedures.length === 0) {
      void get().loadProcedures(airport.marker.code);
    }
  },

  selectProcedure: (key) => set({ selectedProcedureKey: key }),

  async loadProcedures(icao) {
    const code = icao.trim().toUpperCase();
    if (code.length === 0) return;
    set({ isLoadingProcedures: true });
    try {
      await MiddlewareHttpService.init();
      const response = await MiddlewareHttpService.getAirportProcedures(code);
      const procedures = parseProcedureList(response.objectBody?.procedures);
      // 换机场就把旧的选中项清掉 —— 留着会指向一条已经不在列表里的程序
      set({ procedures, selectedProcedureKey: null, isLoadingProcedures: false });
    } catch (e) {
      AppLogger.warning(`[Map] load procedures for ${code} failed: ${String(e)}`);
      set({ procedures: [], selectedProcedureKey: null, isLoadingProcedures: false });
    }
  },
  setBeamRunway: (ident) => set((s) => ({
    // 再点一次同一条跑道就收起来
    beamRunwayIdent: s.beamRunwayIdent === ident ? null : ident,
  })),
  toggleGlideslope: () => set((s) => ({ showGlideslope: !s.showGlideslope })),
  toggleCompass: () => set((s) => ({ showCompass: !s.showCompass })),

  toggleWeather() {
    const next = !get().showWeather;
    set({ showWeather: next });
    if (next) {
      void get().refreshWeatherRadarTimestamp(true);
      startRadarInterval(() => void get().refreshWeatherRadarTimestamp());
    } else {
      stopRadarInterval();
    }
  },

  toggleWeatherRainfall: () => set((s) => ({ showWeatherRainfall: !s.showWeatherRainfall })),
  toggleWeatherWind: () => set((s) => ({ showWeatherWind: !s.showWeatherWind })),
  toggleWeatherPressure: () => set((s) => ({ showWeatherPressure: !s.showWeatherPressure })),
  toggleWeatherTemperature: () =>
    set((s) => ({ showWeatherTemperature: !s.showWeatherTemperature })),
  toggleRestrictedAirspace: () =>
    set((s) => ({ showRestrictedAirspace: !s.showRestrictedAirspace })),
  toggleTerrainWarning: () => set((s) => ({ showTerrainWarning: !s.showTerrainWarning })),
  toggleCustomTaxiway: () =>
    set((s) => ({ showCustomTaxiwayRoute: !s.showCustomTaxiwayRoute })),

  setSelectedAirport: (detail) => {
    // 程序是挂在机场上的：换机场或关掉机场，旧机场的程序必须一起清掉，
    // 否则地图上会留着一条孤零零的航线，而面板已经回到「先选一个机场」，
    // 用户从界面上再也找不到取消它的入口。
    set({
      selectedAirport: detail,
      aerowayFeatures: [],
      procedures: [],
      selectedProcedureKey: null,
    });
    if (!detail) return;
    set({ beamRunwayIdent: null, holdings: [] });
    void get().loadAerowayFeatures(detail);
    void get().loadAirportWeather(detail);
    void get().loadRunwayNavaids(detail);
    void get().loadHoldings(detail);
    // 开关开着才拉：程序数据一个机场上百条，没人看的时候不必打这一趟
    if (get().showProcedures) void get().loadProcedures(detail.marker.code);
  },

  async setHomeAirport(airport) {
    set({ homeAirport: airport });
    await PersistenceService.setModuleData(MODULE_NAME, HOME_AIRPORT_KEY, {
      code: airport.code,
      name: airport.name,
      lat: airport.position.latitude,
      lon: airport.position.longitude,
    });
  },

  async clearHomeAirport() {
    set({ homeAirport: null });
    await PersistenceService.removeModuleData(MODULE_NAME, HOME_AIRPORT_KEY);
  },

  // ────────────────────────────────────────────────────────────────────────
  // HUD 计时器
  // ────────────────────────────────────────────────────────────────────────

  toggleHudTimer() {
    if (get().isHudTimerRunning) get().pauseHudTimer();
    else get().startHudTimer();
  },

  startHudTimer() {
    if (get().isHudTimerRunning) return;
    ctx.hudStartedAt = Date.now() - get().hudElapsedMs;
    stopHudInterval();
    ctx.hudTimerHandle = setInterval(() => {
      if (ctx.hudStartedAt === null) return;
      useMapStore.setState({ hudElapsedMs: Date.now() - ctx.hudStartedAt });
    }, 200);
    set({ isHudTimerRunning: true, hasHudTimerStarted: true });
  },

  pauseHudTimer() {
    stopHudInterval();
    set({ isHudTimerRunning: false });
  },

  resetHudTimer() {
    stopHudInterval();
    ctx.hudStartedAt = null;
    set({ hudElapsedMs: 0, isHudTimerRunning: false, hasHudTimerStarted: false });
  },

  async setAutoHudTimerEnabled(value) {
    set({ autoHudTimerEnabled: value });
    await PersistenceService.setModuleData(MODULE_NAME, AUTO_TIMER_ENABLED_KEY, value);
  },

  async setAutoTimerStartMode(mode) {
    set({ autoTimerStartMode: mode });
    await PersistenceService.setModuleData(MODULE_NAME, AUTO_TIMER_START_MODE_KEY, mode);
  },

  async setAutoTimerStopMode(mode) {
    set({ autoTimerStopMode: mode });
    await PersistenceService.setModuleData(MODULE_NAME, AUTO_TIMER_STOP_MODE_KEY, mode);
  },

  // ────────────────────────────────────────────────────────────────────────
  // 告警设置
  // ────────────────────────────────────────────────────────────────────────

  async setAlertsEnabled(value) {
    set({ alertsEnabled: value });
    await PersistenceService.setModuleData(MODULE_NAME, ALERTS_ENABLED_KEY, value);
  },

  async setAlertEnabled(alertId, enabled) {
    const disabled = new Set(get().disabledAlertIds);
    if (enabled) disabled.delete(alertId);
    else disabled.add(alertId);
    const next = [...disabled];
    set({ disabledAlertIds: next });
    await PersistenceService.setModuleData(MODULE_NAME, DISABLED_ALERT_IDS_KEY, next);
  },

  isAlertEnabled(alertId) {
    return !get().disabledAlertIds.includes(alertId);
  },

  async setVerticalRateThresholds(thresholds) {
    const patch: Partial<MapState> = {};
    if (thresholds.climbWarning !== undefined) patch.climbRateWarningFpm = thresholds.climbWarning;
    if (thresholds.climbDanger !== undefined) patch.climbRateDangerFpm = thresholds.climbDanger;
    if (thresholds.descentWarning !== undefined) {
      patch.descentRateWarningFpm = thresholds.descentWarning;
    }
    if (thresholds.descentDanger !== undefined) {
      patch.descentRateDangerFpm = thresholds.descentDanger;
    }
    set(patch);

    const write = (key: string, value: number | undefined) =>
      value === undefined
        ? Promise.resolve()
        : PersistenceService.setModuleData(MODULE_NAME, key, value);

    await Promise.all([
      write(CLIMB_WARNING_KEY, thresholds.climbWarning),
      write(CLIMB_DANGER_KEY, thresholds.climbDanger),
      write(DESCENT_WARNING_KEY, thresholds.descentWarning),
      write(DESCENT_DANGER_KEY, thresholds.descentDanger),
    ]);
  },

  // ────────────────────────────────────────────────────────────────────────
  // 滑行道绘制
  // ────────────────────────────────────────────────────────────────────────

  toggleTaxiwayDrawing() {
    const next = !get().isTaxiwayDrawingActive;
    // 开启绘制时自动显示自定义滑行道图层
    set({ isTaxiwayDrawingActive: next, showCustomTaxiwayRoute: next || get().showCustomTaxiwayRoute });
  },

  addTaxiwayNode(point) {
    const current = currentRoute(get());
    recordUndo(current);
    applyRoute(set, addNode(current, point));
  },

  updateTaxiwayNodePosition(index, point) {
    const current = currentRoute(get());
    const next = moveNode(current, index, point);
    if (!next) return;
    recordUndo(current);
    applyRoute(set, next);
  },

  updateTaxiwayNodeInfo(index, info) {
    const current = currentRoute(get());
    const next = updateNodeInfo(current, index, info);
    if (!next) return;
    recordUndo(current);
    applyRoute(set, next);
  },

  removeTaxiwayNodeAt(index) {
    const current = currentRoute(get());
    const next = removeNode(current, index);
    if (!next) return;
    recordUndo(current);
    applyRoute(set, next);
  },

  insertTaxiwayNodeBetween(segmentIndex, coordinate) {
    const current = currentRoute(get());
    const next = insertNodeBetween(current, segmentIndex, coordinate);
    if (!next) return;
    recordUndo(current);
    applyRoute(set, next);
  },

  updateTaxiwaySegmentInfo(index, info) {
    const current = currentRoute(get());
    const next = updateSegmentInfo(current, index, info);
    if (!next) return;
    recordUndo(current);
    applyRoute(set, next);
  },

  undoTaxiwayRoute() {
    const previous = ctx.undoStack.at(-1);
    if (!previous) return;
    ctx.undoStack = ctx.undoStack.slice(0, -1);
    ctx.redoStack = [...ctx.redoStack, currentRoute(get())];
    set({
      taxiwayNodes: previous.nodes,
      taxiwaySegments: previous.segments,
      hasUnsavedTaxiwayChanges: true,
    });
  },

  redoTaxiwayRoute() {
    const next = ctx.redoStack.at(-1);
    if (!next) return;
    ctx.redoStack = ctx.redoStack.slice(0, -1);
    ctx.undoStack = [...ctx.undoStack, currentRoute(get())];
    set({
      taxiwayNodes: next.nodes,
      taxiwaySegments: next.segments,
      hasUnsavedTaxiwayChanges: true,
    });
  },

  canUndoTaxiwayRoute: () => ctx.undoStack.length > 0,
  canRedoTaxiwayRoute: () => ctx.redoStack.length > 0,

  clearTaxiwayRoute() {
    recordUndo(currentRoute(get()));
    set({
      taxiwayNodes: [],
      taxiwaySegments: [],
      completedTaxiwaySegmentIndexes: [],
      hasUnsavedTaxiwayChanges: false,
      loadedTaxiwayAirportIcao: null,
    });
  },

  exportTaxiwayRoute() {
    const { taxiwayNodes, taxiwaySegments, currentNearestAirportIcao } = get();
    if (taxiwayNodes.length === 0) return -1;

    const payload: MapTaxiwayFileData = {
      icao: currentNearestAirportIcao ?? undefined,
      nodes: taxiwayNodes,
      segments: taxiwaySegments,
    };
    const blob = new Blob([JSON.stringify(payload, null, 2)], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const anchor = document.createElement('a');
    anchor.href = url;
    anchor.download = `taxiway_${currentNearestAirportIcao ?? 'route'}.json`;
    anchor.click();
    URL.revokeObjectURL(url);
    set({ hasUnsavedTaxiwayChanges: false });
    return 1;
  },

  async importTaxiwayRoute(file) {
    try {
      const decoded: unknown = JSON.parse(await file.text());
      const data = parseTaxiwayFile(decoded);
      if (!data || data.nodes.length === 0) return 0;

      recordUndo(currentRoute(get()));
      set({
        taxiwayNodes: data.nodes,
        taxiwaySegments:
          data.segments.length > 0 ? data.segments : rebuildSegments(data.nodes, []),
        loadedTaxiwayAirportIcao: data.icao ?? null,
        showCustomTaxiwayRoute: true,
        hasUnsavedTaxiwayChanges: false,
        completedTaxiwaySegmentIndexes: [],
      });
      return data.nodes.length;
    } catch (e) {
      AppLogger.warning(`[Map] taxiway import failed: ${String(e)}`);
      return 0;
    }
  },

  clearRoute() {
    ctx.lastRoutePoint = null;
    set({ route: [], takeoffPoint: null, landingPoint: null });
  },

  shouldShowReconnectPrompt() {
    const { connectionEpoch, lastReconnectPromptEpoch } = get();
    return connectionEpoch > lastReconnectPromptEpoch && connectionEpoch > 1;
  },

  markReconnectPromptHandled() {
    set({ lastReconnectPromptEpoch: get().connectionEpoch });
  },

  async refreshWeatherRadarTimestamp(force = false) {
    if (!force && !get().showWeather) return;
    try {
      // 走中间件的 /weather/radar/metadata：它代理 RainViewer 并做 5 分钟磁盘缓存，
      // 直连 RainViewer 会因多客户端叠加而触发 429
      await MiddlewareHttpService.init();
      const response = await MiddlewareHttpService.getWeatherRadarMetadata();
      const frames = extractRadarFrames(response.decodedBody);
      const latest = frames[frames.length - 1];
      if (!latest) return;
      set({
        weatherRadarTimestamp: latest.time,
        weatherRadarHost: latest.host,
        weatherRadarPath: latest.path,
      });
    } catch (e) {
      AppLogger.warning(`[Map] radar metadata fetch failed: ${String(e)}`);
    }
  },

  async refreshRestrictedAirspace(bounds) {
    if (!get().showRestrictedAirspace) return;
    try {
      await MiddlewareHttpService.init();
      const response = await MiddlewareHttpService.getRestrictedAirspaceByBounds(bounds);
      const body = response.objectBody;
      const rawZones = Array.isArray(body?.zones) ? body.zones : [];
      set({ restrictedZones: rawZones.map(parseRestrictedZone).filter(isDefined) });
    } catch (e) {
      AppLogger.warning(`[Map] restricted airspace fetch failed: ${String(e)}`);
    }
  },

  async refreshNearbyAirports(bounds, options) {
    if (!get().showAirports) {
      set({ nearbyAirports: [], nearbyOutlines: {} });
      return;
    }
    try {
      await MiddlewareHttpService.init();
      const response = await MiddlewareHttpService.getAirportsByBounds({
        ...bounds,
        limit: NEARBY_AIRPORT_LIMIT,
      });
      const raw = response.objectBody?.airports;
      const list = (Array.isArray(raw) ? raw : []).map(parseNearbyAirport).filter(isDefined);
      set({ nearbyAirports: list });

      if (!options?.withOutlines) {
        // 拉远了就把轮廓丢掉，省得旧数据留在图上
        if (Object.keys(get().nearbyOutlines).length > 0) set({ nearbyOutlines: {} });
        return;
      }
      await loadNearbyOutlines(list, set, get);
    } catch (e) {
      AppLogger.warning(`[Map] nearby airports fetch failed: ${String(e)}`);
    }
  },

  async loadNearbyAeroway(icaos) {
    if (!get().showAeroway || icaos.length === 0) return;

    // 已缓存的先合并上去，屏幕上立刻有东西
    const merge = () => {
      const merged: MapAerowayFeature[] = [];
      for (const icao of icaos) {
        const cached = aerowayCache.get(icao);
        if (cached) merged.push(...cached);
      }
      // 选中机场自己那份也要留着
      const selected = get().selectedAirport?.marker.code;
      if (selected && !icaos.includes(selected)) {
        const own = aerowayCache.get(selected);
        if (own) merged.push(...own);
      }
      set({ aerowayFeatures: merged });
    };
    merge();

    // 并发拉：串行的话第一个机场冷查要等几十秒，后面的全被堵住
    await Promise.all(
      icaos
        .filter((icao) => !aerowayCache.has(icao))
        .map(async (icao) => {
          if (!get().showAeroway) return;
          const features = await fetchAerowayFeatures(icao);
          // 拿到了才刷新；没拿到（还在抓 / 失败）就留给下一次视野变化重试
          if (features) merge();
        }),
    );
  },

  async loadAerowayFeatures(detail) {
    const code = detail.marker.code;
    const cached = aerowayCache.get(code);
    if (cached) {
      set({ aerowayFeatures: cached });
      return;
    }

    set({ isAerowayLoading: true });
    try {
      const features = await fetchAerowayFeatures(code, detail.marker.position);
      if (!features) return;
      // 用户可能在等待期间又换了机场，结果就不该再往上写
      if (get().selectedAirport?.marker.code === code) set({ aerowayFeatures: features });
    } finally {
      set({ isAerowayLoading: false });
    }
  },

  async loadAirportWeather(detail) {
    const code = detail.marker.code;
    try {
      const weather = await fetchAirportWeather(code);
      if (!weather) return;
      const current = get().selectedAirport;
      // 等待期间换了机场就丢弃，别把 A 的天气贴到 B 上
      if (current?.marker.code !== code) return;
      set({ selectedAirport: { ...current, ...weather } });
    } catch (e) {
      AppLogger.warning(`[Map] metar fetch failed for ${code}: ${String(e)}`);
    }
  },

  async loadHoldings(detail) {
    const code = detail.marker.code;
    const cached = holdingCache.get(code);
    if (cached) {
      if (get().selectedAirport?.marker.code === code) set({ holdings: cached });
      return;
    }
    try {
      await MiddlewareHttpService.init();
      const response = await MiddlewareHttpService.getHoldingPatterns(code);
      const raw = response.objectBody?.holdings;
      const list = (Array.isArray(raw) ? raw : [])
        .map(parseHoldingPattern)
        .filter(isDefined);
      holdingCache.set(code, list);
      // 等待期间换了机场就丢弃，别把 A 的等待航线画到 B 上
      if (get().selectedAirport?.marker.code !== code) return;
      set({ holdings: list });
    } catch (e) {
      AppLogger.warning(`[Map] holdings fetch failed for ${code}: ${String(e)}`);
    }
  },

  async loadRunwayNavaids(detail) {
    const code = detail.marker.code;
    const cached = navaidCache.get(code);
    if (cached) {
      const current = get().selectedAirport;
      if (current?.marker.code === code) set({ selectedAirport: { ...current, runwayNavaids: cached } });
      return;
    }
    try {
      await MiddlewareHttpService.init();
      const response = await MiddlewareHttpService.getRunwayNavaids(code);
      const raw = response.objectBody?.navaids;
      const byRunway: Record<string, MapRunwayNavaid> = {};
      for (const item of Array.isArray(raw) ? raw : []) {
        const navaid = parseRunwayNavaid(item);
        if (navaid) byRunway[navaid.runway] = navaid;
      }
      navaidCache.set(code, byRunway);

      // 顺带取公布的进近类型（ILS / GLS / RNAV …），画波束时要按类型分色
      const approaches = await fetchRunwayApproaches(code);

      const current = get().selectedAirport;
      // 等待期间换了机场就丢弃，别把 A 的 ILS 贴到 B 上
      if (current?.marker.code !== code) return;
      set({
        selectedAirport: { ...current, runwayNavaids: byRunway, runwayApproaches: approaches },
      });
    } catch (e) {
      AppLogger.warning(`[Map] runway navaid fetch failed for ${code}: ${String(e)}`);
    }
  },
}));

/** ICAO → 跑道进近设施；导航数据一个会话内不会变 */
const navaidCache = new Map<string, Record<string, MapRunwayNavaid>>();

/** ICAO → 等待航线 */
const holdingCache = new Map<string, MapHoldingPattern[]>();

/** ICAO → 各跑道端公布的进近类型 */
const approachCache = new Map<string, Record<string, readonly string[]>>();

/** 取公布的进近类型；失败返回空表，不影响其余机场信息展示 */
async function fetchRunwayApproaches(
  icao: string,
): Promise<Record<string, readonly string[]>> {
  const cached = approachCache.get(icao);
  if (cached) return cached;
  try {
    const response = await MiddlewareHttpService.getRunwayApproaches(icao);
    const raw = response.objectBody?.approaches;
    const byRunway: Record<string, readonly string[]> = {};
    for (const item of Array.isArray(raw) ? raw : []) {
      const map = toJsonMap(item);
      const runway = pickString(map ?? {}, ['runway'])?.toUpperCase();
      if (!map || !runway) continue;
      const types = Array.isArray(map.types)
        ? map.types.filter((type): type is string => typeof type === 'string')
        : [];
      byRunway[runway] = types;
    }
    approachCache.set(icao, byRunway);
    return byRunway;
  } catch (e) {
    AppLogger.warning(`[Map] approach types fetch failed for ${icao}: ${String(e)}`);
    return {};
  }
}



// ──────────────────────────────────────────────────────────────────────────
// 机场地面要素
// ──────────────────────────────────────────────────────────────────────────

/** ICAO → 地面要素；机场地面结构一个会话内不会变 */
const aerowayCache = new Map<string, MapAerowayFeature[]>();

/**
 * 正在轮询中的机场，避免同一个机场被并发拉多次
 *
 * 后端冷查 Overpass 要几十秒，期间会一直回 status=pending，
 * 视野一动就重复发起的话会堆出一大票并行轮询。
 */
const aerowayPending = new Set<string>();

/** 后端仍在抓取时的轮询间隔与上限（约 2 分钟封顶） */
const AEROWAY_POLL_INTERVAL_MS = 4_000;
const AEROWAY_POLL_MAX_ATTEMPTS = 30;

const sleep = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

/**
 * 取一个机场的地面要素，后端还在抓就轮询等它
 *
 * ⚠️ 这里**不能**把失败结果写进 aerowayCache。之前失败时记了个空数组，
 * 意思是「这机场没有滑行道」，于是同一个机场再也不会重试 ——
 * 加上后端当时同步等 Overpass、前端 10s 就超时，
 * 结果只有事先捂热缓存的 ZBAA 能显示，其他机场全军覆没。
 *
 * @returns 成功返回要素数组；仍未就绪或失败返回 null（留待下次重试）
 */
async function fetchAerowayFeatures(
  icao: string,
  center?: { latitude: number; longitude: number },
): Promise<MapAerowayFeature[] | null> {
  const cached = aerowayCache.get(icao);
  if (cached) return cached;
  if (aerowayPending.has(icao)) return null;

  aerowayPending.add(icao);
  try {
    for (let attempt = 0; attempt < AEROWAY_POLL_MAX_ATTEMPTS; attempt++) {
      await MiddlewareHttpService.init();
      const response = await MiddlewareHttpService.getAirportAeroway(icao, center);
      const body = response.objectBody;

      // 后端刚抓失败、正在冷却，别再连着问了，等下次视野变化再试
      if (body?.status === 'error') {
        AppLogger.warning(`[Map] aeroway upstream cooling down: ${icao}`);
        return null;
      }

      // 后端把任务丢给后台了，等一会儿再问
      if (body?.status === 'pending') {
        await sleep(AEROWAY_POLL_INTERVAL_MS);
        continue;
      }

      const raw = body?.features;
      const features = (Array.isArray(raw) ? raw : [])
        .map(parseAerowayFeature)
        .filter(isDefined);
      // 空结果同样不缓存：正常机场不可能一条跑道都没有
      if (features.length === 0) return null;
      aerowayCache.set(icao, features);
      return features;
    }
    AppLogger.warning(`[Map] aeroway still pending after polling: ${icao}`);
    return null;
  } catch (e) {
    AppLogger.warning(`[Map] aeroway fetch failed for ${icao}: ${String(e)}`);
    return null;
  } finally {
    aerowayPending.delete(icao);
  }
}



// ──────────────────────────────────────────────────────────────────────────
// 视野内机场
// ──────────────────────────────────────────────────────────────────────────

/** 一次最多取多少个机场；密集区域（如欧洲）不加限制会一屏几百个 */
const NEARBY_AIRPORT_LIMIT = 60;

/** 一轮最多补多少个轮廓：每个都要拉一次机场明细，不能敞开来 */
const NEARBY_OUTLINE_BUDGET = 8;

/**
 * ICAO → 轮廓缓存
 *
 * 机场跑道和停机位是静态数据，一次会话内不会变，
 * 平移地图来回扫同一片区域时没必要反复拉明细。
 * 存 null 表示「拉过了但算不出轮廓」，避免对着同一个机场重试。
 */
const outlineCache = new Map<string, MapCoordinate[] | null>();

async function loadNearbyOutlines(
  airports: MapAirportMarker[],
  set: (patch: Partial<MapState>) => void,
  get: () => MapState,
): Promise<void> {
  const pending = airports.filter((airport) => !outlineCache.has(airport.code));
  // 已缓存的先铺上，避免等网络回来之前图上一片空白
  applyOutlines(airports, set);
  if (pending.length === 0) return;

  for (const airport of pending.slice(0, NEARBY_OUTLINE_BUDGET)) {
    try {
      const response = await MiddlewareHttpService.getAirportByIcao(airport.code);
      const body = response.objectBody;
      const detail = body ? parseAirportDetail(body, airport.code) : null;
      outlineCache.set(airport.code, detail ? computeAirportOutline(detail) : null);
    } catch {
      // 单个机场拉不到不影响其它的，标记成「算不出」跳过
      outlineCache.set(airport.code, null);
    }
    // 视野已经变了就别再往下补，结果也用不上了
    if (get().nearbyAirports !== airports) return;
  }
  applyOutlines(airports, set);
}

function applyOutlines(
  airports: MapAirportMarker[],
  set: (patch: Partial<MapState>) => void,
): void {
  const outlines: Record<string, MapCoordinate[]> = {};
  for (const airport of airports) {
    const cached = outlineCache.get(airport.code);
    if (cached) outlines[airport.code] = cached;
  }
  set({ nearbyOutlines: outlines });
}


// ──────────────────────────────────────────────────────────────────────────
// 天气瓦片地址（经中间件代理，与桌面版路径一致）
// ──────────────────────────────────────────────────────────────────────────

export function weatherRadarTileUrl(host: string | null, path: string | null): string | null {
  if (!host || !path) return null;
  const base = MiddlewareHttpService.baseUrl;
  return `${base}/api/v1/weather/radar/tile?host=${encodeURIComponent(host)}&path=${encodeURIComponent(path)}&z={z}&x={x}&y={y}`;
}

export function weatherOverlayTileUrl(layer: 'rain' | 'pressure' | 'wind' | 'temp'): string {
  return `${MiddlewareHttpService.baseUrl}/api/v1/weather/overlay/tile?layer=${layer}&z={z}&x={x}&y={y}`;
}

// ──────────────────────────────────────────────────────────────────────────
// 内部工具
// ──────────────────────────────────────────────────────────────────────────

function isLayerStyle(value: unknown): value is MapLayerStyle {
  return value === 'dark' || value === 'satellite' || value === 'terrain' || value === 'taxiway';
}







/**
 * 上报新出现的地形告警
 *
 * 只在告警「从无到有」的那一帧上报，避免持续告警期间每帧刷接口。
 */
function reportNewTerrainWarnings(
  previous: MapFlightAlert[],
  next: MapFlightAlert[],
  flightData: FlightData,
): void {
  const previousIds = new Set(previous.map((alert) => alert.id));
  const fresh = next.filter(
    (alert) => alert.id === 'terrain_warning' && !previousIds.has(alert.id),
  );
  if (fresh.length === 0) return;

  const { latitude, longitude, radioAltitude, verticalSpeed } = flightData;
  if (latitude === undefined || longitude === undefined) return;

  for (const alert of fresh) {
    void MiddlewareHttpService.reportTerrainWarning({
      alertId: alert.id,
      alertLevel: alert.level,
      radioAltitudeFt: radioAltitude ?? 0,
      verticalSpeedFpm: verticalSpeed ?? 0,
      latitude,
      longitude,
    }).catch((e: unknown) => {
      AppLogger.warning(`[Map] terrain warning report failed: ${String(e)}`);
    });
  }
}

function stopHudInterval(): void {
  if (ctx.hudTimerHandle !== null) {
    clearInterval(ctx.hudTimerHandle);
    ctx.hudTimerHandle = null;
  }
}

function startRadarInterval(callback: () => void): void {
  stopRadarInterval();
  ctx.radarTimerHandle = setInterval(callback, RADAR_REFRESH_INTERVAL_MS);
}

function stopRadarInterval(): void {
  if (ctx.radarTimerHandle !== null) {
    clearInterval(ctx.radarTimerHandle);
    ctx.radarTimerHandle = null;
  }
}








