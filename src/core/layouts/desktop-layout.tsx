import {
  flattenNavigationElements,
  type NavigationElement,
} from '../module-registry/navigation/navigation-registry';
import { CustomAppBar } from '../widgets/common/custom-app-bar';
import { DesktopSidebar } from '../widgets/desktop/sidebar';
import styles from './desktop-layout.module.css';

/**
 * 桌面端布局
 *
 * 对应 Flutter 版 `core/layouts/desktop_layout.dart`：
 * 左侧可折叠侧边栏，右侧 AppBar + 内容区。
 * 内容区保留桌面版的 1000px 最小宽度约束，低于此值整体横向滚动。
 */
export interface DesktopLayoutProps {
  navigationElements: NavigationElement[];
  selectedIndex: number;
  onNavigationChanged: (index: number) => void;
}

export function DesktopLayout({
  navigationElements,
  selectedIndex,
  onNavigationChanged,
}: DesktopLayoutProps) {
  const flatItems = flattenNavigationElements(navigationElements);
  const currentItem = flatItems[selectedIndex] ?? flatItems[0];
  if (!currentItem) return null;

  return (
    <div className={`${styles.scroller} scroll-area`}>
      <div className={styles.shell}>
        <DesktopSidebar
          elements={navigationElements}
          selectedIndex={selectedIndex}
          onItemSelected={onNavigationChanged}
        />

        <main className={styles.main}>
          <CustomAppBar currentItem={currentItem} />
          {/*
            key 绑定当前页 id：切换导航项时强制重建页面组件树，
            等价于 Flutter 每次取 currentItem.page 得到全新 Widget 的行为。
          */}
          <div className={styles.content} key={currentItem.id}>
            {currentItem.page}
          </div>
        </main>
      </div>
    </div>
  );
}
