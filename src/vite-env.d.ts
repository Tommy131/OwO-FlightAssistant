/// <reference types="vite/client" />

/** 构建期注入的环境变量 */
interface ImportMetaEnv {
  readonly VITE_APP_VERSION?: string;
  readonly VITE_APP_BUILD?: string;
  /** 中间件 HTTP 地址（仅 vite.config.ts 的 dev proxy 使用） */
  readonly VITE_MIDDLEWARE_HTTP?: string;
  /** 中间件 WebSocket 地址（仅 dev proxy 使用） */
  readonly VITE_MIDDLEWARE_WS?: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}
