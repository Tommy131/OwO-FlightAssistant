import { WizardStepRegistry } from '../setup-wizard/wizard-step-registry';
import { AppLogger } from '../utils/logger';
import { AppBarActionRegistry } from './app-bar/app-bar-action';
import type { Clearable, ModuleRegistrar } from './clearable';
import {
  NavigationAvailabilityRegistry,
  NavigationRegistry,
} from './navigation/navigation-registry';
import { ProviderRegistry } from './provider/provider-registry';
import {
  AboutPageRegistry,
  SettingsPageRegistry,
} from './settings-page/settings-page-registry';
import {
  SidebarFooterRegistry,
  SidebarMiniCardRegistry,
  SidebarTitleBadgeRegistry,
  SidebarTitleRegistry,
} from './sidebar/sidebar-registries';

/**
 * 模块注册管理器
 *
 * 对应 Flutter 版 `lib/core/module_registry/module_registry.dart`。
 * 这是整个应用的微内核：core 层不认识任何业务模块，
 * 全部业务能力由模块在 `register()` 中反向注入到下列 11 张注册表。
 */
class ModuleRegistryImpl {
  private modules: ModuleRegistrar[] = [];
  private cleanupCallbacks: (() => Promise<void>)[] = [];
  private initialized = false;

  /** 所有子注册表，统一管理清理 */
  private readonly registries: Clearable[] = [
    WizardStepRegistry,
    AboutPageRegistry,
    SettingsPageRegistry,
    AppBarActionRegistry,
    NavigationRegistry,
    NavigationAvailabilityRegistry,
    SidebarFooterRegistry,
    SidebarMiniCardRegistry,
    SidebarTitleRegistry,
    SidebarTitleBadgeRegistry,
    ProviderRegistry,
  ];

  get isInitialized(): boolean {
    return this.initialized;
  }

  /** 注册模块（必须在 initializeAll 之前） */
  registerModule(module: ModuleRegistrar): void {
    if (this.initialized) {
      throw new Error('Cannot register modules after initialization');
    }
    this.modules.push(module);
  }

  /** 初始化所有模块 */
  initializeAll(): void {
    if (this.initialized) return;
    for (const module of this.modules) {
      try {
        module.register();
      } catch (e) {
        AppLogger.error(`[ModuleRegistry] register failed: ${module.moduleName}`, e);
      }
    }
    this.initialized = true;
    AppLogger.info(`[ModuleRegistry] ${this.modules.length} modules registered`);
  }

  /** 注册应用关闭时的清理回调 */
  registerCleanup(callback: () => Promise<void>): void {
    this.cleanupCallbacks.push(callback);
  }

  /** 执行所有清理回调 */
  async performCleanup(): Promise<void> {
    for (const callback of this.cleanupCallbacks) {
      try {
        await callback();
      } catch (e) {
        AppLogger.warning(`[ModuleRegistry] Cleanup callback failed: ${String(e)}`);
      }
    }
  }

  // ── 各子注册表访问器（与桌面版同名）──
  get wizardSteps() {
    return WizardStepRegistry;
  }
  get settingsPages() {
    return SettingsPageRegistry;
  }
  get aboutPages() {
    return AboutPageRegistry;
  }
  get appBarActions() {
    return AppBarActionRegistry;
  }
  get navigation() {
    return NavigationRegistry;
  }
  get navigationAvailability() {
    return NavigationAvailabilityRegistry;
  }
  get sidebarFooters() {
    return SidebarFooterRegistry;
  }
  get sidebarMiniCards() {
    return SidebarMiniCardRegistry;
  }
  get sidebarTitle() {
    return SidebarTitleRegistry;
  }
  get sidebarTitleBadge() {
    return SidebarTitleBadgeRegistry;
  }
  get providers() {
    return ProviderRegistry;
  }

  /** 清空所有注册（仅用于测试） */
  clear(): void {
    this.modules = [];
    this.initialized = false;
    for (const registry of this.registries) registry.clear();
    this.cleanupCallbacks = [];
  }
}

export const ModuleRegistry = new ModuleRegistryImpl();
export type { ModuleRegistrar } from './clearable';
