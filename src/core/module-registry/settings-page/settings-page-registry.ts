import type { ReactNode } from 'react';
import type { Clearable } from '../clearable';

/**
 * 设置页与关于页注册表
 *
 * 对应 Flutter 版 `settings_page_item.dart` / `settings_page_registry.dart`
 * 与 `about_page_item.dart` / `about_page_registry.dart`。
 * 模块（如 http、map）通过这里把自己的设置面板挂进统一设置页。
 */

export interface SettingsPageItem {
  readonly id: string;
  /** Material Symbols 图标名 */
  readonly icon: string;
  /** 优先级，数字越小越靠前 */
  readonly priority: number;
  /** 标题（render 期间调用，可读 translate） */
  getTitle(): string;
  /** 描述（可选） */
  getDescription?(): string | null;
  render(): ReactNode;
}

class SettingsPageRegistryImpl implements Clearable {
  private factories = new Map<string, () => SettingsPageItem>();

  register(id: string, factory: () => SettingsPageItem): void {
    this.factories.set(id, factory);
  }

  getAllPages(): SettingsPageItem[] {
    return [...this.factories.values()]
      .map((factory) => factory())
      .sort((a, b) => a.priority - b.priority);
  }

  getPage(id: string): SettingsPageItem | null {
    const factory = this.factories.get(id);
    return factory ? factory() : null;
  }

  clear(): void {
    this.factories.clear();
  }
}

export const SettingsPageRegistry = new SettingsPageRegistryImpl();

// ──────────────────────────────────────────────────────────────────────────
// 关于页卡片
// ──────────────────────────────────────────────────────────────────────────

export interface AboutPageItem {
  readonly id: string;
  readonly priority: number;
  render(): ReactNode;
}

class AboutPageRegistryImpl implements Clearable {
  private items = new Map<string, AboutPageItem>();

  register(item: AboutPageItem): void {
    this.items.set(item.id, item);
  }

  getAllItems(): AboutPageItem[] {
    return [...this.items.values()].sort((a, b) => a.priority - b.priority);
  }

  clear(): void {
    this.items.clear();
  }
}

export const AboutPageRegistry = new AboutPageRegistryImpl();
