import { describe, expect, it } from 'vitest';
import { bearingDeg, buildApproachBeam, destination } from './approach-beam';
import type { MapCoordinate, MapRunwayNavaid } from '../models/map-models';

/**
 * 进近波束几何
 *
 * 重点守住**磁航道 vs 真方位**这条线 —— 波束曾经用磁航道作图，
 * 结果整体转过一个磁差角（北京实测 7.9°），肉眼可见地歪出跑道。
 * 这类错误不写测试就只能靠人盯着地图发现。
 */

// ZBAA 18R/36L：数据取自 earth_nav.dat 与 apt.dat 的真实记录
const RUNWAY_18R_THRESHOLD: MapCoordinate = { latitude: 40.102061, longitude: 116.569672 };
const RUNWAY_36L_THRESHOLD: MapCoordinate = { latitude: 40.07345, longitude: 116.574192 };

/** 18R 的航向台：磁航道 181°，真方位 173.111° —— 两者差 7.9° 的磁差 */
const ILG_NAVAID: MapRunwayNavaid = {
  runway: '18R',
  category: 'CAT I',
  locIdent: 'ILG',
  locFrequency: '110.30',
  locCourse: 181,
  locTrueBearing: 173.111,
  glideslopeAngle: 3,
  rangeNm: 18,
  hasDme: true,
};

describe('buildApproachBeam', () => {
  it('用真方位作图，而不是磁航道', () => {
    const beam = buildApproachBeam(
      'ILS',
      '18R',
      RUNWAY_18R_THRESHOLD,
      RUNWAY_36L_THRESHOLD,
      ILG_NAVAID,
    );
    expect(beam).not.toBeNull();

    // 波束从入口朝进近方向张开 = 真方位的反向
    const [start, end] = beam!.centerline;
    const actual = bearingDeg(start, end);
    const expected = (173.111 + 180) % 360;
    expect(actual).toBeCloseTo(expected, 1);

    // 若误用磁航道 181°，方位会是 1°，与正确值差约 7.9°
    const wrong = (181 + 180) % 360;
    expect(Math.abs(actual - wrong)).toBeGreaterThan(7);
  });

  it('标签显示磁航道，几何却用真方位', () => {
    const beam = buildApproachBeam(
      'ILS',
      '18R',
      RUNWAY_18R_THRESHOLD,
      RUNWAY_36L_THRESHOLD,
      ILG_NAVAID,
    )!;
    // course 是给人看的（座舱与进近图都是磁航道）
    expect(beam.course).toBe(181);
  });

  it('没有航向台数据时退回按跑道两端算出的真方位', () => {
    const beam = buildApproachBeam(
      'RNAV',
      '18R',
      RUNWAY_18R_THRESHOLD,
      RUNWAY_36L_THRESHOLD,
      undefined,
    )!;
    const runwayTrueBearing = bearingDeg(RUNWAY_18R_THRESHOLD, RUNWAY_36L_THRESHOLD);
    expect(beam.course).toBeCloseTo(runwayTrueBearing, 3);
  });

  it('用航向台公布的作用距离作为波束长度', () => {
    const beam = buildApproachBeam(
      'ILS',
      '18R',
      RUNWAY_18R_THRESHOLD,
      RUNWAY_36L_THRESHOLD,
      ILG_NAVAID,
    )!;
    expect(beam.rangeNm).toBe(18);
  });

  it('ILS 的航道扇区是 ±2.5°（Annex 10）', () => {
    const beam = buildApproachBeam(
      'ILS',
      '18R',
      RUNWAY_18R_THRESHOLD,
      RUNWAY_36L_THRESHOLD,
      ILG_NAVAID,
    )!;
    // polygon[0] 是入口，其后是外弧；首尾两点即扇区两侧边界
    const outward = (173.111 + 180) % 360;
    const leftEdge = bearingDeg(beam.polygon[0], beam.polygon[1]);
    const rightEdge = bearingDeg(beam.polygon[0], beam.polygon[beam.polygon.length - 1]);

    const delta = (a: number, b: number) => {
      const diff = Math.abs(a - b) % 360;
      return diff > 180 ? 360 - diff : diff;
    };
    expect(delta(leftEdge, outward)).toBeCloseTo(2.5, 1);
    expect(delta(rightEdge, outward)).toBeCloseTo(2.5, 1);
  });

  it('楔形以跑道入口为顶点', () => {
    const beam = buildApproachBeam(
      'ILS',
      '18R',
      RUNWAY_18R_THRESHOLD,
      RUNWAY_36L_THRESHOLD,
      ILG_NAVAID,
    )!;
    expect(beam.polygon[0]).toEqual(RUNWAY_18R_THRESHOLD);
  });
});

describe('destination', () => {
  it('沿正北走一度纬度约 60 海里', () => {
    const from: MapCoordinate = { latitude: 0, longitude: 0 };
    const to = destination(from, 0, 60);
    expect(to.latitude).toBeCloseTo(1, 1);
    expect(to.longitude).toBeCloseTo(0, 3);
  });

  it('跨日界线时经度仍归一化在 -180..180', () => {
    const from: MapCoordinate = { latitude: 0, longitude: 179.9 };
    const to = destination(from, 90, 60);
    expect(to.longitude).toBeGreaterThanOrEqual(-180);
    expect(to.longitude).toBeLessThanOrEqual(180);
    // 越过日界线后应当变成负经度
    expect(to.longitude).toBeLessThan(0);
  });
});

describe('bearingDeg', () => {
  it('正北为 0°、正东为 90°', () => {
    const origin: MapCoordinate = { latitude: 0, longitude: 0 };
    expect(bearingDeg(origin, { latitude: 1, longitude: 0 })).toBeCloseTo(0, 3);
    expect(bearingDeg(origin, { latitude: 0, longitude: 1 })).toBeCloseTo(90, 3);
  });

  it('返回值始终在 0..360', () => {
    const origin: MapCoordinate = { latitude: 40, longitude: 116 };
    const west = bearingDeg(origin, { latitude: 40, longitude: 115 });
    expect(west).toBeGreaterThanOrEqual(0);
    expect(west).toBeLessThan(360);
    expect(west).toBeCloseTo(270, 0);
  });
});
