import { describe, expect, it } from 'vitest';
import { buildHoldingGeometry } from './holding-geometry';
import type { MapHoldingPattern } from '../models/map-models';

/**
 * 等待航线几何
 *
 * 尺寸不是随便画的：转弯半径按标准转弯率 r = V/(20π)，直线段由公布的
 * 时间或距离决定。这些数字错了，画出来的环圈大小就没有意义。
 */

// ZBAA AA320：真实公布数据（入航道 161°、右转、1.5 分钟腿）
const AA320: MapHoldingPattern = {
  fix: 'AA320',
  lat: 40.0,
  lon: 116.5,
  inboundCourse: 161,
  legMinutes: 1.5,
  legDistanceNm: 0,
  turnDirection: 'R',
  minAltitudeFt: 9850,
  maxAltitudeFt: 0,
  maxSpeedKt: 0,
};

describe('buildHoldingGeometry', () => {
  it('转弯半径按标准转弯率 r = V/(20π)', () => {
    const geometry = buildHoldingGeometry({ ...AA320, maxSpeedKt: 230 })!;
    // 230kt 下：230 / (20π) ≈ 3.66 NM
    expect(geometry.radiusNm).toBeCloseTo(230 / (20 * Math.PI), 2);
  });

  it('没公布速度时用默认等待速度', () => {
    const withSpeed = buildHoldingGeometry({ ...AA320, maxSpeedKt: 230 })!;
    const withoutSpeed = buildHoldingGeometry({ ...AA320, maxSpeedKt: 0 })!;
    // 默认就是 230kt，两者应当一致
    expect(withoutSpeed.radiusNm).toBeCloseTo(withSpeed.radiusNm, 6);
  });

  it('按时间飞时，腿长 = 速度 × 分钟', () => {
    const geometry = buildHoldingGeometry({ ...AA320, legMinutes: 1, maxSpeedKt: 240 })!;
    // 240kt 飞 1 分钟 = 4 NM
    expect(geometry.legNm).toBeCloseTo(4, 3);
  });

  it('公布了距离时优先用距离', () => {
    const geometry = buildHoldingGeometry({
      ...AA320,
      legMinutes: 1.5,
      legDistanceNm: 7,
      maxSpeedKt: 230,
    })!;
    expect(geometry.legNm).toBe(7);
  });

  it('航线闭合：末点回到起点', () => {
    const geometry = buildHoldingGeometry(AA320)!;
    const first = geometry.path[0];
    const last = geometry.path[geometry.path.length - 1];
    expect(last.latitude).toBeCloseTo(first.latitude, 9);
    expect(last.longitude).toBeCloseTo(first.longitude, 9);
  });

  it('定位点落在航线上（它是入航段的终点）', () => {
    const geometry = buildHoldingGeometry(AA320)!;
    const onPath = geometry.path.some(
      (point) =>
        Math.abs(point.latitude - AA320.lat) < 1e-9 &&
        Math.abs(point.longitude - AA320.lon) < 1e-9,
    );
    expect(onPath).toBe(true);
  });

  it('左右转的出航边分居入航道两侧', () => {
    const right = buildHoldingGeometry({ ...AA320, turnDirection: 'R' })!;
    const left = buildHoldingGeometry({ ...AA320, turnDirection: 'L' })!;
    expect(right.turnDirection).toBe('R');
    expect(left.turnDirection).toBe('L');

    // 取各自离定位点最远的点，两者应当分布在入航道的相反侧
    const spread = (path: typeof right.path) =>
      path.reduce(
        (acc, p) => acc + (p.longitude - AA320.lon),
        0,
      ) / path.length;
    expect(Math.sign(spread(right.path))).not.toBe(Math.sign(spread(left.path)));
  });

  it('坐标非法时返回 null 而不是画到 (0,0)', () => {
    expect(buildHoldingGeometry({ ...AA320, lat: Number.NaN })).toBeNull();
    expect(buildHoldingGeometry({ ...AA320, inboundCourse: Number.NaN })).toBeNull();
  });
});
