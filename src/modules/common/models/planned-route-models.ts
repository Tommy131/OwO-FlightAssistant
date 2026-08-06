/**
 * 计划航路模型（SimBrief 导入）
 *
 * 放在 common/ 而不是 map/ 的原因：**地图与简报两个模块都要用**。
 * 全库的约定是功能模块之间零互引，跨模块共享的状态一律落在 common/
 * （flight-data-store 就是这么做的）—— 否则删掉 map 模块简报就编不过了。
 */

/** 与 MapCoordinate 结构等价，但不依赖 map 模块 */
export interface PlannedCoordinate {
  readonly latitude: number;
  readonly longitude: number;
}

/** 航路上的机场（起降/备降） */
export interface PlannedAirport {
  readonly code: string;
  readonly name?: string;
  readonly position: PlannedCoordinate;
}

/** 计划航路上的一个点 */
export interface PlannedRoutePoint {
  readonly ident: string;
  readonly name?: string;
  readonly position: PlannedCoordinate;
  /** 计划过点高度（英尺） */
  readonly altitudeFt?: number;
  /** 进入该点所经航路；SID/STAR 段这里是程序名 */
  readonly viaAirway?: string;
  /** 属于 SID/STAR —— 据此与巡航航路分色 */
  readonly isSidStar: boolean;
  /** 航段阶段：CLB / CRZ / DSC */
  readonly stage?: string;
}

/** 计划航路的燃油部分（单位随 OFP，可能是 kg 也可能是 lbs） */
export interface PlannedFuel {
  readonly units?: string;
  readonly planRamp?: number;
  readonly planTakeoff?: number;
  readonly planLanding?: number;
  readonly enrouteBurn?: number;
  readonly alternateBurn?: number;
  readonly contingency?: number;
  readonly reserve?: number;
  readonly taxi?: number;
  readonly extra?: number;
}

/** 一份导入的飞行计划 */
export interface PlannedRoute {
  readonly flightNumber?: string;
  readonly aircraftIcao?: string;
  readonly origin: PlannedAirport;
  readonly destination: PlannedAirport;
  readonly alternate?: PlannedAirport;
  /** 原始航路串，如 "RADYR2 SLVRR DCT FEYLA ROOBY3" */
  readonly routeText?: string;
  readonly distanceNm?: number;
  readonly cruiseAltitudeFt?: number;
  /** 计划航路航时（秒），取自 OFP —— 算真实平均油耗要用它 */
  readonly enrouteSeconds?: number;
  readonly points: readonly PlannedRoutePoint[];
  readonly fuel: PlannedFuel;
  /** OFP 生成时间；用来提示「这份计划有多旧」 */
  readonly generatedAt?: Date;
}
