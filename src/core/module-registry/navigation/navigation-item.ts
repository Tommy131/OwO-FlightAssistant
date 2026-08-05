import type { ReactNode } from 'react';

/**
 * 导航项模型
 *
 * 对应 Flutter 版 `navigation_item.dart`。
 * `icon` / `activeIcon` 由 Flutter 的 `IconData` 改为 Material Symbols 图标名字符串
 * （例如 `Icons.home_outlined` → `'home'` + 非填充，`Icons.home` → `'home'` + 填充）。
 */
export interface NavigationItem {
  readonly id: string;
  readonly title: string;
  /** Material Symbols 图标名（未选中态，描边风格） */
  readonly icon: string;
  /** 选中态图标名，省略时复用 icon 并切换为填充风格 */
  readonly activeIcon?: string;
  /** 页面内容 */
  readonly page: ReactNode;
  /** 可选的徽章文本（如消息数量） */
  readonly badge?: string;
  /** 排序优先级，数值越小越靠前 */
  readonly priority: number;
  /** 所属分组 ID */
  readonly groupId?: string;
  /** 是否默认启用（false 表示需要后端连通才可用） */
  readonly defaultEnabled: boolean;
}

/** 构造导航项，补齐与 Flutter 版一致的默认值 */
export function createNavigationItem(
  init: Omit<NavigationItem, 'priority' | 'defaultEnabled'> &
    Partial<Pick<NavigationItem, 'priority' | 'defaultEnabled'>>,
): NavigationItem {
  return {
    priority: 100,
    defaultEnabled: false,
    ...init,
  };
}
