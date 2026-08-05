import type { ReactNode } from 'react';
import { MaterialIcon } from '../common/icon';
import styles from './module-side-nav.module.css';

/**
 * 模块内二级侧边导航的可复用外壳
 *
 * 对应 Flutter 版 `core/widgets/navigation/module_side_nav.dart`：
 * 供 checklist、toolbox 等模块在自己的页面内部搭建左侧导航。
 *
 * 紧凑模式（isCompact）下侧栏只留图标条，展开时以浮层覆盖内容区，
 * 点击遮罩收起 —— 与桌面版的 ResponsiveSidebarShell 行为一致。
 */

export interface ResponsiveSidebarShellProps {
  isCompact: boolean;
  isExpanded: boolean;
  compactWidth: number;
  expandedWidth: number;
  content: ReactNode;
  /** 面板构建函数，宿主据此在常驻/浮层两种形态下复用同一份内容 */
  buildPanel: (options: {
    useCompactNav: boolean;
    showLabel: boolean;
    isFloating: boolean;
  }) => ReactNode;
  onCollapse: () => void;
}

export function ResponsiveSidebarShell({
  isCompact,
  isExpanded,
  compactWidth,
  expandedWidth,
  content,
  buildPanel,
  onCollapse,
}: ResponsiveSidebarShellProps) {
  return (
    <div className={styles.shell}>
      <div className={styles.row}>
        <div
          className={styles.staticPanel}
          style={{ width: isCompact ? compactWidth : expandedWidth }}
        >
          {buildPanel({
            useCompactNav: isCompact,
            showLabel: !isCompact,
            isFloating: false,
          })}
        </div>
        <div className={styles.content}>{content}</div>
      </div>

      {isCompact && (
        <>
          <div
            className={`${styles.scrim}${isExpanded ? ` ${styles.scrimVisible}` : ''}`}
            style={{ left: compactWidth }}
            onClick={onCollapse}
            role="presentation"
          />
          <div
            className={styles.floatingPanel}
            style={{ left: isExpanded ? compactWidth : -expandedWidth }}
            aria-hidden={!isExpanded}
          >
            {buildPanel({ useCompactNav: true, showLabel: true, isFloating: true })}
          </div>
        </>
      )}
    </div>
  );
}

// ──────────────────────────────────────────────────────────────────────────
// 面板容器
// ──────────────────────────────────────────────────────────────────────────

export interface SidebarPanelContainerProps {
  width: number;
  isFloating: boolean;
  topSlot?: ReactNode;
  children: ReactNode;
  /** 点击面板空白处的回调（用于收起浮层） */
  onBlankTap?: () => void;
}

export function SidebarPanelContainer({
  width,
  isFloating,
  topSlot,
  children,
  onBlankTap,
}: SidebarPanelContainerProps) {
  return (
    <div
      className={`${styles.panel}${isFloating ? ` ${styles.panelFloating}` : ''}`}
      style={{ width }}
      onClick={onBlankTap ? (event) => {
        // 只有点到容器本身（而非子项）才触发
        if (event.target === event.currentTarget) onBlankTap();
      } : undefined}
    >
      {topSlot}
      <div className={`${styles.panelBody} scroll-area`}>{children}</div>
    </div>
  );
}

// ──────────────────────────────────────────────────────────────────────────
// 折叠切换按钮
// ──────────────────────────────────────────────────────────────────────────

export interface SidebarToggleButtonProps {
  showLabel: boolean;
  enabled: boolean;
  isExpanded: boolean;
  onPress: () => void;
  expandedText?: string;
  collapsedText?: string;
}

export function SidebarToggleButton({
  showLabel,
  enabled,
  isExpanded,
  onPress,
  expandedText = '收起菜单',
  collapsedText = '展开菜单',
}: SidebarToggleButtonProps) {
  return (
    <div className={styles.toggleWrap}>
      <button
        type="button"
        disabled={!enabled}
        onClick={onPress}
        className={`${styles.toggleButton}${showLabel ? '' : ` ${styles.toggleButtonIconOnly}`}`}
      >
        <MaterialIcon name="menu" size={20} />
        {showLabel && (
          <span className={styles.toggleLabel}>{isExpanded ? expandedText : collapsedText}</span>
        )}
      </button>
    </div>
  );
}

// ──────────────────────────────────────────────────────────────────────────
// 导航项
// ──────────────────────────────────────────────────────────────────────────

export interface SidebarNavItemTileProps {
  /** Material Symbols 图标名 */
  icon: string;
  label: string;
  isSelected: boolean;
  onTap: () => void;
  showLabel: boolean;
  /** 选中态强调色，默认主色 */
  primaryColor?: string;
  /** 右侧附加内容（进度、计数等） */
  trailing?: ReactNode;
}

export function SidebarNavItemTile({
  icon,
  label,
  isSelected,
  onTap,
  showLabel,
  primaryColor = 'var(--color-primary)',
  trailing,
}: SidebarNavItemTileProps) {
  return (
    <button
      type="button"
      title={label}
      onClick={onTap}
      aria-current={isSelected ? 'true' : undefined}
      className={[
        styles.navTile,
        isSelected ? styles.navTileSelected : '',
        showLabel ? '' : styles.navTileIconOnly,
      ]
        .filter(Boolean)
        .join(' ')}
      style={
        isSelected
          ? {
              borderRightColor: primaryColor,
              background: `color-mix(in srgb, ${primaryColor} 10%, transparent)`,
              color: primaryColor,
            }
          : undefined
      }
    >
      <MaterialIcon name={icon} filled={isSelected} size={20} />
      {showLabel && (
        <>
          <span className={styles.navTileLabel}>{label}</span>
          {trailing}
        </>
      )}
    </button>
  );
}
