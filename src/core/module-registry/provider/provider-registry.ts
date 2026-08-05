import type { Clearable } from '../clearable';
import { AppLogger } from '../../utils/logger';

/**
 * Store 绑定注册表（对应 Flutter 版 `provider_registry.dart`）
 *
 * ── 从 Provider 到 Zustand 的语义映射 ──
 * Flutter 用 `MultiProvider` 把模块 Provider 挂进 Widget 树，其中相当一部分是
 * `ChangeNotifierProxyProvider<HomeProvider, XProvider>`：每当 HomeProvider 更新，
 * 就把最新快照推给模块 Provider。
 *
 * Zustand 的 store 是全局的，不需要挂树；ProxyProvider 的「派生 + 联动」语义
 * 等价于「模块 store 订阅飞行数据 store」。因此这里注册的是 **绑定函数**：
 * 应用启动时统一 `setupAll()`，各模块在自己的 setup 里建立订阅并返回清理函数。
 */

export interface StoreBinding {
  /** 唯一标识，便于日志定位 */
  readonly id: string;
  /** 建立订阅，返回取消订阅的清理函数 */
  setup(): () => void;
}

class ProviderRegistryImpl implements Clearable {
  private bindings: StoreBinding[] = [];
  private disposers: (() => void)[] = [];
  private active = false;

  /** 注册 store 绑定 */
  register(binding: StoreBinding): void {
    if (this.bindings.some((existing) => existing.id === binding.id)) return;
    this.bindings.push(binding);
  }

  /** 建立全部订阅（应用启动时调用一次） */
  setupAll(): void {
    if (this.active) return;
    for (const binding of this.bindings) {
      try {
        this.disposers.push(binding.setup());
      } catch (e) {
        AppLogger.warning(`[ProviderRegistry] setup failed for ${binding.id}: ${String(e)}`);
      }
    }
    this.active = true;
    AppLogger.info(`[ProviderRegistry] ${this.disposers.length} store bindings active`);
  }

  /** 拆除全部订阅 */
  teardownAll(): void {
    for (const dispose of this.disposers) {
      try {
        dispose();
      } catch (e) {
        AppLogger.warning(`[ProviderRegistry] teardown failed: ${String(e)}`);
      }
    }
    this.disposers = [];
    this.active = false;
  }

  getAll(): readonly StoreBinding[] {
    return this.bindings;
  }

  clear(): void {
    this.teardownAll();
    this.bindings = [];
  }
}

export const ProviderRegistry = new ProviderRegistryImpl();
