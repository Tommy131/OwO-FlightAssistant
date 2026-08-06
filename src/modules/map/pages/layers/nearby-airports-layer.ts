/**
 * 视野内机场图层：pin + ICAO + 机场范围轮廓
 *
 * 缩放到一定级别后显示当前画布内的所有机场，点击 pin 直接定位过去。
 */

import L from 'leaflet';
import { isBrightMapBackground, type MapAirportMarker } from '../../models/map-models';
import { nearbyAirportHtml } from '../../services/map-marker-html';
import { useMapStore } from '../../providers/map-store';

/** 缩放到这一级才开始画视野内的机场 pin，再远就是满屏小点 */
export const NEARBY_AIRPORT_MIN_ZOOM = 8;

/** 缩放到这一级才补机场轮廓（要逐个拉机场明细，代价不低） */
export const NEARBY_OUTLINE_MIN_ZOOM = 11;

/**
 * 画当前视野内的机场：pin + ICAO + 机场范围
 *
 * 点 pin 走的是和搜索一样的选中流程 —— 拉明细、填底卡、相机飞过去。
 */
export function renderNearbyAirports(
  map: L.Map,
  group: L.LayerGroup | undefined,
  onClick: (airport: MapAirportMarker) => void,
): void {
  if (!group) return;
  group.clearLayers();

  const state = useMapStore.getState();
  if (!state.showAirports) return;
  if (map.getZoom() < NEARBY_AIRPORT_MIN_ZOOM) return;

  const bright = isBrightMapBackground(state.layerStyle);
  const selectedCode = state.selectedAirport?.marker.code;

  for (const airport of state.nearbyAirports) {
    // 选中的那个由 renderAirportDetail 画得更详细，这里跳过免得重影
    if (airport.code === selectedCode) continue;

    const outline = state.nearbyOutlines[airport.code];
    if (outline && outline.length >= 3) {
      L.polygon(
        outline.map((point) => [point.latitude, point.longitude] as [number, number]),
        {
          color: '#199e70',
          weight: 1.5,
          opacity: 0.65,
          dashArray: '5 4',
          fillColor: '#199e70',
          fillOpacity: 0.06,
          interactive: false,
        },
      ).addTo(group);
    }

    L.marker([airport.position.latitude, airport.position.longitude], {
      icon: L.divIcon({
        className: 'owo-map-autolabel',
        html: nearbyAirportHtml(airport, bright),
      }),
      title: airport.name ? `${airport.code} · ${airport.name}` : airport.code,
      // 让 pin 压在轮廓之上，方便点
      zIndexOffset: 200,
    })
      .on('click', () => onClick(airport))
      .addTo(group);
  }
}
