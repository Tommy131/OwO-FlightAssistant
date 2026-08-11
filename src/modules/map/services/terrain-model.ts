/**
 * 地形模型：高程瓦片查询、前视地形告警判定、地形分级着色
 *
 * 纯计算，不碰 React / Leaflet / Zustand / IO。瓦片由 `terrain-tiles.ts` 拉回来，
 * 本模块只对已经在手的数据做判断。
 *
 * ## 高程从哪来
 *
 * 中间件 `/api/v1/terrain/tiles` 代理在线 DEM（Open-Meteo / Copernicus DEM）。
 * 走在线 DEM 而不是读模拟器自带地形，是因为 X-Plane 侧走的是 UDP dataref 协议，
 * 只能拿到本机脚下的 AGL，对前视毫无用处；在线 DEM 查的是真实世界高程，
 * 与模拟器无关，一套实现同时覆盖 X-Plane 与 MSFS 2020/2024。
 *
 * ## 这套判定的已知局限（必须如实告知用户，不要当成机载设备用）
 *
 * - **网格约 2.8 km**，比机载 EGPWS 的 0.5 NM 粗。够判「前方有没有比我高的山」，
 *   不足以分辨单条窄山脊；
 * - **DEM 只有地形，没有障碍物**。铁塔、烟囱、索道一概不在里面；
 * - **瓦片没拉回来的地方一律不判**，宁可沉默也不能因为「查不到高程」就报平安。
 */

import type { MapCoordinate } from '../models/map-models';
import { destination, distanceInNm } from './geo';
import { MapLocalizationKeys as K } from '../localization/map-localization';

/** 一块高程瓦片，字段与中间件 `terrain.Tile` 一一对应 */
export interface TerrainTile {
  readonly south: number;
  readonly west: number;
  readonly spanDeg: number;
  readonly cellSpanDeg: number;
  readonly grid: number;
  /** 行主序高程（米），自南向北、自西向东，长度恒为 grid² */
  readonly elevationsM: readonly number[];
}

/** 地形相对本机高度的分级 */
/**
 * 地形分级。
 *
 * `safe` 是「有数据、且确认安全」，与「没有数据」是两回事 ——
 * 从前两者都是一片空白，看不出脚下到底是查过了没事，还是压根没查到。
 * 画成淡绿色就能一眼分开。
 */
export type TerrainBand = 'above' | 'near' | 'below' | 'safe';

/**
 * 分级阈值（英尺，地形高程减本机高度）
 *
 * 沿用 EGPWS 地形显示「高于本机 / 接近本机 / 低于本机」的惯例，
 * 具体分界是本项目定的，不是哪份标准的原文。
 */
export const TERRAIN_ABOVE_FT = 0;
export const TERRAIN_NEAR_FT = -1000;
export const TERRAIN_DRAW_FLOOR_FT = -2000;

/** 分级配色 —— 必须与 `models/map-legends.ts` 的 TERRAIN_LEGEND 逐条一致 */
export const TERRAIN_BAND_COLOR: Record<TerrainBand, string> = {
  above: '#d03b3b',
  near: '#ec835a',
  below: '#fab219',
  safe: '#3ddc84',
};

/** 米 → 英尺 */
export const METERS_TO_FEET = 3.280839895;

/** 前视判定参数 */
/** 告警（PULL UP 级）的前视时间 */
export const TERRAIN_WARNING_LOOK_AHEAD_SEC = 30;
/** 提示（TERRAIN AHEAD 级）的前视时间 */
export const TERRAIN_CAUTION_LOOK_AHEAD_SEC = 60;
/** 要求的最小地形余度 */
export const TERRAIN_REQUIRED_CLEARANCE_FT = 700;
/** 前视距离的上下限，避免低速时只看几百米、高速时把半个国家都算进来 */
export const TERRAIN_MIN_LOOK_AHEAD_NM = 2;
export const TERRAIN_MAX_LOOK_AHEAD_NM = 25;
/** 前视采样点数 */
export const TERRAIN_SAMPLE_COUNT = 24;
/** 低于此地速视为没在飞（停机坪 / 滑行），不判前视 */
export const TERRAIN_MIN_GROUND_SPEED_KT = 40;
/**
 * 低于此无线电高度不判前视。
 *
 * 起降阶段贴着地面飞是正常的，这时候判前视会一路狂响。那一段交给既有的
 * 「无线电高度 + 下沉率」近地告警，两者分工不重叠。
 */
export const TERRAIN_MIN_RADIO_ALTITUDE_FT = 1000;

/** 单个采样点的判定结果 */
export interface TerrainSample {
  readonly coord: MapCoordinate;
  readonly distanceNm: number;
  readonly timeSec: number;
  /** 该点地形高程（英尺 MSL） */
  readonly terrainFt: number;
  /** 按当前垂直速度推到该点时的预计高度（英尺 MSL） */
  readonly predictedAltitudeFt: number;
  /** 预计高度减地形高程 */
  readonly clearanceFt: number;
}

/** 一次前视扫描的结果 */
export interface TerrainLookAhead {
  /** 取到高程的采样点 */
  readonly samples: readonly TerrainSample[];
  /** 因为瓦片还没拉回来而跳过的采样点数 */
  readonly missingSamples: number;
  /** 余度最小的采样点 */
  readonly worst?: TerrainSample;
  /** 本次是否真的做了判定。false 表示条件不满足（在地面、太慢、太低、无数据） */
  readonly evaluated: boolean;
}

export interface TerrainLookAheadInput {
  readonly position: MapCoordinate;
  /** 真航迹角 */
  readonly trackDeg: number;
  readonly groundSpeedKt: number;
  /** 本机气压高度（英尺 MSL） */
  readonly altitudeFt: number;
  readonly verticalSpeedFpm: number;
  readonly radioAltitudeFt?: number;
  readonly onGround?: boolean;
}

/** 前视告警 —— 形状与 `flight-alerts.ts` 的 MapFlightAlert 对齐 */
export interface TerrainAheadAlert {
  readonly id: 'terrain_ahead_danger' | 'terrain_ahead_caution';
  readonly level: 'danger' | 'caution';
  readonly message: string;
}

/** 地图上要画的一个地形格子 */
export interface TerrainCell {
  readonly south: number;
  readonly west: number;
  readonly north: number;
  readonly east: number;
  /** 格子中心，用于按半径裁剪 */
  readonly centerLat: number;
  readonly centerLon: number;
  readonly band: TerrainBand;
  readonly color: string;
  readonly elevationFt: number;
}

/**
 * 地形显示半径（海里）：只画本机周围这个圆内的格子。
 *
 * 瓦片是按经纬矩形取回来的，直接全画出来，显示范围就是一块方方正正的补丁，
 * 边界横平竖直、随瓦片边界跳变，而且离本机越远的角落越没有意义 ——
 * 地形告警关心的是「我周围有什么」，那本就是个以本机为心的圆。
 * 裁成圆形之后，边界跟着飞机走，看上去才像地形雷达的扫描范围。
 */
export const TERRAIN_DISPLAY_RADIUS_NM = 40;

/**
 * 安全区的抽稀步长：每 N 行 N 列才画一个，且格子放大到 N 倍边长。
 *
 * 巡航时圆内几乎每一格都是安全的，逐格画等于把格子数翻好几倍，
 * 而它们全是同一片淡绿、彼此完全冗余。
 *
 * 放大边长是必须的 —— 只抽稀不放大，方格之间会留出空档，
 * 铺出来是一张棋盘而不是一片底色。
 *
 * 告警格不抽稀：那几格的位置和形状正是要看的东西，差一格就是差一个网格距。
 */
export const SAFE_CELL_STRIDE = 2;

/** 覆盖范围 */
export interface TerrainBounds {
  readonly south: number;
  readonly west: number;
  readonly north: number;
  readonly east: number;
}

// ────────────────────────────────────────────────────────────────────────────
// 高程查询
// ────────────────────────────────────────────────────────────────────────────

/**
 * 网格下标换算的容差，单位是「格」。
 *
 * 与中间件 `terrain.cellIndexEpsilon` 同源同因：0.25/10 这样的格距不是二进制
 * 可精确表示的数，落在格线上的点相减再相除会得到 0.9999999999998 这种
 * 刚好跨不过整数边界的值，于是被算进前一格。折算成距离不到 3 微米。
 */
const CELL_INDEX_EPSILON = 1e-9;

/** 把「距瓦片西南角的偏移」换算成网格下标；超出瓦片返回 undefined */
function cellIndex(offset: number, span: number, grid: number): number | undefined {
  if (!(offset >= 0) || offset >= span) return undefined;
  const index = Math.floor((offset / span) * grid + CELL_INDEX_EPSILON);
  return index >= grid ? grid - 1 : index;
}

/** 在单块瓦片里取高程（米）；坐标不在本瓦片内返回 undefined */
export function tileElevationM(tile: TerrainTile, coord: MapCoordinate): number | undefined {
  if (tile.grid <= 0 || tile.elevationsM.length !== tile.grid * tile.grid) return undefined;
  const span = tile.spanDeg > 0 ? tile.spanDeg : tile.cellSpanDeg * tile.grid;
  if (!(span > 0)) return undefined;
  const row = cellIndex(coord.latitude - tile.south, span, tile.grid);
  if (row === undefined) return undefined;
  const col = cellIndex(coord.longitude - tile.west, span, tile.grid);
  if (col === undefined) return undefined;
  return tile.elevationsM[row * tile.grid + col];
}

/** 在一组瓦片里取高程（米）；没有覆盖该点的瓦片返回 undefined */
export function elevationM(
  tiles: readonly TerrainTile[],
  coord: MapCoordinate,
): number | undefined {
  for (const tile of tiles) {
    const found = tileElevationM(tile, coord);
    if (found !== undefined) return found;
  }
  return undefined;
}

// ────────────────────────────────────────────────────────────────────────────
// 分级着色
// ────────────────────────────────────────────────────────────────────────────

/**
 * 按地形相对本机的高度分级；低到不值得画时返回 undefined。
 */
export function terrainBandFor(terrainFt: number, aircraftFt: number): TerrainBand | undefined {
  if (!Number.isFinite(terrainFt) || !Number.isFinite(aircraftFt)) return undefined;
  const relative = terrainFt - aircraftFt;
  if (relative >= TERRAIN_ABOVE_FT) return 'above';
  if (relative >= TERRAIN_NEAR_FT) return 'near';
  if (relative >= TERRAIN_DRAW_FLOOR_FT) return 'below';
  // 低于绘制下限即为「查过、确认安全」。返回 safe 而不是 undefined，
  // 这样界面能把「安全」与「没数据」区分开
  return 'safe';
}

/**
 * 把瓦片摊成可以直接画的格子。
 *
 * 格子本身仍是方的（高程网格就是方的，照实画）。变的是**显示范围**：
 * 给了本机位置就只产出以本机为圆心、`TERRAIN_DISPLAY_RADIUS_NM` 为半径的
 * 圆内格子，边界跟着飞机走，而不是一块随瓦片边界跳变的方补丁。
 *
 * 告警格（above / near / below）逐格产出：那几格的位置和形状正是要看的东西，
 * 差一格就是差一个网格距。
 *
 * 安全格按 `SAFE_CELL_STRIDE` 抽稀并同倍放大边长。圆内几乎每格都是安全的，
 * 逐格产出纯属冗余；只抽稀不放大则会留出空档，铺成一张棋盘。
 */
export function buildTerrainCells(
  tiles: readonly TerrainTile[],
  aircraftAltitudeFt: number,
  options: { center?: MapCoordinate; radiusNm?: number } = {},
): TerrainCell[] {
  const cells: TerrainCell[] = [];
  if (!Number.isFinite(aircraftAltitudeFt)) return cells;

  const center = options.center;
  const radiusNm = options.radiusNm ?? TERRAIN_DISPLAY_RADIUS_NM;

  for (const tile of tiles) {
    if (tile.grid <= 0 || tile.elevationsM.length !== tile.grid * tile.grid) continue;
    const span = tile.spanDeg > 0 ? tile.spanDeg : tile.cellSpanDeg * tile.grid;
    if (!(span > 0)) continue;
    const cellSpan = span / tile.grid;

    for (let row = 0; row < tile.grid; row++) {
      for (let col = 0; col < tile.grid; col++) {
        const elevationFt = tile.elevationsM[row * tile.grid + col] * METERS_TO_FEET;
        const band = terrainBandFor(elevationFt, aircraftAltitudeFt);
        if (!band) continue;
        const isSafe = band === 'safe';
        // 抽稀只对安全格生效，且只保留步长网格的左上角那一格
        if (isSafe && (row % SAFE_CELL_STRIDE !== 0 || col % SAFE_CELL_STRIDE !== 0)) continue;

        // 安全格放大到步长倍边长，方格之间才不会留出空档
        const cellExtent = isSafe ? cellSpan * SAFE_CELL_STRIDE : cellSpan;
        const south = tile.south + row * cellSpan;
        const west = tile.west + col * cellSpan;
        const centerLat = south + cellExtent / 2;
        const centerLon = west + cellExtent / 2;

        /*
         * 圆形裁剪：按格子中心到本机的距离判。
         * 拿不到本机位置就不裁 —— 宁可多画一圈，也别因为一时没有定位
         * 把整层地形显示成空白。
         */
        if (
          center &&
          distanceInNm(center, { latitude: centerLat, longitude: centerLon }) > radiusNm
        ) {
          continue;
        }

        cells.push({
          south,
          west,
          north: south + cellExtent,
          east: west + cellExtent,
          centerLat,
          centerLon,
          band,
          color: TERRAIN_BAND_COLOR[band],
          elevationFt,
        });
      }
    }
  }
  return cells;
}

// ────────────────────────────────────────────────────────────────────────────
// 覆盖范围
// ────────────────────────────────────────────────────────────────────────────

/**
 * 本机周边需要覆盖的范围。
 *
 * 只取本机周边而不是整个视野：机载 EGPWS 的地形显示同样只画导航显示量程内的
 * 地形，而且瓦片是要真金白银打上游的，缩到最小比例尺就拉全球没有意义。
 */
export function terrainBoundsAround(center: MapCoordinate, radiusNm: number): TerrainBounds {
  const radius = Math.max(1, radiusNm);
  const north = destination(center, 0, radius);
  const south = destination(center, 180, radius);
  const east = destination(center, 90, radius);
  const west = destination(center, 270, radius);
  return {
    south: south.latitude,
    west: west.longitude,
    north: north.latitude,
    east: east.longitude,
  };
}

// ────────────────────────────────────────────────────────────────────────────
// 前视判定
// ────────────────────────────────────────────────────────────────────────────

/**
 * 沿当前航迹前视扫描地形。
 *
 * 预测高度只投影**下降**：还在爬升时假定就此改平，这样算出来的余度更小、
 * 判定更保守 —— 「我等会儿会爬上去」不该成为不报警的理由。
 */
export function sampleTerrainAhead(
  input: TerrainLookAheadInput,
  tiles: readonly TerrainTile[],
): TerrainLookAhead {
  const empty: TerrainLookAhead = { samples: [], missingSamples: 0, evaluated: false };

  if (input.onGround === true) return empty;
  if (!Number.isFinite(input.altitudeFt)) return empty;
  if (!Number.isFinite(input.trackDeg)) return empty;
  if (!Number.isFinite(input.groundSpeedKt) || input.groundSpeedKt < TERRAIN_MIN_GROUND_SPEED_KT) {
    return empty;
  }
  if (
    input.radioAltitudeFt !== undefined &&
    Number.isFinite(input.radioAltitudeFt) &&
    input.radioAltitudeFt < TERRAIN_MIN_RADIO_ALTITUDE_FT
  ) {
    return empty;
  }

  const reachNm = clamp(
    (input.groundSpeedKt * TERRAIN_CAUTION_LOOK_AHEAD_SEC) / 3600,
    TERRAIN_MIN_LOOK_AHEAD_NM,
    TERRAIN_MAX_LOOK_AHEAD_NM,
  );
  const stepNm = reachNm / TERRAIN_SAMPLE_COUNT;
  // 只投影下降；爬升按改平算
  const projectedVsFpm = Math.min(input.verticalSpeedFpm ?? 0, 0);

  const samples: TerrainSample[] = [];
  let missingSamples = 0;
  let worst: TerrainSample | undefined;

  for (let step = 1; step <= TERRAIN_SAMPLE_COUNT; step++) {
    const distanceNm = stepNm * step;
    const coord = destination(input.position, input.trackDeg, distanceNm);
    const elevation = elevationM(tiles, coord);
    if (elevation === undefined) {
      missingSamples++;
      continue;
    }
    const timeSec = (distanceNm / input.groundSpeedKt) * 3600;
    const predictedAltitudeFt = input.altitudeFt + (projectedVsFpm * timeSec) / 60;
    const terrainFt = elevation * METERS_TO_FEET;
    const sample: TerrainSample = {
      coord,
      distanceNm,
      timeSec,
      terrainFt,
      predictedAltitudeFt,
      clearanceFt: predictedAltitudeFt - terrainFt,
    };
    samples.push(sample);
    if (!worst || sample.clearanceFt < worst.clearanceFt) worst = sample;
  }

  return {
    samples,
    missingSamples,
    worst,
    // 一个点都没取到就等于没判 —— 不能把「查不到高程」当成「前方没有山」
    evaluated: samples.length > 0,
  };
}

/**
 * 由前视扫描结果给出告警。没有触发条件时返回 null。
 */
export function buildTerrainAheadAlert(lookAhead: TerrainLookAhead): TerrainAheadAlert | null {
  if (!lookAhead.evaluated) return null;

  let breach: TerrainSample | undefined;
  for (const sample of lookAhead.samples) {
    if (sample.clearanceFt >= TERRAIN_REQUIRED_CLEARANCE_FT) continue;
    if (!breach || sample.timeSec < breach.timeSec) breach = sample;
  }
  if (!breach) return null;

  if (breach.timeSec <= TERRAIN_WARNING_LOOK_AHEAD_SEC) {
    return {
      id: 'terrain_ahead_danger',
      level: 'danger',
      message: K.alertTerrainAheadDanger,
    };
  }
  if (breach.timeSec <= TERRAIN_CAUTION_LOOK_AHEAD_SEC) {
    return {
      id: 'terrain_ahead_caution',
      level: 'caution',
      message: K.alertTerrainAheadCaution,
    };
  }
  return null;
}

function clamp(value: number, min: number, max: number): number {
  return Math.min(Math.max(value, min), max);
}
