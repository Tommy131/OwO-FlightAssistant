import { PersistenceService } from './persistence-service';
import { pushSettingsBulk } from './settings-sync';
import { AppLogger } from '../utils/logger';

/**
 * 应用初始化服务
 *
 * 对应 Flutter 版 `core/services/app_initialization_service.dart` + `bootstrap_service.dart`。
 *
 * ── 「只初始化一次」是怎么保证的 ──
 * 首启完成标记 `app_setup_completed` 存在**中间件数据库**里（经 PersistenceService
 * 的后端同步层）。因此：
 *   - 换浏览器、无痕窗口、清站点数据 → 后端仍有标记，直接进主界面
 *   - 只有「重置应用」显式清空后端设置，才会重新走向导
 *
 * 后端不可达时退回本地 IndexedDB 的标记，保证离线也不会反复弹向导。
 */

const FIRST_LAUNCH_KEY = 'app_setup_completed';

export type AppInitResult =
  | { kind: 'success'; isFirstLaunch: boolean }
  | { kind: 'failure'; error: string };

class AppInitializationServiceImpl {
  async run(): Promise<AppInitResult> {
    try {
      // ensureReady 内部会拉取后端设置并合并进本地缓存
      await PersistenceService.ensureReady();
      await AppLogger.init();

      const completed = PersistenceService.getBool(FIRST_LAUNCH_KEY) ?? false;
      AppLogger.info(
        `App initialization done. firstLaunch=${!completed} backendBacked=${PersistenceService.isBackendBacked}`,
      );
      return { kind: 'success', isFirstLaunch: !completed };
    } catch (e) {
      AppLogger.error('App initialization failed', e);
      return { kind: 'failure', error: String(e) };
    }
  }

  /**
   * 标记首启向导已完成
   *
   * 用 bulk-set 把「完成标记 + 向导里配的语言/日志设置」一次性写进后端，
   * 避免逐条写入时中途失败留下半套配置。
   */
  async markSetupCompleted(extraSettings: Record<string, unknown> = {}): Promise<void> {
    await PersistenceService.setBool(FIRST_LAUNCH_KEY, true);

    const entries: Record<string, unknown> = {
      [FIRST_LAUNCH_KEY]: true,
      ...extraSettings,
    };
    const ok = await pushSettingsBulk(entries);
    AppLogger.info(
      ok
        ? '[Init] setup flag persisted to backend database'
        : '[Init] backend unavailable, setup flag queued for retry',
    );
  }

  /** 重置应用：清空本地缓存与后端设置，下次启动重走向导 */
  async resetApp(): Promise<void> {
    await PersistenceService.resetApp();
  }
}

export const AppInitializationService = new AppInitializationServiceImpl();
