import { MapLocalizationKeys as K } from '../localization/map-localization';

/**
 * 图层图例定义
 *
 * ⚠️ 数值区间与配色必须与中间件 `internal/apps/common/http/handlers/v1/map_overlay.go`
 * 的 `colorForLayer()` 逐条对齐 —— 那里是像素真正上色的地方，
 * 这里只是把同一套规则画成色标。改了一边就要改另一边。
 */

export type MapLegendId =
  | 'radar'
  | 'rain'
  | 'wind'
  | 'pressure'
  | 'temp'
  | 'airspace'
  | 'terrain';

/** 连续色带：渐变条 + 刻度 */
export interface MapLegendRamp {
  readonly kind: 'ramp';
  readonly id: MapLegendId;
  readonly titleKey: string;
  /** 单位；纯定性的色带（雷达回波）留空 */
  readonly unit?: string;
  /** 渐变停靠色，顺序即由弱到强 */
  readonly colors: readonly string[];
  /** 显示在色带下方的刻度值，均匀分布 */
  readonly ticks: readonly string[];
}

/** 离散色块：一个类别一块颜色 */
export interface MapLegendSwatches {
  readonly kind: 'swatches';
  readonly id: MapLegendId;
  readonly titleKey: string;
  readonly items: readonly { readonly color: string; readonly labelKey: string }[];
}

export type MapLegend = MapLegendRamp | MapLegendSwatches;

/**
 * RainViewer 气象雷达（配色方案 4「Universal Blue」）
 *
 * 该方案的颜色是从真实瓦片里逐像素采样得到的，不是估的：
 * 浅青→深蓝表示由弱到中等的降水，黄→橙→红是对流强降水，品红为最强回波。
 * 上游只提供图像不提供数值刻度，因此这里按定性的「弱→强」标注。
 */
const RADAR_LEGEND: MapLegendRamp = {
  kind: 'ramp',
  id: 'radar',
  titleKey: K.legendRadarTitle,
  colors: [
    '#88ddee',
    '#00a3e0',
    '#0077aa',
    '#004768',
    '#ffee00',
    '#ffc500',
    '#ff4400',
    '#cd0d00',
    '#ff6cff',
  ],
  ticks: [K.legendWeak, K.legendStrong],
};

/** 降雨量：Open-Meteo precipitation，0–20 mm/h */
const RAIN_LEGEND: MapLegendRamp = {
  kind: 'ramp',
  id: 'rain',
  titleKey: K.legendRainTitle,
  unit: 'mm/h',
  colors: ['#88ddee', '#00a3e0', '#00699c', '#ffd200', '#e62800'],
  ticks: ['0', '5', '10', '15', '20+'],
};

/** 高空风：Open-Meteo wind_speed_10m，0–120 km/h */
const WIND_LEGEND: MapLegendRamp = {
  kind: 'ramp',
  id: 'wind',
  titleKey: K.legendWindTitle,
  unit: 'km/h',
  colors: ['#3a62c4', '#3eadce', '#62d288', '#f8ca48', '#e0564a'],
  ticks: ['0', '30', '60', '90', '120+'],
};

/** 气压：Open-Meteo pressure_msl，970–1045 hPa */
const PRESSURE_LEGEND: MapLegendRamp = {
  kind: 'ramp',
  id: 'pressure',
  titleKey: K.legendPressureTitle,
  unit: 'hPa',
  colors: ['#462080', '#2b77aa', '#4aa85e', '#edc948'],
  ticks: ['970', '995', '1020', '1045'],
};

/** 温度：Open-Meteo temperature_2m，−35–45 °C */
const TEMP_LEGEND: MapLegendRamp = {
  kind: 'ramp',
  id: 'temp',
  titleKey: K.legendTempTitle,
  unit: '°C',
  colors: ['#3252b9', '#3da7d8', '#7bd06f', '#f5c44b', '#e0574a'],
  ticks: ['-35', '-15', '5', '25', '45'],
};

/** 限制空域：与 map-canvas 的 AIRSPACE_SEVERITY_COLOR 一致 */
const AIRSPACE_LEGEND: MapLegendSwatches = {
  kind: 'swatches',
  id: 'airspace',
  titleKey: K.legendAirspaceTitle,
  items: [
    { color: '#d03b3b', labelKey: K.legendAirspaceCritical },
    { color: '#ec835a', labelKey: K.legendAirspaceWarning },
    { color: '#fab219', labelKey: K.legendAirspaceAdvisory },
  ],
};

/** 地形告警：与 map-models 的 MAP_ALERT_LEVEL_COLOR 一致 */
const TERRAIN_LEGEND: MapLegendSwatches = {
  kind: 'swatches',
  id: 'terrain',
  titleKey: K.legendTerrainTitle,
  items: [
    { color: '#d03b3b', labelKey: K.legendTerrainDanger },
    { color: '#ec835a', labelKey: K.legendTerrainWarning },
    { color: '#fab219', labelKey: K.legendTerrainCaution },
  ],
};

export const MAP_LEGENDS: Record<MapLegendId, MapLegend> = {
  radar: RADAR_LEGEND,
  rain: RAIN_LEGEND,
  wind: WIND_LEGEND,
  pressure: PRESSURE_LEGEND,
  temp: TEMP_LEGEND,
  airspace: AIRSPACE_LEGEND,
  terrain: TERRAIN_LEGEND,
};

/** 把色带停靠色拼成 CSS linear-gradient */
export function legendGradient(colors: readonly string[]): string {
  if (colors.length === 1) return colors[0];
  const stops = colors.map(
    (color, index) => `${color} ${(index / (colors.length - 1)) * 100}%`,
  );
  return `linear-gradient(90deg, ${stops.join(', ')})`;
}
