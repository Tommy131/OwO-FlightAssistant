import { clear as idbClear, del as idbDel, get as idbGet, set as idbSet } from 'idb-keyval';
import { AppLogger } from '../utils/logger';
import { pullSettings, pushSetting, removeSetting, resetSettings } from './settings-sync';

/**
 * 应用持久化存储
 *
 * 对应 Flutter 版 `lib/core/services/persistence_service.dart`。
 *
 * ── Web 降级说明 ──
 * 桌面版把所有配置写进用户自选目录下的 JSON 文件，并支持「迁移存储路径」。
 * 浏览器没有任意文件系统写权限，因此这里改为：
 *   - 全量数据放在内存 Map 中（与桌面版 `_data` 语义一致，读取同步、零延迟）
 *   - 变更后异步落盘到 IndexedDB（带 300ms 防抖合并写入，对应桌面版的保存队列）
 * 「自选存储路径」在 Web 无对应能力，设置页改为展示存储用量与清理入口。
 */

/** IndexedDB 中存放主数据表的键 */
const ROOT_KEY = 'owo-flight-assistant/persistence';
/** 存放缓存类数据（可被「清除缓存」清空）的键 */
const CACHE_KEY = 'owo-flight-assistant/cache';

/**
 * 存储值类型
 *
 * 用 `unknown` 而非递归的 JsonValue 联合：值最终经 structuredClone 进 IndexedDB，
 * 递归联合会让每个调用点都要 cast（`as never` 之类），得不偿失。
 * 约束是「必须可结构化克隆」——不要往里塞函数、Symbol、DOM 节点。
 */
type JsonValue = unknown;

class PersistenceServiceImpl {
  private data: Record<string, JsonValue> = {};
  private cache: Record<string, JsonValue> = {};
  private initialized = false;
  private readyPromise: Promise<void> | null = null;
  private saveTimer: ReturnType<typeof setTimeout> | null = null;
  private pendingSave: Promise<void> | null = null;
  /** 与 pendingSave 配套的 resolve —— 必须与 Promise 的创建分开持有，见 scheduleSave */
  private pendingSaveResolve: (() => void) | null = null;
  /** 后端设置是否可达（设置页展示存储位置时用） */
  private backendAvailable = false;

  /** 设置是否已同步到中间件数据库 */
  get isBackendBacked(): boolean {
    return this.backendAvailable;
  }

  get isInitialized(): boolean {
    return this.initialized;
  }

  /** 等待初始化完成（幂等，可重复调用） */
  async ensureReady(): Promise<void> {
    if (this.initialized) return;
    this.readyPromise ??= this.init();
    await this.readyPromise;
  }

  /**
   * 载入全量数据
   *
   * 两层来源，**后端优先**：
   *   1. IndexedDB —— 本地缓存，保证离线可用、读取同步
   *   2. 中间件 `/api/v1/settings/all` —— 共享真相源
   *
   * 后端可达时用它覆盖本地同名键，因此换浏览器 / 清站点数据后
   * 语言、日志设置、首启完成标记都还在，不会重跑初始化向导。
   */
  private async init(): Promise<void> {
    try {
      const [stored, storedCache] = await Promise.all([
        idbGet<Record<string, JsonValue>>(ROOT_KEY),
        idbGet<Record<string, JsonValue>>(CACHE_KEY),
      ]);
      this.data = stored ?? {};
      this.cache = storedCache ?? {};
      AppLogger.info(
        `[Persistence] loaded ${Object.keys(this.data).length} keys from IndexedDB`,
      );
    } catch (e) {
      AppLogger.warning(`[Persistence] load failed, starting empty: ${String(e)}`);
      this.data = {};
      this.cache = {};
    }

    // 先标记就绪：下面拉后端设置时也会用到本服务，避免自我死锁
    this.initialized = true;

    try {
      const remote = await pullSettings();
      if (remote !== null) {
        this.data = { ...this.data, ...remote };
        this.backendAvailable = true;
        AppLogger.info(`[Persistence] merged ${Object.keys(remote).length} keys from backend`);
        // 后端拉到的内容回写本地缓存，供下次离线启动使用
        void this.flush();
      } else {
        AppLogger.info('[Persistence] backend unavailable, using local cache only');
      }
    } catch (e) {
      AppLogger.warning(`[Persistence] backend settings pull failed: ${String(e)}`);
    }
    return;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 读取（同步，与桌面版一致）
  // ──────────────────────────────────────────────────────────────────────────

  get<T = JsonValue>(key: string): T | undefined {
    return this.data[key] as T | undefined;
  }

  getString(key: string): string | undefined {
    const value = this.data[key];
    return typeof value === 'string' ? value : undefined;
  }

  getInt(key: string): number | undefined {
    const value = this.data[key];
    return typeof value === 'number' ? Math.trunc(value) : undefined;
  }

  getDouble(key: string): number | undefined {
    const value = this.data[key];
    return typeof value === 'number' ? value : undefined;
  }

  getBool(key: string): boolean | undefined {
    const value = this.data[key];
    return typeof value === 'boolean' ? value : undefined;
  }

  getStringList(key: string): string[] | undefined {
    const value = this.data[key];
    if (!Array.isArray(value)) return undefined;
    return value.filter((item): item is string => typeof item === 'string');
  }

  containsKey(key: string): boolean {
    return Object.prototype.hasOwnProperty.call(this.data, key);
  }

  /** 全部键（设置页统计用） */
  keys(): string[] {
    return Object.keys(this.data);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 写入
  // ──────────────────────────────────────────────────────────────────────────

  async set(key: string, value: JsonValue): Promise<void> {
    this.data[key] = value;
    // 本地先落盘保证不丢，再同步后端；后端不可达时下次启动会补传
    await this.scheduleSave();
    void pushSetting(key, value);
  }

  setString(key: string, value: string): Promise<void> {
    return this.set(key, value);
  }

  setInt(key: string, value: number): Promise<void> {
    return this.set(key, Math.trunc(value));
  }

  setDouble(key: string, value: number): Promise<void> {
    return this.set(key, value);
  }

  setBool(key: string, value: boolean): Promise<void> {
    return this.set(key, value);
  }

  setStringList(key: string, value: string[]): Promise<void> {
    return this.set(key, value);
  }

  async remove(key: string): Promise<void> {
    delete this.data[key];
    await this.scheduleSave();
    void removeSetting(key);
  }

  async clear(): Promise<void> {
    this.data = {};
    await this.flush();
    void resetSettings();
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 模块专属命名空间（对应桌面版 getModuleData / setModuleData）
  // ──────────────────────────────────────────────────────────────────────────

  /** 读取某模块的命名空间数据 */
  getModuleData<T = JsonValue>(moduleName: string, key: string): T | undefined {
    const bucket = this.data[`module:${moduleName}`];
    if (!bucket || typeof bucket !== 'object' || Array.isArray(bucket)) return undefined;
    return (bucket as Record<string, JsonValue>)[key] as T | undefined;
  }

  /** 写入某模块的命名空间数据 */
  async setModuleData(moduleName: string, key: string, value: JsonValue): Promise<void> {
    const { bucketKey, bucket } = this.updateModuleData(moduleName, key, value);
    await this.scheduleSave();
    // 模块数据整桶同步，保证后端始终是完整快照
    void pushSetting(bucketKey, bucket);
  }

  /**
   * 绕过防抖并把 IndexedDB 失败暴露给调用方。
   *
   * 录制收尾不能在「只改了内存」后就清掉唯一的恢复存档，
   * 所以它们使用这条可验证的强制落盘路径。
   */
  async setModuleDataDurable(
    moduleName: string,
    key: string,
    value: JsonValue,
  ): Promise<void> {
    const { bucketKey, bucket } = this.updateModuleData(moduleName, key, value);
    await this.flushDurable();
    void pushSetting(bucketKey, bucket);
  }

  private updateModuleData(
    moduleName: string,
    key: string,
    value: JsonValue,
  ): { bucketKey: string; bucket: Record<string, JsonValue> } {
    const bucketKey = `module:${moduleName}`;
    const existing = this.data[bucketKey];
    const bucket: Record<string, JsonValue> =
      existing && typeof existing === 'object' && !Array.isArray(existing)
        ? { ...(existing as Record<string, JsonValue>) }
        : {};
    bucket[key] = value;
    this.data[bucketKey] = bucket;
    return { bucketKey, bucket };
  }

  async removeModuleData(moduleName: string, key: string): Promise<void> {
    const bucketKey = `module:${moduleName}`;
    const existing = this.data[bucketKey];
    if (!existing || typeof existing !== 'object' || Array.isArray(existing)) return;
    const bucket = { ...(existing as Record<string, JsonValue>) };
    delete bucket[key];
    this.data[bucketKey] = bucket;
    await this.scheduleSave();
    void pushSetting(bucketKey, bucket);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 缓存区（可被「清除缓存」单独清空，不影响设置）
  // ──────────────────────────────────────────────────────────────────────────

  getCache<T = JsonValue>(key: string): T | undefined {
    return this.cache[key] as T | undefined;
  }

  async setCache(key: string, value: JsonValue): Promise<void> {
    this.cache[key] = value;
    await idbSet(CACHE_KEY, this.cache);
  }

  /** 估算占用字节数（JSON 序列化后的 UTF-8 长度 + Storage API 实测值） */
  async getCacheSize(): Promise<number> {
    try {
      if (navigator.storage?.estimate) {
        const estimate = await navigator.storage.estimate();
        if (typeof estimate.usage === 'number') return estimate.usage;
      }
    } catch {
      /* 退回到手工估算 */
    }
    const encoder = new TextEncoder();
    return (
      encoder.encode(JSON.stringify(this.data)).byteLength +
      encoder.encode(JSON.stringify(this.cache)).byteLength
    );
  }

  /** 清除缓存（保留应用设置），对应桌面版 clearCache */
  async clearCache(): Promise<void> {
    this.cache = {};
    await idbDel(CACHE_KEY);
    AppLogger.info('[Persistence] cache cleared');
  }

  /** 重置应用：清空全部配置与缓存 */
  async resetApp(): Promise<void> {
    this.data = {};
    this.cache = {};
    if (this.saveTimer !== null) {
      clearTimeout(this.saveTimer);
      this.saveTimer = null;
    }
    // 取消待落盘时必须把等在上面的调用方放行，否则它们会永远挂着
    this.pendingSaveResolve?.();
    this.pendingSave = null;
    this.pendingSaveResolve = null;
    await idbClear();
    await resetSettings();
    AppLogger.info('[Persistence] app reset (local + backend)');
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 落盘（防抖合并，对应桌面版的保存队列）
  // ──────────────────────────────────────────────────────────────────────────

  /**
   * 防抖落盘：300ms 内的连续写入合并成一次。
   *
   * ⚠️ 这里曾有一个会**永久挂死所有调用方**的写法：
   *
   *     if (this.saveTimer !== null) clearTimeout(this.saveTimer);
   *     this.pendingSave ??= new Promise((resolve) => {
   *       this.saveTimer = setTimeout(...);   // ← 只在 Promise 新建时才排定时器
   *     });
   *
   * 第二次调用会 clearTimeout 掉定时器，而 `??=` 见 pendingSave 非空便不再新建，
   * 于是**新的定时器压根没排**：resolve 永远不会被调用，pendingSave 也永远不会
   * 复位 —— 之后每一次 `await setModuleData(...)` 都拿到同一个死 Promise。
   * 表现是「点了保存，界面就此不动，也不报错」。
   *
   * 修法：Promise 的创建与定时器的排定分开 —— resolve 单独存起来，
   * 每次调用都重新排定时器。
   */
  private scheduleSave(): Promise<void> {
    if (this.saveTimer !== null) clearTimeout(this.saveTimer);
    this.pendingSave ??= new Promise<void>((resolve) => {
      this.pendingSaveResolve = resolve;
    });

    this.saveTimer = setTimeout(() => {
      this.saveTimer = null;
      const resolve = this.pendingSaveResolve;
      this.pendingSave = null;
      this.pendingSaveResolve = null;
      void this.flush().finally(() => resolve?.());
    }, 300);

    return this.pendingSave;
  }

  /** 立即写盘（页面卸载前调用） */
  async flush(): Promise<void> {
    try {
      await this.flushDurable();
    } catch (e) {
      AppLogger.warning(`[Persistence] save failed: ${String(e)}`);
    }
  }

  private async flushDurable(): Promise<void> {
    await idbSet(ROOT_KEY, this.data);
  }
}

/** 单例，对应 Flutter 版的 `PersistenceService()` 工厂构造 */
export const PersistenceService = new PersistenceServiceImpl();

// 页面隐藏/卸载时确保最后一次写入落盘
if (typeof window !== 'undefined') {
  window.addEventListener('pagehide', () => void PersistenceService.flush());
  document.addEventListener('visibilitychange', () => {
    if (document.visibilityState === 'hidden') void PersistenceService.flush();
  });
}
