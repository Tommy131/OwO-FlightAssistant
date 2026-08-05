import { useCallback, useEffect, useRef, useState } from 'react';
import { useIsDesktopLayout } from './layouts/responsive';
import { DesktopLayout } from './layouts/desktop-layout';
import { MobileLayout } from './layouts/mobile-layout';
import { ModuleRegistry } from './module-registry/module-registry';
import {
  flattenNavigationElements,
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

  // ── 切页面时记下当前页，刷新后回到这里而不是首页 ──
  const goToIndex = useCallback((index: number) => {
    setSelectedIndex(index);
    const item = NavigationRegistry.getAllItems()[index];
    if (item) void PersistenceService.setString(LAST_NAVIGATION_KEY, item.id);
  }, []);

  // ── 恢复上次停留的页面 ──
  useEffect(() => {
    if (!isInitialized || isSetupMode || navigationRestored.current) return;
    // 模块要全部注册完，getAllItems() 才是完整的
    if (NavigationRegistry.getAllItems().length === 0) return;
    navigationRestored.current = true;

    const savedId = PersistenceService.getString(LAST_NAVIGATION_KEY);
    if (!savedId) return;
    const index = NavigationRegistry.getAllItems().findIndex((item) => item.id === savedId);
    // 找不到就留在首页：可能是那个模块被停用了
    if (index >= 0) setSelectedIndex(index);
  }, [isInitialized, isSetupMode]);

  // ── 消费跨模块导航命令（NavigationCommandBus.goTo）──
  useEffect(() => {
    if (!navigationTargetId || !isInitialized) return;

    const elements = NavigationRegistry.getAllItems();
    const targetIndex = elements.findIndex((item) => item.id === navigationTargetId);
    clearNavigationCommand();
    if (targetIndex < 0) return;
    goToIndex(targetIndex);
  }, [navigationTargetId, isInitialized, clearNavigationCommand, goToIndex]);

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

  // 注册表工厂在此处求值 —— 内部可安全使用 hooks（见 navigation-registry.ts 的说明）
  const elements = NavigationRegistry.getNavigationElements();
  const flatItems = flattenNavigationElements(elements);

  // 导航项数量变化时把越界索引拉回首项
  const safeIndex = selectedIndex < flatItems.length ? selectedIndex : 0;

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
