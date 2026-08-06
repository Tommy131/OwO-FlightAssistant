import { describe, expect, it } from 'vitest';
import { escapeHtml } from './escape-html';

/**
 * HTML 转义
 *
 * 这是 NFR-6 的落地点。地图图层把外部文本拼进 Leaflet 的 `divIcon` 与
 * `bindTooltip`，而 Leaflet 对字符串内容一律走 `node.innerHTML = content`。
 * 转义一旦被改坏，界面上看不出任何异样 —— 只有真被人塞了脚本才会知道。
 */

describe('escapeHtml', () => {
  it('转义五个危险字符', () => {
    expect(escapeHtml('&')).toBe('&amp;');
    expect(escapeHtml('<')).toBe('&lt;');
    expect(escapeHtml('>')).toBe('&gt;');
    expect(escapeHtml('"')).toBe('&quot;');
    expect(escapeHtml("'")).toBe('&#39;');
  });

  it('& 必须最先替换，否则会二次转义', () => {
    // 先换 < 再换 & 的话，'&lt;' 里的 & 会被再转一次，变成 '&amp;lt;'
    expect(escapeHtml('<')).toBe('&lt;');
    expect(escapeHtml('&lt;')).toBe('&amp;lt;');
  });

  it('挡住脚本注入的典型载荷', () => {
    expect(escapeHtml('<script>alert(1)</script>')).toBe(
      '&lt;script&gt;alert(1)&lt;/script&gt;',
    );
    // OSM 的 ref 字段可被任何人编辑，这是最现实的入口
    expect(escapeHtml('<img src=x onerror=alert(1)>')).toBe(
      '&lt;img src=x onerror=alert(1)&gt;',
    );
  });

  it('挡住属性上下文的逃逸（双引号与单引号都要管）', () => {
    expect(escapeHtml('" onmouseover="alert(1)')).toBe(
      '&quot; onmouseover=&quot;alert(1)',
    );
    expect(escapeHtml("' onmouseover='alert(1)")).toBe(
      '&#39; onmouseover=&#39;alert(1)',
    );
  });

  it('正常文本原样通过', () => {
    expect(escapeHtml('ZBAA')).toBe('ZBAA');
    expect(escapeHtml('W1')).toBe('W1');
    expect(escapeHtml('北京首都国际机场')).toBe('北京首都国际机场');
    expect(escapeHtml('')).toBe('');
  });

  it('全部替换而不只替换第一处', () => {
    expect(escapeHtml('<<>>')).toBe('&lt;&lt;&gt;&gt;');
  });
});
