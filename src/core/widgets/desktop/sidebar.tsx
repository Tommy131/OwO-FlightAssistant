import { useState } from 'react';
import { AppConstants } from '../../constants/app-constants';
import { LocalizationKeys } from '../../localization/localization-keys';
import { useTranslate } from '../../localization/use-translate';
import { ModuleRegistry } from '../../module-registry/module-registry';
import type { NavigationGroup } from '../../module-registry/navigation/navigation-group';
import type { NavigationItem } from '../../module-registry/navigation/navigation-item';
import type { NavigationElement } from '../../module-registry/navigation/navigation-registry';
import { useThemeStore } from '../../theme/theme-store';
import { MaterialIcon } from '../common/icon';
import { MarqueeText } from '../common/marquee-text';
import styles from './sidebar.module.css';

/**
 * 桌面端侧边栏
 *
 * 对应 Flutter 版 `core/widgets/desktop/sidebar.dart`（702 行）。
 * 完整保留：展开/折叠动画、分组折叠、可用性置灰、徽章、
 * 迷你信息卡片、标题徽章、页脚插槽。
 *
 * 宽度 200 ↔ 60，动画 300ms —— 与 AppThemeData 中的常量一致。
 */
export interface DesktopSidebarProps {
  elements: NavigationElement[];
  selectedIndex: number;
  onItemSelected: (index: number) => void;
  initiallyExpanded?: boolean;
}

export function DesktopSidebar({
  elements,
  selectedIndex,
  onItemSelected,
  initiallyExpanded = true,
}: DesktopSidebarProps) {
  const t = useTranslate();
  const [isExpanded, setIsExpanded] = useState(initiallyExpanded);
  const [expandedGroups, setExpandedGroups] = useState<Record<string, boolean>>(() => {
    const initial: Record<string, boolean> = {};
    for (const element of elements) {
      if (element.kind === 'group') initial[element.group.id] = element.group.initiallyExpanded;
    }
    return initial;
  });

  const isCollapsed = !isExpanded;

  const toggleSidebar = () => setIsExpanded((prev) => !prev);

  const toggleGroup = (groupId: string) => {
    // 折叠态下点击分组先展开侧边栏（与桌面版一致）
    if (isCollapsed) {
      setIsExpanded(true);
      return;
    }
    setExpandedGroups((prev) => ({ ...prev, [groupId]: !(prev[groupId] ?? true) }));
  };

  // 注册表工厂在 render 期间求值，允许其内部使用 hooks
  const miniCard = ModuleRegistry.sidebarMiniCards.resolve();
  const titleBadge = ModuleRegistry.sidebarTitleBadge.resolve();
  const footers = ModuleRegistry.sidebarFooters.getAllFooters();

  // 把分组结构展开成带 flatIndex 的渲染列表
  let flatIndexCounter = 0;
  const rendered: React.ReactNode[] = [];

  for (const element of elements) {
    if (element.kind === 'group') {
      const group = element.group;
      const isGroupExpanded = expandedGroups[group.id] ?? true;
      // 折叠态忽略分组开合，始终显示全部图标
      const showChildren = isGroupExpanded || isCollapsed;

      rendered.push(
        <GroupHeader
          key={`group-${group.id}`}
          group={group}
          isExpanded={isGroupExpanded}
          isCollapsed={isCollapsed}
          onToggle={() => toggleGroup(group.id)}
        />,
      );

      const children: React.ReactNode[] = [];
      for (const item of element.children) {
        const currentIndex = flatIndexCounter++;
        children.push(
          <SidebarNavItem
            key={item.id}
            item={item}
            isSelected={selectedIndex === currentIndex}
            isCollapsed={isCollapsed}
            isSubItem
            onSelect={() => onItemSelected(currentIndex)}
          />,
        );
      }

      if (children.length > 0) {
        rendered.push(
          <div
            key={`group-children-${group.id}`}
            className={`${styles.groupChildren}${showChildren ? '' : ` ${styles.groupChildrenHidden}`}`}
          >
            {children}
          </div>,
        );
      }
    } else {
      const currentIndex = flatIndexCounter++;
      rendered.push(
        <SidebarNavItem
          key={element.item.id}
          item={element.item}
          isSelected={selectedIndex === currentIndex}
          isCollapsed={isCollapsed}
          onSelect={() => onItemSelected(currentIndex)}
        />,
      );
    }
  }

  const sidebarTitle = ModuleRegistry.sidebarTitle.resolve(AppConstants.appName);

  return (
    <nav
      className={`${styles.sidebar}${isCollapsed ? ` ${styles.sidebarCollapsed}` : ''}`}
      aria-label={sidebarTitle}
    >
      {/* ── 头部：Logo + 标题/徽章 + 折叠按钮 ── */}
      <header className={styles.header}>
        {isCollapsed ? (
          <button
            type="button"
            className={styles.logoButton}
            onClick={toggleSidebar}
            title={t(LocalizationKeys.expandSidebar)}
            aria-label={t(LocalizationKeys.expandSidebar)}
          >
            <Logo />
            {titleBadge && (
              <span className={styles.logoBadge}>{titleBadge.render({ isCollapsed: true })}</span>
            )}
          </button>
        ) : (
          <>
            <Logo />
            <div className={styles.headerTitles}>
              {titleBadge ? (
                titleBadge.render({ isCollapsed: false })
              ) : (
                <span className={styles.greeting}>{t(LocalizationKeys.userGreeting)}</span>
              )}
            </div>
            <button
              type="button"
              className={styles.collapseButton}
              onClick={toggleSidebar}
              title={t(LocalizationKeys.collapseSidebar)}
              aria-label={t(LocalizationKeys.collapseSidebar)}
            >
              <MaterialIcon name="menu_open" size={20} color="var(--color-primary)" />
            </button>
          </>
        )}
      </header>

      {/* ── 导航列表 ── */}
      <div className={`${styles.navList} scroll-area`}>{rendered}</div>

      {/* ── 迷你信息卡片 ── */}
      {miniCard && (
        <div className={styles.miniCardSlot}>{miniCard.render({ isCollapsed })}</div>
      )}

      {/* ── 页脚插槽 ── */}
      {footers.map((footer) => (
        <div key={footer.id} className={styles.footerSlot}>
          {isCollapsed ? footer.renderCollapsed() : footer.renderExpanded()}
        </div>
      ))}
    </nav>
  );
}

function Logo() {
  const t = useTranslate();
  return (
    <img
      src={AppConstants.assetIconPath}
      alt={t(LocalizationKeys.appLogo)}
      className={styles.logo}
    />
  );
}

// ──────────────────────────────────────────────────────────────────────────
// 分组标题
// ──────────────────────────────────────────────────────────────────────────

function GroupHeader({
  group,
  isExpanded,
  isCollapsed,
  onToggle,
}: {
  group: NavigationGroup;
  isExpanded: boolean;
  isCollapsed: boolean;
  onToggle: () => void;
}) {
  if (isCollapsed) {
    return (
      <div className={styles.groupHeaderCollapsed} title={group.title}>
        <MaterialIcon name={group.icon} size={16} color="var(--color-on-surface-a40)" />
      </div>
    );
  }

  return (
    <button
      type="button"
      className={styles.groupHeader}
      onClick={onToggle}
      aria-expanded={isExpanded}
    >
      <MaterialIcon name={group.icon} size={14} color="var(--color-on-surface-a40)" />
      <MarqueeText text={group.title.toUpperCase()} className={styles.groupTitle} />
      <MaterialIcon
        name="expand_more"
        size={14}
        color="var(--color-on-surface-a40)"
        className={isExpanded ? undefined : styles.chevronCollapsed}
      />
    </button>
  );
}

// ──────────────────────────────────────────────────────────────────────────
// 导航项
// ──────────────────────────────────────────────────────────────────────────

function SidebarNavItem({
  item,
  isSelected,
  isCollapsed,
  isSubItem = false,
  onSelect,
}: {
  item: NavigationItem;
  isSelected: boolean;
  isCollapsed: boolean;
  isSubItem?: boolean;
  onSelect: () => void;
}) {
  const t = useTranslate();
  const accentColor = useThemeStore((state) => state.currentTheme.accentColor);
  // 可用性解析器内部会订阅后端连通状态（等价于桌面版的 context.watch）
  const isEnabled = ModuleRegistry.navigationAvailability.isEnabled(item);

  const semanticsLabel = item.badge
    ? `${item.title}, ${t(LocalizationKeys.badgeLabel)} ${item.badge}`
    : item.title;

  return (
    <button
      type="button"
      onClick={isEnabled ? onSelect : undefined}
      disabled={!isEnabled}
      aria-current={isSelected ? 'page' : undefined}
      aria-label={semanticsLabel}
      title={isCollapsed ? semanticsLabel : undefined}
      className={[
        styles.navItem,
        isSelected ? styles.navItemSelected : '',
        !isEnabled ? styles.navItemDisabled : '',
        isSubItem && !isCollapsed ? styles.navItemSub : '',
        isCollapsed ? styles.navItemCollapsed : '',
      ]
        .filter(Boolean)
        .join(' ')}
    >
      <MaterialIcon
        name={isSelected && item.activeIcon ? item.activeIcon : item.icon}
        filled={isSelected}
        size={20}
      />
      {!isCollapsed && (
        <>
          <MarqueeText text={item.title} className={styles.navItemTitle} />
          {item.badge && (
            <span className={styles.navItemBadge} style={{ background: accentColor }}>
              {item.badge}
            </span>
          )}
        </>
      )}
    </button>
  );
}
