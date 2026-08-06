/**
 * HTML 转义（NFR-6：外部文本插入 DOM 前必须转义）
 *
 * 地图图层大量使用 Leaflet 的 `divIcon` 与 `bindTooltip`，两者传字符串时
 * **内部都是 `node.innerHTML = content`** —— 也就是说，凡是把外部文本拼进
 * 这两处的地方都是 XSS 落点。而这些文本的来源并不都可信：
 *
 *   - 滑行道要素的 `ref` / `name` 来自 OpenStreetMap（Overpass），任何人可编辑；
 *   - 自绘滑行道的 `segment.name` 可由用户从 JSON 文件导入，别人分享的文件同样能带脚本；
 *   - 机场名、跑道号、空域名来自中间件解析的本地导航数据。
 *
 * 所以这里不区分「可信来源」，一律转义。
 */

/** 转义 `& < > " '`，覆盖文本节点与双/单引号属性值两种上下文 */
export function escapeHtml(text: string): string {
  return text
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}
