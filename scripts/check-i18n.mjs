#!/usr/bin/env node
/**
 * i18n 门禁（工程手册 §7）
 *
 * 校验三件事：
 *   1. 同一份译文文件里，各语言的**键集必须一致**（漏译会让界面直接显示 key）；
 *   2. **不得有重复键**（后者静默覆盖前者，极难发现）；
 *   3. 同一个 key 在各语言里的**占位符数量必须对齐**（`{}` 数量不同会串位）。
 *
 * 另外报告各语言的覆盖率。缺失语言**不算失败** —— 本项目有
 * 「当前语言 → en_US → key」的回退链，模块只提供 zh/en 是已知且有意的取舍
 * （见 docs/DESIGN.md 开放问题）。但覆盖率必须可见，不能悄悄退化。
 *
 * 退出码非零即失败。
 */
import { readFileSync, readdirSync, statSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join, relative } from 'node:path';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const srcRoot = join(root, 'src');

/** 项目支持的语言（与 core/localization 的 locale 列表一致） */
const LOCALES = ['zh_CN', 'en_US', 'de_DE'];

function walk(dir, files = []) {
  for (const entry of readdirSync(dir)) {
    const full = join(dir, entry);
    if (statSync(full).isDirectory()) walk(full, files);
    else if (/\.ts$/.test(entry)) files.push(full);
  }
  return files;
}

/** 按语言块切开一份译文文件，返回 { locale: [key, ...] } */
function extractByLocale(source) {
  const result = {};
  const localePattern = new RegExp(`\\n\\s{2,4}\\[?(${LOCALES.join('|')})\\]?\\s*:\\s*\\{`, 'g');
  const marks = [...source.matchAll(localePattern)];
  for (let i = 0; i < marks.length; i++) {
    const locale = marks[i][1];
    const start = marks[i].index + marks[i][0].length;
    const end = i + 1 < marks.length ? marks[i + 1].index : source.length;
    const body = source.slice(start, end);
    // 键写作 [K.someKey]: '文案'
    result[locale] = [...body.matchAll(/\[K\.(\w+)\]\s*:\s*('|")((?:\\.|(?!\2).)*)\2/g)].map(
      (m) => ({ key: m[1], text: m[3] }),
    );
  }
  return result;
}

const problems = [];
const coverage = {};

for (const file of walk(srcRoot)) {
  const source = readFileSync(file, 'utf8');
  if (!/\[K\.\w+\]\s*:/.test(source)) continue;

  const path = relative(root, file).replace(/\\/g, '/');
  const byLocale = extractByLocale(source);
  const locales = Object.keys(byLocale);
  if (locales.length === 0) continue;

  // 1. 重复键
  for (const locale of locales) {
    const seen = new Set();
    for (const { key } of byLocale[locale]) {
      if (seen.has(key)) problems.push(`${path} [${locale}] 重复键：${key}`);
      seen.add(key);
    }
  }

  // 2. 键集一致（只比较该文件里**已声明**的语言）
  const keySets = Object.fromEntries(
    locales.map((locale) => [locale, new Set(byLocale[locale].map((e) => e.key))]),
  );
  const union = new Set(locales.flatMap((locale) => [...keySets[locale]]));
  for (const locale of locales) {
    const missing = [...union].filter((key) => !keySets[locale].has(key));
    if (missing.length > 0) {
      problems.push(
        `${path} [${locale}] 缺 ${missing.length} 个键：${missing.slice(0, 5).join(', ')}${
          missing.length > 5 ? ' …' : ''
        }`,
      );
    }
  }

  // 3. 占位符对齐
  const placeholderCount = (text) => (text.match(/\{\}/g) || []).length;
  const byKey = {};
  for (const locale of locales) {
    for (const { key, text } of byLocale[locale]) {
      (byKey[key] ??= {})[locale] = placeholderCount(text);
    }
  }
  for (const [key, counts] of Object.entries(byKey)) {
    const values = new Set(Object.values(counts));
    if (values.size > 1) {
      problems.push(
        `${path} 占位符数量不一致 ${key}：${Object.entries(counts)
          .map(([l, n]) => `${l}=${n}`)
          .join(' ')}`,
      );
    }
  }

  // 覆盖率统计
  for (const locale of LOCALES) {
    coverage[locale] ??= { have: 0, total: 0 };
    coverage[locale].total += union.size;
    coverage[locale].have += keySets[locale] ? keySets[locale].size : 0;
  }
}

console.log('i18n 覆盖率：');
for (const locale of LOCALES) {
  const { have, total } = coverage[locale] ?? { have: 0, total: 0 };
  const percent = total === 0 ? 100 : Math.round((have / total) * 100);
  const note = percent < 100 ? '  ← 走回退链显示 en_US' : '';
  console.log(`  ${locale.padEnd(6)} ${String(have).padStart(5)}/${total}  ${percent}%${note}`);
}

if (problems.length > 0) {
  console.error('\ni18n 校验失败：');
  for (const problem of problems) console.error('  - ' + problem);
  process.exit(1);
}

console.log('\ni18n 校验通过：无重复键、已声明语言键集一致、占位符对齐');
