import { describe, expect, it } from 'vitest';
import { buildFuelPlan } from './briefing-service';
import type { PlannedFuel } from '../../common/models/planned-route-models';

/**
 * 简报燃油计划
 *
 * 两条来源共用一个出口：导入的 SimBrief 配载优先，没有就退回按距离的粗估。
 * 两者精度差着数量级，所以 `source` 与 `units` 必须准确 ——
 * 用户要靠它判断能不能照着这份数字加油。
 *
 * **单位一律不换算**：SimBrief 给的是用户自己设置的那套（也就是他机上 FMS 用的），
 * 换算过去反而对不上。
 */

const importedLbs: PlannedFuel = {
  units: 'lbs',
  planRamp: 16863,
  planTakeoff: 16463,
  planLanding: 9777,
  enrouteBurn: 6686,
  alternateBurn: 1200,
  contingency: 334,
  reserve: 5082,
  taxi: 400,
  extra: 0,
};

describe('没有导入时退回粗估', () => {
  it('沿用原有配方，单位为 KG', () => {
    const fuel = buildFuelPlan({ distanceNm: 1000, hasAlternate: false });
    expect(fuel.source).toBe('estimate');
    expect(fuel.units).toBe('KG');
    // 航段 = 1000 × 2.5
    expect(fuel.trip).toBe(2500);
    expect(fuel.reserve).toBe(1500);
    expect(fuel.taxi).toBe(200);
    expect(fuel.extra).toBe(125);
    expect(fuel.total).toBe(4325);
  });

  it('有备降时加一份 200NM 的量', () => {
    const withAlt = buildFuelPlan({ distanceNm: 1000, hasAlternate: true });
    const without = buildFuelPlan({ distanceNm: 1000, hasAlternate: false });
    expect(withAlt.total - without.total).toBe(500);
  });

  it('没有距离也给得出一份计划（手填航班常见）', () => {
    const fuel = buildFuelPlan({ hasAlternate: false });
    expect(fuel.source).toBe('estimate');
    expect(fuel.total).toBe(1700);
    expect(fuel.avgFlow).toBe(2600);
  });
});

describe('有导入时用真实配载', () => {
  it('逐项取自 OFP，不做任何换算', () => {
    const fuel = buildFuelPlan({ distanceNm: 256, hasAlternate: true, imported: importedLbs, importedEnrouteSeconds: 3095 });
    expect(fuel.source).toBe('simbrief');
    // 关键：单位保持 lbs，不能悄悄换成 KG（差 2.2 倍且看不出来）
    expect(fuel.units).toBe('LBS');
    expect(fuel.trip).toBe(6686);
    expect(fuel.total).toBe(16863);
    expect(fuel.reserve).toBe(5082);
    expect(fuel.taxi).toBe(400);
    expect(fuel.alternate).toBe(1200);
  });

  it('contingency 与 extra 合并成一栏 —— 简报只有一个「额外」', () => {
    const fuel = buildFuelPlan({ distanceNm: 256, hasAlternate: true, imported: importedLbs, importedEnrouteSeconds: 3095 });
    expect(fuel.extra).toBe(334);

    const both = buildFuelPlan({
      distanceNm: 256,
      hasAlternate: true,
      imported: { ...importedLbs, contingency: 300, extra: 700 },
    });
    expect(both.extra).toBe(1000);
  });

  it('平均油耗用 OFP 的真实航时算，不是按假定速度反推', () => {
    // 6686 lbs ÷ (3095s / 3600) = 7777 lbs/h。
    // 若按「距离 ÷ 450kt」反推会得到约 15000 —— 差近一倍，
    // 而且它夹在一堆真实数字中间，看不出是估的
    const fuel = buildFuelPlan({
      distanceNm: 256,
      hasAlternate: true,
      imported: importedLbs,
      importedEnrouteSeconds: 3095,
    });
    expect(Math.round(fuel.avgFlow)).toBe(7777);
  });

  it('没有航时就留 0，不编一个看起来合理的数', () => {
    const fuel = buildFuelPlan({ distanceNm: 256, hasAlternate: true, imported: importedLbs });
    expect(fuel.avgFlow).toBe(0);
  });

  it('落地油量优先用 OFP 的计划着陆油量', () => {
    const fuel = buildFuelPlan({ distanceNm: 256, hasAlternate: true, imported: importedLbs, importedEnrouteSeconds: 3095 });
    expect(fuel.estimatedArrivalFuel).toBe(9777);
  });

  it('OFP 没给着陆油量时退回「备份 + 备降」', () => {
    const { planLanding, ...withoutLanding } = importedLbs;
    void planLanding;
    const fuel = buildFuelPlan({
      distanceNm: 256,
      hasAlternate: true,
      imported: withoutLanding,
    });
    expect(fuel.estimatedArrivalFuel).toBe(5082 + 1200);
  });

  it('单位缺失时退回 KG 而不是留空', () => {
    const { units, ...withoutUnits } = importedLbs;
    void units;
    expect(buildFuelPlan({ distanceNm: 256, hasAlternate: true, imported: withoutUnits }).units)
      .toBe('KG');
  });
});

describe('导入数据不完整时的取舍', () => {
  it('缺航段耗油就整份退回估算 —— 半真半估比全估更危险', () => {
    // 用户会以为整份都是真实配载，照着加油就出问题
    const { enrouteBurn, ...noTrip } = importedLbs;
    void enrouteBurn;
    const fuel = buildFuelPlan({ distanceNm: 1000, hasAlternate: false, imported: noTrip });
    expect(fuel.source).toBe('estimate');
    expect(fuel.units).toBe('KG');
    expect(fuel.total).toBe(4325);
  });

  it('缺总油量同样整份退回估算', () => {
    const { planRamp, ...noTotal } = importedLbs;
    void planRamp;
    expect(buildFuelPlan({ distanceNm: 1000, hasAlternate: false, imported: noTotal }).source)
      .toBe('estimate');
  });

  it('空对象与 undefined 都退回估算', () => {
    expect(buildFuelPlan({ distanceNm: 500, hasAlternate: false, imported: {} }).source)
      .toBe('estimate');
    expect(buildFuelPlan({ distanceNm: 500, hasAlternate: false, imported: undefined }).source)
      .toBe('estimate');
  });

  it('可选项缺失时按 0 计，不影响主干', () => {
    const fuel = buildFuelPlan({
      distanceNm: 256,
      hasAlternate: false,
      imported: { units: 'kg', enrouteBurn: 5000, planRamp: 9000 },
    });
    expect(fuel.source).toBe('simbrief');
    expect(fuel.alternate).toBe(0);
    expect(fuel.reserve).toBe(0);
    expect(fuel.taxi).toBe(0);
    expect(fuel.extra).toBe(0);
  });
});
