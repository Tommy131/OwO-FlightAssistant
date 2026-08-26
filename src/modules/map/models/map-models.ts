/**
 * 地图模块数据模型
 * 对应 Flutter 版 `modules/map/models/*.dart`
 */

// ──────────────────────────────────────────────────────────────────────────
// 底图图层
// ──────────────────────────────────────────────────────────────────────────

export type MapLayerStyle = 'dark' | 'satellite' | 'terrain' | 'taxiway';

export const MAP_LAYER_STYLES: MapLayerStyle[] = ['dark', 'satellite', 'terrain', 'taxiway'];

/**
 * 底图瓦片地址
 *
 * 全部用带完整注记的样式：机场的停机坪、航站楼、滑行道轮廓都靠底图画出来，
 * 换成 `_nolabels` 变体会把这些地面结构一起抹掉，机场里只剩一片空白。
 *
 * 滑行道**编号**（W1 / N1 这种）另由 `renderAeroway()` 用 OSM aeroway 矢量
 * 单独画，可以随图层开关单独隐藏 —— 底图负责地面结构，矢量层负责航空标注。
 */
export function mapTileUrl(style: MapLayerStyle): string {
  switch (style) {
    case 'satellite':
      return 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
    case 'terrain':
      // OpenTopoMap：OSM 数据渲染的地形图，带等高线与晕渲。
      //
      // ⚠️ 这里原本用的是 Esri World_Topo_Map / World_Hillshade，但两者在
      // 中国等地区 z15 以上没有数据，返回的是一张画着
      // "Map data not yet available" 的 **200** 图片（恒定 2521 字节）——
      // 和 RainViewer 那张 "Zoom Level Not Supported" 一样，状态码查不出来。
      // OpenTopoMap 全球覆盖到 z17，换过来就不会再出现占位图。
      return 'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png';
    case 'taxiway':
      // OSM 标准样式是唯一能渲染出 aeroway 细节（停机坪、航站楼、
      // 滑行道几何与 ref 注记）的免费栅格源
      return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
    case 'dark':
      // CARTO 自 2026-08 起要求 API key；匿名瓦片会返回带水印的 200 图片。
      // Esri 深灰画布与项目既有卫星底图使用同一公共服务，无需把密钥下发到浏览器。
      return 'https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Dark_Gray_Base/MapServer/tile/{z}/{y}/{x}';
  }
}

/**
 * 底图的最大原生级别
 *
 * 超出源的覆盖范围时，瓦片服务往往**不返回 HTTP 错误**，而是回一张 200 的
 * 占位图（Esri 是 "Map data not yet available"，RainViewer 是
 * "Zoom Level Not Supported"）—— 靠状态码根本发现不了。
 * 返回值交给 Leaflet 的 maxNativeZoom，让它放大最后一级可用瓦片。
 *
 * 返回 undefined 表示该源在全部缩放级别都有数据。
 */
export function mapTileMaxNativeZoom(style: MapLayerStyle): number | undefined {
  // OpenTopoMap 官方只出到 z17
  if (style === 'terrain') return 17;
  return undefined;
}

/**
 * 叠在底图之上的注记层
 *
 * 卫星影像本身没有任何文字，配上 Esri 的地名/边界参考层才认得出地方；
 * 其余底图自带注记，返回 null 表示不需要。
 */
export function mapReferenceOverlayUrl(style: MapLayerStyle): string | null {
  if (style === 'satellite') {
    return 'https://server.arcgisonline.com/ArcGIS/rest/services/Reference/World_Boundaries_and_Places/MapServer/tile/{z}/{y}/{x}';
  }
  if (style === 'dark') {
    return 'https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Dark_Gray_Reference/MapServer/tile/{z}/{y}/{x}';
  }
  return null;
}

/** 浅色底图需要给标记加深色描边才看得清 */
export function isBrightMapBackground(style: MapLayerStyle): boolean {
  return style === 'terrain' || style === 'taxiway';
}

export function mapTileAttribution(style: MapLayerStyle): string {
  switch (style) {
    case 'satellite':
      return '© Esri, Maxar, Earthstar Geographics';
    case 'terrain':
      return '© OpenStreetMap contributors, SRTM | © OpenTopoMap (CC-BY-SA)';
    case 'taxiway':
      return '© OpenStreetMap contributors';
    default:
      return '© Esri, HERE, Garmin, OpenStreetMap contributors, GIS user community';
  }
}

// ──────────────────────────────────────────────────────────────────────────
// 坐标与航路
// ──────────────────────────────────────────────────────────────────────────

export interface MapCoordinate {
  readonly latitude: number;
  readonly longitude: number;
}

export interface MapRoutePoint extends MapCoordinate {
  readonly altitude?: number;
  readonly groundSpeed?: number;
  readonly timestamp?: Date;
}

// ──────────────────────────────────────────────────────────────────────────
// 机场
// ──────────────────────────────────────────────────────────────────────────

export interface MapAirportMarker {
  readonly code: string;
  readonly name?: string;
  readonly position: MapCoordinate;
  /** 主要机场（起降/备降）用更醒目的图标 */
  readonly isPrimary: boolean;
}

/**
 * 跑道端的进近设施
 *
 * 来自中间件解析的 X-Plane `earth_nav.dat`（apt.dat 里没有这些）。
 */
export interface MapRunwayNavaid {
  /** 跑道端，如 `18L` */
  readonly runway: string;
  /** ILS 类别：`CAT I` / `CAT II` / `CAT III`，只有航向台时为 `LOC` */
  readonly category?: string;
  readonly locIdent?: string;
  /** 航向台频率（MHz），如 `111.70` */
  readonly locFrequency?: string;
  /** 航向台磁航道（度），用于展示 —— 座舱和进近图上标的都是磁航道 */
  readonly locCourse?: number;
  /** 航向台真方位（度），用于画图 —— 地图上的方位角是真方位 */
  readonly locTrueBearing?: number;
  /** 下滑道角度（度），如 3.0；无下滑道时为空 */
  readonly glideslopeAngle?: number;
  /** 台站标高（英尺），约等于跑道入口标高 */
  readonly elevationFt?: number;
  /** 航向台作用距离（海里），用作进近波束长度 */
  readonly rangeNm?: number;
  readonly hasDme: boolean;
  readonly dmeIdent?: string;
}

/** 某跑道端已公布的进近类型（来自 CIFP 程序数据） */

/** 已公布的等待航线（来自 earth_hold.dat） */
// ──────────────────────────────────────────────────────────────────────────
// 公布程序（SID / STAR / 进近）
// ──────────────────────────────────────────────────────────────────────────

export type MapProcedureKind = 'SID' | 'STAR' | 'APPROACH';

/** 程序里的一段 */
export interface MapProcedureLeg {
  readonly sequence: number;
  readonly fixIdent?: string;
  /** 坐标；`hasPosition` 为假时不可用 */
  readonly position?: MapCoordinate;
  /**
   * 是否解析出了坐标。
   *
   * `CA`（飞到某高度）这类以条件结束的航段本就没有定位点，
   * 画线时要跳过它而不是把它当成 (0,0)。
   */
  readonly hasPosition: boolean;
  /** ARINC 424 航段类型：TF / DF / CF / CA / VA … */
  readonly legType?: string;
  readonly turnDirection?: string;
  /** 高度限制描述：`+` 不低于 / `-` 不高于 / `B` 区间之内 */
  readonly altitudeDescription?: string;
  readonly altitude1Ft?: number;
  readonly altitude2Ft?: number;
  readonly speedLimitKt?: number;
  readonly magneticCourse?: number;
}

/** 一条公布程序（含其某一条转换） */
export interface MapProcedure {
  readonly kind: MapProcedureKind;
  readonly name: string;
  /** 转换标识：SID/STAR 常是跑道（RW18R），进近是进场定位点 */
  readonly transition?: string;
  readonly legs: readonly MapProcedureLeg[];
}

export interface MapHoldingPattern {
  readonly fix: string;
  readonly lat: number;
  readonly lon: number;
  /** 入航道（磁航向，度） */
  readonly inboundCourse: number;
  /** 直线段时间（分钟），为 0 表示按距离飞 */
  readonly legMinutes: number;
  /** 直线段长度（海里），为 0 表示按时间飞 */
  readonly legDistanceNm: number;
  /** R=右转（标准）/ L=左转 */
  readonly turnDirection: 'L' | 'R';
  readonly minAltitudeFt: number;
  readonly maxAltitudeFt: number;
  readonly maxSpeedKt: number;
}

export interface MapRunwayGeometry {
  readonly ident: string;
  readonly leIdent?: string;
  readonly heIdent?: string;
  readonly start: MapCoordinate;
  readonly end: MapCoordinate;
  readonly lengthM?: number;
  /** 道面类型（ASPH / CONC / GRASS…），后端 Surface 字段 */
  readonly surface?: string;
}

/** 跑道的一个端点（一条跑道有两个，方向相反） */
export interface MapRunwayEnd {
  /** 该端的编号，如 `16R` */
  readonly ident: string;
  /** 该端的入口坐标 */
  readonly threshold: MapCoordinate;
  /** 所属跑道的完整编号，如 `16R/34L` */
  readonly runwayIdent: string;
}

/**
 * 把一条跑道拆成两个端点。
 *
 * 一条跑道有两个方向，从哪头起飞是完全不同的两件事（航向差 180°、
 * 滑到的位置在场地两端）。界面上只给「16R/34L」一个按钮，用户就没法
 * 指定要去哪一头 —— 只能由程序挑近的那个，而近的未必是管制给的那个。
 *
 * 端点编号优先用后端的 `leIdent` / `heIdent`；老数据只有合并编号时，
 * 按 `/` 拆开兜底。两者都没有就退回整条跑道的编号，至少还能用。
 *
 * `start` 对应 LE 端、`end` 对应 HE 端（见 map-airport-parser 的构造）。
 */
export function runwayEnds(runway: MapRunwayGeometry): MapRunwayEnd[] {
  const [fallbackLe, fallbackHe] = runway.ident.split('/');
  const leIdent = (runway.leIdent ?? fallbackLe ?? runway.ident).trim();
  const heIdent = (runway.heIdent ?? fallbackHe ?? runway.ident).trim();

  const ends: MapRunwayEnd[] = [
    { ident: leIdent, threshold: runway.start, runwayIdent: runway.ident },
    { ident: heIdent, threshold: runway.end, runwayIdent: runway.ident },
  ];
  // 两端编号一样（数据缺失导致的兜底重合）时只留一个，免得出现两个同名按钮
  return ends[0].ident === ends[1].ident ? [ends[0]] : ends;
}

/**
 * 机场地面要素（跑道 / 滑行道 / 停机坪）
 *
 * 通用底图瓦片没法按要素过滤，打开就连市政道路和商铺 POI 一起来。
 * 这些几何来自 OpenStreetMap 的 aeroway 标签（经中间件查询并缓存），
 * 只含航空要素，可以在干净底图上自己画出机场地面结构。
 */
export type MapAerowayKind = 'runway' | 'taxiway' | 'taxilane' | 'apron' | 'helipad';

export interface MapAerowayFeature {
  readonly kind: MapAerowayKind;
  /** 滑行道编号（A5 / K6）或跑道号（07L/25R） */
  readonly ref?: string;
  readonly name?: string;
  /** 首尾重合，应按面渲染（停机坪多为闭合） */
  readonly closed: boolean;
  readonly points: MapCoordinate[];
}

export interface MapParkingSpot {
  readonly name?: string;
  readonly position: MapCoordinate;
  readonly headingDeg?: number;
}

export interface MapSelectedAirportDetail {
  readonly marker: MapAirportMarker;
  readonly source?: string;
  readonly runways: string[];
  readonly runwayGeometries: MapRunwayGeometry[];
  readonly parkingSpots: MapParkingSpot[];
  /**
   * 通讯频率，**保留类型与值**而不是预先拼成串。
   *
   * 原先这里存的是 ["TOWER 118.500", ...] 这样拼好的字符串，卡片只能把它们
   * 一个个摆成 chip：大机场光地面就有五条，一排 chip 二十多个，
   * 要找的塔台频率反而淹在里面。按类别归并与配色需要结构化的类型字段，
   * 归并逻辑见 modules/common/services/airport-frequencies.ts。
   */
  readonly frequencies: { type?: string; value?: string }[];
  readonly atis?: string;
  readonly rawMetar?: string;
  readonly decodedMetar?: string;
  readonly approachRule?: string;
  /** 各跑道端的 ILS/LOC/GS/DME，按跑道端号索引 */
  readonly runwayNavaids?: Readonly<Record<string, MapRunwayNavaid>>;
  /** 各跑道端已公布的进近类型，按跑道端号索引 */
  readonly runwayApproaches?: Readonly<Record<string, readonly string[]>>;
}

// ──────────────────────────────────────────────────────────────────────────
// 航空器状态
// ──────────────────────────────────────────────────────────────────────────

export interface MapAircraftState {
  readonly position: MapCoordinate;
  readonly heading?: number;
  readonly headingTarget?: number;
  readonly altitude?: number;
  readonly groundSpeed?: number;
  readonly airspeed?: number;
  readonly pitch?: number;
  readonly bank?: number;
  readonly angleOfAttack?: number;
  readonly verticalSpeed?: number;
  readonly windSpeed?: number;
  readonly windDirection?: number;
  readonly radioAltitude?: number;
  readonly stallWarning?: boolean;
  readonly onGround?: boolean;
  readonly parkingBrake?: boolean;
}

export interface MapAIAircraftState {
  readonly id: string;
  readonly type?: string;
  readonly position: MapCoordinate;
  readonly altitude?: number;
  readonly heading?: number;
  readonly groundSpeed?: number;
  readonly onGround?: boolean;
}

// ──────────────────────────────────────────────────────────────────────────
// 告警
// ──────────────────────────────────────────────────────────────────────────

export type MapFlightAlertLevel = 'caution' | 'warning' | 'danger';

export interface MapFlightAlert {
  readonly id: string;
  readonly level: MapFlightAlertLevel;
  readonly message: string;
}

export const MAP_ALERT_LEVEL_COLOR: Record<MapFlightAlertLevel, string> = {
  caution: '#fab219',
  warning: '#ec835a',
  danger: '#d03b3b',
};

/** 级别严重度，数值越大越紧急（用于同时告警时取最高级） */
export const MAP_ALERT_LEVEL_RANK: Record<MapFlightAlertLevel, number> = {
  caution: 0,
  warning: 1,
  danger: 2,
};

/**
 * 一组告警里最紧急的那一级；没有告警返回 undefined。
 *
 * 边框只有一圈，同时报「坡度过大」和「地形逼近」时必须按最高级闪 ——
 * 取第一条或最后一条都可能把致命告警显示成黄色。
 */
export function highestAlertLevel(
  alerts: readonly MapFlightAlert[],
): MapFlightAlertLevel | undefined {
  let highest: MapFlightAlertLevel | undefined;
  for (const alert of alerts) {
    if (highest === undefined || MAP_ALERT_LEVEL_RANK[alert.level] > MAP_ALERT_LEVEL_RANK[highest]) {
      highest = alert.level;
    }
  }
  return highest;
}

// ──────────────────────────────────────────────────────────────────────────
// 计时器自动启停模式
// ──────────────────────────────────────────────────────────────────────────

export type MapAutoTimerStartMode = 'runwayMovement' | 'pushback' | 'anyMovement';
export type MapAutoTimerStopMode =
  | 'stableLanding'
  | 'runwayExitAfterLanding'
  | 'parkingArrival';

export const MAP_AUTO_TIMER_START_MODES: MapAutoTimerStartMode[] = [
  'runwayMovement',
  'pushback',
  'anyMovement',
];
export const MAP_AUTO_TIMER_STOP_MODES: MapAutoTimerStopMode[] = [
  'stableLanding',
  'runwayExitAfterLanding',
  'parkingArrival',
];

// ──────────────────────────────────────────────────────────────────────────
// 滑行道
// ──────────────────────────────────────────────────────────────────────────

export interface MapTaxiwayNode {
  readonly position: MapCoordinate;
  /** 节点名称（如滑行道交叉点编号） */
  readonly name?: string;
  readonly note?: string;
}

export interface MapTaxiwaySegment {
  /** 起点节点索引 */
  readonly fromIndex: number;
  readonly toIndex: number;
  readonly name?: string;
  readonly note?: string;
  /** 限速（kt），用于地面引导提示 */
  readonly speedLimitKt?: number;
}

/** 滑行道路线文件结构（导入导出格式，与桌面版一致） */
export interface MapTaxiwayFileData {
  readonly icao?: string;
  readonly nodes: MapTaxiwayNode[];
  readonly segments: MapTaxiwaySegment[];
}

// ──────────────────────────────────────────────────────────────────────────
// 限制空域
// ──────────────────────────────────────────────────────────────────────────

export interface MapRestrictedZone {
  readonly id: string;
  readonly name?: string;
  readonly category?: string;
  /** 多边形顶点；为空时用 center + radiusM 表示圆形区域 */
  readonly polygon: MapCoordinate[];
  readonly center?: MapCoordinate;
  readonly radiusM?: number;
  readonly lowerAltitudeFt?: number;
  readonly upperAltitudeFt?: number;
}

// ──────────────────────────────────────────────────────────────────────────
// 数据快照
// ──────────────────────────────────────────────────────────────────────────

