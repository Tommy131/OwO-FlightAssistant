import type { JsonMap } from '../../../core/utils/parse-utils';

/**
 * WebSocket 增量帧组装器
 *
 * 中间件在协商了 `delta=1` 后只推变化的字段，本类负责把增量打回本地状态，
 * 还原出与全量帧等价的 body 交给上层解析。
 *
 * ── 帧格式（与中间件 `ws_stream.go` 对齐）──
 * - 全量：`{ type: "snapshot", seq, delta_enabled, raw_dataset, client_dataset, ... }`
 * - 增量：`{ type: "delta", seq, base_seq, changed: {...}, removed: [["a","b"], ...] }`
 *
 * `removed` 是**路径数组**而不是点号字符串：X-Plane 的 dataref 键名里带斜杠和点，
 * 拼成字符串再拆会还原到错误的位置。
 *
 * ── 断链检测 ──
 * `base_seq` 对不上本地的 `seq` 就说明中间丢了帧。这时候必须停下来要一次
 * 重同步，而不是硬合并 —— 硬合并出来的状态不会报错，只会让某几个字段
 * 永远停在旧值上，是最难查的一类问题。
 *
 * 纯计算类：不 import React / IO / 任何框架，可被直接单测。
 */

/** 组装结果：body 为 null 表示这帧不可用 */
export interface AssembleResult {
  /** 可交给上层解析的完整 body；null 表示需要等重同步 */
  body: JsonMap | null;
  /** true 时调用方应向服务端发送 `{"type":"resync"}` */
  needsResync: boolean;
}

/** 增量帧携带的数据键（信封字段之外的部分） */
const DATA_KEYS = ['raw_dataset', 'client_dataset'] as const;

export class WsDeltaAssembler {
  /** 最近一次完整的数据部分（raw_dataset / client_dataset） */
  private data: JsonMap | null = null;
  private lastSeq = 0;

  /** 连接重建时调用，丢弃旧状态 */
  reset(): void {
    this.data = null;
    this.lastSeq = 0;
  }

  /** 当前是否已经有可用的基准状态 */
  get hasBaseline(): boolean {
    return this.data !== null;
  }

  accept(frame: JsonMap): AssembleResult {
    const type = typeof frame.type === 'string' ? frame.type : 'snapshot';

    if (type !== 'delta') {
      // 全量帧：直接作为新基准。老版本中间件不带 type，也走这里。
      const data: JsonMap = {};
      for (const key of DATA_KEYS) {
        if (frame[key] !== undefined) data[key] = frame[key];
      }
      this.data = data;
      this.lastSeq = toSeq(frame.seq);
      return { body: frame, needsResync: false };
    }

    const baseSeq = toSeq(frame.base_seq);
    if (this.data === null || baseSeq !== this.lastSeq) {
      // 丢帧了：本地基准和服务端对不上，只能要一次全量。
      return { body: null, needsResync: true };
    }

    const changed = isPlainObject(frame.changed) ? frame.changed : {};
    const next = deepMerge(this.data, changed);
    for (const path of readRemovedPaths(frame.removed)) {
      removeAtPath(next, path);
    }
    this.data = next;
    this.lastSeq = toSeq(frame.seq);

    // 信封字段（simulator_type / simulator_version / timestamp …）逐帧都带，
    // 直接盖在还原出来的数据上就是一个完整 body。
    const body: JsonMap = { ...frame, ...next };
    delete body.changed;
    delete body.removed;
    return { body, needsResync: false };
  }
}

// ──────────────────────────────────────────────────────────────────────────
// 纯函数工具
// ──────────────────────────────────────────────────────────────────────────

function toSeq(value: unknown): number {
  return typeof value === 'number' && Number.isFinite(value) ? value : 0;
}

function isPlainObject(value: unknown): value is JsonMap {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

/** 从帧里读出 removed 路径数组，忽略任何形状不对的项 */
function readRemovedPaths(value: unknown): string[][] {
  if (!Array.isArray(value)) return [];
  const out: string[][] = [];
  for (const entry of value) {
    if (!Array.isArray(entry)) continue;
    const path = entry.filter((segment): segment is string => typeof segment === 'string');
    if (path.length === entry.length && path.length > 0) out.push(path);
  }
  return out;
}

/**
 * 深合并，返回新对象（不改原状态）。
 *
 * 只有两边都是普通对象时才下钻；数组与类型不同的值一律整体替换 ——
 * 服务端的差异算法就是这么切的，两边必须完全一致。
 */
function deepMerge(base: JsonMap, patch: JsonMap): JsonMap {
  const out: JsonMap = { ...base };
  for (const [key, value] of Object.entries(patch)) {
    const existing = out[key];
    if (isPlainObject(value) && isPlainObject(existing)) {
      out[key] = deepMerge(existing, value);
    } else {
      out[key] = value;
    }
  }
  return out;
}

/** 按路径删除一个键，途中遇到非对象就当作已经删掉了 */
function removeAtPath(root: JsonMap, path: string[]): void {
  let node: JsonMap = root;
  for (let i = 0; i < path.length - 1; i += 1) {
    const child = node[path[i]];
    if (!isPlainObject(child)) return;
    // deepMerge 只在被改动的分支上建了新对象，未改动的分支仍与上一帧共享引用。
    // 删除必须写在自己的副本上，否则会把历史状态一起改掉。
    const copy: JsonMap = { ...child };
    node[path[i]] = copy;
    node = copy;
  }
  delete node[path[path.length - 1]];
}
