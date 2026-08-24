/**
 * 后端传输端口（Port）
 *
 * `core/` 是框架层，**不允许 import `modules/`** —— 否则框架就绑死在某个业务
 * 模块上，模块也没法独立裁剪了。但 core 里的同步服务确实要发请求。
 *
 * 解法是依赖倒置：core 只声明**它需要什么**（本文件的接口），
 * 具体实现由 `modules/http` 在启动时注入。依赖方向因此仍然是
 * modules → core，而不是反过来。
 *
 * 未注入时所有调用返回「不可用」，调用方据此降级到纯本地存储 ——
 * 后端离线本来就要能用，这条路径必须存在。
 */

/** 与中间件交互所需的最小能力集合 */
export interface BackendTransport {
  /** 确保连接参数已就绪；重复调用应当是幂等的 */
  init(): Promise<void>;

  saveRecord(
    kind: BackendRecordKind,
    id: string,
    record: unknown,
    options?: BackendRecordMutationOptions,
  ): Promise<BackendRecordMutationResult | void>;
  deleteRecord(
    kind: BackendRecordKind,
    id: string,
    options?: BackendRecordMutationOptions,
  ): Promise<BackendRecordMutationResult | void>;
  listRecords(kind: BackendRecordKind): Promise<unknown[]>;
  /** Additive state API; old transports may continue to implement listRecords only. */
  listRecordState?(
    kind: BackendRecordKind,
  ): Promise<BackendRecordState>;

  getAllSettings(): Promise<Record<string, unknown>>;
  setSetting(key: string, value: unknown): Promise<void>;
  deleteSetting(key: string): Promise<void>;
  resetSettings(): Promise<void>;
  setSettingsBulk(entries: Record<string, unknown>): Promise<void>;
}

export type BackendRecordKind = 'flightLog' | 'landingReport' | 'briefing';

export interface BackendRecordMutationOptions {
  expectedRevision?: number;
}

export interface BackendRecordMutationResult {
  revision?: number;
  deleted?: boolean;
}

export interface BackendRecordTombstone {
  id: string;
  revision: number;
  deleted: true;
}

export interface BackendRecordState {
  records: unknown[];
  revisions: Record<string, number>;
  tombstones: BackendRecordTombstone[];
}

let transport: BackendTransport | null = null;

/**
 * 注入实现（由 `modules/http` 在模块注册期调用）
 *
 * 传 null 可解除注入，主要用于测试。
 */
export function setBackendTransport(implementation: BackendTransport | null): void {
  transport = implementation;
}

/**
 * 取当前实现
 *
 * @returns 未注入时返回 null，调用方必须按「后端不可用」处理
 */
export function getBackendTransport(): BackendTransport | null {
  return transport;
}
