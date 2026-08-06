/**
 * ESLint 配置（工程手册 §4.1 警告即错误）
 *
 * `tsc --noEmit` 只管类型，管不了「类型正确但运行时会出错」的写法。本配置只收
 * 那些能抓到**真实缺陷**的规则，不收纯风格规则（缩进/引号交给 .editorconfig）。
 *
 * 之所以开类型感知（projectService），是因为本项目最容易踩的两类坑都要类型信息：
 *   - 浮动 Promise：地图图层大量 async 拉取，漏 await 会让失败静默消失；
 *   - 误用 any：后端响应是 unknown，解析器里一旦退化成 any，字段拼错也不报错。
 */

import js from '@eslint/js';
import tseslint from 'typescript-eslint';
import reactHooks from 'eslint-plugin-react-hooks';

export default tseslint.config(
  {
    ignores: ['dist/**', 'node_modules/**', 'tools/**', 'scripts/**', '*.config.*'],
  },
  js.configs.recommended,
  ...tseslint.configs.recommendedTypeChecked,
  {
    languageOptions: {
      parserOptions: {
        projectService: true,
        tsconfigRootDir: import.meta.dirname,
      },
    },
    plugins: { 'react-hooks': reactHooks },
    rules: {
      ...reactHooks.configs.recommended.rules,

      // ── 真实缺陷 ─────────────────────────────────────────────
      // 漏 await 的 Promise：失败会变成未捕获的 rejection，界面上什么也看不到
      '@typescript-eslint/no-floating-promises': 'error',
      '@typescript-eslint/no-misused-promises': 'error',
      // 后端响应必须以 unknown 进解析器，退化成 any 就等于放弃全部校验
      '@typescript-eslint/no-unsafe-argument': 'error',

      // ── 降级为 warn：存量较多，先可见再逐步清 ────────────────
      '@typescript-eslint/no-unsafe-assignment': 'warn',
      '@typescript-eslint/no-unsafe-member-access': 'warn',
      '@typescript-eslint/no-unsafe-call': 'warn',
      '@typescript-eslint/no-unsafe-return': 'warn',

      // 解构剔除键的惯用法：`const { id: _id, ...rest } = record`。
      // `_` 前缀就是「我知道它没用，我要的是 rest」的通行写法，不该报错。
      '@typescript-eslint/no-unused-vars': [
        'error',
        { argsIgnorePattern: '^_', varsIgnorePattern: '^_', destructuredArrayIgnorePattern: '^_' },
      ],

      // ── 关掉：与本项目的既定设计冲突或价值为负 ────────────────
      // 同步实现一个返回 Promise 的接口方法（如 FlightDataAdapter.setFlightNumber、
      // registerCleanup 的回调）是完全正当的 —— 契约要求返回 Promise，
      // 实现里恰好没有可等待的东西。为此把 async 去掉反而要手写 Promise.resolve()。
      '@typescript-eslint/require-await': 'off',
      // 模块注册表工厂在 render 期求值，等价于 Flutter 的 context.watch，
      // 这是 DESIGN.md §3.3 明确写下的有意设计，不是「在非组件里调 hook」。
      'react-hooks/rules-of-hooks': 'off',
      // i18n 键值表里大量非空断言与模板串，收益低噪音高
      '@typescript-eslint/restrict-template-expressions': 'off',
    },
  },
  {
    // 测试文件：断言里刻意构造脏数据，unsafe 系列规则会误报
    files: ['**/*.test.ts', '**/*.test.tsx'],
    rules: {
      '@typescript-eslint/no-unsafe-argument': 'off',
      '@typescript-eslint/no-explicit-any': 'off',
    },
  },
);
