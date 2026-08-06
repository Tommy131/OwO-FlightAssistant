import { PersistenceService } from '../../../core/services/persistence-service';
import { AppLogger } from '../../../core/utils/logger';
import { MiddlewareHttpException, MiddlewareHttpResponse } from '../models/http-models';

/**
 * 中间件 HTTP 客户端
 *
 * 对应 Flutter 版 `modules/http/services/middleware_http_service.dart`，
 * 逐个方法对齐，保持相同的 API 契约与持久化键名。
 *
 * ── Web 适配说明（CORS）──
 * 浏览器不能直接跨源请求 `http://127.0.0.1:18080`。
 * 因此默认 baseUrl 改为同源代理前缀 `/mw-api`，由 Vite dev server 转发（见 vite.config.ts）。
 * 用户仍可在「中间件设置」里改成任意绝对地址 —— 此时需要中间件自身下发 CORS 头。
 */

const BASE_URL_KEY = 'middleware_http_base_url';
const WEBSOCKET_BASE_URL_KEY = 'middleware_ws_base_url';
const TIMEOUT_MS_KEY = 'middleware_http_timeout_ms';

/** 同源代理前缀（开发与同源部署下的默认值） */
export const PROXY_HTTP_PREFIX = '/mw-api';
export const PROXY_WS_PATH = '/mw-ws';

/** 桌面版的原始默认地址，仅用于设置页展示与「恢复默认」 */
export const DESKTOP_DEFAULT_BASE_URL = 'http://127.0.0.1:18080';
export const DESKTOP_DEFAULT_WS_BASE_URL = 'ws://127.0.0.1:18081/api/v1/simulator/ws';

const DEFAULT_BASE_URL = PROXY_HTTP_PREFIX;
const DEFAULT_TIMEOUT_MS = 10_000;

class MiddlewareHttpServiceImpl {
  private baseUrlValue: string = DEFAULT_BASE_URL;
  private webSocketBaseUrlValue: string = deriveDefaultWebSocketUrl();
  private timeoutMs: number = DEFAULT_TIMEOUT_MS;
  private headers: Record<string, string> = {
    Accept: 'application/json',
    'Content-Type': 'application/json',
  };
  private initialized = false;

  get baseUrl(): string {
    return this.baseUrlValue;
  }

  get webSocketBaseUrl(): string {
    return this.webSocketBaseUrlValue;
  }

  get timeout(): number {
    return this.timeoutMs;
  }

  get defaultHeaders(): Readonly<Record<string, string>> {
    return { ...this.headers };
  }

  /** 从持久化载入配置（幂等） */
  async init(): Promise<void> {
    if (this.initialized) return;
    await PersistenceService.ensureReady();

    const savedBaseUrl = PersistenceService.getString(BASE_URL_KEY);
    if (savedBaseUrl && savedBaseUrl.trim().length > 0) {
      this.baseUrlValue = normalizeBaseUrl(savedBaseUrl);
    }

    const savedWsUrl = PersistenceService.getString(WEBSOCKET_BASE_URL_KEY);
    if (savedWsUrl && savedWsUrl.trim().length > 0) {
      this.webSocketBaseUrlValue = normalizeWebSocketBaseUrl(savedWsUrl);
    } else {
      this.webSocketBaseUrlValue = deriveWebSocketUrlFromBase(this.baseUrlValue);
    }

    const timeout = PersistenceService.getInt(TIMEOUT_MS_KEY);
    if (timeout && timeout > 0) this.timeoutMs = timeout;

    this.initialized = true;
  }

  /** 更新配置（对应桌面版 configure） */
  async configure(options: {
    baseUrl?: string;
    webSocketBaseUrl?: string;
    timeoutMs?: number;
    defaultHeaders?: Record<string, string>;
    persist?: boolean;
  }): Promise<void> {
    const { baseUrl, webSocketBaseUrl, timeoutMs, defaultHeaders, persist = true } = options;

    if (baseUrl && baseUrl.trim().length > 0) {
      this.baseUrlValue = normalizeBaseUrl(baseUrl);
      if (!webSocketBaseUrl || webSocketBaseUrl.trim().length === 0) {
        this.webSocketBaseUrlValue = deriveWebSocketUrlFromBase(this.baseUrlValue);
      }
    }
    if (webSocketBaseUrl && webSocketBaseUrl.trim().length > 0) {
      this.webSocketBaseUrlValue = normalizeWebSocketBaseUrl(webSocketBaseUrl);
    }
    if (timeoutMs && timeoutMs > 0) {
      this.timeoutMs = timeoutMs;
    }
    if (defaultHeaders) {
      this.headers = { ...defaultHeaders };
    }

    if (persist) {
      await PersistenceService.ensureReady();
      await PersistenceService.setString(BASE_URL_KEY, this.baseUrlValue);
      await PersistenceService.setString(WEBSOCKET_BASE_URL_KEY, this.webSocketBaseUrlValue);
      await PersistenceService.setInt(TIMEOUT_MS_KEY, this.timeoutMs);
    }
  }

  setAuthToken(token: string | null): void {
    if (!token || token.trim().length === 0) {
      delete this.headers.Authorization;
      return;
    }
    this.headers.Authorization = `Bearer ${token.trim()}`;
  }

  // ── 通用请求 ──

  get(
    path: string,
    options: { queryParameters?: QueryParams; headers?: Record<string, string> } = {},
  ): Promise<MiddlewareHttpResponse> {
    return this.request({ method: 'GET', path, ...options });
  }

  post(
    path: string,
    options: {
      body?: unknown;
      queryParameters?: QueryParams;
      headers?: Record<string, string>;
    } = {},
  ): Promise<MiddlewareHttpResponse> {
    return this.request({ method: 'POST', path, ...options });
  }

  put(path: string, options: { body?: unknown } = {}): Promise<MiddlewareHttpResponse> {
    return this.request({ method: 'PUT', path, ...options });
  }

  patch(path: string, options: { body?: unknown } = {}): Promise<MiddlewareHttpResponse> {
    return this.request({ method: 'PATCH', path, ...options });
  }

  delete(path: string, options: { body?: unknown } = {}): Promise<MiddlewareHttpResponse> {
    return this.request({ method: 'DELETE', path, ...options });
  }

  async request(options: {
    method: string;
    path: string;
    body?: unknown;
    queryParameters?: QueryParams;
    headers?: Record<string, string>;
    timeoutMs?: number;
  }): Promise<MiddlewareHttpResponse> {
    const { method, path, body, queryParameters, headers, timeoutMs } = options;
    const url = this.buildUrl(path, queryParameters);
    const mergedHeaders = { ...this.headers, ...headers };
    const requestBody = serializeBody(body, mergedHeaders);

    const controller = new AbortController();
    const effectiveTimeout = timeoutMs ?? this.timeoutMs;
    const timer = setTimeout(() => controller.abort(), effectiveTimeout);

    try {
      const response = await fetch(url, {
        method: method.toUpperCase(),
        headers: mergedHeaders,
        body: requestBody ?? undefined,
        signal: controller.signal,
      });

      const responseHeaders: Record<string, string> = {};
      response.headers.forEach((value, key) => {
        responseHeaders[key] = value;
      });
      const text = await response.text();

      const result = new MiddlewareHttpResponse(
        response.status,
        responseHeaders,
        text,
        url,
      );

      if (!result.isSuccess) {
        AppLogger.warning(
          `HTTP request failed: ${method} ${path}, status: ${result.statusCode}`,
        );
        throw new MiddlewareHttpException({
          message: 'HTTP request failed',
          statusCode: result.statusCode,
          data: result.decodedBody,
          uri: url,
        });
      }
      return result;
    } catch (e) {
      if (e instanceof MiddlewareHttpException) throw e;
      if (e instanceof DOMException && e.name === 'AbortError') {
        AppLogger.warning(`HTTP request timeout: ${method} ${path}`);
        throw new MiddlewareHttpException({
          message: `Request timeout: ${effectiveTimeout}ms`,
          uri: url,
        });
      }
      AppLogger.error(`Middleware HTTP request error: ${method} ${path}`, e);
      throw new MiddlewareHttpException({ message: `Request error: ${String(e)}`, uri: url });
    } finally {
      clearTimeout(timer);
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 具体 API（与桌面版逐一对应）
  // ──────────────────────────────────────────────────────────────────────────

  getHealth(): Promise<MiddlewareHttpResponse> {
    return this.get('/health');
  }

  getVersion(): Promise<MiddlewareHttpResponse> {
    return this.get('/api/v1/version');
  }

  getAirportByIcao(icao: string): Promise<MiddlewareHttpResponse> {
    return this.get(`/api/v1/airport/${normalizeIcao(icao)}`);
  }

  getAirportLayoutByIcao(icao: string): Promise<MiddlewareHttpResponse> {
    return this.get(`/api/v1/airport-layout/${normalizeIcao(icao)}`);
  }

  getMetarByIcao(icao: string): Promise<MiddlewareHttpResponse> {
    return this.get(`/api/v1/metar/${normalizeIcao(icao)}`);
  }

  getAirportList(): Promise<MiddlewareHttpResponse> {
    return this.get('/api/v1/airport-list');
  }

  getAirportSuggestions(query: string, limit = 8): Promise<MiddlewareHttpResponse> {
    return this.get('/api/v1/airport-suggest', {
      queryParameters: { q: query.trim().toUpperCase(), limit },
    });
  }

  /**
   * 拉取 SimBrief 上该用户最新的飞行计划
   *
   * 传用户名或数字 Pilot ID 均可。**这两者都不是密钥** ——
   * SimBrief 的 API key 是给「生成航路」用的，读取已有 OFP 不需要，
   * 所以它按普通设置项存即可。
   */
  fetchSimBriefPlan(identity: {
    username?: string;
    userId?: string;
  }): Promise<MiddlewareHttpResponse> {
    const queryParameters: Record<string, string> = {};
    const userId = identity.userId?.trim();
    const username = identity.username?.trim();
    // 数字 ID 更稳（用户名可改），两者都给时优先用它
    if (userId) queryParameters.userid = userId;
    else if (username) queryParameters.username = username;
    return this.get('/api/v1/simbrief/fetch', { queryParameters });
  }

  /** 机场跑道/滑行道/停机坪矢量（后端代 Overpass 查询并缓存） */
  getAirportAeroway(
    icao: string,
    center?: { latitude: number; longitude: number },
  ): Promise<MiddlewareHttpResponse> {
    return this.get('/api/v1/aeroway/query', {
      queryParameters: {
        icao: normalizeIcao(icao),
        ...(center ? { lat: center.latitude, lon: center.longitude } : {}),
      },
    });
  }

  /** 跑道进近设施：ILS 类别 / 航向台频率 / 下滑道角度 / DME */
  getRunwayNavaids(icao: string): Promise<MiddlewareHttpResponse> {
    return this.get('/api/v1/runway/navaid', {
      queryParameters: { icao: normalizeIcao(icao) },
    });
  }

  /** 各跑道端已公布的进近类型（ILS / GLS / RNAV …） */
  getRunwayApproaches(icao: string): Promise<MiddlewareHttpResponse> {
    return this.get('/api/v1/approach/query', {
      queryParameters: { icao: normalizeIcao(icao) },
    });
  }

  /** 机场终端区已公布的等待航线 */
  getHoldingPatterns(icao: string): Promise<MiddlewareHttpResponse> {
    return this.get('/api/v1/holding/query', {
      queryParameters: { icao: normalizeIcao(icao) },
    });
  }

  getAirportsByBounds(bounds: {
    minLat: number;
    maxLat: number;
    minLon: number;
    maxLon: number;
    limit?: number;
  }): Promise<MiddlewareHttpResponse> {
    return this.get('/api/v1/airports', {
      queryParameters: {
        min_lat: bounds.minLat,
        max_lat: bounds.maxLat,
        min_lon: bounds.minLon,
        max_lon: bounds.maxLon,
        limit: bounds.limit ?? 20,
      },
    });
  }

  getRestrictedAirspaceByBounds(bounds: {
    minLat: number;
    maxLat: number;
    minLon: number;
    maxLon: number;
    limit?: number;
  }): Promise<MiddlewareHttpResponse> {
    return this.get('/api/v1/airspace/restricted', {
      queryParameters: {
        min_lat: bounds.minLat,
        max_lat: bounds.maxLat,
        min_lon: bounds.minLon,
        max_lon: bounds.maxLon,
        limit: bounds.limit ?? 18,
      },
    });
  }

  getWindProfile(params: {
    latitude: number;
    longitude: number;
    altitudeFt: number;
  }): Promise<MiddlewareHttpResponse> {
    return this.get('/api/v1/weather/wind/profile', {
      queryParameters: {
        lat: params.latitude,
        lon: params.longitude,
        altitude_ft: params.altitudeFt,
      },
    });
  }

  reportMapWind(params: {
    latitude: number;
    longitude: number;
    altitudeFt: number;
    speedKt: number;
    directionDeg: number;
    sampleCount: number;
  }): Promise<MiddlewareHttpResponse> {
    return this.post('/api/v1/map/report/wind', {
      body: {
        latitude: params.latitude,
        longitude: params.longitude,
        altitude_ft: params.altitudeFt,
        speed_kt: params.speedKt,
        direction_deg: params.directionDeg,
        sample_count: params.sampleCount,
      },
    });
  }

  reportMapAirspace(params: {
    latitude: number;
    longitude: number;
    nearestZoneId: string;
    insideRestricted: boolean;
    visibleZones: number;
    source: string;
  }): Promise<MiddlewareHttpResponse> {
    return this.post('/api/v1/map/report/airspace', {
      body: {
        latitude: params.latitude,
        longitude: params.longitude,
        nearest_zone_id: params.nearestZoneId,
        inside_restricted: params.insideRestricted,
        visible_zones: params.visibleZones,
        source: params.source,
      },
    });
  }

  reportTerrainWarning(params: {
    alertId: string;
    alertLevel: string;
    radioAltitudeFt: number;
    verticalSpeedFpm: number;
    latitude: number;
    longitude: number;
  }): Promise<MiddlewareHttpResponse> {
    return this.post('/api/v1/map/report/terrain-warning', {
      body: {
        alert_id: params.alertId,
        alert_level: params.alertLevel,
        radio_altitude_ft: params.radioAltitudeFt,
        vertical_speed_fpm: params.verticalSpeedFpm,
        latitude: params.latitude,
        longitude: params.longitude,
      },
    });
  }

  getSimulatorState(type: string): Promise<MiddlewareHttpResponse> {
    return this.post('/api/v1/simulator/state', { body: { type: type.trim().toLowerCase() } });
  }

  connectSimulator(params: {
    type: string;
    timeout?: number;
    address?: string;
  }): Promise<MiddlewareHttpResponse> {
    return this.post('/api/v1/simulator/connect', {
      body: {
        type: params.type.trim().toLowerCase(),
        timeout: params.timeout ?? 8,
        address: params.address?.trim() ?? '',
      },
    });
  }

  getSimulatorData(token: string): Promise<MiddlewareHttpResponse> {
    return this.post('/api/v1/simulator/data', { body: { token: token.trim() } });
  }

  disconnectSimulator(token: string): Promise<MiddlewareHttpResponse> {
    return this.post('/api/v1/simulator/disconnect', { body: { token: token.trim() } });
  }

  getSimulatorWebSocketInfo(): Promise<MiddlewareHttpResponse> {
    return this.get('/api/v1/simulator/ws');
  }

  getPerformanceAircraftProfiles(): Promise<MiddlewareHttpResponse> {
    return this.get('/api/v1/performance/aircraft-profiles');
  }

  /** RainViewer 雷达帧索引（中间件代理并缓存 5 分钟，规避 429） */
  getWeatherRadarMetadata(): Promise<MiddlewareHttpResponse> {
    return this.get('/api/v1/weather/radar/metadata');
  }

  // ── 飞行日志 / 简报的服务端持久化 ──

  listFlightLogs(): Promise<MiddlewareHttpResponse> {
    return this.get('/api/v1/flight-logs/list');
  }

  saveFlightLog(id: string, record: unknown): Promise<MiddlewareHttpResponse> {
    return this.post('/api/v1/flight-logs/save', { body: { id, record } });
  }

  deleteFlightLog(id: string): Promise<MiddlewareHttpResponse> {
    return this.post('/api/v1/flight-logs/delete', { body: { id } });
  }

  listBriefings(): Promise<MiddlewareHttpResponse> {
    return this.get('/api/v1/briefings/list');
  }

  // ── 应用设置的服务端持久化（存中间件 SQLite）──

  getAllSettings(): Promise<MiddlewareHttpResponse> {
    return this.get('/api/v1/settings/all');
  }

  setSetting(key: string, value: unknown): Promise<MiddlewareHttpResponse> {
    return this.post('/api/v1/settings/set', { body: { key, value } });
  }

  setSettingsBulk(entries: Record<string, unknown>): Promise<MiddlewareHttpResponse> {
    return this.post('/api/v1/settings/bulk-set', { body: { entries } });
  }

  deleteSetting(key: string): Promise<MiddlewareHttpResponse> {
    return this.post('/api/v1/settings/delete', { body: { key } });
  }

  resetSettings(): Promise<MiddlewareHttpResponse> {
    return this.post('/api/v1/settings/reset');
  }

  saveBriefing(id: string, record: unknown): Promise<MiddlewareHttpResponse> {
    return this.post('/api/v1/briefings/save', { body: { id, record } });
  }

  deleteBriefing(id: string): Promise<MiddlewareHttpResponse> {
    return this.post('/api/v1/briefings/delete', { body: { id } });
  }

  calculatePerformance(params: {
    aircraftId: string;
    runwayLength: number;
    pressureAltitude: number;
    oat: number;
    headwind: number;
    aircraftWeight: number;
    wetRunway: boolean;
  }): Promise<MiddlewareHttpResponse> {
    return this.post('/api/v1/performance/calculate', {
      body: {
        aircraft_id: params.aircraftId.trim(),
        runway_length: params.runwayLength,
        pressure_altitude: params.pressureAltitude,
        oat: params.oat,
        headwind: params.headwind,
        aircraft_weight: params.aircraftWeight,
        wet_runway: params.wetRunway,
      },
    });
  }

  // ──────────────────────────────────────────────────────────────────────────
  // WebSocket 地址解析
  // ──────────────────────────────────────────────────────────────────────────

  /**
   * 解析实时数据 WebSocket 地址
   *
   * 与桌面版一致，先问后端 `/api/v1/simulator/ws` 拿实际地址；
   * 但当前端走同源代理时，后端返回的 `ws_address`（通常是 127.0.0.1:18081）
   * 在浏览器里同样受同源限制，因此代理模式下固定使用 `/mw-ws` 代理路径。
   */
  async resolveSimulatorWebSocketUri(token: string): Promise<string> {
    if (this.isUsingProxy()) {
      return buildProxyWebSocketUrl(token);
    }

    let base = this.webSocketBaseUrlValue;
    try {
      const info = await this.getSimulatorWebSocketInfo();
      const body = info.objectBody;
      const wsAddress = typeof body?.ws_address === 'string' ? body.ws_address.trim() : '';
      if (wsAddress.length > 0) base = normalizeWebSocketBaseUrl(wsAddress);
    } catch {
      /* 拿不到就退回本地配置 */
    }
    return this.buildSimulatorWebSocketUri(token, base);
  }

  buildSimulatorWebSocketUri(token: string, base?: string): string {
    if (this.isUsingProxy() && !base) return buildProxyWebSocketUrl(token);
    const wsBase = normalizeWebSocketBaseUrl(base ?? this.webSocketBaseUrlValue);
    const url = new URL(wsBase);
    url.searchParams.set('token', token.trim());
    url.hostname = resolveClientReachableHost(url.hostname, this.baseUrlValue);
    return url.toString();
  }

  /** 当前是否在走同源代理（baseUrl 为相对路径时成立） */
  isUsingProxy(): boolean {
    return this.baseUrlValue.startsWith('/');
  }

  private buildUrl(path: string, queryParameters?: QueryParams): string {
    const normalizedPath = path.trim().length === 0 ? '/' : path.trim();
    const base = this.baseUrlValue;

    // 相对前缀（代理模式）：直接拼接
    let full: string;
    if (base.startsWith('/')) {
      const left = base.replace(/\/+$/, '');
      const right = normalizedPath.startsWith('/') ? normalizedPath : `/${normalizedPath}`;
      full = `${left}${right}`;
    } else {
      const baseUri = new URL(base);
      const leftSegments = baseUri.pathname.split('/').filter(Boolean);
      const rightSegments = normalizedPath.split('/').filter(Boolean);
      baseUri.pathname = `/${[...leftSegments, ...rightSegments].join('/')}`;
      full = baseUri.toString();
    }

    if (!queryParameters) return full;
    const search = new URLSearchParams();
    for (const [key, value] of Object.entries(queryParameters)) {
      search.set(key, value === null || value === undefined ? '' : String(value));
    }
    const query = search.toString();
    if (query.length === 0) return full;
    return full.includes('?') ? `${full}&${query}` : `${full}?${query}`;
  }
}

type QueryParams = Record<string, string | number | boolean | null | undefined>;

// ──────────────────────────────────────────────────────────────────────────
// 工具函数
// ──────────────────────────────────────────────────────────────────────────

function serializeBody(body: unknown, headers: Record<string, string>): string | null {
  if (body === null || body === undefined) return null;
  if (typeof body === 'string') return body;
  const contentType = (headers['Content-Type'] ?? headers['content-type'] ?? '').toLowerCase();
  if (contentType.includes('application/json')) return JSON.stringify(body);
  // 非 JSON content-type 但传了对象：String() 会得到 "[object Object]"，
  // 等于把一段垃圾发给后端。序列化成 JSON 至少是可读、可排查的。
  return JSON.stringify(body);
}

function normalizeBaseUrl(value: string): string {
  const trimmed = value.trim();
  // 相对前缀直接归一化
  if (trimmed.startsWith('/')) return trimmed.replace(/\/+$/, '') || '/';
  try {
    const uri = new URL(trimmed);
    uri.search = '';
    uri.hash = '';
    return uri.toString().replace(/\/+$/, '');
  } catch {
    return trimmed.replace(/\/+$/, '');
  }
}

function normalizeWebSocketBaseUrl(value: string): string {
  const trimmed = ensureWebSocketScheme(value.trim());
  try {
    const uri = new URL(trimmed);
    uri.search = '';
    uri.hash = '';
    return uri.toString().replace(/\/+$/, '');
  } catch {
    return trimmed.replace(/\/+$/, '');
  }
}

function ensureWebSocketScheme(value: string): string {
  if (value.startsWith('ws://') || value.startsWith('wss://')) return value;
  return `ws://${value}`;
}

/** 0.0.0.0 / :: 等监听地址在客户端不可达，回退到 baseUrl 的主机 */
function resolveClientReachableHost(host: string, baseUrl: string): string {
  const normalized = host.trim();
  const unusable = ['', '0.0.0.0', '::', '[::]'];
  if (!unusable.includes(normalized)) return normalized;
  try {
    const fallback = new URL(baseUrl).hostname.trim();
    if (!unusable.includes(fallback)) return fallback;
  } catch {
    /* baseUrl 是相对路径时无主机可取 */
  }
  return '127.0.0.1';
}

/** 由 HTTP baseUrl 推导 WS 地址（端口 +1，路径固定），与桌面版一致 */
function deriveWebSocketUrlFromBase(baseUrl: string): string {
  if (baseUrl.startsWith('/')) return deriveDefaultWebSocketUrl();
  try {
    const uri = new URL(baseUrl);
    const scheme = uri.protocol === 'https:' ? 'wss' : 'ws';
    const port = uri.port ? Number(uri.port) + 1 : 18081;
    return `${scheme}://${uri.hostname}:${port}/api/v1/simulator/ws`;
  } catch {
    return DESKTOP_DEFAULT_WS_BASE_URL;
  }
}

/** 同源代理下的 WS 地址（由页面协议推导 ws/wss） */
function deriveDefaultWebSocketUrl(): string {
  if (typeof window === 'undefined') return DESKTOP_DEFAULT_WS_BASE_URL;
  const scheme = window.location.protocol === 'https:' ? 'wss' : 'ws';
  return `${scheme}://${window.location.host}${PROXY_WS_PATH}`;
}

function buildProxyWebSocketUrl(token: string): string {
  const url = new URL(deriveDefaultWebSocketUrl());
  url.searchParams.set('token', token.trim());
  return url.toString();
}

function normalizeIcao(icao: string): string {
  return icao.trim().toUpperCase();
}

/** 单例，对应 Flutter 版 `MiddlewareHttpService()` 工厂构造 */
export const MiddlewareHttpService = new MiddlewareHttpServiceImpl();
