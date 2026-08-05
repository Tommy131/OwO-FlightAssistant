import { useState } from 'react';
import { AppBarActionRegistry } from '../module-registry/app-bar/app-bar-action';
import type { NavigationItem } from '../module-registry/navigation/navigation-item';
import { CustomAppBar } from '../widgets/common/custom-app-bar';
import { MaterialIcon } from '../widgets/common/icon';
import { MobileBottomNavbar } from '../widgets/mobile/bottom-navbar';
import styles from './mobile-layout.module.css';

/**
 * 移动端布局
 *
 * 对应 Flutter 版 `core/layouts/mobile_layout.dart`：
 * 上 AppBar、中内容区、下底部导航；
 * 当前页若注册了二级菜单（如 toolbox 的 6 个 tab），AppBar 左侧出现汉堡按钮打开抽屉。
 */
export interface MobileLayoutProps {
  navigationItems: NavigationItem[];
  selectedIndex: number;
  onNavigationChanged: (index: number) => void;
}

export function MobileLayout({
  navigationItems,
  selectedIndex,
  onNavigationChanged,
}: MobileLayoutProps) {
  const [drawerOpen, setDrawerOpen] = useState(false);
  const currentItem = navigationItems[selectedIndex] ?? navigationItems[0];
  if (!currentItem) return null;

  const sideMenus = AppBarActionRegistry.getSideMenus(currentItem.id);

  return (
    <div className={styles.shell}>
      <CustomAppBar
        currentItem={currentItem}
        hasSideMenu={sideMenus.length > 0}
        onOpenSideMenu={() => setDrawerOpen(true)}
      />

      <div className={styles.content} key={currentItem.id}>
        {currentItem.page}
      </div>

      <MobileBottomNavbar
        items={navigationItems}
        selectedIndex={selectedIndex}
        onItemSelected={onNavigationChanged}
      />

      {drawerOpen && sideMenus.length > 0 && (
        <div className={styles.drawerScrim} onClick={() => setDrawerOpen(false)}>
          <aside
            className={styles.drawer}
            onClick={(event) => event.stopPropagation()}
            aria-label={currentItem.title}
          >
            {/* 抽屉头部：当前模块图标 + 名称 */}
            <div className={styles.drawerHeader}>
              <span className={styles.drawerHeaderIcon}>
                <MaterialIcon
                  name={currentItem.activeIcon ?? currentItem.icon}
                  filled
                  size={22}
                  color="var(--color-primary)"
                />
              </span>
              <span className={styles.drawerHeaderTitle}>{currentItem.title}</span>
            </div>

            <div className={`${styles.drawerBody} scroll-area`}>
              {sideMenus.map((entry) => {
                const selected = entry.isSelected?.() ?? false;
                return (
                  <button
                    key={entry.id}
                    type="button"
                    onClick={() => {
                      setDrawerOpen(false);
                      entry.onTap();
                    }}
                    className={`${styles.drawerItem}${selected ? ` ${styles.drawerItemSelected}` : ''}`}
                  >
                    <span className={styles.drawerItemIcon}>
                      <MaterialIcon name={entry.icon} filled={selected} size={20} />
                    </span>
                    <span className={styles.drawerItemLabel}>{entry.getTitle()}</span>
                  </button>
                );
              })}
            </div>
          </aside>
        </div>
      )}
    </div>
  );
}
