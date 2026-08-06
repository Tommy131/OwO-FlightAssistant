import { create } from 'zustand';
import type { Clearable } from '../clearable';
import type { NavigationGroup } from './navigation-group';
import type { NavigationItem } from './navigation-item';

/**
 * 导航注册表 / 可用性注册表 / 跨模块导航命令总线
 *
 * 对应 Flutter 版 `navigation_registry.dart`。
 *
 * ── React 适配说明 ──
 * Flutter 的工厂签名是 `NavigationItem Function(BuildContext)`，靠 BuildContext 取翻译与 Provider 状态。
 * Web 版把 BuildContext 去掉：翻译走全局 `translate()`，状态走 Zustand `getState()`/hooks。
 *
 * ⚠️ 重要约束：`NavigationItemFactory` 与 `NavigationAvailabilityResolver` **会在组件 render 期间被调用**，
 * 因此允许在其中调用 hooks（等价于 Flutter 的 `context.watch`）。
 * 这是安全的，因为 `ModuleRegistry.initializeAll()` 之后禁止再注册，
 * 工厂/解析器数组长度恒定，hooks 调用顺序稳定。
 */

export type NavigationItemFactory = () => NavigationItem;
export type NavigationGroupFactory = () => NavigationGroup;
export type NavigationAvailabilityResolver = (item: NavigationItem) => boolean;

// ──────────────────────────────────────────────────────────────────────────
// 导航命令总线：任意模块可请求跳转到某个导航项
// ──────────────────────────────────────────────────────────────────────────

interface NavigationCommandState {
  targetId: string | null;
  goTo: (id: string) => void;
  clear: () => void;
}

/** 对应 Flutter 版的 `NavigationCommandBus` + `ValueNotifier<String?>` */
export const useNavigationCommandStore = create<NavigationCommandState>((set) => ({
  targetId: null,
  goTo: (id) => set({ targetId: id }),
  clear: () => set({ targetId: null }),
}));

export const NavigationCommandBus = {
  /** 请求跳转到指定导航项，例如 `NavigationCommandBus.goTo('settings')` */
  goTo(id: string): void {
    useNavigationCommandStore.getState().goTo(id);
  },
  clear(): void {
    useNavigationCommandStore.getState().clear();
  },
  get targetId(): string | null {
    return useNavigationCommandStore.getState().targetId;
  },
};

// ──────────────────────────────────────────────────────────────────────────
// 导航可用性
// ──────────────────────────────────────────────────────────────────────────

class NavigationAvailabilityRegistryImpl implements Clearable {
  private resolvers: NavigationAvailabilityResolver[] = [];

  register(resolver: NavigationAvailabilityResolver): void {
    this.resolvers.push(resolver);
  }

  /**
   * 判断导航项是否可用（全部 resolver 都通过才算可用）
   * ⚠️ 只能在组件 render 期间调用 —— resolver 内部可能使用 hooks
   */
  isEnabled(item: NavigationItem): boolean {
    for (const resolver of this.resolvers) {
      if (!resolver(item)) return false;
    }
    return true;
  }

  clear(): void {
    this.resolvers = [];
  }
}

export const NavigationAvailabilityRegistry = new NavigationAvailabilityRegistryImpl();

// ──────────────────────────────────────────────────────────────────────────
// 导航元素：单个导航项，或一个带子项的分组
// ──────────────────────────────────────────────────────────────────────────

export type NavigationElement =
  | { kind: 'item'; item: NavigationItem; priority: number }
  | { kind: 'group'; group: NavigationGroup; children: NavigationItem[]; priority: number };


/** 把分组结构拍平成线性导航项列表（用于按 index 切换页面） */
export function flattenNavigationElements(elements: NavigationElement[]): NavigationItem[] {
  const flat: NavigationItem[] = [];
  for (const element of elements) {
    if (element.kind === 'group') {
      flat.push(...element.children);
    } else {
      flat.push(element.item);
    }
  }
  return flat;
}

// ──────────────────────────────────────────────────────────────────────────
// 导航注册表
// ──────────────────────────────────────────────────────────────────────────

class NavigationRegistryImpl implements Clearable {
  private itemFactories: NavigationItemFactory[] = [];
  private groupFactories: NavigationGroupFactory[] = [];

  /** 注册导航项 */
  register(factory: NavigationItemFactory): void {
    this.itemFactories.push(factory);
  }

  /** 注册导航分组 */
  registerGroup(factory: NavigationGroupFactory): void {
    this.groupFactories.push(factory);
  }

  /** 获取所有导航项（按优先级排序） */
  getAllItems(): NavigationItem[] {
    return this.itemFactories
      .map((factory) => factory())
      .sort((a, b) => a.priority - b.priority);
  }

  /**
   * 获取导航元素树（分组 + 孤立项，整体按优先级排序）
   * ⚠️ 只能在组件 render 期间调用 —— 工厂内部会调用 translate/hooks
   */
  getNavigationElements(): NavigationElement[] {
    const allItems = this.itemFactories.map((factory) => factory());
    const allGroups = this.groupFactories.map((factory) => factory());

    const elements: NavigationElement[] = [];
    const processedItemIds = new Set<string>();

    // 1. 处理分组
    for (const group of allGroups) {
      const children = allItems
        .filter((item) => item.groupId === group.id)
        .sort((a, b) => a.priority - b.priority);
      elements.push({ kind: 'group', group, children, priority: group.priority });
      for (const child of children) processedItemIds.add(child.id);
    }

    // 2. 处理不属于任何分组的孤立项
    for (const item of allItems) {
      if (processedItemIds.has(item.id)) continue;
      elements.push({ kind: 'item', item, priority: item.priority });
    }

    // 3. 整体按优先级排序
    elements.sort((a, b) => a.priority - b.priority);
    return elements;
  }

  clear(): void {
    this.itemFactories = [];
    this.groupFactories = [];
  }
}

export const NavigationRegistry = new NavigationRegistryImpl();
