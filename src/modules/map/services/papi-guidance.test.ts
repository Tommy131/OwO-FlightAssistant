import { describe, expect, it } from 'vitest';
import { computePapiGuidance } from './papi-guidance';
import type {
  MapAircraftState,
  MapSelectedAirportDetail,
} from '../models/map-models';

/**
 * PAPI 目视坡度指示
 *
 * 四盏灯的红白组合直接对应偏高/偏低，判错了就是给出错误的进近引导。
 * 这里用「构造一架处在指定仰角上的飞机」来反推灯色，覆盖五种判定。
 */

const THRESHOLD = { latitude: 40.0, longitude: 116.0 };
// 跑道朝正北：另一端在入口以北，于是进近方向来自南侧
const FAR_END = { latitude: 40.05, longitude: 116.0 };

const FT_PER_NM = 6076.12;

/** 造一个位于入口正南、距离 distanceNm、仰角 angleDeg 的飞机 */
function aircraftAtAngle(angleDeg: number, distanceNm = 4): MapAircraftState {
  const heightFt = Math.tan((angleDeg * Math.PI) / 180) * distanceNm * FT_PER_NM;
  // 1 度纬度 ≈ 60 海里，正南方向
  const latitude = THRESHOLD.latitude - distanceNm / 60;
  return {
    position: { latitude, longitude: THRESHOLD.longitude },
    radioAltitude: heightFt,
    onGround: false,
  };
}

const DETAIL: MapSelectedAirportDetail = {
  marker: { code: 'TEST', position: THRESHOLD, isPrimary: true },
  runways: ['18/36'],
  runwayGeometries: [
    { ident: '36/18', leIdent: '36', heIdent: '18', start: THRESHOLD, end: FAR_END },
  ],
  parkingSpots: [],
  frequencyBadges: [],
  runwayNavaids: {
    // 标称下滑角 3.00°
    '36': { runway: '36', glideslopeAngle: 3, hasDme: false },
  },
};

describe('computePapiGuidance', () => {
  it('正好在坡度上 → 白白红红', () => {
    const guidance = computePapiGuidance(aircraftAtAngle(3), DETAIL)!;
    expect(guidance.verdict).toBe('onSlope');
    expect(guidance.lights).toEqual(['white', 'white', 'red', 'red']);
  });

  it('远高于坡度 → 四白', () => {
    const guidance = computePapiGuidance(aircraftAtAngle(4), DETAIL)!;
    expect(guidance.verdict).toBe('high');
    expect(guidance.lights.every((light) => light === 'white')).toBe(true);
  });

  it('远低于坡度 → 四红', () => {
    const guidance = computePapiGuidance(aircraftAtAngle(2), DETAIL)!;
    expect(guidance.verdict).toBe('low');
    expect(guidance.lights.every((light) => light === 'red')).toBe(true);
  });

  it('略高 → 三白一红', () => {
    // 落在 θ+1/6° 与 θ+0.5° 之间
    const guidance = computePapiGuidance(aircraftAtAngle(3.3), DETAIL)!;
    expect(guidance.verdict).toBe('slightlyHigh');
    expect(guidance.lights.filter((l) => l === 'white')).toHaveLength(3);
  });

  it('略低 → 一白三红', () => {
    const guidance = computePapiGuidance(aircraftAtAngle(2.7), DETAIL)!;
    expect(guidance.verdict).toBe('slightlyLow');
    expect(guidance.lights.filter((l) => l === 'white')).toHaveLength(1);
  });

  it('用该跑道公布的下滑角，而不是写死 3°', () => {
    const steep: MapSelectedAirportDetail = {
      ...DETAIL,
      runwayNavaids: { '36': { runway: '36', glideslopeAngle: 3.2, hasDme: false } },
    };
    // 3.2° 坡度下，飞在 3.2° 才算正常
    expect(computePapiGuidance(aircraftAtAngle(3.2), steep)!.verdict).toBe('onSlope');
    expect(computePapiGuidance(aircraftAtAngle(3.2), steep)!.targetAngle).toBe(3.2);
    // 同一位置放到 3.0° 坡度上就偏高了
    expect(computePapiGuidance(aircraftAtAngle(3.2), DETAIL)!.verdict).not.toBe('onSlope');
  });

  // ── 显示条件：不满足时必须整个不显示，而不是给个错误指示 ──

  it('落地滑行时不显示', () => {
    const onGround = { ...aircraftAtAngle(3), onGround: true };
    expect(computePapiGuidance(onGround, DETAIL)).toBeNull();
  });

  it('距离过远时不显示', () => {
    expect(computePapiGuidance(aircraftAtAngle(3, 20), DETAIL)).toBeNull();
  });

  it('高度过高时不显示', () => {
    // 4 海里外飞在 3000 英尺以上
    const high = aircraftAtAngle(3, 4);
    expect(computePapiGuidance({ ...high, radioAltitude: 5000 }, DETAIL)).toBeNull();
  });

  it('没对正跑道方向时不显示', () => {
    // 把飞机挪到跑道正东侧，与进近方向夹角远超 45°
    const offside: MapAircraftState = {
      position: { latitude: THRESHOLD.latitude, longitude: THRESHOLD.longitude + 0.08 },
      radioAltitude: 1200,
      onGround: false,
    };
    expect(computePapiGuidance(offside, DETAIL)).toBeNull();
  });

  it('未连接模拟器（无飞机数据）时不显示', () => {
    expect(computePapiGuidance(null, DETAIL)).toBeNull();
    expect(computePapiGuidance(aircraftAtAngle(3), null)).toBeNull();
  });
});
