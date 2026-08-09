/**
 * 滑行引导高亮图层
 *
 * 画的是「接下来该怎么滑」，与自绘滑行道（用户自己画的参考线）和
 * 地面结构（OSM 矢量底图）都不是一回事，所以配色刻意拉开：
 * 这里用高饱和的橙，压在地面结构之上、标记之下。
 *
 * 底下衬一条更宽的暗色描边 —— 卫星底图上机坪是浅灰的，
 * 单一条亮线糊在上面根本看不清走向。
 */

import L from 'leaflet';
import { escapeHtml } from '../../../../core/utils/escape-html';
import type { MapCoordinate } from '../../models/map-models';
import { MARKER_Z } from './layer-style';

const TAXI_ROUTE_COLOR = '#ff8c1a';
const TAXI_ROUTE_HALO = 'rgba(8,12,20,.75)';

/** 起终点标记的最低缩放级别；再远就只剩一条线 */
export const TAXI_MARKER_MIN_ZOOM = 13;

function endpointHtml(label: string, color: string): string {
  return `<div style="position:absolute;left:0;top:0;transform:translate(-50%,-50%);
    display:flex;align-items:center;gap:4px">
    <span style="width:9px;height:9px;border-radius:50%;background:${color};
      border:2px solid rgba(255,255,255,.92);flex-shrink:0"></span>
    <span style="padding:1px 6px;border-radius:8px;background:rgba(12,18,28,.88);
      border:1px solid ${color};color:#fff3e0;font-size:10px;font-weight:700;
      white-space:nowrap">${escapeHtml(label)}</span>
  </div>`;
}

/**
 * 重画滑行路线。
 *
 * @param labels 起点与终点的标签文字（终点通常是 hold short 的跑道号）
 */
export function renderTaxiRoute(
  map: L.Map,
  group: L.LayerGroup | undefined,
  points: readonly MapCoordinate[] | null,
  visible: boolean,
  labels: { start: string; end: string },
): void {
  if (!group) return;
  group.clearLayers();
  // 一个点连不成线，也说明规划没成功，不必画
  if (!visible || !points || points.length < 2) return;

  const latlngs = points.map((point) => [point.latitude, point.longitude] as [number, number]);

  L.polyline(latlngs, { color: TAXI_ROUTE_HALO, weight: 9, opacity: 0.9 }).addTo(group);
  L.polyline(latlngs, {
    color: TAXI_ROUTE_COLOR,
    weight: 4,
    opacity: 0.95,
    // 虚线暗示「计划要走的」，与已经飞过的实线航迹区分
    dashArray: '10 6',
  }).addTo(group);

  if (map.getZoom() < TAXI_MARKER_MIN_ZOOM) return;
  const ends: [MapCoordinate, string][] = [
    [points[0], labels.start],
    [points[points.length - 1], labels.end],
  ];
  for (const [point, label] of ends) {
    L.marker([point.latitude, point.longitude], {
      icon: L.divIcon({
        className: 'owo-map-autolabel',
        html: endpointHtml(label, TAXI_ROUTE_COLOR),
        iconSize: undefined,
      }),
      zIndexOffset: MARKER_Z.taxiwayRef,
      interactive: false,
    }).addTo(group);
  }
}
