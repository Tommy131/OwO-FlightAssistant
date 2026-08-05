import type { MapCoordinate, MapRunwayNavaid } from '../models/map-models';

/**
 * 进近波束几何
 *
 * 把跑道入口 + 航道 + 张角画成一个楔形，也就是进近图上那条从跑道向外张开的
 * 引导扇区。飞机落在扇区里就意味着横向偏差在满刻度范围内。
 *
 * ── 张角取值依据 ──
 * ILS 航向台的**航道扇区**（course sector）按 ICAO Annex 10 定义为
 * 满刻度偏转 ±2.5°（跑道入口处对应约 ±105m 的宽度）。
 * GLS / RNAV(LPV) 的横向引导同样是角度制，最终进近段的张角与 ILS 同量级，
 * 这里按各自的典型值给，并在图例里标明类型。
 *
 * ⚠️ 这是按标准张角画出的**示意扇区**，不是某条具体程序公布的保护区。
 * 真实运行请以 AIP 进近图为准。
 */

/** 波束类型：决定张角与配色 */
export type ApproachBeamKind = 'ILS' | 'GLS' | 'RNAV';

export interface ApproachBeam {
  readonly kind: ApproachBeamKind;
  readonly runway: string;
  /** 楔形多边形顶点（入口 → 左边界 → 右边界 → 回到入口） */
  readonly polygon: MapCoordinate[];
  /** 中线，从入口延伸到波束尽头 */
  readonly centerline: readonly [MapCoordinate, MapCoordinate];
  /** 磁航道（度），标签上显示的就是这个 */
  readonly course: number;
  /** 波束长度（海里） */
  readonly rangeNm: number;
  readonly navaid?: MapRunwayNavaid;
}

/** 各类波束的半张角（度） */
const HALF_ANGLE_DEG: Record<ApproachBeamKind, number> = {
  // ILS 航道扇区满刻度 ±2.5°（Annex 10）
  ILS: 2.5,
  // GLS 横向引导按 GBAS 最终进近段，量级与 ILS 相同
  GLS: 2.5,
  // RNAV(GNSS) 最终进近段横向偏差略宽
  RNAV: 3,
};

/** 拿不到台站作用距离时的默认波束长度（海里） */
const DEFAULT_RANGE_NM = 18;

/** 画多少段来近似扇形的外弧 */
const ARC_SEGMENTS = 12;

const EARTH_RADIUS_NM = 3440.065;

/**
 * 为一个跑道端生成进近波束
 *
 * @param threshold 跑道入口坐标
 * @param farEnd    跑道另一端，用来在没有航向台数据时定出航道方向
 */
export function buildApproachBeam(
  kind: ApproachBeamKind,
  runway: string,
  threshold: MapCoordinate,
  farEnd: MapCoordinate,
  navaid?: MapRunwayNavaid,
): ApproachBeam | null {
  /*
   * ⚠️ 画图必须用**真方位**，标签才用磁航道。
   *
   * 地图上的方位角是真方位，而航向台公布的 locCourse 是**磁**航道，
   * 两者差一个磁差角。直接拿磁航道去画，波束会整体转过那个角度 ——
   * 北京约 6°，一眼就能看出没对正跑道。
   *
   * 真方位拿不到时退回按跑道两端算出来的方位（那本来就是真方位）。
   */
  const trueBearing = navaid?.locTrueBearing ?? bearingDeg(threshold, farEnd);
  // 标签上显示的航道：有磁航道就用磁航道，没有就退回真方位
  const course = navaid?.locCourse ?? trueBearing;
  if (!Number.isFinite(trueBearing) || !Number.isFinite(course)) return null;

  const rangeNm = navaid?.rangeNm ?? DEFAULT_RANGE_NM;
  const half = HALF_ANGLE_DEG[kind];
  // 波束从入口**朝进近方向**张开，也就是跑道走向的反方向
  const outward = (trueBearing + 180) % 360;

  const polygon: MapCoordinate[] = [threshold];
  for (let i = 0; i <= ARC_SEGMENTS; i++) {
    const offset = -half + (2 * half * i) / ARC_SEGMENTS;
    polygon.push(destination(threshold, outward + offset, rangeNm));
  }

  return {
    kind,
    runway,
    polygon,
    centerline: [threshold, destination(threshold, outward, rangeNm)],
    course,
    rangeNm,
    navaid,
  };
}

/**
 * 从某点按方位角走一段距离
 *
 * 大圆公式；这个尺度（几十海里）用平面近似也行，但大圆写起来一样简单，
 * 高纬度时还不会变形。
 */
export function destination(
  from: MapCoordinate,
  bearing: number,
  distanceNm: number,
): MapCoordinate {
  const angular = distanceNm / EARTH_RADIUS_NM;
  const theta = (bearing * Math.PI) / 180;
  const lat1 = (from.latitude * Math.PI) / 180;
  const lon1 = (from.longitude * Math.PI) / 180;

  const lat2 = Math.asin(
    Math.sin(lat1) * Math.cos(angular) + Math.cos(lat1) * Math.sin(angular) * Math.cos(theta),
  );
  const lon2 =
    lon1 +
    Math.atan2(
      Math.sin(theta) * Math.sin(angular) * Math.cos(lat1),
      Math.cos(angular) - Math.sin(lat1) * Math.sin(lat2),
    );

  return {
    latitude: (lat2 * 180) / Math.PI,
    // 归一化到 -180..180，跨日界线时才不会画出一条横穿地图的线
    longitude: (((lon2 * 180) / Math.PI + 540) % 360) - 180,
  };
}

export function bearingDeg(from: MapCoordinate, to: MapCoordinate): number {
  const lat1 = (from.latitude * Math.PI) / 180;
  const lat2 = (to.latitude * Math.PI) / 180;
  const deltaLon = ((to.longitude - from.longitude) * Math.PI) / 180;
  const y = Math.sin(deltaLon) * Math.cos(lat2);
  const x =
    Math.cos(lat1) * Math.sin(lat2) - Math.sin(lat1) * Math.cos(lat2) * Math.cos(deltaLon);
  return ((Math.atan2(y, x) * 180) / Math.PI + 360) % 360;
}
