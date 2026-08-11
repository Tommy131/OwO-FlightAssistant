import { describe, expect, it } from 'vitest';

import {
  formatWindDirection,
  formatWindSpeedKt,
  parseMetarWind,
} from './metar-wind';

describe('parseMetarWind', () => {
  it('解析节为单位的风组', () => {
    const wind = parseMetarWind('ZBAA 110430Z 10015KT CAVOK 31/24 Q1007 NOSIG');
    expect(wind?.directionDeg).toBe(100);
    expect(wind?.speedKt).toBeCloseTo(15, 5);
  });

  // 用户截图里的 ZBAA 就是 MPS：10003MPS —— 不换算的话指针旁边会写成 "3 kt"，
  // 而实际是 3 m/s ≈ 5.8 kt，差了近一倍
  it('m/s 换算成节', () => {
    const wind = parseMetarWind('ZBAA 110430Z 10003MPS 060V150 CAVOK 31/24 Q1007 NOSIG');
    expect(wind?.directionDeg).toBe(100);
    expect(wind?.speedKt).toBeCloseTo(5.83, 1);
  });

  it('km/h 换算成节', () => {
    const wind = parseMetarWind('ZBAA 110430Z 10036KMH CAVOK Q1007');
    expect(wind?.speedKt).toBeCloseTo(19.4, 1);
  });

  it('解析阵风', () => {
    const wind = parseMetarWind('KJFK 110451Z 28015G25KT 10SM FEW250 M01/M12 A3012');
    expect(wind?.speedKt).toBeCloseTo(15, 5);
    expect(wind?.gustKt).toBeCloseTo(25, 5);
  });

  it('三位数风速（台风级）也能解', () => {
    const wind = parseMetarWind('RJTT 110430Z 090105KT 9999 Q1000');
    expect(wind?.speedKt).toBeCloseTo(105, 5);
  });

  it('VRB 标成不定风，保留风速但没有方向', () => {
    const wind = parseMetarWind('EDDM 110420Z VRB03KT CAVOK 19/12 Q1021 NOSIG');
    expect(wind?.variable).toBe(true);
    expect(wind?.directionDeg).toBeUndefined();
    expect(wind?.speedKt).toBeCloseTo(3, 5);
  });

  it('00000KT 判为静风', () => {
    const wind = parseMetarWind('ZSPD 110430Z 00000KT CAVOK 20/10 Q1013');
    expect(wind?.calm).toBe(true);
    expect(wind?.speedKt).toBe(0);
  });

  it('风向 360 归一成 0（都表示正北）', () => {
    const wind = parseMetarWind('ZBAA 110430Z 36008KT CAVOK Q1007');
    expect(wind?.directionDeg).toBe(0);
  });

  /*
   * 不锚定单位的话，气压组 Q1007、日期时间组 110430Z 里的数字
   * 都可能被当成风组解出来 —— 指针会指向一个凭空捏造的方向。
   */
  it('不会把气压组或时间组误当成风组', () => {
    expect(parseMetarWind('ZBAA 110430Z CAVOK 31/24 Q1007 NOSIG')).toBeNull();
    expect(parseMetarWind('110430Z')).toBeNull();
  });

  it('空输入返回 null', () => {
    expect(parseMetarWind(undefined)).toBeNull();
    expect(parseMetarWind('')).toBeNull();
  });

  it('小写报文也能解', () => {
    const wind = parseMetarWind('zbaa 110430z 10003mps cavok');
    expect(wind?.directionDeg).toBe(100);
  });
});

describe('formatWindDirection', () => {
  it('三位补零加度号', () => {
    expect(formatWindDirection(parseMetarWind('ZBAA 110430Z 09008KT'))).toBe('090°');
  });

  it('静风与不定风有各自的说法', () => {
    expect(formatWindDirection(parseMetarWind('ZBAA 110430Z 00000KT'))).toBe('CALM');
    expect(formatWindDirection(parseMetarWind('ZBAA 110430Z VRB03KT'))).toBe('VRB');
  });

  it('没有风组时给占位符', () => {
    expect(formatWindDirection(null)).toBe('--');
  });
});

describe('formatWindSpeedKt', () => {
  it('取整并带单位', () => {
    expect(formatWindSpeedKt(5.83)).toBe('6 kt');
    expect(formatWindSpeedKt(0)).toBe('0 kt');
  });

  it('无效值给占位符', () => {
    expect(formatWindSpeedKt(undefined)).toBe('--');
    expect(formatWindSpeedKt(Number.NaN)).toBe('--');
  });
});
