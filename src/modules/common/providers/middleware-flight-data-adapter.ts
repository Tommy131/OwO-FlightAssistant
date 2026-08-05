import { NavigationCommandBus } from '../../../core/module-registry/navigation/navigation-registry';
import { PersistenceService } from '../../../core/services/persistence-service';
import { AppLogger } from '../../../core/utils/logger';
import {
  calculateDistanceNm,
  pickDouble,
  pickMap,
  pickString,
  readAngleDegrees,
  toBool,
  toDouble,
  toInt,
  toJsonMap,
  type JsonMap,
} from '../../../core/utils/parse-utils';
import {
  extractErrorMessage,
  isConnectionLostError,
} from '../../http/models/http-models';
import { MiddlewareHttpService } from '../../http/services/middleware-http-service';
import {
  emptyFlightData,
  type AIAircraftState,
  type AirportInfo,
  type FlightAlert,
  type FlightData,
  type FlightDataSnapshot,
  type LiveMetarData,
  type SimulatorType,
} from '../models/common-models';

/**
 * Middleware 后端飞行数据适配器
 *
 * 对应 Flutter 版 `modules/common/providers/middleware_flight_data_adapter.dart`（1211 行）。
 *
 * 主要职责：
 *   - WebSocket 连接管理（失败自动回退到 HTTP 轮询）
 *   - 后端健康监控与掉线处理（2s 探测 + 10s 宽限期）
 *   - METAR 气象数据刷新（15 分钟有效期 + 2 分钟防抖）
 *   - 油量充足性计算（Haversine 大圆距离）
 *
 * Dart 的 `Stream<FlightDataSnapshot>` 在这里换成轻量的订阅者集合。
 */

const BACKEND_MONITOR_INTERVAL_MS = 2_000;
const BACKEND_DISCONNECT_GRACE_PERIOD_MS = 10_000;
const POLL_INTERVAL_MS_KEY = 'middleware_flight_data_interval_ms';

export const DEFAULT_POLL_INTERVAL_MS = 300;
export const MIN_POLL_INTERVAL_MS = 100;
export const MAX_POLL_INTERVAL_MS = 2000;

/** METAR 自动刷新策略 */
const METAR_VALID_DURATION_MS = 15 * 60 * 1000;
const METAR_AUTO_FETCH_DEBOUNCE_MS = 2 * 60 * 1000;

export type SnapshotListener = (snapshot: FlightDataSnapshot) => void;

/** 飞行数据适配器接口（对应 flight_data_adapter.dart） */
export interface FlightDataAdapter {
  subscribe(listener: SnapshotListener): () => void;
  connect(type: SimulatorType): Promise<boolean>;
  disconnect(): Promise<void>;
  refreshBackendHealth(): Promise<boolean>;
  getFlightDataIntervalMs(): Promise<number>;
  setFlightDataIntervalMs(milliseconds: number): Promise<void>;
  setFlightNumber(value: string | null): Promise<void>;
  setDeparture(airport: AirportInfo | null): Promise<void>;
  setDestination(airport: AirportInfo | null): Promise<void>;
  setAlternate(airport: AirportInfo | null): Promise<void>;
  searchAirports(keyword: string): Promise<AirportInfo[]>;
  refreshMetar(airport: AirportInfo): Promise<void>;
  dispose(): void;
}

export class MiddlewareFlightDataAdapter implements FlightDataAdapter {
  private listeners = new Set<SnapshotListener>();
  private pollIntervalMs = DEFAULT_POLL_INTERVAL_MS;

  private pollTimer: ReturnType<typeof setInterval> | null = null;
  private ws: WebSocket | null = null;
  private token: string | null = null;
  private simulatorType: SimulatorType = 'none';
  private isConnected = false;
  private errorMessage?: string;
  private aircraftTitle?: string;
  private isPaused?: boolean;
  private transponderState?: string;
  private transponderCode?: string;
  private flightNumber?: string;
  private isFuelSufficient?: boolean;
  private flightData: FlightData = emptyFlightData();
  private departureAirport?: AirportInfo;
  private destinationAirport?: AirportInfo;
  private alternateAirport?: AirportInfo;
  private nearestAirport?: AirportInfo;
  private suggestedAirports: AirportInfo[] = [];
  private metarsByIcao: Record<string, LiveMetarData> = {};
  private metarErrorsByIcao: Record<string, string> = {};
  private metarRefreshingIcaos = new Set<string>();
  private metarLastAutoFetchAt = new Map<string, number>();

  private disposed = false;
  private polling = false;
  private backendReachable = false;
  private checkingBackendHealthTask: Promise<boolean> | null = null;
  private backendHealthMonitorTimer: ReturnType<typeof setInterval> | null = null;
  private monitorChecking = false;
  private backendDisconnectHandled = false;
  private lastBackendReachableAt: number | null = null;
  private backendOutageVersion = 0;

  // ──────────────────────────────────────────────────────────────────────────
  // 订阅
  // ──────────────────────────────────────────────────────────────────────────

  subscribe(listener: SnapshotListener): () => void {
    this.listeners.add(listener);
    // 立即推送当前状态，等价于 Flutter 的 BehaviorSubject 语义
    listener(this.buildSnapshot());
    return () => this.listeners.delete(listener);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 连接管理
  // ──────────────────────────────────────────────────────────────────────────

  async connect(type: SimulatorType): Promise<boolean> {
    await MiddlewareHttpService.init();
    await this.loadPollIntervalFromStorage();
    this.errorMessage = undefined;

    if (type === 'none') {
      this.errorMessage = 'invalid_simulator_type';
      this.emitSnapshot();
      return false;
    }

    try {
      if (this.token && this.token.length > 0) {
        AppLogger.info('Disconnecting existing session before new connection');
        await this.disconnect();
      }

      AppLogger.info(`Connecting to simulator: ${type}`);
      const response = await MiddlewareHttpService.connectSimulator({ type });
      const body = response.objectBody;
      if (!body) {
        this.errorMessage = 'invalid_connect_response';
        this.emitSnapshot();
        return false;
      }
      const token = String(body.token ?? '').trim();
      if (token.length === 0) {
        this.errorMessage = 'missing_token';
        this.emitSnapshot();
        return false;
      }

      this.token = token;
      this.simulatorType = type;
      this.isConnected = true;
      await this.startRealtimeUpdates(token);
      await this.pollData();
      this.emitSnapshot();
      return true;
    } catch (e) {
      this.errorMessage = extractErrorMessage(e);
      this.isConnected = false;
      this.simulatorType = 'none';
      this.token = null;
      this.stopPolling();
      AppLogger.error('FlightData simulator connect failed', e);
      this.emitSnapshot();
      return false;
    }
  }

  async disconnect(): Promise<void> {
    const token = this.token;
    this.token = null;
    this.closeWebSocket();
    this.stopPolling();
    if (token && token.length > 0) {
      try {
        await MiddlewareHttpService.disconnectSimulator(token);
      } catch {
        /* 断开失败不阻塞本地状态清理 */
      }
    }
    this.isConnected = false;
    this.simulatorType = 'none';
    this.aircraftTitle = undefined;
    this.isPaused = undefined;
    this.transponderState = undefined;
    this.transponderCode = undefined;
    this.errorMessage = undefined;
    this.flightData = emptyFlightData();
    this.metarRefreshingIcaos.clear();
    this.metarLastAutoFetchAt.clear();
    this.stopBackendHealthMonitor();
    this.backendDisconnectHandled = false;
    this.lastBackendReachableAt = null;
    this.emitSnapshot();
  }

  dispose(): void {
    this.disposed = true;
    this.stopBackendHealthMonitor();
    this.closeWebSocket();
    this.stopPolling();
    this.listeners.clear();
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 航班号与机场
  // ──────────────────────────────────────────────────────────────────────────

  async setFlightNumber(value: string | null): Promise<void> {
    const trimmed = value?.trim() ?? '';
    this.flightNumber = trimmed.length === 0 ? undefined : trimmed;
    this.emitSnapshot();
  }

  async setDeparture(airport: AirportInfo | null): Promise<void> {
    if (!airport) {
      this.departureAirport = undefined;
      this.emitSnapshot();
      return;
    }
    const target = this.withBestCoordinates(await this.resolveAirportTarget(airport));
    this.departureAirport = target;
    this.addToSuggestions(target);
    await this.refreshMetar(target);
    this.emitSnapshot();
  }

  async setDestination(airport: AirportInfo | null): Promise<void> {
    if (!airport) {
      this.destinationAirport = undefined;
      this.updateFuelSufficiency();
      this.emitSnapshot();
      return;
    }
    const target = this.withBestCoordinates(await this.resolveAirportTarget(airport));
    this.destinationAirport = target;
    this.addToSuggestions(target);
    await this.refreshMetar(target);
    this.updateFuelSufficiency();
    this.emitSnapshot();
  }

  async setAlternate(airport: AirportInfo | null): Promise<void> {
    if (!airport) {
      this.alternateAirport = undefined;
      this.updateFuelSufficiency();
      this.emitSnapshot();
      return;
    }
    const target = this.withBestCoordinates(await this.resolveAirportTarget(airport));
    this.alternateAirport = target;
    this.addToSuggestions(target);
    await this.refreshMetar(target);
    this.updateFuelSufficiency();
    this.emitSnapshot();
  }

  async searchAirports(keyword: string): Promise<AirportInfo[]> {
    const trimmed = keyword.trim();
    if (trimmed.length === 0) return [];
    try {
      await MiddlewareHttpService.init();
      const response = await MiddlewareHttpService.getAirportSuggestions(trimmed);
      const body = response.objectBody;
      const suggestions = body?.suggestions;
      if (!Array.isArray(suggestions)) return [];
      return suggestions
        .map((item) => toJsonMap(item))
        .filter((item): item is JsonMap => item !== null)
        .map((item) => airportFromSuggestion(item));
    } catch {
      return [];
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // METAR
  // ──────────────────────────────────────────────────────────────────────────

  async refreshMetar(airport: AirportInfo): Promise<void> {
    const icao = airport.icaoCode.trim().toUpperCase();
    if (icao.length === 0) return;
    if (this.metarRefreshingIcaos.has(icao)) return;

    this.metarRefreshingIcaos.add(icao);
    this.emitSnapshot();
    try {
      await MiddlewareHttpService.init();
      const response = await MiddlewareHttpService.getMetarByIcao(icao);
      const body = response.objectBody;
      if (!body) {
        this.metarErrorsByIcao = { ...this.metarErrorsByIcao, [icao]: 'invalid_metar_response' };
        this.emitSnapshot();
        return;
      }
      const raw = String(body.raw_metar ?? '').trim();
      const translated = String(body.translated_metar ?? '').trim();
      const metarTimestamp =
        toInt(body.metar_timestamp_unix) ??
        toInt(body.timestamp) ??
        Math.floor(Date.now() / 1000);

      this.metarsByIcao = {
        ...this.metarsByIcao,
        [icao]: {
          raw: raw.length === 0 ? translated : raw,
          timestamp: new Date(metarTimestamp * 1000),
          displayWind: pickString(body, ['display_wind', 'wind']) ?? '--',
          displayVisibility: pickString(body, ['display_visibility', 'visibility']) ?? '--',
          displayTemperature:
            pickString(body, ['display_temperature', 'temperature']) ?? '--',
          displayAltimeter: pickString(body, ['display_altimeter', 'altimeter']) ?? '--',
        },
      };
      const { [icao]: _removed, ...restErrors } = this.metarErrorsByIcao;
      this.metarErrorsByIcao = restErrors;
      this.emitSnapshot();
    } catch (e) {
      this.metarErrorsByIcao = { ...this.metarErrorsByIcao, [icao]: extractErrorMessage(e) };
      this.emitSnapshot();
    } finally {
      this.metarRefreshingIcaos.delete(icao);
      this.emitSnapshot();
    }
  }

  /** 按需自动刷新最近机场 METAR（15 分钟有效期，2 分钟防抖） */
  private ensureCurrentAirportMetar(): void {
    if (!this.isConnected) return;
    const airport = this.nearestAirport;
    if (!airport) return;
    const icao = airport.icaoCode.trim().toUpperCase();
    if (icao.length === 0) return;
    if (this.metarRefreshingIcaos.has(icao)) return;

    const now = Date.now();
    const metar = this.metarsByIcao[icao];
    if (metar && now - metar.timestamp.getTime() <= METAR_VALID_DURATION_MS) return;

    const lastAutoFetch = this.metarLastAutoFetchAt.get(icao);
    if (lastAutoFetch !== undefined && now - lastAutoFetch <= METAR_AUTO_FETCH_DEBOUNCE_MS) {
      return;
    }
    this.metarLastAutoFetchAt.set(icao, now);
    void this.refreshMetar(airport);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 后端健康监控
  // ──────────────────────────────────────────────────────────────────────────

  refreshBackendHealth(): Promise<boolean> {
    return this.checkBackendHealth();
  }

  private checkBackendHealth(): Promise<boolean> {
    if (this.disposed) return Promise.resolve(false);
    if (this.checkingBackendHealthTask) return this.checkingBackendHealthTask;
    const task = this.performBackendHealthCheck().finally(() => {
      if (this.checkingBackendHealthTask === task) this.checkingBackendHealthTask = null;
    });
    this.checkingBackendHealthTask = task;
    return task;
  }

  private async performBackendHealthCheck(): Promise<boolean> {
    try {
      await MiddlewareHttpService.init();
      await MiddlewareHttpService.getHealth();
      this.updateBackendHealth(true);
      return true;
    } catch (e) {
      AppLogger.warning(`Backend health check failed: ${extractErrorMessage(e)}`);
      this.updateBackendHealth(false);
      return false;
    }
  }

  private updateBackendHealth(reachable: boolean): void {
    if (reachable) {
      this.lastBackendReachableAt = Date.now();
      this.backendDisconnectHandled = false;
      if (this.backendHealthMonitorTimer === null) this.startBackendHealthMonitor();
    }
    if (this.backendReachable === reachable) return;
    this.backendReachable = reachable;
    this.emitSnapshot();
  }

  private startBackendHealthMonitor(): void {
    this.stopBackendHealthMonitor();
    this.backendHealthMonitorTimer = setInterval(() => {
      void this.monitorBackendHealth();
    }, BACKEND_MONITOR_INTERVAL_MS);
  }

  private stopBackendHealthMonitor(): void {
    if (this.backendHealthMonitorTimer !== null) {
      clearInterval(this.backendHealthMonitorTimer);
      this.backendHealthMonitorTimer = null;
    }
    this.monitorChecking = false;
  }

  private async monitorBackendHealth(): Promise<void> {
    if (this.disposed || this.backendDisconnectHandled || this.monitorChecking) return;
    if (this.lastBackendReachableAt === null) return;

    this.monitorChecking = true;
    try {
      const reachable = await this.performBackendHealthCheck();
      if (reachable) return;
      const lastReachableAt = this.lastBackendReachableAt;
      if (lastReachableAt === null) return;
      if (Date.now() - lastReachableAt < BACKEND_DISCONNECT_GRACE_PERIOD_MS) return;

      // 持续掉线超过宽限期：标记中断并把用户拉回首页
      this.backendDisconnectHandled = true;
      this.stopBackendHealthMonitor();
      this.backendOutageVersion += 1;
      this.emitSnapshot();
      NavigationCommandBus.goTo('home');
    } finally {
      this.monitorChecking = false;
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 轮询间隔
  // ──────────────────────────────────────────────────────────────────────────

  async getFlightDataIntervalMs(): Promise<number> {
    await this.loadPollIntervalFromStorage();
    return this.pollIntervalMs;
  }

  async setFlightDataIntervalMs(milliseconds: number): Promise<void> {
    const next = sanitizePollIntervalMs(milliseconds);
    this.pollIntervalMs = next;
    await PersistenceService.ensureReady();
    await PersistenceService.setInt(POLL_INTERVAL_MS_KEY, next);
    if (this.pollTimer !== null) this.startPolling();
  }

  private async loadPollIntervalFromStorage(): Promise<void> {
    await PersistenceService.ensureReady();
    const stored = PersistenceService.getInt(POLL_INTERVAL_MS_KEY);
    this.pollIntervalMs = sanitizePollIntervalMs(stored ?? this.pollIntervalMs);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // WebSocket 与轮询
  // ──────────────────────────────────────────────────────────────────────────

  private async startRealtimeUpdates(token: string): Promise<void> {
    const connected = await this.connectWebSocket(token);
    // WS 建立失败时回退到 HTTP 轮询，最快 1s 一次
    if (!connected) this.startPolling(1000);
  }

  private async connectWebSocket(token: string): Promise<boolean> {
    try {
      const wsUri = await MiddlewareHttpService.resolveSimulatorWebSocketUri(token);
      AppLogger.info(`Connecting to WebSocket: ${wsUri}`);
      this.closeWebSocket();

      const socket = new WebSocket(wsUri);
      this.ws = socket;

      // 等待握手完成（成功 → true，失败/超时 → false 并回退轮询）
      const opened = await new Promise<boolean>((resolve) => {
        const timer = setTimeout(() => resolve(false), 5000);
        socket.addEventListener(
          'open',
          () => {
            clearTimeout(timer);
            resolve(true);
          },
          { once: true },
        );
        socket.addEventListener(
          'error',
          () => {
            clearTimeout(timer);
            resolve(false);
          },
          { once: true },
        );
      });

      if (!opened) {
        AppLogger.warning('WebSocket handshake failed, falling back to polling');
        this.closeWebSocket();
        return false;
      }

      socket.addEventListener('message', (event) => this.handleWebSocketEvent(event.data));
      socket.addEventListener('error', () => {
        AppLogger.error('WebSocket stream error');
        this.handleWebSocketClosed();
      });
      socket.addEventListener('close', () => {
        AppLogger.info('WebSocket connection closed by server');
        this.handleWebSocketClosed();
      });

      AppLogger.info('WebSocket connection established');
      return true;
    } catch (e) {
      AppLogger.error('FlightData websocket connect failed', e);
      return false;
    }
  }

  private handleWebSocketEvent(data: unknown): void {
    if (typeof data !== 'string') return;
    try {
      const payload = toJsonMap(JSON.parse(data));
      if (!payload) return;
      if (payload.error !== null && payload.error !== undefined) {
        this.errorMessage = String(payload.error);
        this.emitSnapshot();
        return;
      }
      this.applySimulatorResponseBody(payload);
    } catch {
      /* 非法帧直接丢弃 */
    }
  }

  private handleWebSocketClosed(): void {
    if (this.token && this.token.length > 0 && !this.disposed) {
      this.startPolling(1000);
    }
  }

  private closeWebSocket(): void {
    const socket = this.ws;
    this.ws = null;
    if (!socket) return;
    try {
      // 先摘掉监听器，避免主动关闭触发回退轮询
      socket.onclose = null;
      socket.onerror = null;
      socket.close();
    } catch {
      /* 忽略关闭异常 */
    }
  }

  private startPolling(minIntervalMs?: number): void {
    this.stopPolling();
    const intervalMs =
      minIntervalMs === undefined
        ? this.pollIntervalMs
        : Math.max(this.pollIntervalMs, minIntervalMs);
    this.pollTimer = setInterval(() => void this.pollData(), intervalMs);
  }

  private stopPolling(): void {
    if (this.pollTimer !== null) {
      clearInterval(this.pollTimer);
      this.pollTimer = null;
    }
  }

  private async pollData(): Promise<void> {
    if (this.polling) return;
    const token = this.token;
    if (!token || token.length === 0) return;

    this.polling = true;
    try {
      const response = await MiddlewareHttpService.getSimulatorData(token);
      const body = response.objectBody;
      if (!body) return;
      this.applySimulatorResponseBody(body);
    } catch (e) {
      this.errorMessage = extractErrorMessage(e);
      if (isConnectionLostError(e)) {
        this.isConnected = false;
        this.simulatorType = 'none';
        this.token = null;
        this.stopPolling();
      }
      AppLogger.error('FlightData simulator polling failed', e);
      this.emitSnapshot();
    } finally {
      this.polling = false;
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 数据解析
  // ──────────────────────────────────────────────────────────────────────────

  private applySimulatorResponseBody(body: JsonMap): void {
    const clientMap = toJsonMap(body.client_dataset);
    const rawMap = toJsonMap(body.raw_dataset);
    if (!clientMap && !rawMap) return;

    // client_dataset 覆盖 raw_dataset（与桌面版展开顺序一致）
    const dataset: JsonMap = { ...(rawMap ?? {}), ...(clientMap ?? {}) };

    this.errorMessage = undefined;
    this.isConnected = toBool(dataset.connected) ?? true;
    this.isPaused = toBool(dataset.is_paused);
    this.transponderState = pickString(dataset, ['transponder_state']);
    this.transponderCode = pickString(dataset, ['transponder_code']);
    this.aircraftTitle =
      asText(dataset.aircraft_display_name) ??
      asText(dataset.aircraft_model) ??
      asText(dataset.aircraft_profile) ??
      asText(body.simulator_version) ??
      this.aircraftTitle;

    this.flightData = flightDataFromDataset(dataset);
    this.updateFuelSufficiency();

    const nearest = toJsonMap(dataset.nearest_airport);
    if (nearest) {
      const airport = airportFromNearestAirport(nearest);
      if (airport) {
        this.nearestAirport = airport;
        this.addToSuggestions(airport);
      }
    }

    this.ensureCurrentAirportMetar();
    this.emitSnapshot();
  }

  private addToSuggestions(airport: AirportInfo): void {
    const next: AirportInfo[] = [airport];
    for (const item of this.suggestedAirports) {
      if (item.icaoCode.toUpperCase() === airport.icaoCode.toUpperCase()) continue;
      next.push(item);
      if (next.length >= 8) break;
    }
    this.suggestedAirports = next;
  }

  /** 用 ICAO 向后端换取完整机场信息（含坐标） */
  private async resolveAirportTarget(airport: AirportInfo): Promise<AirportInfo> {
    const normalizedIcao = airport.icaoCode.trim().toUpperCase();
    if (normalizedIcao.length === 0) return airport;
    try {
      await MiddlewareHttpService.init();
      const response = await MiddlewareHttpService.getAirportByIcao(normalizedIcao);
      const root = response.objectBody;
      if (!root) return airport;

      // 后端返回结构在不同版本间有嵌套差异，逐层向下探测
      const payload = pickMap(root, ['data']) ?? root;
      const detail = pickMap(payload, ['airport_detail', 'airportDetail']) ?? payload;
      const airportMap = pickMap(detail, ['airport']) ?? detail;

      return {
        icaoCode: pickString(airportMap, ['icao', 'ICAO'])?.toUpperCase() ?? normalizedIcao,
        iataCode: pickString(airportMap, ['iata', 'IATA']) ?? '',
        name:
          pickString(airportMap, ['name', 'Name']) ??
          pickString(detail, ['name', 'Name']) ??
          airport.name,
        nameChinese: airport.nameChinese,
        latitude:
          pickDouble(airportMap, ['latitude', 'lat', 'Lat']) ??
          pickDouble(detail, ['latitude', 'lat', 'Lat']) ??
          pickDouble(payload, ['latitude', 'lat', 'Lat']) ??
          airport.latitude,
        longitude:
          pickDouble(airportMap, ['longitude', 'lon', 'lng', 'Lon']) ??
          pickDouble(detail, ['longitude', 'lon', 'lng', 'Lng', 'Lon']) ??
          pickDouble(payload, ['longitude', 'lon', 'lng', 'Lng', 'Lon']) ??
          airport.longitude,
      };
    } catch {
      return airport;
    }
  }

  /** 坐标为 (0,0) 时从已知机场中补齐 */
  private withBestCoordinates(airport: AirportInfo): AirportInfo {
    if (airport.latitude !== 0 && airport.longitude !== 0) return airport;
    const code = airport.icaoCode.trim().toUpperCase();
    if (code.length === 0) return airport;

    const candidates: (AirportInfo | undefined)[] = [
      this.nearestAirport,
      this.departureAirport,
      this.destinationAirport,
      this.alternateAirport,
      ...this.suggestedAirports,
    ];
    for (const item of candidates) {
      if (!item) continue;
      if (item.icaoCode.trim().toUpperCase() !== code) continue;
      if (item.latitude === 0 || item.longitude === 0) continue;
      return { ...airport, latitude: item.latitude, longitude: item.longitude };
    }
    return airport;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 油量充足性
  // ──────────────────────────────────────────────────────────────────────────

  private updateFuelSufficiency(): void {
    const fuelQuantity = this.flightData.fuelQuantity;
    const destination = this.destinationAirport
      ? this.withBestCoordinates(this.destinationAirport)
      : undefined;

    if (fuelQuantity === undefined || !destination) {
      this.isFuelSufficient = undefined;
      return;
    }
    const { latitude, longitude } = this.flightData;
    if (
      latitude === undefined ||
      longitude === undefined ||
      destination.latitude === 0 ||
      destination.longitude === 0
    ) {
      this.isFuelSufficient = undefined;
      return;
    }

    const distanceNm = calculateDistanceNm(
      latitude,
      longitude,
      destination.latitude,
      destination.longitude,
    );
    const required = buildFuelPlanTotal(distanceNm, this.alternateAirport !== undefined);
    this.isFuelSufficient = fuelQuantity >= required;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 快照推送
  // ──────────────────────────────────────────────────────────────────────────

  private buildSnapshot(): FlightDataSnapshot {
    return {
      isConnected: this.isConnected,
      isBackendReachable: this.backendReachable,
      backendOutageVersion: this.backendOutageVersion,
      simulatorType: this.simulatorType,
      errorMessage: this.errorMessage,
      aircraftTitle: this.aircraftTitle,
      isPaused: this.isPaused,
      transponderState: this.transponderState,
      transponderCode: this.transponderCode,
      flightNumber: this.flightNumber,
      isFuelSufficient: this.isFuelSufficient,
      flightData: this.flightData,
      departureAirport: this.departureAirport,
      destinationAirport: this.destinationAirport,
      alternateAirport: this.alternateAirport,
      nearestAirport: this.nearestAirport,
      suggestedAirports: this.suggestedAirports,
      metarsByIcao: this.metarsByIcao,
      metarErrorsByIcao: this.metarErrorsByIcao,
      metarRefreshingIcaos: new Set(this.metarRefreshingIcaos),
    };
  }

  private emitSnapshot(): void {
    if (this.disposed) return;
    const snapshot = this.buildSnapshot();
    for (const listener of this.listeners) {
      try {
        listener(snapshot);
      } catch (e) {
        AppLogger.warning(`[FlightDataAdapter] listener failed: ${String(e)}`);
      }
    }
  }
}

// ──────────────────────────────────────────────────────────────────────────
// 纯函数：数据集 → FlightData
// ──────────────────────────────────────────────────────────────────────────

/** 从中间件数据集构建 FlightData（96 字段，键名与桌面版逐一对齐） */
export function flightDataFromDataset(dataset: JsonMap): FlightData {
  const noseGearDown = toDouble(dataset.nose_gear_down);
  const leftGearDown = toDouble(dataset.left_gear_down);
  const rightGearDown = toDouble(dataset.right_gear_down);

  return {
    airspeed: toDouble(dataset.ias_kt ?? dataset.airspeed_kt),
    machNumber: toDouble(dataset.mach_number),
    trueAirspeed: toDouble(dataset.tas_kt ?? dataset.true_airspeed_kt),
    altitude: toDouble(dataset.altitude_ft),
    heading: toDouble(dataset.heading_deg),
    verticalSpeed: toDouble(dataset.vertical_speed_fpm ?? dataset.vs_fpm),
    gForce: toDouble(dataset.g_force_g ?? dataset.g_force),
    touchdownGearG: toDouble(dataset.touchdown_gear_g),
    noseGearG: toDouble(dataset.nose_gear_g),
    leftGearG: toDouble(dataset.left_gear_g),
    rightGearG: toDouble(dataset.right_gear_g),
    pitch: readAngleDegrees(dataset, ['pitch_deg'], ['pitch']),
    bank: readAngleDegrees(dataset, ['bank_deg', 'roll_deg'], ['bank', 'roll']),
    angleOfAttack: readAngleDegrees(
      dataset,
      ['aoa_deg', 'angle_of_attack_deg', 'alpha_deg', 'angleofattack_deg'],
      ['aoa', 'angle_of_attack', 'alpha', 'angleofattack'],
    ),
    stallWarning: toBool(
      dataset.stall_warning ?? dataset.is_stalling ?? dataset.stall_warning_active,
    ),
    latitude: toDouble(dataset.latitude),
    longitude: toDouble(dataset.longitude),
    departureAirport: pickString(dataset, [
      'departure_airport',
      'departure_airport_icao',
      'origin_airport',
    ]),
    arrivalAirport: pickString(dataset, [
      'arrival_airport',
      'arrival_airport_icao',
      'destination_airport',
    ]),
    groundSpeed: toDouble(dataset.ground_speed_kt),
    com1Frequency: toDouble(dataset.com1_frequency_mhz),
    outsideAirTemperature: toDouble(dataset.outside_temp_c),
    totalAirTemperature: toDouble(dataset.total_temp_c),
    windSpeed: toDouble(dataset.wind_speed_kt),
    windDirection: toDouble(dataset.wind_direction_deg),
    windGust: toDouble(dataset.wind_gust_kt),
    gustDelta: toDouble(dataset.gust_delta_kt),
    gustFactorRate: toDouble(dataset.gust_factor_rate),
    crosswindComponent: toDouble(dataset.crosswind_component_kt),
    radioAltitude: toDouble(dataset.radio_altitude_ft),
    baroPressure: toDouble(dataset.baro_pressure_inhg),
    baroPressureUnit: asText(dataset.baro_pressure_unit),
    visibility: toDouble(dataset.visibility_m),
    numEngines: toInt(dataset.num_engines),
    fuelQuantity: toDouble(dataset.fuel_quantity_kg),
    fuelFlow: toDouble(dataset.fuel_flow_kg_h),
    engine1N1: toDouble(dataset.engine1_n1),
    engine2N1: toDouble(dataset.engine2_n1),
    engine1N2: toDouble(dataset.engine1_n2),
    engine2N2: toDouble(dataset.engine2_n2),
    engine1EGT: toDouble(dataset.engine1_egt_c),
    engine2EGT: toDouble(dataset.engine2_egt_c),
    aileronInput: toDouble(dataset.aileron_input),
    elevatorInput: toDouble(dataset.elevator_input),
    rudderInput: toDouble(dataset.rudder_input),
    aileronTrim: toDouble(dataset.aileron_trim),
    elevatorTrim: toDouble(dataset.elevator_trim),
    rudderTrim: toDouble(dataset.rudder_trim),
    masterWarning: toBool(dataset.master_warning),
    masterCaution: toBool(dataset.master_caution),
    fireWarningEngine1: toBool(dataset.fire_warning_engine1),
    fireWarningEngine2: toBool(dataset.fire_warning_engine2),
    fireWarningAPU: toBool(dataset.fire_warning_apu),
    beacon: toBool(dataset.beacon),
    strobes: toBool(dataset.strobes),
    navLights: toBool(dataset.nav_lights),
    logoLights: toBool(dataset.logo_lights),
    wingLights: toBool(dataset.wing_lights),
    landingLights: toBool(dataset.landing_lights),
    taxiLights: toBool(dataset.taxi_lights),
    runwayTurnoffLights: toBool(dataset.runway_turnoff_lights),
    wheelWellLights: toBool(dataset.wheel_well_lights),
    onGround: toBool(dataset.on_ground),
    parkingBrake: toBool(dataset.parking_brake),
    speedBrake: toBool(dataset.speed_brake_active),
    speedBrakeLabel: buildSpeedBrakeLabel(dataset),
    spoilersDeployed: toBool(dataset.spoilers_deployed),
    autoBrakeLabel: asText(dataset.auto_brake_label),
    flapsDeployed: toBool(dataset.flaps_deployed),
    flapsLabel: buildFlapsLabel(dataset),
    flapsAngle: toDouble(dataset.flaps_angle_deg),
    flapsDeployRatio: toDouble(dataset.flaps_deploy_ratio),
    gearDown:
      inferGearDownStateFromRatio(noseGearDown, leftGearDown, rightGearDown) ??
      toBool(dataset.gear_down),
    noseGearDown,
    leftGearDown,
    rightGearDown,
    apuRunning: toBool(dataset.apu_running),
    engine1Running: toBool(dataset.engine1_running),
    engine2Running: toBool(dataset.engine2_running),
    autopilotEngaged: toBool(dataset.autopilot_engaged),
    autothrottleEngaged: toBool(dataset.autothrottle_engaged),
    autopilotHeadingTarget: toDouble(
      dataset.autopilot_heading_target_deg ?? dataset.heading_target,
    ),
    autopilotLateralMode: pickString(dataset, ['autopilot_lateral_mode']),
    autopilotVerticalMode: pickString(dataset, ['autopilot_vertical_mode']),
    aircraftProfile: asText(dataset.aircraft_profile),
    aircraftId: asText(dataset.aircraft_id),
    aircraftManufacturer: asText(dataset.aircraft_manufacturer),
    aircraftFamily: asText(dataset.aircraft_family),
    aircraftModel: asText(dataset.aircraft_model),
    aircraftIcao: asText(dataset.aircraft_icao),
    aircraftDisplayName: asText(dataset.aircraft_display_name),
    flightPhase: pickString(dataset, ['flight_phase']),
    flightAlertLevel: pickString(dataset, ['flight_alert_level']),
    flightAlerts: parseFlightAlerts(dataset.flight_alerts),
    aiAircraft: parseAIAircraft(dataset.ai_aircraft),
  };
}

function parseFlightAlerts(value: unknown): FlightAlert[] {
  if (!Array.isArray(value)) return [];
  const alerts: FlightAlert[] = [];
  for (const item of value) {
    const map = toJsonMap(item);
    if (!map) continue;
    const id = pickString(map, ['id']) ?? '';
    const level = pickString(map, ['level']) ?? '';
    const message = pickString(map, ['message']) ?? '';
    if (id.length === 0 && message.length === 0) continue;
    alerts.push({ id, level, message });
  }
  return alerts;
}

function parseAIAircraft(value: unknown): AIAircraftState[] {
  if (!Array.isArray(value)) return [];
  const result: AIAircraftState[] = [];
  for (const item of value) {
    const map = toJsonMap(item);
    if (!map) continue;
    const latitude = toDouble(map.latitude);
    const longitude = toDouble(map.longitude);
    if (latitude === undefined || longitude === undefined) continue;
    if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) continue;
    const id = asText(map.id);
    result.push({
      id: id && id.length > 0 ? id : `AI-${result.length + 1}`,
      type: asText(map.type),
      latitude,
      longitude,
      altitude: toDouble(map.altitude_ft),
      heading: toDouble(map.heading_deg),
      groundSpeed: toDouble(map.ground_speed_kt),
      onGround: toBool(map.on_ground),
    });
  }
  return result;
}

function airportFromSuggestion(raw: JsonMap): AirportInfo {
  const icao = pickString(raw, ['icao', 'ICAO'])?.toUpperCase() ?? '';
  return {
    icaoCode: icao,
    iataCode: pickString(raw, ['iata', 'IATA']) ?? '',
    name: pickString(raw, ['name', 'Name']) ?? icao,
    nameChinese: '',
    latitude: pickDouble(raw, ['latitude', 'lat', 'Lat']) ?? 0,
    longitude: pickDouble(raw, ['longitude', 'lon', 'lng', 'Lng', 'Lon']) ?? 0,
  };
}

function airportFromNearestAirport(raw: JsonMap): AirportInfo | null {
  const icao = asText(raw.icao)?.toUpperCase() ?? '';
  if (icao.length === 0) return null;
  const label = asText(raw.label);
  return {
    icaoCode: icao,
    iataCode: '',
    name: label && label.length > 0 ? label : icao,
    nameChinese: '',
    latitude: toDouble(raw.latitude) ?? 0,
    longitude: toDouble(raw.longitude) ?? 0,
  };
}

function buildSpeedBrakeLabel(dataset: JsonMap): string | undefined {
  const ratio = toDouble(dataset.speed_brake_ratio);
  if (ratio === undefined) return undefined;
  return `${Math.round(ratio * 100)}%`;
}

function buildFlapsLabel(dataset: JsonMap): string | undefined {
  const angle = toDouble(dataset.flaps_angle_deg);
  if (angle !== undefined) return `${Math.round(angle)}°`;
  const ratio = toDouble(dataset.flaps_deploy_ratio);
  if (ratio !== undefined) return `${Math.round(ratio * 100)}%`;
  return undefined;
}

/** 由三个起落架的放下比例推断整体状态（平均值 ≥ 0.5 视为放下） */
function inferGearDownStateFromRatio(
  noseGearDown: number | undefined,
  leftGearDown: number | undefined,
  rightGearDown: number | undefined,
): boolean | undefined {
  const ratios: number[] = [];
  for (const raw of [noseGearDown, leftGearDown, rightGearDown]) {
    const normalized = normalizeGearRatio(raw);
    if (normalized !== undefined) ratios.push(normalized);
  }
  if (ratios.length === 0) return undefined;
  const average = ratios.reduce((a, b) => a + b, 0) / ratios.length;
  return average >= 0.5;
}

/** 起落架比例归一化：支持 0-1 与 0-100 两种量纲 */
function normalizeGearRatio(value: number | undefined): number | undefined {
  if (value === undefined || !Number.isFinite(value)) return undefined;
  if (value >= 0 && value <= 1) return value;
  if (value > 1 && value <= 100) return value / 100;
  return undefined;
}

/**
 * 燃油计划总量（kg）
 * 航段 = 距离 × 2.5；备降固定按 200nm 计；备份 1500；滑行 200；额外 5%
 */
export function buildFuelPlanTotal(distanceNm: number, hasAlternate: boolean): number {
  const trip = distanceNm * 2.5;
  const alternate = hasAlternate ? 200 * 2.5 : 0;
  const reserve = 1500;
  const taxi = 200;
  const extra = trip * 0.05;
  return trip + alternate + reserve + taxi + extra;
}

function sanitizePollIntervalMs(value: number): number {
  if (value < MIN_POLL_INTERVAL_MS) return MIN_POLL_INTERVAL_MS;
  if (value > MAX_POLL_INTERVAL_MS) return MAX_POLL_INTERVAL_MS;
  return value;
}

function asText(value: unknown): string | undefined {
  if (value === null || value === undefined) return undefined;
  const text = String(value);
  return text.length > 0 ? text : undefined;
}
