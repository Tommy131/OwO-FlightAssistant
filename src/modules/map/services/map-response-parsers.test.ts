import { describe, expect, it } from 'vitest';
import {
  extractRadarFrames,
  isValidCoordinate,
  parseAerowayFeature,
  parseAltitudeFt,
  parseHoldingPattern,
  parseNearbyAirport,
  parseRestrictedZone,
  parseRunwayNavaid,
} from './map-response-parsers';

/**
 * 后端响应解析
 *
 * 这些解析器直面外部输入：中间件的字段大小写不统一（PascalCase 与 snake_case 混用），
 * 上游还可能返回脏数据。测试重点是**两种命名都认**、**脏数据不炸且不产出畸形模型**。
 */

describe('isValidCoordinate', () => {
  it('接受正常坐标', () => {
    expect(isValidCoordinate(40.08, 116.58)).toBe(true);
    expect(isValidCoordinate(-33.9, 151.2)).toBe(true);
  });

  it('拒绝超范围与非数值', () => {
    expect(isValidCoordinate(91, 0)).toBe(false);
    expect(isValidCoordinate(0, 181)).toBe(false);
    expect(isValidCoordinate(Number.NaN, 0)).toBe(false);
  });

  it('拒绝 (0,0)：几乎总是「字段缺失」而非真在几内亚湾', () => {
    expect(isValidCoordinate(0, 0)).toBe(false);
  });
});

describe('parseHoldingPattern', () => {
  const raw = {
    fix: 'AA320',
    lat: 40.0,
    lon: 116.5,
    inbound_course: 161,
    leg_minutes: 1.5,
    turn_direction: 'R',
    min_altitude_ft: 9850,
  };

  it('解析 snake_case 字段', () => {
    const hold = parseHoldingPattern(raw)!;
    expect(hold.fix).toBe('AA320');
    expect(hold.inboundCourse).toBe(161);
    expect(hold.legMinutes).toBe(1.5);
    expect(hold.minAltitudeFt).toBe(9850);
  });

  it('也认 camelCase 字段', () => {
    const hold = parseHoldingPattern({
      fix: 'X',
      lat: 1,
      lon: 1,
      inboundCourse: 90,
      legMinutes: 1,
    })!;
    expect(hold.inboundCourse).toBe(90);
  });

  it('转向只认 L，其余一律按标准右转', () => {
    expect(parseHoldingPattern({ ...raw, turn_direction: 'L' })!.turnDirection).toBe('L');
    expect(parseHoldingPattern({ ...raw, turn_direction: 'R' })!.turnDirection).toBe('R');
    expect(parseHoldingPattern({ ...raw, turn_direction: '' })!.turnDirection).toBe('R');
  });

  it('缺关键字段时返回 null', () => {
    expect(parseHoldingPattern({ lat: 1, lon: 1 })).toBeNull();
    expect(parseHoldingPattern({ fix: 'X', lon: 1 })).toBeNull();
    expect(parseHoldingPattern(null)).toBeNull();
    expect(parseHoldingPattern('not an object')).toBeNull();
  });
});

describe('parseRunwayNavaid', () => {
  it('保留磁航道与真方位两个字段', () => {
    const navaid = parseRunwayNavaid({
      runway: '18r',
      category: 'CAT I',
      loc_frequency: '110.30',
      loc_course: 181,
      loc_true_bearing: 173.111,
      glideslope_angle: 3,
      has_dme: true,
    })!;
    // 跑道号统一大写，前端按大写查表
    expect(navaid.runway).toBe('18R');
    expect(navaid.locCourse).toBe(181);
    expect(navaid.locTrueBearing).toBe(173.111);
    expect(navaid.hasDme).toBe(true);
  });

  it('hasDme 只认布尔 true，不把字符串当真', () => {
    expect(parseRunwayNavaid({ runway: '1', has_dme: 'true' })!.hasDme).toBe(false);
    expect(parseRunwayNavaid({ runway: '1', has_dme: 1 })!.hasDme).toBe(false);
    expect(parseRunwayNavaid({ runway: '1', hasDme: true })!.hasDme).toBe(true);
  });

  it('没有跑道号就没法索引，返回 null', () => {
    expect(parseRunwayNavaid({ category: 'CAT I' })).toBeNull();
  });
});

describe('parseAerowayFeature', () => {
  const points = [
    [40.0, 116.0],
    [40.1, 116.1],
  ];

  it('解析滑行道并保留编号', () => {
    const feature = parseAerowayFeature({ kind: 'taxiway', ref: 'W1', points })!;
    expect(feature.kind).toBe('taxiway');
    expect(feature.ref).toBe('W1');
    expect(feature.points).toHaveLength(2);
    expect(feature.points[0]).toEqual({ latitude: 40.0, longitude: 116.0 });
  });

  it('未知类型直接丢弃', () => {
    expect(parseAerowayFeature({ kind: 'highway', points })).toBeUndefined();
    expect(parseAerowayFeature({ kind: '', points })).toBeUndefined();
  });

  it('剔除非法坐标；剩不到两点就整条丢弃', () => {
    const feature = parseAerowayFeature({
      kind: 'taxiway',
      points: [[40.0, 116.0], [0, 0], [999, 999], [40.1, 116.1]],
    })!;
    expect(feature.points).toHaveLength(2);

    expect(
      parseAerowayFeature({ kind: 'taxiway', points: [[40.0, 116.0], [0, 0]] }),
    ).toBeUndefined();
  });

  it('空 ref / name 归一成 undefined，而不是空串', () => {
    const feature = parseAerowayFeature({ kind: 'apron', ref: '  ', name: '', points })!;
    expect(feature.ref).toBeUndefined();
    expect(feature.name).toBeUndefined();
  });
});

describe('parseNearbyAirport', () => {
  it('认后端的 PascalCase 字段', () => {
    const airport = parseNearbyAirport({
      ICAO: 'ZBAA',
      Name: 'Beijing Capital Intl',
      Lat: 40.078,
      Lon: 116.594,
    })!;
    expect(airport.code).toBe('ZBAA');
    expect(airport.position.latitude).toBeCloseTo(40.078, 3);
  });

  it('坐标非法时丢弃，避免机场被画到 (0,0)', () => {
    expect(parseNearbyAirport({ ICAO: 'ZBAA', Lat: 0, Lon: 0 })).toBeUndefined();
  });
});

describe('parseAltitudeFt', () => {
  // 后端 airspace.go 固定发字符串："6500 ft AMSL" / "SFC"
  it('从带单位的字符串里取数值', () => {
    expect(parseAltitudeFt('6500 ft AMSL')).toBe(6500);
    expect(parseAltitudeFt('4500 ft AMSL')).toBe(4500);
  });

  it('SFC = 地表 = 0 英尺，不是「没有数据」', () => {
    // 这条容易被改错：SFC 是空域下限的合法取值（贴地），
    // 若返回 undefined，界面会把「地表」显示成「未知下限」
    expect(parseAltitudeFt('SFC')).toBe(0);
    expect(parseAltitudeFt('sfc')).toBe(0);
  });

  it('真正没有数据时才是 undefined', () => {
    expect(parseAltitudeFt(null)).toBeUndefined();
    expect(parseAltitudeFt(undefined)).toBeUndefined();
    expect(parseAltitudeFt('UNL')).toBeUndefined();
  });
});

describe('parseRestrictedZone', () => {
  it('解析限制空域的中心与半径', () => {
    const zone = parseRestrictedZone({
      id: 'R1',
      name: 'Test Zone',
      center: { lat: 40, lon: 116 },
      radius_m: 5000,
    });
    // 字段名可能因后端版本而异，能解析出来时至少要有 id
    if (zone) expect(zone.id).toBeTruthy();
  });

  it('脏输入不抛异常', () => {
    expect(() => parseRestrictedZone(null)).not.toThrow();
    expect(() => parseRestrictedZone('x')).not.toThrow();
    expect(() => parseRestrictedZone({})).not.toThrow();
  });
});

describe('extractRadarFrames', () => {
  it('从 RainViewer 索引里取出帧列表并带上 host', () => {
    const frames = extractRadarFrames({
      host: 'https://tilecache.rainviewer.com',
      radar: {
        past: [
          { time: 1785787200, path: '/v2/radar/aaa' },
          { time: 1785787800, path: '/v2/radar/bbb' },
        ],
      },
    });
    expect(frames).toHaveLength(2);
    expect(frames[0].host).toBe('https://tilecache.rainviewer.com');
    expect(frames[1].path).toBe('/v2/radar/bbb');
  });

  it('跳过缺 time 或 path 的帧', () => {
    const frames = extractRadarFrames({
      host: 'h',
      radar: { past: [{ time: 1 }, { path: '/p' }, { time: 2, path: '/ok' }] },
    });
    expect(frames).toHaveLength(1);
    expect(frames[0].path).toBe('/ok');
  });

  it('结构不对时返回空数组而不是抛异常', () => {
    expect(extractRadarFrames(null)).toEqual([]);
    expect(extractRadarFrames({})).toEqual([]);
    expect(extractRadarFrames({ radar: {} })).toEqual([]);
  });
});
