import type {
  BackendRecordKind,
  BackendTransport,
} from '../../../core/services/backend-transport';
import { MiddlewareHttpService } from './middleware-http-service';

/**
 * `BackendTransport` 端口的中间件实现
 *
 * core 层的同步服务只认 `BackendTransport` 接口，不认识本模块；
 * 这里把接口方法映射到具体的中间件接口调用，在模块注册期注入进 core。
 *
 * 这样 core → modules 的反向依赖被消除，core 也仍然可以被单独测试
 * （测试里注入一个假的实现即可）。
 */
export const middlewareBackendTransport: BackendTransport = {
  init() {
    return MiddlewareHttpService.init();
  },

  async saveRecord(kind: BackendRecordKind, id: string, record: unknown) {
    if (kind === 'flightLog') await MiddlewareHttpService.saveFlightLog(id, record);
    else await MiddlewareHttpService.saveBriefing(id, record);
  },

  async deleteRecord(kind: BackendRecordKind, id: string) {
    if (kind === 'flightLog') await MiddlewareHttpService.deleteFlightLog(id);
    else await MiddlewareHttpService.deleteBriefing(id);
  },

  async listRecords(kind: BackendRecordKind) {
    const response =
      kind === 'flightLog'
        ? await MiddlewareHttpService.listFlightLogs()
        : await MiddlewareHttpService.listBriefings();
    const records = response.objectBody?.records;
    return Array.isArray(records) ? records : [];
  },

  async getAllSettings() {
    const response = await MiddlewareHttpService.getAllSettings();
    const entries = response.objectBody?.entries;
    if (!entries || typeof entries !== 'object' || Array.isArray(entries)) return {};
    return entries as Record<string, unknown>;
  },

  async setSetting(key: string, value: unknown) {
    await MiddlewareHttpService.setSetting(key, value);
  },

  async deleteSetting(key: string) {
    await MiddlewareHttpService.deleteSetting(key);
  },

  async resetSettings() {
    await MiddlewareHttpService.resetSettings();
  },

  async setSettingsBulk(entries: Record<string, unknown>) {
    await MiddlewareHttpService.setSettingsBulk(entries);
  },
};
