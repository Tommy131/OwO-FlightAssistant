import type {
  BackendRecordKind,
  BackendRecordMutationOptions,
  BackendRecordMutationResult,
  BackendRecordState,
  BackendRecordTombstone,
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

  async saveRecord(
    kind: BackendRecordKind,
    id: string,
    record: unknown,
    options?: BackendRecordMutationOptions,
  ) {
    if (kind === 'flightLog') await MiddlewareHttpService.saveFlightLog(id, record);
    else if (kind === 'landingReport') {
      const response = await MiddlewareHttpService.saveLandingReport(
        id,
        record,
        options?.expectedRevision,
      );
      return mutationResult(response.objectBody);
    }
    else await MiddlewareHttpService.saveBriefing(id, record);
  },

  async deleteRecord(
    kind: BackendRecordKind,
    id: string,
    options?: BackendRecordMutationOptions,
  ) {
    if (kind === 'flightLog') await MiddlewareHttpService.deleteFlightLog(id);
    else if (kind === 'landingReport') {
      const response = await MiddlewareHttpService.deleteLandingReport(
        id,
        options?.expectedRevision,
      );
      const result = mutationResult(response.objectBody);
      return {
        ...result,
        ...(response.objectBody?.tombstone === true ? { deleted: true } : {}),
      };
    }
    else await MiddlewareHttpService.deleteBriefing(id);
  },

  async listRecords(kind: BackendRecordKind) {
    const response =
      kind === 'flightLog'
        ? await MiddlewareHttpService.listFlightLogs()
        : kind === 'landingReport'
          ? await MiddlewareHttpService.listLandingReports()
          : await MiddlewareHttpService.listBriefings();
    const records: unknown = response.objectBody?.records;
    return Array.isArray(records) ? (records as unknown[]) : [];
  },

  async listRecordState(kind: BackendRecordKind): Promise<BackendRecordState> {
    if (kind !== 'landingReport') {
      return {
        records: await this.listRecords(kind),
        revisions: {},
        tombstones: [],
      };
    }
    const response = await MiddlewareHttpService.listLandingReports();
    const body = response.objectBody;
    const records = Array.isArray(body?.records) ? body.records : [];
    const revisions = numericRecord(body?.revisions);
    const tombstones = Array.isArray(body?.tombstones)
      ? body.tombstones.map(tombstoneFromRaw).filter(isTombstone)
      : [];
    return { records, revisions, tombstones };
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

function mutationResult(
  body: Record<string, unknown> | null,
): BackendRecordMutationResult {
  const revision = safeRevision(body?.revision);
  const deleted = typeof body?.deleted === 'boolean' ? body.deleted : undefined;
  return {
    ...(revision === undefined ? {} : { revision }),
    ...(deleted === undefined ? {} : { deleted }),
  };
}

function numericRecord(raw: unknown): Record<string, number> {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) return {};
  const result: Record<string, number> = {};
  for (const [id, value] of Object.entries(raw)) {
    const revision = safeRevision(value);
    if (revision !== undefined) result[id] = revision;
  }
  return result;
}

function tombstoneFromRaw(raw: unknown): BackendRecordTombstone | undefined {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) return undefined;
  const item = raw as Record<string, unknown>;
  const id = typeof item.id === 'string' ? item.id.trim() : '';
  const revision = safeRevision(item.revision);
  if (id.length === 0 || revision === undefined || item.deleted !== true) return undefined;
  return { id, revision, deleted: true };
}

function isTombstone(
  value: BackendRecordTombstone | undefined,
): value is BackendRecordTombstone {
  return value !== undefined;
}

function safeRevision(raw: unknown): number | undefined {
  return typeof raw === 'number' && Number.isSafeInteger(raw) && raw >= 0
    ? raw
    : undefined;
}
