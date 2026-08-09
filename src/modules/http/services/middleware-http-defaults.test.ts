import { describe, expect, it } from 'vitest';
import {
  DESKTOP_DEFAULT_WS_BASE_URL,
  PROXY_HTTP_PREFIX,
  defaultBaseUrl,
  defaultWebSocketUrl,
} from './middleware-http-service';

/**
 * 默认地址推导
 *
 * 这两个判断错了**不会报错**：中间件对未知路径回落到 SPA 的 index.html，
 * `/mw-api/...` 会拿到 HTTP 200 + 一段 HTML，健康检查照样通过、界面显示已连接，
 * 只是每个接口都解析不出数据。v1.0.5-beta 的内嵌产物就是这么整个哑掉的。
 */

const loc = (over: Partial<Record<'protocol' | 'host' | 'hostname' | 'port', string>> = {}) => ({
  protocol: 'http:',
  host: '127.0.0.1:18080',
  hostname: '127.0.0.1',
  port: '18080',
  ...over,
});

describe('defaultBaseUrl', () => {
  it('开发下走 Vite 代理前缀', () => {
    expect(defaultBaseUrl(true)).toBe(PROXY_HTTP_PREFIX);
  });

  it('内嵌托管下必须是空串 —— 带前缀会被 SPA 兜底吞掉', () => {
    expect(defaultBaseUrl(false)).toBe('');
    expect(defaultBaseUrl(false)).not.toContain('mw-api');
  });
});

describe('defaultWebSocketUrl', () => {
  it('开发下走 /mw-ws 代理', () => {
    expect(defaultWebSocketUrl(true, loc())).toBe('ws://127.0.0.1:18080/mw-ws');
  });

  it('内嵌托管下按端口 +1 指向真实 WS 端点', () => {
    expect(defaultWebSocketUrl(false, loc())).toBe(
      'ws://127.0.0.1:18081/api/v1/simulator/ws',
    );
  });

  it('换主机部署也跟着走，不写死回环地址', () => {
    expect(
      defaultWebSocketUrl(false, loc({ host: 'efb.lan:18080', hostname: 'efb.lan' })),
    ).toBe('ws://efb.lan:18081/api/v1/simulator/ws');
  });

  it('https 页面用 wss，否则浏览器会拦掉混合内容', () => {
    const secure = loc({ protocol: 'https:', host: 'efb.lan:8443', hostname: 'efb.lan', port: '8443' });
    expect(defaultWebSocketUrl(false, secure)).toBe('wss://efb.lan:8444/api/v1/simulator/ws');
    expect(defaultWebSocketUrl(true, secure)).toBe('wss://efb.lan:8443/mw-ws');
  });

  it('端口缺省（80/443）时退回默认 WS 端口', () => {
    expect(defaultWebSocketUrl(false, loc({ host: 'efb.lan', hostname: 'efb.lan', port: '' }))).toBe(
      'ws://efb.lan:18081/api/v1/simulator/ws',
    );
  });

  it('拿不到页面地址时退回桌面版默认值', () => {
    expect(defaultWebSocketUrl(false, null)).toBe(DESKTOP_DEFAULT_WS_BASE_URL);
    expect(defaultWebSocketUrl(true, null)).toBe(DESKTOP_DEFAULT_WS_BASE_URL);
  });
});
