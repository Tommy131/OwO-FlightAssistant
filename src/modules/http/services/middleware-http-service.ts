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
 * 开发下默认 baseUrl 是同源代理前缀 `/mw-api`，由 Vite dev server 转发（见 vite.config.ts）。
 * 用户仍可在「中间件设置」里改成任意绝对地址 —— 此时需要中间件自身下发 CORS 头。
 *
 * ⚠️ 构建产物由中间件自己内嵌托管，接口就在**同源根路径**下，此时绝不能带 `/mw-api`：
 * 中间件对未知路径一律回落到 SPA 的 index.html，于是 `/mw-api/...` 会拿到
 * **HTTP 200 + 一段 HTML**。状态码是 200，健康检查照样「通过」，
 * 界面显示已连接，可每个接口都解析不出数据 —— 这种失败一声不吭，最难查。
 */

const BASE_URL_KEY = 'middleware_http_base_url';
const WEBSOCKET_BASE_URL_KEY = 'middleware_ws_base_url';
const TIMEOUT_MS_KEY = 'middleware_http_timeout_ms';

/** 同源代理前缀（仅开发下的默认值） */
export const PROXY_HTTP_PREFIX = '/mw-api';
export const PROXY_WS_PATH = '/mw-ws';

/** 桌面版的原始默认地址，仅用于设置页展示与「恢复默认」 */
export const DESKTOP_DEFAULT_BASE_URL = 'http://127.0.0.1:18080';
export const DESKTOP_DEFAULT_WS_BASE_URL = 'ws://127.0.0.1:18081/api/v1/simulator/ws';

/** 内嵌托管时 WS 与 HTTP 的端口差（18080 → 18081），沿用桌面版约定 */
const WS_PORT_OFFSET = 1;

/**
 * 默认 HTTP 基址。
 *
 * 开发下走 Vite 代理前缀，内嵌托管下必须是空串（同源根路径，见文件头的警告）。
 * 抽成纯函数是为了能直接测两种模式 —— 这个判断错了不会报错，只会静默失灵。
 */
export function defaultBaseUrl(isDev: boolean): string {
  return isDev ? PROXY_HTTP_PREFIX : '';
}

/**
 * 默认 WS 地址。
 *
 * 开发下走 Vite 的 `/mw-ws` 代理；内嵌托管下 WS 与 HTTP 不同端口，
 * 按端口 +1 从当前页面地址推出来，这样换主机部署也不用手改设置。
 */
export function defaultWebSocketUrl(
  isDev: boolean,
  location: { protocol: string; host: string; hostname: string; port: string } | null,
): string {
  if (!location) return DESKTOP_DEFAULT_WS_BASE_URL;
  const scheme = location.protocol === 'https:' ? 'wss' : 'ws';
  if (isDev) return `${scheme}://${location.host}${PROXY_WS_PATH}`;
  const httpPort = Number(location.port);
  const port = Number.isFinite(httpPort) && httpPort > 0 ? httpPort + WS_PORT_OFFSET : 18081;
  return `${scheme}://${location.hostname}:${port}/api/v1/simulator/ws`;
}

const DEFAULT_BASE_URL = defaultBaseUrl(import.meta.env.DEV);
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

  /**
   * 健康检查
   *
   * 只看状态码是不够的：baseUrl 指错时中间件会把请求当成前端路由，
   * 回落到 SPA 的 index.html —— HTTP 200，内容是 HTML。
   * 于是「连接正常」，可每个接口都取不到数据。
   * 这里必须验到响应确实是个 JSON 对象，才算连上的是中间件。
   */
  async getHealth(): Promise<MiddlewareHttpResponse> {
    const response = await this.get('/health');
    if (!response.objectBody) {
      AppLogger.warning(
        `[Http] /health 返回的不是 JSON，baseUrl 可能指错了：${this.baseUrlValue || '(同源)'}`,
      );
      throw new MiddlewareHttpException({
        message: 'health check returned non-JSON body',
        statusCode: response.statusCode,
        uri: response.uri,
      });
    }
    return response;
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

  /**
   * 地形高程瓦片
   *
   * 中间件按 0.25° 一块、每块 10×10 网格切好并长期缓存，所以同一片区域
   * 只有第一次会真的打上游。范围跨度有上限（超了后端直接拒），
   * 调用方应当只请求本机周边，而不是整个视野 —— 机载 EGPWS 的地形显示
   * 同样只画导航显示量程内的地形。
   */
  getTerrainTiles(bounds: {
    south: number;
    west: number;
    north: number;
    east: number;
  }): Promise<MiddlewareHttpResponse> {
    return this.get('/api/v1/terrain/tiles', {
      queryParameters: {
        south: String(bounds.south),
        west: String(bounds.west),
        north: String(bounds.north),
        east: String(bounds.east),
      },
    });
  }

  /**
   * 按经纬度查时区
   *
   * 返回里带 IANA 时区名，拿到之后本地用 Intl 自己走时即可 ——
   * 显示一个秒级跳动的钟不该每秒来问一次后端。
   */
  getTimezoneAt(latitude: number, longitude: number): Promise<MiddlewareHttpResponse> {
    return this.get('/api/v1/timezone', {
      queryParameters: { lat: String(latitude), lon: String(longitude) },
    });
  }

  /**
   * 检查是否有可用更新
   *
   * 中间件那边缓存 30 分钟（未鉴权的 GitHub API 每小时只有 60 次配额）。
   * `force` 用于设置页的手动检查 —— 用户点了按钮却拿到半小时前的缓存，
   * 会以为按钮坏了。
   */
  getUpdateCheck(force = false): Promise<MiddlewareHttpResponse> {
    return this.get('/api/v1/update/check', {
      queryParameters: force ? { force: 'true' } : undefined,
    });
  }

  /** 记下被忽略的版本；tag 传空表示取消忽略 */
  postUpdateIgnore(tag: string): Promise<MiddlewareHttpResponse> {
    return this.post('/api/v1/update/ignore', { body: { tag } });
  }

  /** 开始下载并替换中间件自身 */
  postUpdateInstall(tag: string): Promise<MiddlewareHttpResponse> {
    return this.post('/api/v1/update/install', { body: { tag } });
  }

  /** 查自更新进度 */
  getUpdateStatus(): Promise<MiddlewareHttpResponse> {
    return this.get('/api/v1/update/status');
  }

  getMetarByIcao(icao: string, force = false): Promise<MiddlewareHttpResponse> {
    return this.get(`/api/v1/metar/${normalizeIcao(icao)}`, {
      queryParameters: force ? { force: 'true' } : undefined,
    });
  }

  /**
   * 批量 METAR
   *
   * 默认只读中间件缓存并对未命中的机场触发后台预热，所以首帧一定很快，
   * 缺的那几个下一轮轮询就补齐了。`wait: true` 才会让后端同步回源 ——
   * EFB 卡片首次打开时才值得这么等。
   */
  getMetarBatch(icaos: readonly string[], wait = false): Promise<MiddlewareHttpResponse> {
    return this.post('/api/v1/weather/metar-batch', {
      body: { icaos: icaos.map(normalizeIcao), wait },
      // wait 模式下后端要串行回源，10s 偶尔不够
      ...(wait ? { timeoutMs: 20_000 } : {}),
    });
  }

  /** 近场机场（按距离升序），后端顺手预热这些机场的详情 */
  getNearbyAirports(params: {
    latitude: number;
    longitude: number;
    radiusNm?: number;
    limit?: number;
  }): Promise<MiddlewareHttpResponse> {
    return this.get('/api/v1/airports/nearby', {
      queryParameters: {
        lat: params.latitude,
        lon: params.longitude,
        radius_nm: params.radiusNm ?? 100,
        limit: params.limit ?? 5,
      },
    });
  }

  /** 声明「我马上要用这些机场」，让中间件在后台先把缓存热起来 */
  prewarmCache(params: {
    icaos?: readonly string[];
    latitude?: number;
    longitude?: number;
    radiusNm?: number;
    metar?: boolean;
  }): Promise<MiddlewareHttpResponse> {
    return this.post('/api/v1/cache/prewarm', {
      body: {
        icaos: (params.icaos ?? []).map(normalizeIcao),
        latitude: params.latitude ?? null,
        longitude: params.longitude ?? null,
        radius_nm: params.radiusNm ?? 0,
        metar: params.metar ?? true,
      },
    });
  }

  /** 各层缓存的命中率与容量指标（诊断页用） */
  getCacheStats(): Promise<MiddlewareHttpResponse> {
    return this.get('/api/v1/cache/stats');
  }

  /**
   * 连接诊断与数据质量指标
   *
   * 分上下行两段回报：`upstream` 是「模拟器 → 中间件」（到包率 / 重复帧 / 断流），
   * `downstream` 是「中间件 → 前端」（推送耗时 / 间隔 / 写失败）。
   * 画面冻住但接口都正常时，问题一定在 upstream 那一段。
   */
  getConnectionDiagnostics(simulatorType?: string): Promise<MiddlewareHttpResponse> {
    return this.get('/api/v1/diagnostics/connection', {
      queryParameters: simulatorType ? { type: simulatorType.trim().toLowerCase() } : undefined,
    });
  }

  /**
   * 导航数据源：可用列表 + 当前生效的源。
   *
   * `configured` 是配置里存的、`effective` 是实际会被查询用到的 ——
   * 存着的那个源可能已经不可用了（模拟器卸载、路径变了），
   * 两者分开报，界面才不会把一个失效的选项显示成当前值。
   */
  getNavDataSources(): Promise<MiddlewareHttpResponse> {
    return this.get('/api/v1/navdata/sources');
  }

  /** 切换导航数据源；传空串表示交给中间件自动选择 */
  setNavDataSource(source: string): Promise<MiddlewareHttpResponse> {
    return this.post('/api/v1/navdata/set-source', { body: { source } });
  }

  /** 可观测性看板：路由耗时排行、错误分类、WS 与缓存状态 */
  getObservabilityDashboard(): Promise<MiddlewareHttpResponse> {
    return this.get('/api/v1/observability/dashboard');
  }

  /**
   * 遥测字段契约与兼容性报告
   *
   * 传上本前端编译时依据的契约版本，后端会算出「你不认识哪些新字段」
   * 和「你可能还在用哪些已弃用字段」。字段被彻底删掉时 `compatible` 为 false ——
   * 这是唯一会真的让老前端读到 undefined 的情况。
   */
  getTelemetryContract(clientVersion?: string): Promise<MiddlewareHttpResponse> {
    return this.get('/api/v1/contract/schema', {
      queryParameters: clientVersion ? { client_version: clientVersion } : undefined,
    });
  }

  /**
   * 用契约校验一份遥测载荷
   *
   * 不传 payload 时后端会校验**当前实况**遥测 —— 出问题时的现场取证：
   * 直接告诉你哪个字段类型不对、哪个数值超了范围。
   */
  validateTelemetryContract(input: {
    payload?: Record<string, unknown>;
    strict?: boolean;
    simulatorType?: string;
  } = {}): Promise<MiddlewareHttpResponse> {
    return this.post('/api/v1/contract/validate', {
      body: {
        payload: input.payload ?? {},
        strict: input.strict ?? false,
        simulator_type: input.simulatorType?.trim().toLowerCase() ?? '',
      },
    });
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

  /**
   * 统一航班计划：从 SimBrief 拉取
   *
   * 与 `fetchSimBriefPlan` 拿的是同一份 OFP，区别是这里返回**归一化后的**
   * FlightPlan（带 `source` 字段），与手动导入 OFP / FPL 的结果同形状，
   * 前端渲染一套代码就够。
   */
  fetchFlightPlan(identity: {
    username?: string;
    userId?: string;
  }): Promise<MiddlewareHttpResponse> {
    const queryParameters: Record<string, string> = {};
    const userId = identity.userId?.trim();
    const username = identity.username?.trim();
    if (userId) queryParameters.userid = userId;
    else if (username) queryParameters.username = username;
    return this.get('/api/v1/flight-plan/fetch', { queryParameters });
  }

  /**
   * 统一航班计划：解析用户提交的 OFP JSON 或简化 FPL 航路串
   *
   * `source: 'auto'` 时后端按内容判别（以 `{` 开头当 OFP，其余当航路串）。
   * FPL 的航路点坐标由后端查本地导航库补齐，查不到的会出现在
   * `plan.unresolved` 里 —— 那些点没有坐标，航线会从旁边直接过去。
   */
  parseFlightPlan(input: {
    content: string;
    source?: 'auto' | 'ofp' | 'fpl';
    origin?: string;
    destination?: string;
    alternate?: string;
    flightNumber?: string;
    aircraftIcao?: string;
    cruiseAltitudeFt?: number;
  }): Promise<MiddlewareHttpResponse> {
    return this.post('/api/v1/flight-plan/parse', {
      body: {
        source: input.source ?? 'auto',
        content: input.content,
        origin: normalizeIcao(input.origin ?? ''),
        destination: normalizeIcao(input.destination ?? ''),
        alternate: normalizeIcao(input.alternate ?? ''),
        flight_number: input.flightNumber?.trim() ?? '',
        aircraft_icao: input.aircraftIcao?.trim().toUpperCase() ?? '',
        cruise_altitude_ft: input.cruiseAltitudeFt ?? 0,
      },
    });
  }

  /** 某机场公布的 SID / STAR / 进近程序航段（后端解析 CIFP 并补齐坐标） */
  getAirportProcedures(icao: string): Promise<MiddlewareHttpResponse> {
    return this.get('/api/v1/procedure/query', {
      queryParameters: { icao: normalizeIcao(icao) },
    });
  }

  /**
   * 航路气象剖面：沿航线取各气压层的高空风与温度
   *
   * 走 POST 是因为航路点可能上百个，塞进 query string 会超长；
   * 后端会抽稀到 12 个点再问上游。
   */
  getRouteWeatherProfile(input: {
    points: readonly { lat: number; lon: number }[];
    departureEpoch?: number;
    enrouteMinutes?: number;
  }): Promise<MiddlewareHttpResponse> {
    return this.request({
      method: 'POST',
      path: '/api/v1/weather/route-profile',
      body: {
        points: input.points,
        departure_epoch: input.departureEpoch ?? 0,
        enroute_minutes: input.enrouteMinutes ?? 0,
      },
      // 后端要向上游取十几个坐标的多层数据，默认 10s 偶尔不够
      timeoutMs: 25_000,
    });
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

  // ── 飞行日志 / 简报 / 落地报告的服务端持久化 ──

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
  listLandingReports(): Promise<MiddlewareHttpResponse> {
    return this.get('/api/v1/landing-reports/list');
  }

  saveLandingReport(id: string, record: unknown): Promise<MiddlewareHttpResponse> {
    return this.post('/api/v1/landing-reports/save', { body: { id, record } });
  }

  deleteLandingReport(id: string): Promise<MiddlewareHttpResponse> {
    return this.post('/api/v1/landing-reports/delete', { body: { id } });
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
    url.searchParams.set('delta', '1');
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

    // 相对基址（空串＝同源根路径，`/mw-api` ＝开发代理）：直接拼接
    let full: string;
    if (base.length === 0 || base.startsWith('/')) {
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
  // 相对基址（含同源根路径）没有主机可取，只能从页面地址推
  if (baseUrl.length === 0 || baseUrl.startsWith('/')) return deriveDefaultWebSocketUrl();
  try {
    const uri = new URL(baseUrl);
    const scheme = uri.protocol === 'https:' ? 'wss' : 'ws';
    const port = uri.port ? Number(uri.port) + 1 : 18081;
    return `${scheme}://${uri.hostname}:${port}/api/v1/simulator/ws`;
  } catch {
    return DESKTOP_DEFAULT_WS_BASE_URL;
  }
}

/** 由当前页面地址推导 WS 地址 */
function deriveDefaultWebSocketUrl(): string {
  if (typeof window === 'undefined') return DESKTOP_DEFAULT_WS_BASE_URL;
  return defaultWebSocketUrl(import.meta.env.DEV, window.location);
}

function buildProxyWebSocketUrl(token: string): string {
  const url = new URL(deriveDefaultWebSocketUrl());
  url.searchParams.set('token', token.trim());
  // 协商增量推送。老版本中间件不认这个参数，会照常发全量帧，
  // 前端的 WsDeltaAssembler 两种都吃，所以可以无条件带上。
  url.searchParams.set('delta', '1');
  return url.toString();
}

function normalizeIcao(icao: string): string {
  return icao.trim().toUpperCase();
}

/** 单例，对应 Flutter 版 `MiddlewareHttpService()` 工厂构造 */
export const MiddlewareHttpService = new MiddlewareHttpServiceImpl();
