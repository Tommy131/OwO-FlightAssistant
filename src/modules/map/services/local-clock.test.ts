import { describe, expect, it } from 'vitest';

import {
  ZONE_QUANTIZE_DEG,
  crossesDateBoundary,
  formatClock,
  formatOffsetLabel,
  formatUtcClock,
  formatZonedDate,
  zoneCellKey,
} from './local-clock';

/** 2026-08-10 19:00:14 UTC —— 柏林夏令时 21:00:14 */
const SUMMER = new Date('2026-08-10T19:00:14Z');
/** 2026-01-10 19:00:14 UTC —— 柏林冬令时 20:00:14 */
const WINTER = new Date('2026-01-10T19:00:14Z');

describe('formatClock', () => {
  it('按时区换算', () => {
    expect(formatClock(SUMMER, 'UTC')).toBe('19:00:14');
    expect(formatClock(SUMMER, 'Europe/Berlin')).toBe('21:00:14');
    expect(formatClock(SUMMER, 'Asia/Shanghai')).toBe('03:00:14');
    expect(formatClock(SUMMER, 'America/New_York')).toBe('15:00:14');
  });

  // 交给 Intl 算的意义就在这里：同一个时区名，夏冬自动差一小时
  it('夏令时自动生效', () => {
    expect(formatClock(SUMMER, 'Europe/Berlin')).toBe('21:00:14');
    expect(formatClock(WINTER, 'Europe/Berlin')).toBe('20:00:14');
  });

  it('南半球的夏令时方向相反', () => {
    expect(formatClock(SUMMER, 'Australia/Sydney')).toBe('05:00:14');
    expect(formatClock(WINTER, 'Australia/Sydney')).toBe('06:00:14');
  });

  it('半小时时区也要对', () => {
    expect(formatClock(SUMMER, 'Asia/Kolkata')).toBe('00:30:14');
  });

  it('用 24 小时制，不能出现 AM/PM', () => {
    const midnight = new Date('2026-08-10T00:30:00Z');
    expect(formatClock(midnight, 'UTC')).toBe('00:30:00');
    expect(formatClock(midnight, 'UTC')).not.toMatch(/[AP]M/i);
  });

  it('时区名不认识时退回 UTC，而不是抛异常', () => {
    expect(formatClock(SUMMER, 'Middle/Earth')).toBe('19:00:14');
    expect(formatClock(SUMMER, '')).toBe('19:00:14');
    expect(formatClock(SUMMER, undefined)).toBe('19:00:14');
  });

  it('无效日期不炸', () => {
    expect(formatClock(new Date('nope'), 'Europe/Berlin')).toBe('--');
  });
});

describe('formatUtcClock', () => {
  it('恒按 UTC', () => {
    expect(formatUtcClock(SUMMER)).toBe('19:00:14');
    expect(formatUtcClock(WINTER)).toBe('19:00:14');
  });
});

describe('formatZonedDate', () => {
  it('给出 YYYY-MM-DD', () => {
    expect(formatZonedDate(SUMMER, 'UTC')).toBe('2026-08-10');
    expect(formatZonedDate(SUMMER, 'Asia/Shanghai')).toBe('2026-08-11');
  });
});

describe('crossesDateBoundary', () => {
  it('当地与 UTC 不同一天时为真', () => {
    expect(crossesDateBoundary(SUMMER, 'Asia/Shanghai')).toBe(true);
    expect(crossesDateBoundary(SUMMER, 'Europe/Berlin')).toBe(false);
    expect(crossesDateBoundary(SUMMER, 'UTC')).toBe(false);
  });

  it('往回跨一天也算', () => {
    const earlyUtc = new Date('2026-08-10T02:00:00Z');
    expect(crossesDateBoundary(earlyUtc, 'America/Los_Angeles')).toBe(true);
  });
});

describe('formatOffsetLabel', () => {
  it('正负零各有其形', () => {
    expect(formatOffsetLabel(7200)).toBe('UTC+02:00');
    expect(formatOffsetLabel(0)).toBe('UTC±00:00');
    expect(formatOffsetLabel(-18000)).toBe('UTC−05:00');
  });

  it('半小时与三刻钟时区', () => {
    expect(formatOffsetLabel(19800)).toBe('UTC+05:30');
    expect(formatOffsetLabel(20700)).toBe('UTC+05:45');
    expect(formatOffsetLabel(-12600)).toBe('UTC−03:30');
  });

  it('非有限值不产出脏字符串', () => {
    expect(formatOffsetLabel(Number.NaN)).toBe('UTC');
  });
});

describe('zoneCellKey', () => {
  // 格点按四舍五入取，所以 48.34 与 48.36 分属两格（分界在 48.35）。
  // 同一格要取分界同侧的两个点。
  it('同一格里的点给出同一个键', () => {
    expect(zoneCellKey(48.32, 11.77)).toBe(zoneCellKey(48.34, 11.79));
  });

  it('跨出一格就换键', () => {
    expect(zoneCellKey(48.34, 11.79)).not.toBe(zoneCellKey(48.46, 11.79));
    expect(zoneCellKey(48.34, 11.79)).not.toBe(zoneCellKey(48.34, 11.91));
  });

  /*
   * 必须是**四舍五入**，不能是向下取整 —— 中间件 `localtime.quantize` 用的是
   * math.Round。两边取整方式不一致，前端就会在格子边界上误判「还在同一格」
   * 而不去重查，于是飞过时区边界后一直显示旧时区。
   *
   * 48.34 与 48.36 向下取整都落在 483，四舍五入才分成 483 / 484。
   */
  it('按四舍五入分格，不是向下取整', () => {
    expect(zoneCellKey(48.34, 11.0)).not.toBe(zoneCellKey(48.36, 11.0));
    expect(zoneCellKey(48.0, 11.34)).not.toBe(zoneCellKey(48.0, 11.36));
  });

  it('赤道与本初子午线两侧不混为一谈', () => {
    expect(zoneCellKey(0.06, 0)).not.toBe(zoneCellKey(-0.06, 0));
    expect(zoneCellKey(0, 0.06)).not.toBe(zoneCellKey(0, -0.06));
  });

  it('坐标不可用时返回 undefined', () => {
    expect(zoneCellKey(Number.NaN, 11)).toBeUndefined();
    expect(zoneCellKey(48, Number.POSITIVE_INFINITY)).toBeUndefined();
  });

  // 格点大小必须跟中间件对齐，否则要么白查要么漏查
  it('格点大小是 0.1°', () => {
    expect(ZONE_QUANTIZE_DEG).toBe(0.1);
  });
});
