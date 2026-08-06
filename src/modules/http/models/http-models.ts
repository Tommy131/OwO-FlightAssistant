/**
 * 中间件 HTTP 响应与异常模型
 *
 * 对应 Flutter 版 `modules/http/models/{http_response,http_exception}.dart`。
 */

export class MiddlewareHttpResponse {
  constructor(
    readonly statusCode: number,
    readonly headers: Record<string, string>,
    readonly body: string,
    readonly uri: string,
  ) {}

  get isSuccess(): boolean {
    return this.statusCode >= 200 && this.statusCode < 300;
  }

  /** 惰性解析的 JSON 响应体；非 JSON 时返回原始字符串 */
  get decodedBody(): unknown {
    if (this.body.length === 0) return null;
    try {
      // JSON.parse 的返回类型是 any，显式收敛成 unknown，
      // 否则调用方拿到 any 就绕过了后续所有类型检查
      return JSON.parse(this.body) as unknown;
    } catch {
      return this.body;
    }
  }

  /** 断言响应体是对象，否则返回 null */
  get objectBody(): Record<string, unknown> | null {
    const decoded = this.decodedBody;
    return decoded !== null && typeof decoded === 'object' && !Array.isArray(decoded)
      ? (decoded as Record<string, unknown>)
      : null;
  }
}

export class MiddlewareHttpException extends Error {
  readonly statusCode?: number;
  readonly data?: unknown;
  readonly uri?: string;

  constructor(init: {
    message: string;
    statusCode?: number;
    data?: unknown;
    uri?: string;
  }) {
    super(init.message);
    this.name = 'MiddlewareHttpException';
    this.statusCode = init.statusCode;
    this.data = init.data;
    this.uri = init.uri;
  }
}

/** 从任意异常中提取可展示的错误文案（对应适配器的 _extractErrorMessage） */
export function extractErrorMessage(error: unknown): string {
  if (error instanceof MiddlewareHttpException) {
    const data = error.data;
    if (data && typeof data === 'object' && !Array.isArray(data)) {
      const message = (data as Record<string, unknown>).error;
      const text = typeof message === 'string' ? message.trim() : '';
      if (text.length > 0) return text;
    }
    return error.message;
  }
  return error instanceof Error ? error.message : String(error);
}

/** 401 / 409 视为会话失效（对应 _isConnectionLostError） */
export function isConnectionLostError(error: unknown): boolean {
  if (!(error instanceof MiddlewareHttpException)) return false;
  return error.statusCode === 401 || error.statusCode === 409;
}
