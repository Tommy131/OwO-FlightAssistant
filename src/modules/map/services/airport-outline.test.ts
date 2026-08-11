import { describe, expect, it } from 'vitest';
import { computeAirportOutline } from './airport-outline';
import type { MapSelectedAirportDetail } from '../models/map-models';

/**
 * 机场轮廓（凸包 + 外扩）
 *
 * 后端不提供机场边界多边形，这个轮廓是由跑道端点与停机位算出来的近似值。
 * 关键性质：必须**包住**所有输入点，且点太少时老实返回 null 而不是画出畸形图。
 */

function detailWith(points: [number, number][]): MapSelectedAirportDetail {
  return {
    marker: { code: 'TEST', position: { latitude: 0, longitude: 0 }, isPrimary: true },
    runways: [],
    runwayGeometries: [],
    parkingSpots: points.map(([latitude, longitude]) => ({
      position: { latitude, longitude },
    })),
    frequencies: [],
  };
}

describe('computeAirportOutline', () => {
  it('点数不足以构成面时返回 null', () => {
    expect(computeAirportOutline(detailWith([]))).toBeNull();
    expect(computeAirportOutline(detailWith([[40, 116]]))).toBeNull();
    expect(computeAirportOutline(detailWith([[40, 116], [40.01, 116.01]]))).toBeNull();
  });

  it('四个角点能围出多边形', () => {
    const outline = computeAirportOutline(
      detailWith([
        [40.0, 116.0],
        [40.0, 116.1],
        [40.1, 116.1],
        [40.1, 116.0],
      ]),
    );
    expect(outline).not.toBeNull();
    expect(outline!.length).toBeGreaterThanOrEqual(3);
  });

  it('轮廓把所有输入点包在里面（外扩过，不会紧贴）', () => {
    const points: [number, number][] = [
      [40.0, 116.0],
      [40.0, 116.1],
      [40.1, 116.1],
      [40.1, 116.0],
    ];
    const outline = computeAirportOutline(detailWith(points))!;

    const lats = outline.map((p) => p.latitude);
    const lons = outline.map((p) => p.longitude);
    // 外扩之后，轮廓的包围盒必须严格大于输入点的包围盒
    expect(Math.min(...lats)).toBeLessThan(40.0);
    expect(Math.max(...lats)).toBeGreaterThan(40.1);
    expect(Math.min(...lons)).toBeLessThan(116.0);
    expect(Math.max(...lons)).toBeGreaterThan(116.1);
  });

  it('凸包会丢弃内部点，只保留外壳', () => {
    const outline = computeAirportOutline(
      detailWith([
        [40.0, 116.0],
        [40.0, 116.1],
        [40.1, 116.1],
        [40.1, 116.0],
        [40.05, 116.05], // 正中间那个点不该出现在外壳上
      ]),
    )!;
    // 四个角 + 外扩，顶点数不应因为多了个内部点而增加
    expect(outline.length).toBeLessThanOrEqual(4);
  });

  it('重合点不会让算法卡住或产出退化多边形', () => {
    const outline = computeAirportOutline(
      detailWith([
        [40.0, 116.0],
        [40.0, 116.0],
        [40.0, 116.0],
        [40.0, 116.1],
        [40.1, 116.05],
      ]),
    );
    expect(outline).not.toBeNull();
    expect(outline!.length).toBeGreaterThanOrEqual(3);
  });

  it('跑道端点也参与轮廓计算', () => {
    const detail: MapSelectedAirportDetail = {
      ...detailWith([[40.0, 116.0]]),
      runwayGeometries: [
        {
          ident: '18/36',
          start: { latitude: 40.1, longitude: 116.0 },
          end: { latitude: 40.0, longitude: 116.1 },
        },
      ],
    };
    // 1 个停机位 + 2 个跑道端 = 3 点，刚好能成面
    expect(computeAirportOutline(detail)).not.toBeNull();
  });
});
