import { describe, expect, it } from 'vitest';
import {
  formatAltitudeConstraint,
  parseProcedure,
  parseProcedureList,
} from './procedure-parser';

/**
 * 公布程序解析
 *
 * 最要紧的一条：**`has_position` 为假的航段不能丢**。
 * `CA`（飞到某高度）本就没有定位点，丢掉它整条程序的序号就断了 ——
 * 而起飞后的第一段往往正是 CA。
 */

/** 后端返回的原始航段形状（字段可选，避免 TS 把各航段推成联合类型） */
type RawLeg = {
  sequence: number;
  fix_ident?: string;
  lat?: number;
  lon?: number;
  has_position: boolean;
  leg_type?: string;
  altitude_description?: string;
  altitude1_ft?: number;
  altitude2_ft?: number;
  speed_limit_kt?: number;
  magnetic_course?: number;
};

const validProcedure = (): { kind: string; name: string; transition: string; legs: RawLeg[] } => ({
  kind: 'SID',
  name: 'BOTP2G',
  transition: 'RW18R',
  legs: [
    {
      sequence: 5,
      fix_ident: 'DE18R',
      lat: 40.06,
      lon: 116.34,
      has_position: true,
      leg_type: 'DF',
    },
    {
      sequence: 10,
      fix_ident: '',
      has_position: false,
      leg_type: 'CA',
      altitude_description: '+',
      altitude1_ft: 500,
      magnetic_course: 181,
    },
    {
      sequence: 20,
      fix_ident: 'AA212',
      lat: 39.93,
      lon: 116.5256,
      has_position: true,
      leg_type: 'DF',
      altitude_description: '+',
      altitude1_ft: 2960,
      speed_limit_kt: 250,
    },
    // 第三个带坐标的航段：降级其中一个来测试时，仍需留下两个才画得出线
    {
      sequence: 30,
      fix_ident: 'AA213',
      lat: 39.85,
      lon: 116.62,
      has_position: true,
      leg_type: 'TF',
    },
  ],
});

describe('parseProcedure', () => {
  it('解析核心字段', () => {
    const procedure = parseProcedure(validProcedure())!;
    expect(procedure.kind).toBe('SID');
    expect(procedure.name).toBe('BOTP2G');
    expect(procedure.transition).toBe('RW18R');
    expect(procedure.legs).toHaveLength(4);
  });

  it('保留没有坐标的航段 —— 丢掉它序号就断了', () => {
    // 起飞后第一段常常是 CA（飞到某高度），本就没有定位点
    const legs = parseProcedure(validProcedure())!.legs;
    const ca = legs.find((leg) => leg.legType === 'CA')!;
    expect(ca).toBeDefined();
    expect(ca.hasPosition).toBe(false);
    expect(ca.position).toBeUndefined();
    // 但它的高度与航道仍然有用
    expect(ca.altitude1Ft).toBe(500);
    expect(ca.magneticCourse).toBe(181);
  });

  it('有坐标的航段带上位置', () => {
    const leg = parseProcedure(validProcedure())!.legs[0];
    expect(leg.hasPosition).toBe(true);
    expect(leg.position).toEqual({ latitude: 40.06, longitude: 116.34 });
  });

  it('坐标非法时降级为无位置，而不是画到 (0,0)', () => {
    const raw = validProcedure();
    raw.legs[0] = { ...raw.legs[0], lat: 0, lon: 0 };
    const leg = parseProcedure(raw)!.legs[0];
    expect(leg.hasPosition).toBe(false);
    expect(leg.position).toBeUndefined();
  });

  it('has_position 只认真布尔', () => {
    const raw = validProcedure();
    (raw.legs[0] as unknown as { has_position: unknown }).has_position = 'true';
    expect(parseProcedure(raw)!.legs[0].hasPosition).toBe(false);
  });

  it('不足两个有坐标的航段就整条丢弃 —— 一个点画不出线', () => {
    const raw = validProcedure();
    raw.legs = [raw.legs[0], raw.legs[1]]; // 一个有坐标 + 一个 CA
    expect(parseProcedure(raw)).toBeNull();
  });

  it('未知类型与空名称一律丢弃', () => {
    expect(parseProcedure({ ...validProcedure(), kind: 'TRANSITION' })).toBeNull();
    expect(parseProcedure({ ...validProcedure(), name: '  ' })).toBeNull();
  });

  it('脏输入返回 null 而不是抛异常', () => {
    for (const input of [null, undefined, 42, 'x', {}, { kind: 'SID' }]) {
      expect(() => parseProcedure(input)).not.toThrow();
      expect(parseProcedure(input)).toBeNull();
    }
  });
});

describe('parseProcedureList', () => {
  it('逐条解析并剔除无效项', () => {
    const list = parseProcedureList([
      validProcedure(),
      { kind: 'BAD', name: 'X', legs: [] },
      null,
      validProcedure(),
    ]);
    expect(list).toHaveLength(2);
  });

  it('不是数组时返回空数组', () => {
    expect(parseProcedureList(null)).toEqual([]);
    expect(parseProcedureList({})).toEqual([]);
  });
});

describe('formatAltitudeConstraint', () => {
  const leg = (over: Record<string, unknown>) =>
    ({ sequence: 1, hasPosition: true, ...over }) as never;

  it('按航图写法标注', () => {
    // 不低于 / 不高于 / 区间之内，是航图上的三种标注
    expect(formatAltitudeConstraint(leg({ altitudeDescription: '+', altitude1Ft: 2960 })))
      .toBe('2960+');
    expect(formatAltitudeConstraint(leg({ altitudeDescription: '-', altitude1Ft: 5000 })))
      .toBe('5000-');
    expect(
      formatAltitudeConstraint(
        leg({ altitudeDescription: 'B', altitude1Ft: 17700, altitude2Ft: 16700 }),
      ),
    ).toBe('17700/16700');
  });

  it('区间但缺第二个高度时退回单值', () => {
    expect(formatAltitudeConstraint(leg({ altitudeDescription: 'B', altitude1Ft: 17700 })))
      .toBe('17700');
  });

  it('没有描述符时只给数字', () => {
    expect(formatAltitudeConstraint(leg({ altitude1Ft: 6890 }))).toBe('6890');
  });

  it('没有高度限制时返回 undefined，而不是 "0"', () => {
    // 0 会被当成「限高到海平面」，比不显示更糟
    expect(formatAltitudeConstraint(leg({}))).toBeUndefined();
    expect(formatAltitudeConstraint(leg({ altitude1Ft: 0 }))).toBeUndefined();
  });
});
