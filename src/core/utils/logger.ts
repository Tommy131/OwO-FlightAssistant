/*
 *        _____   _          __  _____   _____   _       _____   _____
 *      /  _  \ | |        / / /  _  \ |  _  \ | |     /  _  \ /  ___|
 *      | | | | | |  __   / /  | | | | | |_| | | |     | | | | | |
 *      | | | | | | /  | / /   | | | | |  _  { | |     | | | | | |   _
 *      | |_| | | |/   |/ /    | |_| | | |_| | | |___  | |_| | | |_| |
 *      \_____/ |___/|___/     \_____/ |_____/ |_____| \_____/ \_____/
 *
 *  Copyright (c) 2023 by OwOTeam-DGMT (OwOBlog).
 * @Author       : HanskiJay
 * @E-Mail       : support@owoblog.com
 */

/**
 * 应用日志
 *
 * 对应 Flutter 版 `lib/core/utils/logger.dart`。
 *
 * ── Web 降级说明 ──
 * 桌面版把日志写进 `<cacheRoot>/logs/{app,error}.log` 并按体积轮转。
 * 浏览器无文件写权限，因此改为：
 *   - 控制台输出（带等级着色，等价于 PrettyPrinter）
 *   - 内存环形缓冲区（供 log_viewer 模块读取，等价于读日志文件）
 *   - 「分割大小」语义转换为「缓冲区最大条数」，超出后丢弃最旧记录
 *   - 支持一键导出为 .log 文本文件（等价于桌面版的「打开日志文件夹」）
 */

// 与 PersistenceService 构成静态循环依赖，但双方都只在函数体内互相调用
// （模块求值期零交互），ESM 可以正确解析。
import { PersistenceService } from '../services/persistence-service';

export type LogLevel = 'debug' | 'info' | 'warning' | 'error';

export interface LogEntry {
  timestamp: Date;
  level: LogLevel;
  message: string;
  /** error 级别附带的错误对象序列化文本 */
  detail?: string;
}

export interface LogSettings {
  enabled: boolean;
  /** 缓冲区最大条数（对应桌面版的日志分割大小 MB） */
  maxEntries: number;
}

const ENABLED_KEY = 'log_enabled';
const MAX_ENTRIES_KEY = 'log_max_entries';
const DEFAULT_MAX_ENTRIES = 2000;

/** 等级权重，用于过滤 */
export const LOG_LEVEL_ORDER: Record<LogLevel, number> = {
  debug: 0,
  info: 1,
  warning: 2,
  error: 3,
};

const LEVEL_STYLE: Record<LogLevel, string> = {
  debug: 'color:#7f8c8d',
  info: 'color:#0984e3',
  warning: 'color:#e17055;font-weight:600',
  error: 'color:#d63031;font-weight:700',
};

const LEVEL_EMOJI: Record<LogLevel, string> = {
  debug: '🐛',
  info: '💡',
  warning: '⚠️',
  error: '⛔',
};

type LogListener = (entry: LogEntry) => void;

class AppLoggerImpl {
  private entries: LogEntry[] = [];
  private listeners = new Set<LogListener>();
  private enabled = true;
  private maxEntries = DEFAULT_MAX_ENTRIES;
  private initialized = false;

  /** 从持久化载入日志设置 */
  async init(): Promise<void> {
    await PersistenceService.ensureReady();
    this.enabled = PersistenceService.getBool(ENABLED_KEY) ?? true;
    this.maxEntries = PersistenceService.getInt(MAX_ENTRIES_KEY) ?? DEFAULT_MAX_ENTRIES;
    this.initialized = true;
    this.info(`Logger initialized. Buffer capacity: ${this.maxEntries} entries`);
  }

  loadSettings(): LogSettings {
    return { enabled: this.enabled, maxEntries: this.maxEntries };
  }

  async updateSettings(next: Partial<LogSettings>): Promise<void> {
    if (typeof next.enabled === 'boolean') {
      this.enabled = next.enabled;
      await PersistenceService.setBool(ENABLED_KEY, next.enabled);
    }
    if (typeof next.maxEntries === 'number') {
      this.maxEntries = Math.min(Math.max(Math.trunc(next.maxEntries), 100), 100_000);
      await PersistenceService.setInt(MAX_ENTRIES_KEY, this.maxEntries);
      this.trim();
    }
  }

  get isEnabled(): boolean {
    return this.enabled;
  }

  get isInitialized(): boolean {
    return this.initialized;
  }

  get maxBufferEntries(): number {
    return this.maxEntries;
  }

  // ── 输出接口（与桌面版同名）──

  debug(message: string): void {
    this.write('debug', message);
  }

  info(message: string): void {
    this.write('info', message);
  }

  warning(message: string): void {
    this.write('warning', message);
  }

  error(message: string, error?: unknown, stackTrace?: unknown): void {
    const parts: string[] = [];
    if (error !== undefined) parts.push(stringifyError(error));
    // 与上面一样走 stringifyError：栈信息可能是 Error、字符串或任意对象，
    // 直接 String() 的话对象会变成 "[object Object]"，日志里等于什么都没记下
    if (stackTrace !== undefined) parts.push(stringifyError(stackTrace));
    this.write('error', message, parts.length > 0 ? parts.join('\n') : undefined);
  }

  // ── 供 log_viewer 模块使用 ──

  /** 读取全部日志（可按等级与关键字过滤） */
  read(options: { minLevel?: LogLevel; keyword?: string } = {}): LogEntry[] {
    const min = options.minLevel ? LOG_LEVEL_ORDER[options.minLevel] : 0;
    const keyword = options.keyword?.trim().toLowerCase();
    return this.entries.filter((entry) => {
      if (LOG_LEVEL_ORDER[entry.level] < min) return false;
      if (keyword && !entry.message.toLowerCase().includes(keyword)) return false;
      return true;
    });
  }

  /** 订阅新日志（log_viewer 实时追加） */
  subscribe(listener: LogListener): () => void {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  }

  clear(): void {
    this.entries = [];
  }

  /** 序列化为纯文本，供导出 .log 文件 */
  toPlainText(entries: LogEntry[] = this.entries): string {
    return entries
      .map((entry) => {
        const head = `[${formatTimestamp(entry.timestamp)}] [${entry.level.toUpperCase()}] ${entry.message}`;
        return entry.detail ? `${head}\n${entry.detail}` : head;
      })
      .join('\n');
  }

  // ── 内部 ──

  private write(level: LogLevel, message: string, detail?: string): void {
    if (!this.enabled && level !== 'error') return;

    const entry: LogEntry = { timestamp: new Date(), level, message, detail };
    this.entries.push(entry);
    this.trim();

    const prefix = `%c${LEVEL_EMOJI[level]} ${formatTimestamp(entry.timestamp)}`;
    const consoleFn =
      level === 'error' ? console.error : level === 'warning' ? console.warn : console.log;
    if (detail) {
      consoleFn(`${prefix} ${message}`, LEVEL_STYLE[level], `\n${detail}`);
    } else {
      consoleFn(`${prefix} ${message}`, LEVEL_STYLE[level]);
    }

    for (const listener of this.listeners) {
      try {
        listener(entry);
      } catch {
        /* 监听器异常不应影响日志写入 */
      }
    }
  }

  private trim(): void {
    const overflow = this.entries.length - this.maxEntries;
    if (overflow > 0) this.entries.splice(0, overflow);
  }
}

function formatTimestamp(date: Date): string {
  const two = (n: number) => String(n).padStart(2, '0');
  const three = (n: number) => String(n).padStart(3, '0');
  return `${two(date.getHours())}:${two(date.getMinutes())}:${two(date.getSeconds())}.${three(date.getMilliseconds())}`;
}

function stringifyError(error: unknown): string {
  if (error instanceof Error) {
    return error.stack ? `${error.name}: ${error.message}\n${error.stack}` : String(error);
  }
  try {
    return JSON.stringify(error);
  } catch {
    return String(error);
  }
}

export const AppLogger = new AppLoggerImpl();
