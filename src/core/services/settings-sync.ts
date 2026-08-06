import { getBackendTransport } from './backend-transport';
import { AppLogger } from '../utils/logger';

/**
 * 应用设置的服务端同步
 *
 * 语言、日志分割、主题、首启完成标记等全部存在中间件的
 * `resources/persistent/database.db` → `app_settings` 表里。
 *
 * 这样解决两个问题：
 *   1. **只初始化一次** —— 首启向导的完成标记在后端，换浏览器 / 清站点数据都不会重跑
 *   2. **多端一致** —— 桌面端与 Web 端共享同一份配置
 *
 * IndexedDB 退化为本地缓存：后端不可达时仍能正常读写，恢复连通后由
 * `flushPendingSettings()` 补传。
 */

/** 后端不可达期间积压的写入，key → value */
const pendingWrites = new Map<string, unknown>();
/** 后端不可达期间积压的删除 */
const pendingDeletes = new Set<string>();

let backendReachable = true;

/**
 * 拉取后端全部设置
 * @returns 键值对；后端不可达时返回 null（与「后端有但为空」区分开）
 */
export async function pullSettings(): Promise<Record<string, unknown> | null> {
  const transport = getBackendTransport();
  if (!transport) return null;
  try {
    await transport.init();
    const entries = await transport.getAllSettings();
    if (!entries || typeof entries !== 'object' || Array.isArray(entries)) return {};

    backendReachable = true;
    // 拉取成功说明后端回来了，顺手把积压的写入补上
    void flushPendingSettings();
    return entries;
  } catch (e) {
    backendReachable = false;
    AppLogger.warning(`[SettingsSync] pull failed: ${String(e)}`);
    return null;
  }
}

/** 写入单条设置；后端不可达时入队待补传 */
export async function pushSetting(key: string, value: unknown): Promise<void> {
  const transport = getBackendTransport();
  if (!transport) {
    pendingWrites.set(key, value);
    return;
  }
  try {
    await transport.init();
    await transport.setSetting(key, value);
    backendReachable = true;
    pendingDeletes.delete(key);
  } catch (e) {
    backendReachable = false;
    pendingWrites.set(key, value);
    AppLogger.warning(`[SettingsSync] push ${key} queued (backend down): ${String(e)}`);
  }
}

/** 删除单条设置 */
export async function removeSetting(key: string): Promise<void> {
  const transport = getBackendTransport();
  if (!transport) {
    pendingDeletes.add(key);
    pendingWrites.delete(key);
    return;
  }
  try {
    await transport.init();
    await transport.deleteSetting(key);
    backendReachable = true;
    pendingWrites.delete(key);
  } catch {
    backendReachable = false;
    pendingDeletes.add(key);
    pendingWrites.delete(key);
  }
}

/** 清空后端全部设置（对应「重置应用」） */
export async function resetSettings(): Promise<void> {
  pendingWrites.clear();
  pendingDeletes.clear();
  const transport = getBackendTransport();
  if (!transport) return;
  try {
    await transport.init();
    await transport.resetSettings();
  } catch (e) {
    AppLogger.warning(`[SettingsSync] reset failed: ${String(e)}`);
  }
}

/** 批量写入，首启向导一次提交全部配置时使用 */
export async function pushSettingsBulk(entries: Record<string, unknown>): Promise<boolean> {
  if (Object.keys(entries).length === 0) return true;
  const transport = getBackendTransport();
  if (!transport) {
    for (const [key, value] of Object.entries(entries)) pendingWrites.set(key, value);
    return false;
  }
  try {
    await transport.init();
    await transport.setSettingsBulk(entries);
    backendReachable = true;
    return true;
  } catch (e) {
    backendReachable = false;
    for (const [key, value] of Object.entries(entries)) pendingWrites.set(key, value);
    AppLogger.warning(`[SettingsSync] bulk push queued (backend down): ${String(e)}`);
    return false;
  }
}

/** 补传积压的写入与删除 */
export async function flushPendingSettings(): Promise<void> {
  if (pendingWrites.size === 0 && pendingDeletes.size === 0) return;

  const writes = Object.fromEntries(pendingWrites);
  const deletes = [...pendingDeletes];
  pendingWrites.clear();
  pendingDeletes.clear();

  if (Object.keys(writes).length > 0) await pushSettingsBulk(writes);
  for (const key of deletes) await removeSetting(key);
}

export function isBackendSettingsReachable(): boolean {
  return backendReachable;
}
