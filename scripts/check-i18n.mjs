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
 *
 * ── 这个脚本自己踩过的两个坑（见 check-i18n.test.mjs）──
 * 一个校验器漏检时不会报错，只会「一直通过」，比没有校验器更危险 ——
 * 所以下面两条都写成了测试：
 *
 *   1. **一个文件里可能有多个译文对象**。`common-localization.ts` 同时导出
 *      `commonModuleTranslations` 与 `navigationModuleTranslations`，各自带一套
 *      zh_CN/en_US 块。早先按 locale **覆盖**，后一个对象把前一个的 39 个键
 *      整个顶掉，那些键从此不受任何校验。必须累加。
 *   2. **键名的常量别名不止 `K.`**。上面那个文件里导航部分用的是 `N.`。
 *      写死 `K.` 会让换了别名的对象整体隐形。
 */
import { readFileSync, readdirSync, statSync } from 'node:fs';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { dirname, join, relative } from 'node:path';

/** 项目支持的语言（与 core/localization 的 locale 列表一致） */
export const LOCALES = ['zh_CN', 'en_US', 'de_DE'];

/**
 * 匹配一条译文：`[<别名>.<键名>]: '文案'`
 *
 * 别名不写死：见文件头第 2 条。值允许换行后再起（`:` 与引号之间是 `\s*`），
 * 长文案在本项目里就是这么折行的。
 */
const ENTRY_PATTERN = /\[([A-Za-z_$][\w$]*)\.(\w+)\]\s*:\s*('|")((?:\\.|(?!\3).)*)\3/g;

/** 判断一份源码里是否含译文条目 */
export function hasTranslationEntries(source) {
  return /\[[A-Za-z_$][\w$]*\.\w+\]\s*:/.test(source);
}

/**
 * 按语言块切开一份译文文件，返回 `{ locale: [{ key, text }, ...] }`。
 *
 * key 用 `别名.键名` 的完整写法：两个别名下可能有同名属性，
 * 只取属性名会把它们误判成重复键。
 */
export function extractByLocale(source) {
  const result = {};
  const localePattern = new RegExp(`\\n\\s{2,4}\\[?(${LOCALES.join('|')})\\]?\\s*:\\s*\\{`, 'g');
  const marks = [...source.matchAll(localePattern)];
  for (let i = 0; i < marks.length; i++) {
    const locale = marks[i][1];
    const start = marks[i].index + marks[i][0].length;
    const end = i + 1 < marks.length ? marks[i + 1].index : source.length;
    const body = source.slice(start, end);
    const entries = [...body.matchAll(ENTRY_PATTERN)].map((m) => ({
      key: `${m[1]}.${m[2]}`,
      text: m[4],
    }));
    // 累加而不是覆盖：同一文件里的多个译文对象都要算进来
    (result[locale] ??= []).push(...entries);
  }
  return result;
}

/**
 * 审计一份译文源码，返回问题清单与各语言键集。
 *
 * `path` 只用于拼报错信息。
 */
export function auditSource(path, source) {
  const problems = [];
  const byLocale = extractByLocale(source);
  const locales = Object.keys(byLocale);
  if (locales.length === 0) {
    return { problems, keySets: {}, union: new Set() };
  }

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
    if (new Set(Object.values(counts)).size > 1) {
      problems.push(
        `${path} 占位符数量不一致 ${key}：${Object.entries(counts)
          .map(([l, n]) => `${l}=${n}`)
          .join(' ')}`,
      );
    }
  }

  return { problems, keySets, union };
}

function walk(dir, files = []) {
  for (const entry of readdirSync(dir)) {
    const full = join(dir, entry);
    if (statSync(full).isDirectory()) walk(full, files);
    else if (/\.ts$/.test(entry)) files.push(full);
  }
  return files;
}

/** 扫描整个 src 并打印报告，返回退出码 */
function main() {
  const root = join(dirname(fileURLToPath(import.meta.url)), '..');
  const srcRoot = join(root, 'src');

  const problems = [];
  const coverage = {};

  for (const file of walk(srcRoot)) {
    const source = readFileSync(file, 'utf8');
    if (!hasTranslationEntries(source)) continue;

    const path = relative(root, file).replace(/\\/g, '/');
    const audit = auditSource(path, source);
    if (audit.union.size === 0) continue;

    problems.push(...audit.problems);
    for (const locale of LOCALES) {
      coverage[locale] ??= { have: 0, total: 0 };
      coverage[locale].total += audit.union.size;
      coverage[locale].have += audit.keySets[locale] ? audit.keySets[locale].size : 0;
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
    return 1;
  }

  console.log('\ni18n 校验通过：无重复键、已声明语言键集一致、占位符对齐');
  return 0;
}

// 仅在直接运行时执行；被测试 import 时只取上面的纯函数
if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  process.exit(main());
}
