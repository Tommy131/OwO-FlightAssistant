/**
 * 地图图层的配色与层级常量
 *
 * 单独成文件是因为它们**跨图层共享**：`AEROWAY_COLORS` 与 `MARKER_Z` 同时被
 * 地面结构图层与机场详情图层用到，留在任一方都会造成图层之间互相 import。
 *
 * 配色取自真实机场的视觉习惯（沥青道面、黄色滑行道、绿色停机坪），
 * 改动前请一并看 `docs/DESIGN.md` 的图层说明。
 */

import type { ApproachBeamKind } from '../../services/approach-beam';

/**
 * 地面要素配色 —— 照真实机场地面标线与标记牌来
 *
 * ── 道面标线 ──
 * 跑道上的标线是**白色**，滑行道与机坪上的标线是**黄色**，这是 ICAO Annex 14
 * 的硬规定，也是飞行员在座舱里唯一的判断依据。所以：
 *   跑道 = 深沥青色道面 + 白色中线
 *   滑行道 = 灰色道面 + 航空黄中线
 * 道面色（而不是纯黑描边）才让线看起来像铺装，浅底图上也压得住。
 *
 * ── 机位引导线 ──
 * 从停机位推出接入滑行道的那段（stand lead-in / taxilane）实际也是黄色，
 * 只是线更窄。这里保持在同一个黄色家族里、压暗一档并收窄，
 * 既没有编出现实中不存在的颜色，又能一眼分出主滑行道和机位引导线。
 */
export const AEROWAY_COLORS = {
  /** 跑道沥青道面 */
  runwaySurface: '#24282e',
  /** 跑道标线：白色（Annex 14） */
  runwayCenterline: '#ffffff',
  /** 滑行道道面：混凝土灰 */
  taxiwayCasing: '#3c424b',
  /** 滑行道中线：航空黄 */
  taxiway: '#f0c420',
  /** 机位引导线：同族黄压暗一档 */
  taxilane: '#c9a227',
  apronFill: '#39404b',
  apronStroke: '#525c6b',
  helipad: '#4db7ff',
} as const;

/**
 * 滑行道标记牌配色
 *
 * 真机场的**位置牌**（告诉你「你正在 W1 上」）是：黑底 + 黄字 + 黄边框。
 * 我们这些标签正是位置牌的作用，所以照搬这套配色 ——
 * 既符合飞行员的既有认知，四十来个黑底小牌子也比一片纯黄块耐看得多。
 * （黄底黑字是**方向牌**，用于指路，含义不同，不能混用。）
 */
export const TAXIWAY_SIGN = {
  background: '#101215',
  border: '#f0c420',
  text: '#f0c420',
  /** 机位引导线的牌子压暗一档，与道面同步 */
  laneBorder: '#a8862a',
  laneText: '#c9a227',
} as const;

/**
 * 标记的叠放层级
 *
 * Leaflet 把同一个 pane 里的标记按**纬度**自动排 z-index（越靠南越上层），
 * 不给 zIndexOffset 的话，一个滑行道编号牌完全可能压在跑道进近信息板上 ——
 * 恰好那块牌子才是进近时最该看清的东西。这里按重要性显式分层。
 *
 * 只有**互相重叠**的标记才需要比较，而重叠意味着纬度几乎相同、
 * 自动 z 值只差几个像素，所以层间留几百的间距已经绰绰有余。
 * 本机图标用的是 1000（见上方 aircraft），保持在最顶层。
 */
export const MARKER_Z = {
  /** 滑行道编号牌 */
  taxiwayRef: 300,
  /** 跑道端点 / 进近设施信息板：必须压过滑行道与停机位标签 */
  runwayEndpoint: 900,
} as const;

/**
 * 进近波束配色
 *
 * 按导航源分色，和进近图上的习惯一致：
 * ILS 用青（无线电波束），GLS 用品红（GBAS/卫星），RNAV 用绿（GNSS）。
 */
export const BEAM_STYLE: Record<ApproachBeamKind, { color: string; dash?: string }> = {
  ILS: { color: '#4db7ff' },
  GLS: { color: '#e879f9', dash: '10 6' },
  RNAV: { color: '#35d07f', dash: '6 6' },
};

/** 等待航线配色：进近图上等待航线通常与航路信息同色系 */
export const HOLDING_COLOR = '#c084fc';

/** 地图上的 ILS 类别配色，与卡片保持一致 */
export const ILS_CATEGORY_MAP_COLOR: Record<string, string> = {
  'CAT I': '#4db7ff',
  'CAT II': '#35d07f',
  'CAT III': '#a78bfa',
  ILS: '#4db7ff',
  LOC: '#9aa4b2',
};

/** 空域严重度配色，与中间件返回的 severity 字段对应 */
export const AIRSPACE_SEVERITY_COLOR: Record<string, string> = {
  critical: '#d03b3b',
  warning: '#ec835a',
  advisory: '#fab219',
};
