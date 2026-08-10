import { describe, expect, it } from 'vitest';

import { auditSource, extractByLocale, hasTranslationEntries } from './check-i18n.mjs';

/**
 * i18n 门禁自身的回归测试
 *
 * 校验器漏检时不会报错，只会「一直通过」—— 比没有校验器更危险，
 * 因为大家以为它在守着。这里把它漏过的两类情况钉死。
 */

/** 造一份译文源码；每个对象一段，块缩进与真实文件一致（2 空格） */
function translationFile(objects) {
  return objects
    .map(
      ({ name, alias, zh, en }) => `
export const ${name} = {
  zh_CN: {
${Object.entries(zh)
  .map(([key, text]) => `    [${alias}.${key}]: '${text}',`)
  .join('\n')}
  },
  en_US: {
${Object.entries(en)
  .map(([key, text]) => `    [${alias}.${key}]: '${text}',`)
  .join('\n')}
  },
};
`,
    )
    .join('\n');
}

describe('extractByLocale', () => {
  // 坑 1：早先按 locale 覆盖，后一个对象把前一个的键整个顶掉
  it('同一文件里的多个译文对象要累加，不能互相覆盖', () => {
    const source = translationFile([
      { name: 'moduleTranslations', alias: 'K', zh: { a: '甲', b: '乙' }, en: { a: 'A', b: 'B' } },
      { name: 'navigationTranslations', alias: 'N', zh: { x: '丙' }, en: { x: 'X' } },
    ]);

    const byLocale = extractByLocale(source);

    expect(byLocale.zh_CN.map((e) => e.key).sort()).toEqual(['K.a', 'K.b', 'N.x']);
    expect(byLocale.en_US.map((e) => e.key).sort()).toEqual(['K.a', 'K.b', 'N.x']);
  });

  // 坑 2：键名别名写死成 K.，用 N. 的那个对象整体隐形
  it('键名可以用任意常量别名，不限于 K.', () => {
    const source = translationFile([
      { name: 'navigationTranslations', alias: 'N', zh: { x: '丙' }, en: { x: 'X' } },
    ]);

    expect(extractByLocale(source).zh_CN.map((e) => e.key)).toEqual(['N.x']);
  });

  it('不同别名下的同名属性算作不同的键', () => {
    const source = translationFile([
      { name: 'a', alias: 'K', zh: { title: '甲' }, en: { title: 'A' } },
      { name: 'b', alias: 'N', zh: { title: '乙' }, en: { title: 'B' } },
    ]);

    const keys = extractByLocale(source).zh_CN.map((e) => e.key);
    expect(keys).toEqual(['K.title', 'N.title']);
    // 不能被当成重复键
    expect(auditSource('t.ts', source).problems).toEqual([]);
  });

  it('折行写的长文案也能取到', () => {
    const source = `
export const t = {
  zh_CN: {
    [K.long]:
      '这是一段很长的文案，写不下所以换了行',
  },
  en_US: {
    [K.long]:
      'A long sentence that wraps onto the next line',
  },
};
`;
    expect(extractByLocale(source).zh_CN).toEqual([
      { key: 'K.long', text: '这是一段很长的文案，写不下所以换了行' },
    ]);
  });
});

describe('hasTranslationEntries', () => {
  it('认得任意别名的译文文件', () => {
    expect(hasTranslationEntries("  [K.a]: '甲',")).toBe(true);
    expect(hasTranslationEntries("  [N.a]: '甲',")).toBe(true);
  });

  it('普通源码不会被误判', () => {
    expect(hasTranslationEntries('const x = { a: 1 };')).toBe(false);
  });
});

describe('auditSource', () => {
  it('键集一致时没有问题', () => {
    const source = translationFile([
      { name: 't', alias: 'K', zh: { a: '甲', b: '乙' }, en: { a: 'A', b: 'B' } },
    ]);
    expect(auditSource('t.ts', source).problems).toEqual([]);
  });

  it('漏译会被报出来', () => {
    const source = translationFile([
      { name: 't', alias: 'K', zh: { a: '甲', b: '乙' }, en: { a: 'A' } },
    ]);
    const { problems } = auditSource('t.ts', source);
    expect(problems).toHaveLength(1);
    expect(problems[0]).toContain('en_US');
    expect(problems[0]).toContain('K.b');
  });

  // 这条正是修复的意义：第二个对象里的漏译，以前会被整段吞掉
  it('第二个译文对象里的漏译同样能被抓到', () => {
    const source = translationFile([
      { name: 'a', alias: 'K', zh: { a: '甲' }, en: { a: 'A' } },
      { name: 'b', alias: 'N', zh: { x: '丙', y: '丁' }, en: { x: 'X' } },
    ]);
    const { problems } = auditSource('t.ts', source);
    expect(problems).toHaveLength(1);
    expect(problems[0]).toContain('N.y');
  });

  it('重复键会被报出来', () => {
    const source = `
export const t = {
  zh_CN: {
    [K.a]: '甲',
    [K.a]: '甲二',
  },
  en_US: {
    [K.a]: 'A',
  },
};
`;
    const { problems } = auditSource('t.ts', source);
    expect(problems.some((p) => p.includes('重复键：K.a'))).toBe(true);
  });

  it('占位符数量不一致会被报出来', () => {
    const source = translationFile([
      { name: 't', alias: 'K', zh: { a: '{} 到 {}' }, en: { a: 'from {}' } },
    ]);
    const { problems } = auditSource('t.ts', source);
    expect(problems.some((p) => p.includes('占位符数量不一致'))).toBe(true);
  });

  it('没有译文块时返回空结果而不是抛异常', () => {
    const audit = auditSource('t.ts', 'const x = 1;');
    expect(audit.problems).toEqual([]);
    expect(audit.union.size).toBe(0);
  });

  it('union 覆盖两个对象的全部键', () => {
    const source = translationFile([
      { name: 'a', alias: 'K', zh: { a: '甲' }, en: { a: 'A' } },
      { name: 'b', alias: 'N', zh: { x: '丙' }, en: { x: 'X' } },
    ]);
    expect(auditSource('t.ts', source).union.size).toBe(2);
  });
});
