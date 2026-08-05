import type { ReactNode } from 'react';
import type { Clearable } from '../clearable';

/**
 * AppBar 操作按钮 / 侧边二级菜单
 *
 * 对应 Flutter 版 `app_bar_action.dart` + `app_bar_action_registry.dart`。
 * `AppBarSideMenuEntry` 是 toolbox 模块实现 6 个 tab 切换的机制：
 * 模块把「二级菜单项」注册到某个 navigationId 下，
 * 布局层在该页面激活时把它们渲染成左侧抽屉/侧边导航。
 */

/** AppBar 右侧操作按钮 */
export interface AppBarAction {
  readonly id: string;
  readonly priority: number;
  /** 渲染按钮（在组件 render 期间调用，可使用 hooks） */
  render(): ReactNode;
}

/** AppBar 侧边二级菜单项 */
export interface AppBarSideMenuEntry {
  readonly id: string;
  /** 归属的导航项 ID，仅在该页面激活时显示 */
  readonly navigationId: string;
  /** Material Symbols 图标名 */
  readonly icon: string;
  readonly priority: number;
  /** 标题（在 render 期间调用，可读 translate） */
  getTitle(): string;
  /** 是否处于选中态 */
  isSelected?(): boolean;
  onTap(): void;
}

export function createAppBarSideMenuEntry(
  init: Omit<AppBarSideMenuEntry, 'priority'> & Partial<Pick<AppBarSideMenuEntry, 'priority'>>,
): AppBarSideMenuEntry {
  return { priority: 100, ...init };
}

class AppBarActionRegistryImpl implements Clearable {
  private actionFactories = new Map<string, () => AppBarAction>();
  private sideMenuFactories = new Map<string, () => AppBarSideMenuEntry>();

  /** 注册操作按钮 */
  register(id: string, factory: () => AppBarAction): void {
    this.actionFactories.set(id, factory);
  }

  /** 获取所有操作按钮（按优先级排序） */
  getAllActions(): AppBarAction[] {
    return [...this.actionFactories.values()]
      .map((factory) => factory())
      .sort((a, b) => a.priority - b.priority);
  }

  /** 注册侧边二级菜单项 */
  registerSideMenu(id: string, factory: () => AppBarSideMenuEntry): void {
    this.sideMenuFactories.set(id, factory);
  }

  /** 取某个导航页下的全部二级菜单项（按优先级排序） */
  getSideMenus(navigationId: string): AppBarSideMenuEntry[] {
    return [...this.sideMenuFactories.values()]
      .map((factory) => factory())
      .filter((entry) => entry.navigationId === navigationId)
      .sort((a, b) => a.priority - b.priority);
  }

  clear(): void {
    this.actionFactories.clear();
    this.sideMenuFactories.clear();
  }
}

export const AppBarActionRegistry = new AppBarActionRegistryImpl();
