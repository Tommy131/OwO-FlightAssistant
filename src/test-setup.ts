/**
 * 测试环境准备
 *
 * 只做两件事：接上 jest-dom 的断言，以及每个用例后卸载残留的 React 树。
 * 不在这里塞任何业务 mock —— 那样会让「这个测试到底依赖什么」变得看不见，
 * 各测试文件自己声明依赖更容易读。
 */

import '@testing-library/jest-dom/vitest';
import { cleanup } from '@testing-library/react';
import { afterEach } from 'vitest';

afterEach(() => {
  // 不卸载的话，下一个用例里 getByText 会同时命中上一个用例留下的节点
  cleanup();
});
