import type { ReactNode } from 'react';
import type { Clearable } from '../clearable';

/**
 * 侧边栏相关的 4 张注册表
 *
 * 对应 Flutter 版：
 *   - sidebar_footer.dart / sidebar_footer_registry.dart
 *   - sidebar_mini_card.dart / sidebar_mini_card_registry.dart
 *   - sidebar_title_registry.dart
 *   - sidebar_title_badge.dart / sidebar_title_badge_registry.dart
 *
 * ⚠️ `canDisplay()` / `render()` 均在组件 render 期间调用，允许使用 hooks
 *    （等价于 Flutter 里传入 BuildContext 后 `context.watch`）。
 */

// ──────────────────────────────────────────────────────────────────────────
// 侧边栏页脚
// ──────────────────────────────────────────────────────────────────────────

export interface SidebarFooter {
  readonly id: string;
  readonly priority: number;
  /** 侧边栏展开时的渲染 */
  renderExpanded(): ReactNode;
  /** 侧边栏折叠时的渲染 */
  renderCollapsed(): ReactNode;
}

class SidebarFooterRegistryImpl implements Clearable {
  private factories = new Map<string, () => SidebarFooter>();

  register(id: string, factory: () => SidebarFooter): void {
    this.factories.set(id, factory);
  }

  getAllFooters(): SidebarFooter[] {
    return [...this.factories.values()]
      .map((factory) => factory())
      .sort((a, b) => a.priority - b.priority);
  }

  clear(): void {
    this.factories.clear();
  }
}

export const SidebarFooterRegistry = new SidebarFooterRegistryImpl();

// ──────────────────────────────────────────────────────────────────────────
// 侧边栏迷你卡片（多个候选，取第一个 canDisplay 为真的）
// ──────────────────────────────────────────────────────────────────────────

export interface SidebarMiniCard {
  readonly id: string;
  readonly priority: number;
  /** 当前上下文是否应展示此卡片 */
  canDisplay(): boolean;
  render(options: { isCollapsed: boolean }): ReactNode;
}

class SidebarMiniCardRegistryImpl implements Clearable {
  private factories = new Map<string, () => SidebarMiniCard>();

  register(id: string, factory: () => SidebarMiniCard): void {
    this.factories.set(id, factory);
  }

  contains(id: string): boolean {
    return this.factories.has(id);
  }

  /**
   * 解析当前应展示的卡片
   *
   * ⚠️ 与桌面版一致：**所有**候选卡片都会被实例化并依次询问 canDisplay，
   * 因此每个候选的 hooks 都会被调用，顺序稳定，符合 Rules of Hooks。
   */
  resolve(): SidebarMiniCard | null {
    const cards = [...this.factories.values()]
      .map((factory) => factory())
      .sort((a, b) => a.priority - b.priority);
    // 先全部求值再筛选，保证每个候选的 hooks 都被调用（顺序恒定）
    const displayable = cards.map((card) => card.canDisplay());
    const index = displayable.indexOf(true);
    return index >= 0 ? cards[index] : null;
  }

  clear(): void {
    this.factories.clear();
  }
}

export const SidebarMiniCardRegistry = new SidebarMiniCardRegistryImpl();

// ──────────────────────────────────────────────────────────────────────────
// 侧边栏标题
// ──────────────────────────────────────────────────────────────────────────

export type SidebarTitleResolver = () => string | null;

class SidebarTitleRegistryImpl implements Clearable {
  private resolvers = new Map<string, SidebarTitleResolver>();

  register(id: string, resolver: SidebarTitleResolver): void {
    this.resolvers.set(id, resolver);
  }

  /** 后注册者优先（与桌面版的倒序遍历一致） */
  resolve(fallbackTitle: string): string {
    const entries = [...this.resolvers.values()];
    for (let i = entries.length - 1; i >= 0; i--) {
      const title = entries[i]();
      if (title && title.trim().length > 0) return title;
    }
    return fallbackTitle;
  }

  clear(): void {
    this.resolvers.clear();
  }
}

export const SidebarTitleRegistry = new SidebarTitleRegistryImpl();

// ──────────────────────────────────────────────────────────────────────────
// 侧边栏标题徽章（后端连通状态指示）
// ──────────────────────────────────────────────────────────────────────────

export interface SidebarTitleBadge {
  readonly id: string;
  readonly priority: number;
  canDisplay(): boolean;
  render(options: { isCollapsed: boolean }): ReactNode;
}

class SidebarTitleBadgeRegistryImpl implements Clearable {
  private factories = new Map<string, () => SidebarTitleBadge>();

  register(id: string, factory: () => SidebarTitleBadge): void {
    this.factories.set(id, factory);
  }

  resolve(): SidebarTitleBadge | null {
    const badges = [...this.factories.values()]
      .map((factory) => factory())
      .sort((a, b) => a.priority - b.priority);
    const displayable = badges.map((badge) => badge.canDisplay());
    const index = displayable.indexOf(true);
    return index >= 0 ? badges[index] : null;
  }

  clear(): void {
    this.factories.clear();
  }
}

export const SidebarTitleBadgeRegistry = new SidebarTitleBadgeRegistryImpl();
