#!/usr/bin/env node
/**
 * 版本号跨文件同步校验（工程手册 §11.1）
 *
 * 单一事实来源是 package.json 的 version。版本号还出现在 README 的版本行与
 * docs/CHANGELOG.md 的顶部段落里，散落多处就会漂移 —— 这个脚本在 CI 里守住它们。
 *
 * 退出码非零即失败。
 */
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const read = (relative) => readFileSync(join(root, relative), 'utf8');

const version = JSON.parse(read('package.json')).version;
if (!version) {
  console.error('package.json 里没有 version 字段');
  process.exit(1);
}

const problems = [];

// CHANGELOG 顶部必须有本版本的段落，且带日期 —— 发布说明由 CI 从这里取
const changelog = read('docs/CHANGELOG.md');
const heading = new RegExp(`^## v${version.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')} — \\d{4}-\\d{2}-\\d{2}$`, 'm');
if (!heading.test(changelog)) {
  problems.push(
    `docs/CHANGELOG.md 缺少本版本段落，应形如：## v${version} — YYYY-MM-DD`,
  );
}

// README 里出现的版本号必须与 package.json 一致
const readme = read('README.md');
for (const match of readme.matchAll(/\bv?(\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?)\b/g)) {
  // 只校验形似本项目版本的串，避免把依赖版本号（React 19 之类）也算进来
  if (match[1].startsWith(version.split('.')[0] + '.') && match[1] !== version) {
    problems.push(`README.md 中的版本号 ${match[1]} 与 package.json 的 ${version} 不一致`);
  }
}

// app-constants.ts 里的回退值必须与 package.json 一致
//
// 这条是补上一个真实事故：`VITE_APP_VERSION` 从来没有人注入过，界面显示的
// 一直是那个写死的回退值。1.0.4 都要发了，侧边栏还挂着 1.0.3 —— 而当时的
// 版本校验只看 package.json / CHANGELOG / README，压根没看这个文件。
const constants = read('src/core/constants/app-constants.ts');
const fallback = /VITE_APP_VERSION\s*\?\?\s*'([^']+)'/.exec(constants);
if (!fallback) {
  problems.push('src/core/constants/app-constants.ts 里找不到 appVersion 的回退值');
} else if (fallback[1] !== version) {
  problems.push(
    `app-constants.ts 的回退版本 ${fallback[1]} 与 package.json 的 ${version} 不一致`,
  );
}

// package-lock.json 的根包版本必须跟上
//
// npm 只在依赖对不上时才报错，根包的 version 漂了它一声不吭 ——
// 这个文件从 1.0.3-beta 一路漂到 1.0.6-beta 都没人发现。
const lock = JSON.parse(read('package-lock.json'));
for (const [label, actual] of [
  ['package-lock.json 顶层', lock.version],
  ['package-lock.json 的 packages[""]', lock.packages?.['']?.version],
]) {
  if (actual !== version) {
    problems.push(`${label} 的版本 ${actual} 与 package.json 的 ${version} 不一致`);
  }
}

if (problems.length > 0) {
  console.error('版本同步校验失败：');
  for (const problem of problems) console.error('  - ' + problem);
  process.exit(1);
}

console.log(`版本同步校验通过：v${version}`);
