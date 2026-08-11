import { useCallback, useEffect, useRef, useState } from 'react';
import { useIsDesktopLayout } from './layouts/responsive';
import { DesktopLayout } from './layouts/desktop-layout';
import { MobileLayout } from './layouts/mobile-layout';
import { ModuleRegistry } from './module-registry/module-registry';
import {
  flattenNavigationElements,
  NavigationCommandBus,
  NavigationRegistry,
  useNavigationCommandStore,
} from './module-registry/navigation/navigation-registry';
import { AppInitializationService } from './services/app-initialization-service';
import { useLocalizationStore } from './services/localization-service';
import { PersistenceService } from './services/persistence-service';
import { useThemeStore } from './theme/theme-store';
import { AppLogger } from './utils/logger';
import { LoadingScreen } from './widgets/loading-screen';
import { OverlayHost } from './widgets/common/overlay-host';
import { SetupWizard } from './setup-wizard/setup-wizard';

/**
 * 应用根组件
 *
 * 对应 Flutter 版 `core/app.dart` 的 `MyApp` + `MainScreen`：
 * 负责初始化流程、首启向导切换、响应式布局分发与跨模块导航命令的消费。
 *
 * ── Web 降级说明 ──
 * 桌面版在这里还处理无边框标题栏、窗口关闭拦截与 Android 返回键，
 * Web 版这三者均无对应能力，已移除。
 */
/**
 * 上次停留页面的持久化键
 *
 * 存的是导航项 **id** 而不是下标 —— 下标取决于模块注册顺序和当前启用了哪些模块，
 * 换个版本或改个注册顺序就会指到另一个页面上去。
 */
const LAST_NAVIGATION_KEY = 'last_navigation_id';

export function App() {
  const [isInitialized, setIsInitialized] = useState(false);
  const [isSetupMode, setIsSetupMode] = useState(false);
  const [selectedIndex, setSelectedIndex] = useState(0);
  // 恢复只做一次：之后用户自己切页面不该再被覆盖
  const navigationRestored = useRef(false);

  const isDesktop = useIsDesktopLayout();
  const loadTheme = useThemeStore((state) => state.load);
  const initLocalization = useLocalizationStore((state) => state.init);
  // 订阅词条版本，模块注册新翻译后触发导航项重建
  useLocalizationStore((state) => state.revision);
  useLocalizationStore((state) => state.locale);

  const navigationTargetId = useNavigationCommandStore((state) => state.targetId);
  const clearNavigationCommand = useNavigationCommandStore((state) => state.clear);

  /*
   * 注册表工厂在此处求值 —— 内部可安全使用 hooks（见 navigation-registry.ts 的说明）。
   *
   * ⚠️ 下面 goToIndex／恢复上次页面／消费 NavigationCommandBus.goTo 三处
   * 都必须用这份 flatItems，不能各自再去调 `NavigationRegistry.getAllItems()`。
   * getAllItems() 是把所有导航项按各自 priority 整体打平排序，不知道分组
   * （general/flight/tools）的存在；真正决定 selectedIndex 含义、实际渲染出来的
   * 是这份「先按组排序、组内再按各自 priority 排序」的 flatItems。
   * 两份顺序只要存在分组就会整体错位——现在 11 个导航项里 10 个都分了组，
   * 于是按 id 跳转（NavigationCommandBus.goTo，顶栏任务流菜单点哪一步全靠它）
   * 换算出来的下标常常指向另一个页面：点"检查单"跳到"地图"、点"飞行日志"
   * 跳到"工具箱"这类。这里统一改成用同一份顺序，从源头消掉错位。
   */
  const isNavigationReady = isInitialized && !isSetupMode;
  const elements = isNavigationReady ? NavigationRegistry.getNavigationElements() : [];
  const flatItems = flattenNavigationElements(elements);

  // 导航项数量变化时把越界索引拉回首项
  const safeIndex = selectedIndex < flatItems.length ? selectedIndex : 0;

  // ── 切页面时记下当前页，刷新后回到这里而不是首页 ──
  const goToIndex = useCallback(
    (index: number) => {
      setSelectedIndex(index);
      const item = flatItems[index];
      if (item) void PersistenceService.setString(LAST_NAVIGATION_KEY, item.id);
    },
    [flatItems],
  );

  // ── 初始化 ──
  useEffect(() => {
    let cancelled = false;

    void (async () => {
      const result = await AppInitializationService.run();
      if (cancelled) return;

      if (result.kind === 'failure') {
        setIsInitialized(true);
        return;
      }

      await Promise.all([loadTheme(), initLocalization()]);
      if (cancelled) return;

      setIsSetupMode(result.isFirstLaunch);
      setIsInitialized(true);
    })();

    return () => {
      cancelled = true;
    };
  }, [loadTheme, initLocalization]);

  // ── 恢复上次停留的页面 ──
  useEffect(() => {
    if (!isNavigationReady || navigationRestored.current) return;
    // 模块要全部注册完，flatItems 才是完整的
    if (flatItems.length === 0) return;
    navigationRestored.current = true;

    const savedId = PersistenceService.getString(LAST_NAVIGATION_KEY);
    if (!savedId) return;
    const index = flatItems.findIndex((item) => item.id === savedId);
    // 找不到就留在首页：可能是那个模块被停用了
    if (index >= 0) setSelectedIndex(index);
  }, [isNavigationReady, flatItems]);

  // ── 消费跨模块导航命令（NavigationCommandBus.goTo）──
  useEffect(() => {
    if (!navigationTargetId || !isNavigationReady) return;

    const targetIndex = flatItems.findIndex((item) => item.id === navigationTargetId);
    clearNavigationCommand();
    if (targetIndex < 0) return;
    goToIndex(targetIndex);
  }, [navigationTargetId, isNavigationReady, flatItems, clearNavigationCommand, goToIndex]);

  /*
   * ── 广播「当前在哪一页」──
   *
   * 跟着 selectedIndex 走而不是写在 goToIndex 里：切页的来源不止点击一处
   * （还有刷新后恢复上次页面、跨模块 goTo、导航项数量变化把越界下标拉回首项），
   * 只在点击处记录会让其余几条路径下的「当前页」停在过时的值上。
   */
  const currentNavigationId = flatItems[safeIndex]?.id ?? null;
  useEffect(() => {
    NavigationCommandBus.setCurrentId(currentNavigationId);
  }, [currentNavigationId]);

  // ── 关闭前清理（等价于桌面版 onWindowClose 的 performCleanup）──
  useEffect(() => {
    const handleUnload = () => void ModuleRegistry.performCleanup();
    window.addEventListener('pagehide', handleUnload);
    return () => window.removeEventListener('pagehide', handleUnload);
  }, []);

  if (!isInitialized) {
    return (
      <>
        <LoadingScreen />
        <OverlayHost />
      </>
    );
  }

  if (isSetupMode) {
    return (
      <>
        <SetupWizard
          onCompleted={async () => {
            // 向导里配的语言与日志设置随完成标记一起写进后端数据库，
            // 保证换浏览器 / 清缓存后不再重跑初始化
            const logSettings = AppLogger.loadSettings();
            await AppInitializationService.markSetupCompleted({
              language_code: useLocalizationStore.getState().locale,
              log_enabled: logSettings.enabled,
              log_max_entries: logSettings.maxEntries,
            });
            AppLogger.info('Setup wizard completed');
            setIsSetupMode(false);
          }}
        />
        <OverlayHost />
      </>
    );
  }

  return (
    <>
      {isDesktop ? (
        <DesktopLayout
          navigationElements={elements}
          selectedIndex={safeIndex}
          onNavigationChanged={goToIndex}
        />
      ) : (
        <MobileLayout
          navigationItems={flatItems}
          selectedIndex={safeIndex}
          onNavigationChanged={goToIndex}
        />
      )}
      <OverlayHost />
    </>
  );
}
