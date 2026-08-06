import { describe, expect, it } from 'vitest';
import { calculateDistanceNm, toStringOrUndefined, toText } from './parse-utils';

/**
 * 宽容型 JSON 解析工具
 *
 * `toText` 是全项目 30 多处调用点的公共底座，专门用来替掉 `String(x ?? '')` ——
 * 后者遇到对象会给出 `"[object Object]"`，让「字段类型不对」伪装成合法字符串。
 * 这里把「非标量一律当没有值」这条钉死。
 */

describe('toText', () => {
  it('标量原样转文本', () => {
    expect(toText('ZBAA')).toBe('ZBAA');
    expect(toText(36)).toBe('36');
    expect(toText(0)).toBe('0');
    expect(toText(true)).toBe('true');
    expect(toText(false)).toBe('false');
  });

  it('缺失值给空串', () => {
    expect(toText(null)).toBe('');
    expect(toText(undefined)).toBe('');
  });

  it('对象与数组给空串，而不是 "[object Object]"', () => {
    // 这是本函数存在的唯一理由：调用方随后的判空必须能生效
    expect(toText({})).toBe('');
    expect(toText({ icao: 'ZBAA' })).toBe('');
    expect(toText(['a', 'b'])).toBe('');
    expect(toText([])).toBe('');
  });

  it('非有限数字按缺失处理', () => {
    // "NaN" / "Infinity" 作为文本毫无意义，出现在界面上只会让人困惑
    expect(toText(Number.NaN)).toBe('');
    expect(toText(Number.POSITIVE_INFINITY)).toBe('');
  });

  it('不 trim：空白由调用方自己决定怎么处理', () => {
    expect(toText('  ZBAA  ')).toBe('  ZBAA  ');
  });
});

describe('toStringOrUndefined', () => {
  it('trim 后为空一律归 undefined', () => {
    expect(toStringOrUndefined('  ZBAA  ')).toBe('ZBAA');
    expect(toStringOrUndefined('   ')).toBeUndefined();
    expect(toStringOrUndefined('')).toBeUndefined();
    expect(toStringOrUndefined(null)).toBeUndefined();
  });

  it('对象归 undefined —— 曾经会返回 "[object Object]"', () => {
    // 旧实现是 String(value).trim()，对象转出来非空，判空分支永远走不到
    expect(toStringOrUndefined({ a: 1 })).toBeUndefined();
    expect(toStringOrUndefined([1, 2])).toBeUndefined();
  });

  it('数字与布尔仍转文本', () => {
    expect(toStringOrUndefined(36)).toBe('36');
    expect(toStringOrUndefined(false)).toBe('false');
  });
});

describe('calculateDistanceNm', () => {
  it('同一点距离为 0', () => {
    expect(calculateDistanceNm(40, 116, 40, 116)).toBe(0);
  });

  it('一度纬度约 60 海里', () => {
    // 大圆上 1 分纬度 = 1 海里，所以 1 度 ≈ 60 海里
    expect(calculateDistanceNm(40, 116, 41, 116)).toBeCloseTo(60, 0);
  });

  it('与已知航段吻合（ZBAA→ZSPD 约 593 海里）', () => {
    expect(calculateDistanceNm(40.078, 116.594, 31.143, 121.805)).toBeCloseTo(593, 0);
  });

  it('对称：反向距离相同', () => {
    const forward = calculateDistanceNm(40.078, 116.594, 50.033, 8.57);
    const backward = calculateDistanceNm(50.033, 8.57, 40.078, 116.594);
    expect(forward).toBeCloseTo(backward, 9);
  });
});
