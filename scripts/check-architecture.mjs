#!/usr/bin/env node
/**
 * 架构约束门禁（工程手册 §3.2 依赖方向铁律）
 *
 * 光在文档里写「依赖只能向内」是守不住的 —— 本项目就出现过 core/ 反向
 * import modules/ 的情况，而文档同时声称这是铁律。所以把规则写成可执行的检查，
 * 让 CI 来守。
 *
 * ⚠️ 匹配时必须同时覆盖三种写法，否则会漏：
 *   import x from 'y'      具名/默认导入
 *   import 'y'             **副作用导入**（曾漏掉过：只匹配 `from` 的话完全看不见）
 *   require('y') / import('y')  动态引入
 *
 * 退出码非零即失败。
 */

/** 生成能匹配上述三种写法的正则 */
function importPattern(moduleExpression) {
  return new RegExp(
    String.raw`(?:from\s*|import\s*|require\s*\(\s*)['"]${moduleExpression}['"]`,
  );
}
import { readFileSync, readdirSync, statSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join, relative } from 'node:path';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const srcRoot = join(root, 'src');

/** 逐条规则：命中 forbidden 即违规 */
const rules = [
  {
    name: 'core 层不得依赖业务模块',
    // 框架层一旦绑死某个模块，模块就没法独立裁剪了
    appliesTo: (path) => path.startsWith('src/core/'),
    forbidden: importPattern(String.raw`[^'"]*\/modules\/[^'"]*`),
    hint: '改用依赖倒置：在 core 里声明接口，由模块在注册期注入实现（参考 core/services/backend-transport.ts）',
  },
  {
    name: '纯计算 service 不得依赖框架或 IO',
    // 这些是领域层：必须能脱离 React/Leaflet/store 被直接调用与测试
    appliesTo: (path) =>
      /^src\/modules\/[^/]+\/services\//.test(path) &&
      /(approach-beam|holding-geometry|papi-guidance|airport-outline|map-airport-parser|map-response-parsers|planned-route-parser|procedure-parser|taxi-graph|geo|metar-decode|compass-ring|runway-occupancy|aircraft-info-panel-layout|takeoff-landing-metrics|flight-alerts|efb-gates|flight-workflow|ws-delta-assembler|terrain-model|local-clock|update-model)\.ts$/.test(
        path,
      ),
    forbidden: new RegExp(
      importPattern(String.raw`react|leaflet|zustand`).source +
        '|' +
        importPattern(String.raw`[^'"]*\/providers\/[^'"]*`).source,
    ),
    hint: '把框架相关的部分留在调用方，service 只做纯计算',
  },
  {
    name: 'models 不得依赖框架',
    appliesTo: (path) => /^src\/modules\/[^/]+\/models\//.test(path),
    forbidden: importPattern(String.raw`react|leaflet|zustand`),
    hint: '数据模型应是纯类型与常量',
  },
];

function walk(dir, files = []) {
  for (const entry of readdirSync(dir)) {
    const full = join(dir, entry);
    if (statSync(full).isDirectory()) walk(full, files);
    else if (/\.(ts|tsx)$/.test(entry)) files.push(full);
  }
  return files;
}

const violations = [];
for (const file of walk(srcRoot)) {
  const path = relative(root, file).replace(/\\/g, '/');
  const source = readFileSync(file, 'utf8');
  // 去掉注释再匹配：注释里提到路径不算依赖
  const code = source
    .replace(/\/\*[\s\S]*?\*\//g, '')
    .replace(/(^|[^:])\/\/.*$/gm, '$1');

  for (const rule of rules) {
    if (!rule.appliesTo(path)) continue;
    for (const line of code.split('\n')) {
      if (rule.forbidden.test(line)) {
        violations.push({ path, rule: rule.name, line: line.trim(), hint: rule.hint });
      }
    }
  }
}

if (violations.length > 0) {
  console.error('架构约束校验失败：\n');
  for (const violation of violations) {
    console.error(`  [${violation.rule}]`);
    console.error(`    ${violation.path}`);
    console.error(`    ${violation.line}`);
    console.error(`    → ${violation.hint}\n`);
  }
  process.exit(1);
}

console.log('架构约束校验通过：依赖方向未出现反向依赖');
