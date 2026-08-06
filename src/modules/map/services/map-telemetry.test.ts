import { describe, expect, it } from 'vitest';
import {
  appendRoutePoint,
  buildAirportsFromSnapshot,
  distanceInMeters,
  MAX_ROUTE_POINTS,
  MIN_ROUTE_POINT_DISTANCE_M,
} from './map-telemetry';
import type { FlightDataSnapshot } from '../../common/models/common-models';
import type { MapAircraftState, MapCoordinate, MapRoutePoint } from '../models/map-models';

/**
 * 从遥测派生地图要素
 *
 * 航迹这段原先依赖模块级可变量，跑一次就污染下一次，没法测。改成入参后
 * 才能把两条关键行为钉死：**太近不记**（否则停机时几分钟就刷到上限）、
 * **超上限从头裁**（否则内存一路涨）。
 */

function aircraft(latitude: number, longitude: number): MapAircraftState {
  return {
    position: { latitude, longitude },
    altitude: 1000,
    groundSpeed: 120,
  };
}

describe('distanceInMeters', () => {
  it('一度纬度约 111 公里', () => {
    expect(distanceInMeters(40, 116, 41, 116)).toBeCloseTo(111_195, -2);
  });

  it('同一点为 0', () => {
    expect(distanceInMeters(40, 116, 40, 116)).toBe(0);
  });
});

describe('appendRoutePoint', () => {
  it('没有上一点时无条件记录', () => {
    const result = appendRoutePoint([], aircraft(40, 116), null);
    expect(result.appended).toBe(true);
    expect(result.route).toHaveLength(1);
    expect(result.lastPoint).toEqual({ latitude: 40, longitude: 116 });
  });

  it('距上一点太近就不记，并原样返回同一个数组引用', () => {
    // 引用不变很重要：store 靠它判断要不要重渲染整条航迹
    const route: MapRoutePoint[] = [];
    const last: MapCoordinate = { latitude: 40, longitude: 116 };
    const result = appendRoutePoint(route, aircraft(40.0001, 116), last);
    expect(result.appended).toBe(false);
    expect(result.route).toBe(route);
    expect(result.lastPoint).toBe(last);
  });

  it('刚好跨过最小间距就记', () => {
    const last: MapCoordinate = { latitude: 40, longitude: 116 };
    // 纬度每度约 111195 米，取略大于阈值的偏移
    const delta = ((MIN_ROUTE_POINT_DISTANCE_M + 1) / 111_195) * 1;
    const result = appendRoutePoint([], aircraft(40 + delta, 116), last);
    expect(result.appended).toBe(true);
  });

  it('记录高度、地速与时间戳', () => {
    const now = new Date('2026-08-06T10:00:00Z');
    const result = appendRoutePoint([], aircraft(40, 116), null, now);
    expect(result.route[0]).toEqual({
      latitude: 40,
      longitude: 116,
      altitude: 1000,
      groundSpeed: 120,
      timestamp: now,
    });
  });

  it('超过上限时从头裁剪，保留最新的点', () => {
    const route: MapRoutePoint[] = Array.from({ length: MAX_ROUTE_POINTS }, (_, i) => ({
      latitude: i,
      longitude: 0,
      timestamp: new Date(),
    }));

    const result = appendRoutePoint(route, aircraft(99, 99), null);
    expect(result.route).toHaveLength(MAX_ROUTE_POINTS);
    // 最老的那个点被丢掉，最新的在末尾
    expect(result.route[0].latitude).toBe(1);
    expect(result.route[result.route.length - 1].latitude).toBe(99);
  });

  it('不修改传入的数组', () => {
    const route: MapRoutePoint[] = [];
    appendRoutePoint(route, aircraft(40, 116), null);
    expect(route).toHaveLength(0);
  });
});

describe('buildAirportsFromSnapshot', () => {
  const airport = (icaoCode: string, latitude = 40, longitude = 116) => ({
    icaoCode,
    iataCode: '',
    name: `${icaoCode} Intl`,
    nameChinese: '',
    latitude,
    longitude,
  });

  function snapshot(overrides: Partial<FlightDataSnapshot> = {}): FlightDataSnapshot {
    return { suggestedAirports: [], ...overrides } as FlightDataSnapshot;
  }

  it('起飞/目的/备降标为 primary，最近与推荐不标', () => {
    const airports = buildAirportsFromSnapshot(
      snapshot({
        departureAirport: airport('ZBAA', 40.0, 116.0),
        destinationAirport: airport('ZSPD', 31.1, 121.8),
        alternateAirport: airport('ZSSS', 31.2, 121.3),
        nearestAirport: airport('ZBTJ', 39.1, 117.3),
        suggestedAirports: [airport('ZBYN', 37.7, 112.6)],
      }),
    );
    const byCode = Object.fromEntries(airports.map((a) => [a.code, a.isPrimary]));
    expect(byCode).toEqual({
      ZBAA: true,
      ZSPD: true,
      ZSSS: true,
      ZBTJ: false,
      ZBYN: false,
    });
  });

  it('ICAO 去重，先加入的优先级更高', () => {
    // 目的地恰好也是最近机场时，必须保持 primary 而不是被降级
    const airports = buildAirportsFromSnapshot(
      snapshot({
        destinationAirport: airport('ZSPD', 31.1, 121.8),
        nearestAirport: airport('ZSPD', 31.1, 121.8),
      }),
    );
    expect(airports).toHaveLength(1);
    expect(airports[0].isPrimary).toBe(true);
  });

  it('ICAO 统一大写并去空白', () => {
    const airports = buildAirportsFromSnapshot(
      snapshot({ departureAirport: airport('  zbaa  ') }),
    );
    expect(airports[0].code).toBe('ZBAA');
  });

  it('丢弃空 ICAO 与非法坐标', () => {
    const airports = buildAirportsFromSnapshot(
      snapshot({
        departureAirport: airport('', 40, 116),
        destinationAirport: airport('ZSPD', 0, 0),
        alternateAirport: airport('ZSSS', 999, 999),
      }),
    );
    expect(airports).toEqual([]);
  });

  it('全空快照返回空数组而不是抛异常', () => {
    expect(buildAirportsFromSnapshot(snapshot())).toEqual([]);
  });
});
