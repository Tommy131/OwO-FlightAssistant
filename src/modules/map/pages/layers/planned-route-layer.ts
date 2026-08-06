/**
 * 计划航路图层：SimBrief 导入的航路
 *
 * 与「航迹」（实际飞过的轨迹）是两回事 —— 航迹是事后累积的实线，
 * 这里画的是事前规划的虚线，两者会同时出现在图上，所以配色与线型都要拉开。
 *
 * SID/STAR 段与巡航段分色：程序段通常贴着地形绕，和巡航直线混一个色
 * 会让人误以为航路在乱拐。
 */

import L from 'leaflet';
import { escapeHtml } from '../../../../core/utils/escape-html';
import type { PlannedRoute } from '../../../common/models/planned-route-models';
import { MARKER_Z } from './layer-style';

/** 航路点标签的最低缩放级别；再小就糊成一片 */
export const PLANNED_POINT_LABEL_MIN_ZOOM = 6;

const PLANNED_STYLE = {
  /** 巡航段：青色虚线 */
  enroute: { color: '#38bdf8', weight: 2.5, opacity: 0.9, dashArray: '8 6' },
  /** SID/STAR 段：紫色，与巡航拉开 */
  procedure: { color: '#c084fc', weight: 2.5, opacity: 0.9, dashArray: '4 4' },
} as const;

const WAYPOINT_COLOR = '#38bdf8';
const PROCEDURE_COLOR = '#c084fc';

/** 航路点小圆点 + 标识 */
function plannedPointHtml(ident: string, isSidStar: boolean, showLabel: boolean): string {
  const color = isSidStar ? PROCEDURE_COLOR : WAYPOINT_COLOR;
  const dot = `<span style="width:6px;height:6px;border-radius:50%;background:${color};
    border:1px solid rgba(255,255,255,.85);flex-shrink:0"></span>`;
  if (!showLabel) {
    return `<div style="position:absolute;left:0;top:0;transform:translate(-50%,-50%);
      display:flex;align-items:center">${dot}</div>`;
  }
  // 外层零尺寸 + 内层自居中：宽度完全由文字决定，不必预估
  return `<div style="position:absolute;left:0;top:0;transform:translate(-50%,-50%);
    display:flex;align-items:center;gap:4px;padding:1px 5px;border-radius:8px;
    background:rgba(12,18,28,.82);border:1px solid ${color};
    color:#e8f4ff;font-size:9px;font-weight:600;white-space:nowrap">
    ${dot}${escapeHtml(ident)}
  </div>`;
}

/**
 * 重画计划航路。
 *
 * 与其它图层一致：清空后整组重画。这里点数是**航路点**级别（几十个），
 * 不是航迹那种十万级，整组重画完全够用。
 */
export function renderPlannedRoute(
  map: L.Map,
  group: L.LayerGroup | undefined,
  plan: PlannedRoute | null,
  visible: boolean,
): void {
  if (!group) return;
  group.clearLayers();
  if (!visible || !plan || plan.points.length < 2) return;

  const showLabel = map.getZoom() >= PLANNED_POINT_LABEL_MIN_ZOOM;

  // 逐段画：相邻两点的线型取**后一点**的属性，
  // 这样「进入 STAR 的那一段」就归到 STAR 里，与航图的读法一致
  for (let i = 0; i + 1 < plan.points.length; i++) {
    const from = plan.points[i];
    const to = plan.points[i + 1];
    const style = to.isSidStar ? PLANNED_STYLE.procedure : PLANNED_STYLE.enroute;
    L.polyline(
      [
        [from.position.latitude, from.position.longitude],
        [to.position.latitude, to.position.longitude],
      ],
      style,
    ).addTo(group);
  }

  for (const point of plan.points) {
    const marker = L.marker([point.position.latitude, point.position.longitude], {
      icon: L.divIcon({
        className: 'owo-map-autolabel',
        html: plannedPointHtml(point.ident, point.isSidStar, showLabel),
        iconSize: undefined,
      }),
      // 压在航迹之上、跑道端点之下
      zIndexOffset: MARKER_Z.taxiwayRef,
      interactive: true,
    });

    // 悬停给出该点的计划高度与所经航路 —— 这些是看航路时最常要的两项
    const detail = [
      point.altitudeFt !== undefined ? `${point.altitudeFt.toFixed(0)} ft` : undefined,
      point.viaAirway,
      point.stage,
    ]
      .filter((part): part is string => part !== undefined && part.length > 0)
      .join(' · ');
    marker.bindTooltip(
      `${escapeHtml(point.ident)}${detail ? ` — ${escapeHtml(detail)}` : ''}`,
      { direction: 'top' },
    );
    marker.addTo(group);
  }
}
