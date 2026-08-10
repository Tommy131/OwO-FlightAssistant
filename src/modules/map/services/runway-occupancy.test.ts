import { describe, expect, it } from 'vitest';

import type { MapRunwayGeometry } from '../models/map-models';
import {
  DEFAULT_RUNWAY_HALF_WIDTH_M,
  RUNWAY_OCCUPANCY_MAX_AGL_FT,
  findOccupiedRunway,
  normalizeLongitudeDelta,
  projectOntoRunway,
} from './runway-occupancy';

/**
 * 本机所在跑道判定
 *
 * 判据错了不会报错，只会高亮错一条跑道 —— 平行跑道的机场里尤其难用肉眼发现，
 * 所以「中段命中」和「延长线不命中」这两条必须钉死。
 */

/** 一条南北向、长约 3340 m 的跑道（纬度 40.000 → 40.030，经度固定） */
const NS_RUNWAY: MapRunwayGeometry = {
  ident: '18/36',
  start: { latitude: 40.0, longitude: 116.0 },
  end: { latitude: 40.03, longitude: 116.0 },
};

/** 与上面平行、往东偏约 1 km 的另一条 */
const NS_RUNWAY_PARALLEL: MapRunwayGeometry = {
  ident: '18L/36R',
  start: { latitude: 40.0, longitude: 116.0117 },
  end: { latitude: 40.03, longitude: 116.0117 },
};

describe('projectOntoRunway', () => {
  it('中点投影落在跑道正中，垂距为 0', () => {
    const hit = projectOntoRunway({ latitude: 40.015, longitude: 116.0 }, NS_RUNWAY);
    expect(hit).not.toBeNull();
    expect(hit?.offsetM ?? 999).toBeLessThan(0.5);
    expect(hit?.alongM ?? 0).toBeGreaterThan(1600);
  });

  // 只算到端点距离的话，中段这个位置会被判成「离得很远」
  it('偏离中线 20 m 时垂距约 20 m', () => {
    // 1 米经度 ≈ 1/(111320*cos40°) 度
    const oneMeterLon = 1 / (111_320 * Math.cos((40 * Math.PI) / 180));
    const hit = projectOntoRunway(
      { latitude: 40.015, longitude: 116.0 + oneMeterLon * 20 },
      NS_RUNWAY,
    );
    expect(hit?.offsetM ?? 0).toBeGreaterThan(19);
    expect(hit?.offsetM ?? 0).toBeLessThan(21);
  });

  // 只算垂距的话，延长线上几公里外的飞机也会被算进来
  it('投影落在延长线上时返回 null', () => {
    expect(projectOntoRunway({ latitude: 39.99, longitude: 116.0 }, NS_RUNWAY)).toBeNull();
    expect(projectOntoRunway({ latitude: 40.05, longitude: 116.0 }, NS_RUNWAY)).toBeNull();
  });

  it('两端点重合的坏数据不会除零', () => {
    const degenerate = {
      start: { latitude: 40, longitude: 116 },
      end: { latitude: 40, longitude: 116 },
    };
    expect(projectOntoRunway({ latitude: 40, longitude: 116 }, degenerate)).toBeNull();
  });
});

describe('findOccupiedRunway', () => {
  it('压在跑道上时命中', () => {
    const hit = findOccupiedRunway([NS_RUNWAY], {
      position: { latitude: 40.015, longitude: 116.0 },
      onGround: true,
    });
    expect(hit?.ident).toBe('18/36');
  });

  it('离开跑道后不命中', () => {
    const hit = findOccupiedRunway([NS_RUNWAY], {
      position: { latitude: 40.015, longitude: 116.005 },
      onGround: true,
    });
    expect(hit).toBeNull();
  });

  // 验收里点名的场景：平行跑道不能误高亮相邻那条
  it('平行跑道只命中自己压着的那条', () => {
    const onLeft = findOccupiedRunway([NS_RUNWAY, NS_RUNWAY_PARALLEL], {
      position: { latitude: 40.015, longitude: 116.0 },
      onGround: true,
    });
    expect(onLeft?.ident).toBe('18/36');

    const onRight = findOccupiedRunway([NS_RUNWAY, NS_RUNWAY_PARALLEL], {
      position: { latitude: 40.015, longitude: 116.0117 },
      onGround: true,
    });
    expect(onRight?.ident).toBe('18L/36R');
  });

  it('半宽边界内命中、边界外不命中', () => {
    const oneMeterLon = 1 / (111_320 * Math.cos((40 * Math.PI) / 180));
    const inside = findOccupiedRunway([NS_RUNWAY], {
      position: { latitude: 40.015, longitude: 116.0 + oneMeterLon * (DEFAULT_RUNWAY_HALF_WIDTH_M - 5) },
      onGround: true,
    });
    const outside = findOccupiedRunway([NS_RUNWAY], {
      position: { latitude: 40.015, longitude: 116.0 + oneMeterLon * (DEFAULT_RUNWAY_HALF_WIDTH_M + 5) },
      onGround: true,
    });
    expect(inside).not.toBeNull();
    expect(outside).toBeNull();
  });

  it('可以自定义半宽', () => {
    const oneMeterLon = 1 / (111_320 * Math.cos((40 * Math.PI) / 180));
    const position = { latitude: 40.015, longitude: 116.0 + oneMeterLon * 60 };
    expect(findOccupiedRunway([NS_RUNWAY], { position, onGround: true })).toBeNull();
    expect(
      findOccupiedRunway([NS_RUNWAY], { position, onGround: true, halfWidthM: 80 }),
    ).not.toBeNull();
  });

  // 不设高度门槛的话，从跑道正上方三千英尺飞过也会被判成「在跑道上」
  it('高空飞越跑道正上方时不命中', () => {
    const hit = findOccupiedRunway([NS_RUNWAY], {
      position: { latitude: 40.015, longitude: 116.0 },
      onGround: false,
      radioAltitudeFt: 3000,
    });
    expect(hit).toBeNull();
  });

  it('刚离地/拉平高度内仍然命中', () => {
    const hit = findOccupiedRunway([NS_RUNWAY], {
      position: { latitude: 40.015, longitude: 116.0 },
      onGround: false,
      radioAltitudeFt: RUNWAY_OCCUPANCY_MAX_AGL_FT - 10,
    });
    expect(hit?.ident).toBe('18/36');
  });

  it('在地面时忽略高度值', () => {
    const hit = findOccupiedRunway([NS_RUNWAY], {
      position: { latitude: 40.015, longitude: 116.0 },
      onGround: true,
      radioAltitudeFt: 5000,
    });
    expect(hit?.ident).toBe('18/36');
  });

  // 很多机型不提供无线电高度，一票否决等于这功能对它们永远不生效
  it('没有无线电高度且未标明在空中时按贴地处理', () => {
    const hit = findOccupiedRunway([NS_RUNWAY], {
      position: { latitude: 40.015, longitude: 116.0 },
    });
    expect(hit?.ident).toBe('18/36');
  });

  it('明确在空中且没有无线电高度时不命中', () => {
    const hit = findOccupiedRunway([NS_RUNWAY], {
      position: { latitude: 40.015, longitude: 116.0 },
      onGround: false,
    });
    expect(hit).toBeNull();
  });

  it('坐标缺失或为 (0,0) 时不命中', () => {
    expect(
      findOccupiedRunway([NS_RUNWAY], { position: { latitude: 0, longitude: 0 }, onGround: true }),
    ).toBeNull();
    expect(
      findOccupiedRunway([NS_RUNWAY], {
        position: { latitude: Number.NaN, longitude: 116 },
        onGround: true,
      }),
    ).toBeNull();
  });

  it('跑道坐标不合法时跳过该条而不是整体失败', () => {
    const broken: MapRunwayGeometry = {
      ident: 'BAD',
      start: { latitude: 0, longitude: 0 },
      end: { latitude: 0, longitude: 0 },
    };
    const hit = findOccupiedRunway([broken, NS_RUNWAY], {
      position: { latitude: 40.015, longitude: 116.0 },
      onGround: true,
    });
    expect(hit?.ident).toBe('18/36');
  });

  it('空跑道列表返回 null', () => {
    expect(
      findOccupiedRunway([], { position: { latitude: 40.015, longitude: 116 }, onGround: true }),
    ).toBeNull();
  });
});

describe('normalizeLongitudeDelta', () => {
  // 滑行道路网那套曾经栽在这上面：经线两侧会被算成绕地球一圈
  it('跨 180° 时归一到最短方向', () => {
    expect(normalizeLongitudeDelta(359)).toBeCloseTo(-1, 6);
    expect(normalizeLongitudeDelta(-359)).toBeCloseTo(1, 6);
    expect(normalizeLongitudeDelta(1)).toBeCloseTo(1, 6);
  });

  it('跨经线的跑道判定仍然正确', () => {
    const acrossDateLine: MapRunwayGeometry = {
      ident: '09/27',
      start: { latitude: 28.2, longitude: 179.99 },
      end: { latitude: 28.2, longitude: -179.99 },
    };
    const hit = findOccupiedRunway([acrossDateLine], {
      position: { latitude: 28.2, longitude: 180 },
      onGround: true,
    });
    expect(hit?.ident).toBe('09/27');
  });
});
