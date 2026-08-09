/**
 * 起落架构型识别（纯计算）
 *
 * 目的是把「这架飞机的起落架长什么样」从机型信息里判出来，
 * 好让监控页画出与真机相符的示意图，而不是所有机型都一个样。
 *
 * ── 为什么按机型查表而不是看模拟器上报的收放比例 ──
 * 收放比例只说明「现在放下了多少」，说明不了「有没有收放功能」。
 * 固定起落架的塞斯纳比例恒为 1，看起来和一架已放下的 737 毫无区别；
 * 而一架正在收轮的 737 中途比例也是 0.5，同样区分不出。
 * 构型是机型的固有属性，只能靠机型判。
 */

/** 主起落架的机轮排布 */
export type GearBogie =
  /** 单轮（轻型机、支线机的前起） */
  | 'single'
  /** 双轮并排（737/A320 主起、多数窄体前起） */
  | 'dual'
  /** 四轮小车（757/767/A330 主起） */
  | 'bogie4'
  /** 六轮小车（777/A350 主起） */
  | 'bogie6';

export interface GearLayout {
  /** 能不能收放；false = 固定起落架，永远画成放下 */
  readonly retractable: boolean;
  /** 前起机轮数 */
  readonly noseWheels: number;
  /** 主起支柱数（747 是 4 支：两组机身 + 两组机翼） */
  readonly mainStruts: number;
  /** 每支主起的机轮排布 */
  readonly bogie: GearBogie;
  /** 判定依据，显示在示意图下方，让用户知道这是按什么画的 */
  readonly source: string;
}

/** 默认构型：窄体客机（737/A320 那一类），也是识别不出机型时的兜底 */
const NARROW_BODY: GearLayout = {
  retractable: true,
  noseWheels: 2,
  mainStruts: 2,
  bogie: 'dual',
  source: 'NARROW BODY',
};

/**
 * 机型前缀 → 构型。
 *
 * 键是 ICAO 机型代码的前缀，按**从长到短**匹配，
 * 所以 `B74` 要排在 `B7` 之类的泛化前缀之前（这里没有泛化前缀，
 * 但排序逻辑保证以后加了也不会被抢先匹配）。
 */
const BY_ICAO_PREFIX: readonly (readonly [string, GearLayout])[] = [
  // ── 固定起落架的通用航空器 ──
  ['C15', { retractable: false, noseWheels: 1, mainStruts: 2, bogie: 'single', source: 'FIXED GEAR' }],
  ['C17', { retractable: false, noseWheels: 1, mainStruts: 2, bogie: 'single', source: 'FIXED GEAR' }],
  ['P28', { retractable: false, noseWheels: 1, mainStruts: 2, bogie: 'single', source: 'FIXED GEAR' }],
  ['DA4', { retractable: false, noseWheels: 1, mainStruts: 2, bogie: 'single', source: 'FIXED GEAR' }],
  ['DA2', { retractable: false, noseWheels: 1, mainStruts: 2, bogie: 'single', source: 'FIXED GEAR' }],
  ['SR2', { retractable: false, noseWheels: 1, mainStruts: 2, bogie: 'single', source: 'FIXED GEAR' }],

  // ── 可收放的轻型/公务机 ──
  ['BE9', { retractable: true, noseWheels: 1, mainStruts: 2, bogie: 'single', source: 'LIGHT TWIN' }],
  ['C25', { retractable: true, noseWheels: 1, mainStruts: 2, bogie: 'single', source: 'BIZ JET' }],

  /*
   * ── 747：四支主起 ──
   * 两组挂在机身、两组挂在机翼，各 4 轮，共 16 个主轮。
   * 画成两支的话，和 737 就没区别了 —— 而这恰恰是 747 最好认的特征。
   */
  ['B74', { retractable: true, noseWheels: 2, mainStruts: 4, bogie: 'bogie4', source: 'B747 · 4 STRUTS' }],
  ['A38', { retractable: true, noseWheels: 2, mainStruts: 4, bogie: 'bogie4', source: 'A380 · 4 STRUTS' }],

  // ── 六轮小车的重型双发 ──
  ['B77', { retractable: true, noseWheels: 2, mainStruts: 2, bogie: 'bogie6', source: 'B777 · 6-WHEEL' }],
  ['A35', { retractable: true, noseWheels: 2, mainStruts: 2, bogie: 'bogie6', source: 'A350 · 6-WHEEL' }],

  // ── 四轮小车的宽体 ──
  ['B75', { retractable: true, noseWheels: 2, mainStruts: 2, bogie: 'bogie4', source: 'B757 · 4-WHEEL' }],
  ['B76', { retractable: true, noseWheels: 2, mainStruts: 2, bogie: 'bogie4', source: 'B767 · 4-WHEEL' }],
  ['B78', { retractable: true, noseWheels: 2, mainStruts: 2, bogie: 'bogie4', source: 'B787 · 4-WHEEL' }],
  ['A33', { retractable: true, noseWheels: 2, mainStruts: 2, bogie: 'bogie4', source: 'A330 · 4-WHEEL' }],
  ['A34', { retractable: true, noseWheels: 2, mainStruts: 4, bogie: 'bogie4', source: 'A340 · 4 STRUTS' }],
  ['MD1', { retractable: true, noseWheels: 2, mainStruts: 2, bogie: 'bogie4', source: 'MD-11 · 4-WHEEL' }],

  // ── 双轮窄体 ──
  ['B73', { retractable: true, noseWheels: 2, mainStruts: 2, bogie: 'dual', source: 'B737 · DUAL' }],
  ['B72', { retractable: true, noseWheels: 2, mainStruts: 2, bogie: 'dual', source: 'B727 · DUAL' }],
  ['A31', { retractable: true, noseWheels: 2, mainStruts: 2, bogie: 'dual', source: 'A320 FAM · DUAL' }],
  ['A32', { retractable: true, noseWheels: 2, mainStruts: 2, bogie: 'dual', source: 'A320 FAM · DUAL' }],
  ['E17', { retractable: true, noseWheels: 2, mainStruts: 2, bogie: 'dual', source: 'E-JET · DUAL' }],
  ['E19', { retractable: true, noseWheels: 2, mainStruts: 2, bogie: 'dual', source: 'E-JET · DUAL' }],
  ['CRJ', { retractable: true, noseWheels: 2, mainStruts: 2, bogie: 'dual', source: 'CRJ · DUAL' }],
];

/** 机型名里出现这些词，按固定起落架处理（没有 ICAO 代码时的退路） */
const FIXED_GEAR_HINTS: readonly string[] = [
  'CESSNA 152', 'CESSNA 172', 'C172', 'SKYHAWK',
  'CHEROKEE', 'ARCHER', 'WARRIOR',
  'DA40', 'DA20', 'DIAMOND DA',
  'CIRRUS', 'SR20', 'SR22',
  'CUB', 'SAVAGE', 'ICON A5', 'BONANZA',
];

/** 机型名里出现这些词，按 747 的四支主起处理 */
const FOUR_STRUT_HINTS: readonly string[] = ['747', 'A380', 'A340'];

/**
 * 判断起落架构型。
 *
 * @param icao  ICAO 机型代码（B738 / A320 / C172）
 * @param title 机模显示名，ICAO 代码缺失时按关键词兜底
 */
export function resolveGearLayout(icao?: string, title?: string): GearLayout {
  const code = (icao ?? '').trim().toUpperCase();
  if (code.length > 0) {
    // 前缀从长到短匹配，避免短前缀抢在长前缀之前命中
    const sorted = [...BY_ICAO_PREFIX].sort((a, b) => b[0].length - a[0].length);
    for (const [prefix, layout] of sorted) {
      if (code.startsWith(prefix)) return layout;
    }
  }

  const name = (title ?? '').trim().toUpperCase();
  if (name.length > 0) {
    if (FIXED_GEAR_HINTS.some((hint) => name.includes(hint))) {
      return {
        retractable: false,
        noseWheels: 1,
        mainStruts: 2,
        bogie: 'single',
        source: 'FIXED GEAR',
      };
    }
    if (FOUR_STRUT_HINTS.some((hint) => name.includes(hint))) {
      return {
        retractable: true,
        noseWheels: 2,
        mainStruts: 4,
        bogie: 'bogie4',
        source: '4 STRUTS',
      };
    }
  }
  return NARROW_BODY;
}

/** 每种排布的机轮数 */
export function wheelsPerStrut(bogie: GearBogie): number {
  switch (bogie) {
    case 'single':
      return 1;
    case 'dual':
      return 2;
    case 'bogie4':
      return 4;
    case 'bogie6':
      return 6;
  }
}

/**
 * 固定起落架永远是放下状态。
 *
 * 模拟器对固定起落架机型上报的比例并不一致（有的恒为 1，有的干脆不给），
 * 直接照搬会让塞斯纳显示成"起落架收上"—— 那是不存在的状态。
 */
export function effectiveGearRatio(layout: GearLayout, ratio: number | undefined): number {
  if (!layout.retractable) return 1;
  if (ratio === undefined) return 0;
  // 有的模拟器给的是百分比
  return ratio > 1 && ratio <= 100 ? ratio / 100 : ratio;
}
