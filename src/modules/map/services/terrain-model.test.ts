import { describe, expect, it } from 'vitest';

import {
  METERS_TO_FEET,
  SAFE_CELL_STRIDE,
  TERRAIN_BAND_COLOR,
  TERRAIN_CAUTION_LOOK_AHEAD_SEC,
  TERRAIN_MAX_LOOK_AHEAD_NM,
  TERRAIN_MIN_GROUND_SPEED_KT,
  TERRAIN_MIN_RADIO_ALTITUDE_FT,
  TERRAIN_REQUIRED_CLEARANCE_FT,
  TERRAIN_SAMPLE_COUNT,
  type TerrainTile,
  buildTerrainAheadAlert,
  buildTerrainCells,
  elevationM,
  sampleTerrainAhead,
  terrainBandFor,
  terrainBoundsAround,
  tileElevationM,
} from './terrain-model';

const SPAN = 0.25;
const GRID = 10;
const CELL = SPAN / GRID;

/** 造一块瓦片，elevations 按 (row, col) 生成 */
function makeTile(
  south: number,
  west: number,
  fill: (row: number, col: number) => number,
): TerrainTile {
  const elevationsM: number[] = [];
  for (let row = 0; row < GRID; row++) {
    for (let col = 0; col < GRID; col++) elevationsM.push(fill(row, col));
  }
  return { south, west, spanDeg: SPAN, cellSpanDeg: CELL, grid: GRID, elevationsM };
}

/** 一块平坦瓦片 */
function flatTile(south: number, west: number, elevation: number): TerrainTile {
  return makeTile(south, west, () => elevation);
}

describe('tileElevationM', () => {
  const tile = makeTile(47, 11, (row, col) => row * GRID + col);

  it('按行列取到对应格子', () => {
    expect(tileElevationM(tile, { latitude: 47, longitude: 11 })).toBe(0);
    expect(tileElevationM(tile, { latitude: 47, longitude: 11 + CELL })).toBe(1);
    expect(tileElevationM(tile, { latitude: 47 + CELL, longitude: 11 })).toBe(GRID);
  });

  // 与中间件同源的浮点陷阱：格线上的点不能被算进前一格
  it('落在格线上的点归到右侧格子', () => {
    for (let step = 1; step < GRID; step++) {
      expect(tileElevationM(tile, { latitude: 47 + CELL * step, longitude: 11 })).toBe(
        step * GRID,
      );
      expect(tileElevationM(tile, { latitude: 47, longitude: 11 + CELL * step })).toBe(step);
    }
  });

  it('瓦片外的点返回 undefined', () => {
    expect(tileElevationM(tile, { latitude: 46.99, longitude: 11.1 })).toBeUndefined();
    expect(tileElevationM(tile, { latitude: 47.1, longitude: 10.99 })).toBeUndefined();
    expect(tileElevationM(tile, { latitude: 47 + SPAN, longitude: 11.1 })).toBeUndefined();
    expect(tileElevationM(tile, { latitude: 47.1, longitude: 11 + SPAN })).toBeUndefined();
  });

  it('格数与 grid² 对不上的瓦片不给值', () => {
    const broken: TerrainTile = { ...tile, elevationsM: [1, 2, 3] };
    expect(tileElevationM(broken, { latitude: 47.1, longitude: 11.1 })).toBeUndefined();
  });
});

describe('elevationM', () => {
  const tiles = [flatTile(47, 11, 1000), flatTile(47, 11.25, 2000)];

  it('在多块瓦片里找到覆盖该点的那块', () => {
    expect(elevationM(tiles, { latitude: 47.1, longitude: 11.1 })).toBe(1000);
    expect(elevationM(tiles, { latitude: 47.1, longitude: 11.3 })).toBe(2000);
  });

  it('没有瓦片覆盖时返回 undefined —— 不能拿 0 冒充「海平面」', () => {
    expect(elevationM(tiles, { latitude: 47.1, longitude: 12.5 })).toBeUndefined();
    expect(elevationM([], { latitude: 47.1, longitude: 11.1 })).toBeUndefined();
  });
});

describe('terrainBandFor', () => {
  it('按相对本机的高度分三级', () => {
    expect(terrainBandFor(10_000, 10_000)).toBe('above');
    expect(terrainBandFor(12_000, 10_000)).toBe('above');
    expect(terrainBandFor(9_500, 10_000)).toBe('near');
    expect(terrainBandFor(9_000, 10_000)).toBe('near');
    expect(terrainBandFor(8_500, 10_000)).toBe('below');
    expect(terrainBandFor(8_000, 10_000)).toBe('below');
  });

  /*
   * 低于绘制下限的判为 safe，而不是「不画」。
   *
   * 两者在界面上完全不同：safe 会铺一层淡绿，表示「这一片查过了、没事」；
   * 不画则是一片空白，与「压根没取到高程数据」长得一模一样 ——
   * 飞行员没法从空白里分辨自己是安全还是失去了地形信息。
   */
  it('低于本机 2000 ft 以下判为安全，而不是不画', () => {
    expect(terrainBandFor(7_999, 10_000)).toBe('safe');
    expect(terrainBandFor(0, 10_000)).toBe('safe');
  });

  it('非有限值不画', () => {
    expect(terrainBandFor(Number.NaN, 10_000)).toBeUndefined();
    expect(terrainBandFor(10_000, Number.NaN)).toBeUndefined();
  });
});

describe('buildTerrainCells', () => {
  it('告警格逐格产出，并带上与图例一致的配色', () => {
    const tile = makeTile(47, 11, (row) => (row === 0 ? 3000 : 0));
    // 第 0 行 3000 m ≈ 9843 ft；本机 9000 ft → above。其余 0 m → safe
    const cells = buildTerrainCells([tile], 9000);
    const alerting = cells.filter((cell) => cell.band !== 'safe');
    expect(alerting).toHaveLength(GRID);
    for (const cell of alerting) {
      expect(cell.band).toBe('above');
      expect(cell.color).toBe(TERRAIN_BAND_COLOR.above);
      expect(cell.north - cell.south).toBeCloseTo(CELL, 10);
      expect(cell.east - cell.west).toBeCloseTo(CELL, 10);
    }
  });

  /*
   * 安全格抽稀：巡航时视野内几乎每格都安全，逐格画等于把格子数翻十倍，
   * 而它们全是同一片淡绿、完全冗余。告警格不受影响 —— 那几格差一格就是
   * 差一个网格距，位置本身就是信息。
   */
  it('安全格按步长抽稀，告警格不抽', () => {
    const safeOnly = buildTerrainCells([flatTile(47, 11, 0)], 30_000);
    const perAxis = Math.ceil(GRID / SAFE_CELL_STRIDE);
    expect(safeOnly).toHaveLength(perAxis * perAxis);
    expect(safeOnly.every((cell) => cell.band === 'safe')).toBe(true);

    // 同一块瓦片全部判为告警时，一格都不能少
    const alertingOnly = buildTerrainCells([flatTile(47, 11, 3000)], 0);
    expect(alertingOnly).toHaveLength(GRID * GRID);
  });

  it('抽稀后的安全格圆按同样倍数放大，铺出来仍是连续一片', () => {
    const safe = buildTerrainCells([flatTile(47, 11, 0)], 30_000)[0];
    const alerting = buildTerrainCells([flatTile(47, 11, 3000)], 0)[0];
    expect(safe.radiusM).toBeCloseTo(alerting.radiusM * SAFE_CELL_STRIDE, 6);
  });

  it('每个格子都带得出画圆用的中心与半径', () => {
    const cell = buildTerrainCells([flatTile(47, 11, 3000)], 0)[0];
    expect(cell.centerLat).toBeCloseTo((cell.south + cell.north) / 2, 10);
    expect(cell.centerLon).toBeCloseTo((cell.west + cell.east) / 2, 10);
    expect(cell.radiusM).toBeGreaterThan(0);
  });

  it('格子的经纬范围拼得回整块瓦片', () => {
    const tile = flatTile(47, 11, 3000);
    const cells = buildTerrainCells([tile], 0);
    expect(cells).toHaveLength(GRID * GRID);
    expect(Math.min(...cells.map((c) => c.south))).toBeCloseTo(47, 10);
    expect(Math.min(...cells.map((c) => c.west))).toBeCloseTo(11, 10);
    expect(Math.max(...cells.map((c) => c.north))).toBeCloseTo(47 + SPAN, 10);
    expect(Math.max(...cells.map((c) => c.east))).toBeCloseTo(11 + SPAN, 10);
  });

  it('本机高度不可用时一个格子都不画', () => {
    expect(buildTerrainCells([flatTile(47, 11, 3000)], Number.NaN)).toHaveLength(0);
  });

  it('高程按米换英尺，不能直接拿米比英尺', () => {
    // 3000 m = 9842.5 ft。本机 9900 ft：按英尺比是 near，按米直接比会算成 below
    const cells = buildTerrainCells([flatTile(47, 11, 3000)], 9900);
    expect(cells[0]?.band).toBe('near');
    expect(cells[0]?.elevationFt).toBeCloseTo(3000 * METERS_TO_FEET, 6);
  });
});

describe('terrainBoundsAround', () => {
  it('围出一个包住中心点的方框', () => {
    const bounds = terrainBoundsAround({ latitude: 47, longitude: 11 }, 20);
    expect(bounds.south).toBeLessThan(47);
    expect(bounds.north).toBeGreaterThan(47);
    expect(bounds.west).toBeLessThan(11);
    expect(bounds.east).toBeGreaterThan(11);
    // 20 NM ≈ 0.333°
    expect(bounds.north - 47).toBeCloseTo(20 / 60, 2);
  });
});

const CRUISE = {
  position: { latitude: 47, longitude: 11 },
  trackDeg: 0,
  groundSpeedKt: 300,
  altitudeFt: 10_000,
  verticalSpeedFpm: 0,
  radioAltitudeFt: 8_000,
  onGround: false,
};

/** 一整片覆盖前方的平坦瓦片，高程可调 */
function terrainAhead(elevationM_: number): TerrainTile[] {
  return terrainRisingNorthOf(Number.POSITIVE_INFINITY, elevationM_, elevationM_);
}

/**
 * 一整片覆盖前方的瓦片，`thresholdLat` 以北抬高。
 *
 * 注意抬高要**按格**而不是按瓦片：一块瓦片跨 0.25°（约 15 NM），
 * 整块整块地抬根本落不进 5 NM 的前视范围里。
 */
function terrainRisingNorthOf(thresholdLat: number, lowM: number, highM: number): TerrainTile[] {
  const tiles: TerrainTile[] = [];
  for (let latIdx = 186; latIdx <= 192; latIdx++) {
    for (let lonIdx = 42; lonIdx <= 46; lonIdx++) {
      const south = latIdx * SPAN;
      tiles.push(
        makeTile(south, lonIdx * SPAN, (row) => (south + row * CELL >= thresholdLat ? highM : lowM)),
      );
    }
  }
  return tiles;
}

describe('sampleTerrainAhead 的判定前置条件', () => {
  const tiles = terrainAhead(0);

  it('在地面时不判', () => {
    expect(sampleTerrainAhead({ ...CRUISE, onGround: true }, tiles).evaluated).toBe(false);
  });

  it('地速太低时不判', () => {
    const slow = { ...CRUISE, groundSpeedKt: TERRAIN_MIN_GROUND_SPEED_KT - 1 };
    expect(sampleTerrainAhead(slow, tiles).evaluated).toBe(false);
  });

  it('无线电高度太低时不判 —— 那一段归既有的近地告警管', () => {
    const low = { ...CRUISE, radioAltitudeFt: TERRAIN_MIN_RADIO_ALTITUDE_FT - 1 };
    expect(sampleTerrainAhead(low, tiles).evaluated).toBe(false);
  });

  it('无线电高度够高时照常判', () => {
    const ok = { ...CRUISE, radioAltitudeFt: TERRAIN_MIN_RADIO_ALTITUDE_FT + 1 };
    expect(sampleTerrainAhead(ok, tiles).evaluated).toBe(true);
  });

  it('没有无线电高度时不因此跳过', () => {
    const noRa = { ...CRUISE, radioAltitudeFt: undefined };
    expect(sampleTerrainAhead(noRa, tiles).evaluated).toBe(true);
  });

  it('高度不可用时不判', () => {
    expect(sampleTerrainAhead({ ...CRUISE, altitudeFt: Number.NaN }, tiles).evaluated).toBe(false);
  });

  it('一块瓦片都没有时不判，而不是当成前方没有山', () => {
    const result = sampleTerrainAhead(CRUISE, []);
    expect(result.evaluated).toBe(false);
    expect(result.missingSamples).toBe(TERRAIN_SAMPLE_COUNT);
    expect(buildTerrainAheadAlert(result)).toBeNull();
  });

  it('只有部分点有高程时照常判，并记下缺了几个', () => {
    // 从瓦片北缘附近起飞：5 NM 前视会飞出这块瓦片的上边界（47.25），
    // 后半程没有覆盖
    const nearEdge = { ...CRUISE, position: { latitude: 47.2, longitude: 11.1 } };
    const result = sampleTerrainAhead(nearEdge, [flatTile(47, 11, 0)]);
    expect(result.evaluated).toBe(true);
    expect(result.samples.length).toBeGreaterThan(0);
    expect(result.missingSamples).toBeGreaterThan(0);
    expect(result.samples.length + result.missingSamples).toBe(TERRAIN_SAMPLE_COUNT);
  });
});

describe('sampleTerrainAhead 的采样', () => {
  it('沿航迹向前铺开采样点', () => {
    const result = sampleTerrainAhead(CRUISE, terrainAhead(0));
    expect(result.samples).toHaveLength(TERRAIN_SAMPLE_COUNT);
    // 航迹 0° 应当一路往北，经度基本不动
    for (const sample of result.samples) {
      expect(sample.coord.latitude).toBeGreaterThan(CRUISE.position.latitude);
      expect(sample.coord.longitude).toBeCloseTo(CRUISE.position.longitude, 6);
    }
    const distances = result.samples.map((s) => s.distanceNm);
    expect(distances).toEqual([...distances].sort((a, b) => a - b));
  });

  it('前视距离随地速增加，但有上限', () => {
    const slow = sampleTerrainAhead({ ...CRUISE, groundSpeedKt: 120 }, terrainAhead(0));
    const fast = sampleTerrainAhead({ ...CRUISE, groundSpeedKt: 480 }, terrainAhead(0));
    const reach = (r: ReturnType<typeof sampleTerrainAhead>) =>
      r.samples[r.samples.length - 1].distanceNm;
    expect(reach(fast)).toBeGreaterThan(reach(slow));
    // 120 kt × 60 s = 2 NM
    expect(reach(slow)).toBeCloseTo(120 * (TERRAIN_CAUTION_LOOK_AHEAD_SEC / 3600), 6);

    const silly = sampleTerrainAhead({ ...CRUISE, groundSpeedKt: 5000 }, terrainAhead(0));
    expect(reach(silly)).toBeLessThanOrEqual(TERRAIN_MAX_LOOK_AHEAD_NM);
  });

  it('下降会把预计高度压低', () => {
    const level = sampleTerrainAhead(CRUISE, terrainAhead(0));
    const descending = sampleTerrainAhead(
      { ...CRUISE, verticalSpeedFpm: -2000 },
      terrainAhead(0),
    );
    const last = (r: ReturnType<typeof sampleTerrainAhead>) => r.samples[r.samples.length - 1];
    expect(last(descending).predictedAltitudeFt).toBeLessThan(last(level).predictedAltitudeFt);
  });

  // 保守判定：爬升不投影。「我等会儿会爬上去」不该成为不报警的理由
  it('爬升不投影，预计高度与改平时相同', () => {
    const level = sampleTerrainAhead(CRUISE, terrainAhead(0));
    const climbing = sampleTerrainAhead({ ...CRUISE, verticalSpeedFpm: 3000 }, terrainAhead(0));
    const last = (r: ReturnType<typeof sampleTerrainAhead>) => r.samples[r.samples.length - 1];
    expect(last(climbing).predictedAltitudeFt).toBeCloseTo(last(level).predictedAltitudeFt, 6);
  });

  it('余度 = 预计高度 − 地形高程，且 worst 取最小的那个', () => {
    const result = sampleTerrainAhead(CRUISE, terrainAhead(1000));
    const terrainFt = 1000 * METERS_TO_FEET;
    for (const sample of result.samples) {
      expect(sample.terrainFt).toBeCloseTo(terrainFt, 6);
      expect(sample.clearanceFt).toBeCloseTo(sample.predictedAltitudeFt - sample.terrainFt, 6);
    }
    const minClearance = Math.min(...result.samples.map((s) => s.clearanceFt));
    expect(result.worst?.clearanceFt).toBeCloseTo(minClearance, 10);
  });
});

describe('buildTerrainAheadAlert', () => {
  it('地形远低于本机时不报警', () => {
    const result = sampleTerrainAhead(CRUISE, terrainAhead(0));
    expect(buildTerrainAheadAlert(result)).toBeNull();
  });

  it('远处有高地形报 caution', () => {
    // 300 kt 下 60 s 前视 = 5 NM。47.075° 在 4.5 NM 外（约 54 s），
    // 落在 caution 窗口内、warning 窗口外
    const high = (10_000 - TERRAIN_REQUIRED_CLEARANCE_FT + 500) / METERS_TO_FEET;
    const tiles = terrainRisingNorthOf(47.075, 0, high);
    const alert = buildTerrainAheadAlert(sampleTerrainAhead(CRUISE, tiles));
    expect(alert?.id).toBe('terrain_ahead_caution');
    expect(alert?.level).toBe('caution');
  });

  it('近处有高地形报 danger', () => {
    const high = (10_000 - TERRAIN_REQUIRED_CLEARANCE_FT + 500) / METERS_TO_FEET;
    const alert = buildTerrainAheadAlert(sampleTerrainAhead(CRUISE, terrainAhead(high)));
    expect(alert?.id).toBe('terrain_ahead_danger');
    expect(alert?.level).toBe('danger');
  });

  it('余度刚好够就不报', () => {
    const justEnough = (10_000 - TERRAIN_REQUIRED_CLEARANCE_FT) / METERS_TO_FEET;
    expect(buildTerrainAheadAlert(sampleTerrainAhead(CRUISE, terrainAhead(justEnough)))).toBeNull();
  });

  it('余度差一点就报', () => {
    const justShort = (10_000 - TERRAIN_REQUIRED_CLEARANCE_FT + 50) / METERS_TO_FEET;
    expect(buildTerrainAheadAlert(sampleTerrainAhead(CRUISE, terrainAhead(justShort)))).not.toBeNull();
  });

  it('没做判定时一律不报', () => {
    expect(buildTerrainAheadAlert({ samples: [], missingSamples: 3, evaluated: false })).toBeNull();
  });

  it('告警文案用的是 i18n key，不是硬编码中文', () => {
    const alert = buildTerrainAheadAlert(sampleTerrainAhead(CRUISE, terrainAhead(2900)));
    expect(alert?.message).toMatch(/^map\./);
  });
});
