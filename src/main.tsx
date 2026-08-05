import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { App } from './core/app';
import { ModuleRegistry } from './core/module-registry/module-registry';
import { AppLogger } from './core/utils/logger';
import { ModulesRegisterEntry } from './modules/modules-register-entry';
import './styles/global.css';

/**
 * 应用入口
 *
 * 对应 Flutter 版 `lib/main.tsx` 的 `main()`：
 * 先完成模块注册与 store 绑定，再挂载 React 树。
 *
 * ── Web 降级说明 ──
 * 桌面版在这里还要劫持 path_provider、初始化 window_manager 并设置窗口尺寸，
 * Web 无对应能力，均已移除。
 */
function bootstrap(): void {
  try {
    // 1. 注册全部业务模块（写入 11 张注册表）
    ModulesRegisterEntry.registerAll();

    // 2. 建立模块 store 之间的订阅关系（等价于桌面版的 ChangeNotifierProxyProvider）
    ModuleRegistry.providers.setupAll();

    // 3. 挂载 React 树
    const container = document.getElementById('root');
    if (!container) throw new Error('#root container not found');

    createRoot(container).render(
      <StrictMode>
        <App />
      </StrictMode>,
    );
  } catch (e) {
    AppLogger.error('Start application failed!', e);
    // 启动失败时至少给用户一个可读的提示，而不是白屏
    const container = document.getElementById('root');
    if (container) {
      container.innerHTML = `<div style="padding:32px;font-family:sans-serif;color:#e74c3c">
        <h1 style="font-size:18px;margin-bottom:8px">应用启动失败 / Failed to start</h1>
        <pre style="white-space:pre-wrap;font-size:12px">${String(e)}</pre>
      </div>`;
    }
  }
}

bootstrap();
