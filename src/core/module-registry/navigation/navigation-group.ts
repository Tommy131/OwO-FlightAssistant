/**
 * 导航分组模型（对应 Flutter 版 navigation_group.dart）
 * 用于对侧边栏导航项进行分组
 */
export interface NavigationGroup {
  readonly id: string;
  readonly title: string;
  /** Material Symbols 图标名 */
  readonly icon: string;
  /** 排序优先级，数值越小越靠前 */
  readonly priority: number;
  /** 初始是否展开 */
  readonly initiallyExpanded: boolean;
}

export function createNavigationGroup(
  init: Omit<NavigationGroup, 'priority' | 'initiallyExpanded'> &
    Partial<Pick<NavigationGroup, 'priority' | 'initiallyExpanded'>>,
): NavigationGroup {
  return {
    priority: 100,
    initiallyExpanded: true,
    ...init,
  };
}
