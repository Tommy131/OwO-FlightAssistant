/**
 * 航路气象剖面模型
 *
 * 沿计划航路取若干采样点，每点给出几个气压层上的风与温度。
 * 高度用的是上游实测的位势高度而非气压层的标准高度 ——
 * 气压面本身会被高低压顶起压低，那正是要看的东西。
 */

/** 某个采样点在某一气压层上的气象 */
export interface RouteProfileLevel {
  readonly pressureHPa: number;
  readonly altitudeFt: number;
  readonly temperatureC: number;
  readonly windSpeedKt: number;
  readonly windDirectionDeg: number;
}

/** 航路上的一个采样点 */
export interface RouteProfileSample {
  /** 在原始航路点数组里的下标 —— 靠它把剖面对回航路点名 */
  readonly index: number;
  readonly latitude: number;
  readonly longitude: number;
  readonly timeUtc?: string;
  readonly levels: readonly RouteProfileLevel[];
}

/** 一次剖面查询的结果 */
export interface RouteProfile {
  readonly samples: readonly RouteProfileSample[];
  readonly cached: boolean;
}
