import { describe, expect, it } from 'vitest';

import type { AircraftChecklist } from '../models/flight-checklist';
import {
  appliesToSimulator,
  buildChecklistTemplate,
  normalizeRegistration,
  normalizeSimulatorTag,
  parseChecklistFile,
  resolveAircraft,
  serializeChecklists,
} from './checklist-services';

function checklist(overrides: Partial<AircraftChecklist> & { id: string }): AircraftChecklist {
  return {
    name: overrides.id,
    family: 'generic',
    sections: [{ phase: 'coldAndDark', items: [] }],
    ...overrides,
  };
}

describe('normalizeRegistration', () => {
  it('抹平横杠、空格与大小写', () => {
    expect(normalizeRegistration('B-6075')).toBe('B6075');
    expect(normalizeRegistration('b 6075')).toBe('B6075');
    expect(normalizeRegistration(' b-6075 ')).toBe('B6075');
  });

  it('空值安全', () => {
    expect(normalizeRegistration(undefined)).toBe('');
    expect(normalizeRegistration('  ')).toBe('');
  });
});

describe('normalizeSimulatorTag', () => {
  it('认识常见写法', () => {
    expect(normalizeSimulatorTag('xplane')).toBe('xplane');
    expect(normalizeSimulatorTag('X-Plane')).toBe('xplane');
    expect(normalizeSimulatorTag('MSFS')).toBe('msfs');
    expect(normalizeSimulatorTag('msfs2024')).toBe('msfs');
  });

  it('认不出来的一律当 any，不至于把检查单挑没了', () => {
    expect(normalizeSimulatorTag('p3d')).toBe('any');
    expect(normalizeSimulatorTag(undefined)).toBe('any');
  });
});

describe('appliesToSimulator', () => {
  it('没声明 simulators 视为不限', () => {
    expect(appliesToSimulator(checklist({ id: 'a' }), 'msfs')).toBe(true);
  });

  it('声明 any 视为不限', () => {
    expect(appliesToSimulator(checklist({ id: 'a', simulators: ['any'] }), 'msfs')).toBe(true);
  });

  it('声明具体模拟器时只对该模拟器生效', () => {
    const xp = checklist({ id: 'a', simulators: ['xplane'] });
    expect(appliesToSimulator(xp, 'xplane')).toBe(true);
    expect(appliesToSimulator(xp, 'msfs')).toBe(false);
  });
});

describe('resolveAircraft 自动切换', () => {
  const generic = checklist({ id: 'generic', name: 'Generic', family: 'generic' });
  const a320 = checklist({ id: 'a320', name: 'A320', family: 'a320' });
  const b6075 = checklist({
    id: 'my_b6075',
    name: 'My B-6075',
    family: 'a320',
    registrations: ['B-6075'],
  });
  const b6075Msfs = checklist({
    id: 'my_b6075_msfs',
    name: 'My B-6075 (MSFS)',
    family: 'a320',
    registrations: ['B-6075'],
    simulators: ['msfs'],
  });
  const list = [generic, a320, b6075, b6075Msfs];

  it('注册码优先于机型名', () => {
    const selected = resolveAircraft(
      { identifier: 'airbus a320 neo', registration: 'B-6075' },
      list,
    );
    expect(selected?.id).toBe('my_b6075');
  });

  it('注册码相同的多份模板里挑模拟器对得上的那份', () => {
    const selected = resolveAircraft(
      { identifier: 'airbus a320', registration: 'B-6075', simulator: 'msfs' },
      list,
    );
    expect(selected?.id).toBe('my_b6075_msfs');
  });

  it('注册码写法不同也能匹配上', () => {
    expect(resolveAircraft({ registration: 'b6075' }, list)?.id).toBe('my_b6075');
    expect(resolveAircraft({ registration: ' B-6075 ' }, list)?.id).toBe('my_b6075');
  });

  it('注册码匹配不上时回落到机型名', () => {
    const selected = resolveAircraft({ identifier: 'a320', registration: 'N999XX' }, list);
    expect(selected?.id).toBe('a320');
  });

  it('模拟器不匹配但注册码唯一时仍然采用该模板', () => {
    const onlyMsfs = [generic, b6075Msfs];
    const selected = resolveAircraft({ registration: 'B-6075', simulator: 'xplane' }, onlyMsfs);
    expect(selected?.id).toBe('my_b6075_msfs');
  });

  it('保持旧的字符串调用方式可用', () => {
    expect(resolveAircraft('a320', list)?.id).toBe('a320');
    expect(resolveAircraft(undefined, list)?.id).toBe('generic');
  });

  it('家族模糊匹配时优先挑适用当前模拟器的那份', () => {
    const xpB737 = checklist({ id: 'b737_xp', name: 'B737 XP', family: 'b737', simulators: ['xplane'] });
    const msfsB737 = checklist({ id: 'b737_msfs', name: 'B737 MSFS', family: 'b737', simulators: ['msfs'] });
    const selected = resolveAircraft(
      { identifier: 'zibo mod 738', simulator: 'msfs' },
      [generic, xpB737, msfsB737],
    );
    expect(selected?.id).toBe('b737_msfs');
  });
});

describe('模板字段解析', () => {
  it('JSON 里的 version / registrations / simulators 能读出来', () => {
    const content = JSON.stringify({
      aircraft: [
        {
          id: 'test',
          name: 'Test',
          version: '2.1',
          registrations: ['B-6075', 'b 6076'],
          simulators: ['xplane', 'msfs'],
          sections: [{ phase: 'coldAndDark', items: [{ task: 'BATTERY', response: 'ON' }] }],
        },
      ],
    });
    const [parsed] = parseChecklistFile('test.json', content);

    expect(parsed.version).toBe('2.1');
    expect(parsed.registrations).toEqual(['B-6075', 'B 6076']);
    expect(parsed.simulators).toEqual(['xplane', 'msfs']);
  });

  it('注册码写成逗号分隔字符串也认', () => {
    const content = JSON.stringify({
      aircraft: [
        {
          id: 'test',
          name: 'Test',
          registration: 'B-6075, B-6076',
          sections: [{ phase: 'coldAndDark', items: [{ task: 'A', response: 'B' }] }],
        },
      ],
    });
    const [parsed] = parseChecklistFile('test.json', content);
    expect(parsed.registrations).toEqual(['B-6075', 'B-6076']);
  });

  it('认不出的模拟器写法被丢弃，而不是变成「不限」', () => {
    const content = JSON.stringify({
      aircraft: [
        {
          id: 'test',
          name: 'Test',
          simulators: ['p3d'],
          sections: [{ phase: 'coldAndDark', items: [{ task: 'A', response: 'B' }] }],
        },
      ],
    });
    const [parsed] = parseChecklistFile('test.json', content);
    expect(parsed.simulators).toBeUndefined();
  });

  it('txt 的注释头能带元数据', () => {
    const content = [
      '# name: My Plane',
      '# version: 1.3',
      '# registration: B-6075',
      '# simulators: xplane',
      '[before_taxi]',
      'FLAPS | SET',
    ].join('\n');
    const [parsed] = parseChecklistFile('anything.txt', content);

    expect(parsed.name).toBe('My Plane');
    expect(parsed.version).toBe('1.3');
    expect(parsed.registrations).toEqual(['B-6075']);
    expect(parsed.simulators).toEqual(['xplane']);
    expect(parsed.sections[0].items[0].task).toBe('FLAPS');
  });

  it('注释头不会被当成检查项', () => {
    const content = ['# version: 1.0', '[cold_and_dark]', 'BATTERY | ON'].join('\n');
    const [parsed] = parseChecklistFile('a.txt', content);
    const tasks = parsed.sections.flatMap((section) => section.items.map((item) => item.task));
    expect(tasks).toEqual(['BATTERY']);
  });

  it('导出再导入能保住模板字段', () => {
    const original = checklist({
      id: 'roundtrip',
      name: 'Roundtrip',
      version: '3.0',
      registrations: ['B-6075'],
      simulators: ['msfs'],
      sections: [{ phase: 'coldAndDark', items: [{ id: 'i1', task: 'A', response: 'B', isChecked: true }] }],
    });

    const [restored] = parseChecklistFile('x.json', serializeChecklists([original]));

    expect(restored.version).toBe('3.0');
    expect(restored.registrations).toEqual(['B-6075']);
    expect(restored.simulators).toEqual(['msfs']);
    // 勾选状态不该被带出来
    expect(restored.sections[0].items[0].isChecked).toBe(false);
  });
});

describe('buildChecklistTemplate', () => {
  it('生成的模板本身就是合法的导入文件', () => {
    const parsed = parseChecklistFile('checklist_template.json', buildChecklistTemplate('A320neo'));
    expect(parsed.length).toBe(1);
    expect(parsed[0].sections.length).toBeGreaterThan(0);
  });

  it('用机型名做种子时 name / family 已经填好', () => {
    const parsed = parseChecklistFile('t.json', buildChecklistTemplate('Boeing 737-800'));
    expect(parsed[0].name).toBe('Boeing 737-800');
    expect(parsed[0].family).toBe('b737');
  });

  it('没有种子时也能生成', () => {
    const parsed = parseChecklistFile('t.json', buildChecklistTemplate());
    expect(parsed[0].name).toBe('My Aircraft');
  });

  it('模板里列全了字段说明，用户不必去翻文档', () => {
    const template = JSON.parse(buildChecklistTemplate()) as { _readme: string[] };
    const readme = template._readme.join('\n');
    for (const field of ['registrations', 'simulators', 'version', 'phase']) {
      expect(readme).toContain(field);
    }
  });
});
