/**
 * 机场地面结构图层：跑道道面 / 滑行道 / 停机坪 / 直升机坪
 *
 * 数据来自 OSM 的 aeroway 标签（经中间件的 Overpass 代理）。
 * **注意**：`feature.ref` / `feature.name` 是社区可编辑内容，
 * 进 DOM 前必须转义。
 */

import L from 'leaflet';
import { clamp } from '../../../../core/utils/math-utils';
import { escapeHtml } from '../../../../core/utils/escape-html';
import type { MapAerowayFeature, MapCoordinate } from '../../models/map-models';
import { useMapStore } from '../../providers/map-store';
import { AEROWAY_COLORS, MARKER_Z, TAXIWAY_SIGN } from './layer-style';

/** 画地面结构的最低缩放级别；再远这些线会糊成一团 */
export const AEROWAY_MIN_ZOOM = 12;

/** 滑行道编号的显示门槛 */
export const TAXIWAY_REF_MIN_ZOOM = 14;

/**
 * 画机场地面结构
 *
 * 数据来自 OSM 的 aeroway 标签，只有跑道、滑行道、停机坪，
 * 天然不含市政道路和商铺 —— 这正是通用底图瓦片做不到的。
 */
export function renderAeroway(map: L.Map, group: L.LayerGroup | undefined): void {
  if (!group) return;
  group.clearLayers();

  const state = useMapStore.getState();
  if (!state.showAeroway) return;
  const features = state.aerowayFeatures;
  if (features.length === 0) return;

  const zoom = map.getZoom();
  if (zoom < AEROWAY_MIN_ZOOM) return;
  const scale = clamp(2 ** (zoom - 15), 0.35, 2.2);
  const showRefs = zoom >= TAXIWAY_REF_MIN_ZOOM;

  // 视野外的要素一概不画：同时缓存了几个机场时，
  // 不裁剪会往 DOM 里塞几千条根本看不到的线。
  //
  // 跑道**不在这一层画**：它归「跑道」开关管（见 renderAirportDetail），
  // 否则关掉滑行道会把跑道一起关掉。
  const view = map.getBounds().pad(0.25);
  const visible = features.filter(
    (feature) => feature.kind !== 'runway' && intersectsBounds(feature, view),
  );

  // 停机坪先画（面），引导线次之，主滑行道最后 —— 压盖顺序才合理
  const order: Record<string, number> = {
    apron: 0,
    taxilane: 1,
    taxiway: 2,
    helipad: 3,
  };
  const sorted = [...visible].sort((a, b) => (order[a.kind] ?? 9) - (order[b.kind] ?? 9));

  for (const feature of sorted) {
    const path = feature.points.map(
      (point) => [point.latitude, point.longitude] as [number, number],
    );

    if (feature.kind === 'apron' && feature.closed) {
      L.polygon(path, {
        pane: 'aeroway',
        stroke: true,
        color: AEROWAY_COLORS.apronStroke,
        weight: 1,
        opacity: 0.6,
        fillColor: AEROWAY_COLORS.apronFill,
        fillOpacity: 0.5,
        interactive: false,
      }).addTo(group);
      continue;
    }

    if (feature.kind === 'helipad') {
      L.polyline(path, {
        pane: 'aeroway',
        color: AEROWAY_COLORS.helipad,
        weight: clamp(2.4 * scale, 1, 5),
        opacity: 0.85,
        interactive: false,
      }).addTo(group);
      continue;
    }

    const isLane = isStandLane(feature);
    const coreWidth = clamp((isLane ? 1.6 : 2.6) * scale, isLane ? 0.7 : 1.2, isLane ? 3 : 5);
    // 道面比中线宽出好几倍，跟真实滑行道一样：中线只是道面中间那一道漆
    const pavementWidth = coreWidth * (isLane ? 2.6 : 3.4);

    // 先铺道面再画中线，浅底图上也分得清
    L.polyline(path, {
      pane: 'aeroway',
      color: AEROWAY_COLORS.taxiwayCasing,
      weight: pavementWidth,
      opacity: isLane ? 0.55 : 0.75,
      lineCap: 'round',
      lineJoin: 'round',
      interactive: false,
    }).addTo(group);
    L.polyline(path, {
      pane: 'aeroway',
      color: isLane ? AEROWAY_COLORS.taxilane : AEROWAY_COLORS.taxiway,
      weight: coreWidth,
      opacity: isLane ? 0.85 : 1,
      lineCap: 'round',
      lineJoin: 'round',
      interactive: false,
    })
      .bindTooltip(escapeHtml(feature.ref ?? feature.name ?? ''), { sticky: true })
      .addTo(group);
  }

  if (showRefs) renderTaxiwayRefs(group, sorted, zoom);
}

/**
 * 滑行道编号标签
 *
 * OSM 把一条滑行道拆成很多段，每段都带同一个 ref。逐段打标签的话
 * 大机场一屏能出两百个牌子，完全没法看。这里按 ref 归并，
 * 只在该编号最长的那一段中点放一个牌子。
 */
export function renderTaxiwayRefs(
  group: L.LayerGroup,
  features: MapAerowayFeature[],
  zoom: number,
): void {
  const longest = new Map<string, { feature: MapAerowayFeature; length: number }>();

  for (const feature of features) {
    if (feature.kind !== 'taxiway' && feature.kind !== 'taxilane') continue;
    const ref = feature.ref?.trim();
    if (!ref) continue;
    const length = polylineLengthDeg(feature.points);
    const current = longest.get(ref);
    if (!current || length > current.length) longest.set(ref, { feature, length });
  }

  // 缩得较远时只留主滑行道的编号，机位引导线的先不画
  const laneRefsVisible = zoom >= TAXIWAY_REF_MIN_ZOOM + 2;

  for (const [ref, { feature }] of longest) {
    if (isStandLane(feature) && !laneRefsVisible) continue;
    const middle = feature.points[Math.floor(feature.points.length / 2)];
    if (!middle) continue;
    const isLane = isStandLane(feature);
    // 黑底黄字黄框 = 真实机场的滑行道**位置牌**
    L.marker([middle.latitude, middle.longitude], {
      icon: L.divIcon({
        className: 'owo-map-autolabel',
        html: `<div style="position:absolute;left:0;top:0;transform:translate(-50%,-50%);
          padding:1px 5px;border-radius:2px;
          background:${TAXIWAY_SIGN.background};
          border:1px solid ${isLane ? TAXIWAY_SIGN.laneBorder : TAXIWAY_SIGN.border};
          color:${isLane ? TAXIWAY_SIGN.laneText : TAXIWAY_SIGN.text};
          font-size:9px;font-weight:800;letter-spacing:.06em;
          box-shadow:0 1px 3px rgba(0,0,0,.55);
          white-space:nowrap">${escapeHtml(ref)}</div>`,
      }),
      interactive: false,
      zIndexOffset: MARKER_Z.taxiwayRef,
    }).addTo(group);
  }
}

/**
 * 是否是「机位引导线」
 *
 * OSM 里 `aeroway=taxilane` 用得很少（VHHH 的 645 条滑行道一条都没标），
 * 实际上从停机坪连到主滑行道的那些短接线通常**没有编号** ——
 * 有编号的才是管制会念到的正式滑行道。用这个作判据比看标签靠谱。
 */
export function isStandLane(feature: MapAerowayFeature): boolean {
  if (feature.kind === 'taxilane') return true;
  return feature.kind === 'taxiway' && !feature.ref?.trim();
}

/** 要素的包围盒是否与视野相交 */
export function intersectsBounds(feature: MapAerowayFeature, bounds: L.LatLngBounds): boolean {
  let minLat = Infinity;
  let maxLat = -Infinity;
  let minLon = Infinity;
  let maxLon = -Infinity;
  for (const point of feature.points) {
    if (point.latitude < minLat) minLat = point.latitude;
    if (point.latitude > maxLat) maxLat = point.latitude;
    if (point.longitude < minLon) minLon = point.longitude;
    if (point.longitude > maxLon) maxLon = point.longitude;
  }
  return bounds.intersects(L.latLngBounds([minLat, minLon], [maxLat, maxLon]));
}

/** 折线长度（度，仅用于同一机场内比长短，不需要换算成米） */
export function polylineLengthDeg(points: MapCoordinate[]): number {
  let total = 0;
  for (let i = 1; i < points.length; i++) {
    const dLat = points[i].latitude - points[i - 1].latitude;
    const dLon = points[i].longitude - points[i - 1].longitude;
    total += Math.hypot(dLat, dLon);
  }
  return total;
}
