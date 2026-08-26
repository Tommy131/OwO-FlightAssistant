import L from 'leaflet';
import {
  mapReferenceOverlayUrl,
  mapTileAttribution,
  mapTileMaxNativeZoom,
  mapTileUrl,
  type MapLayerStyle,
} from '../models/map-models';

export interface MapBasemapLayers {
  base: L.TileLayer;
  reference?: L.TileLayer;
}

/** 挂载底图，并为拆分标注的 Esri 画布补上参考层。 */
export function installMapBasemap(
  map: L.Map,
  style: MapLayerStyle,
  maxZoom: number,
): MapBasemapLayers {
  const base = L.tileLayer(mapTileUrl(style), {
    attribution: mapTileAttribution(style),
    maxZoom,
    // 超出覆盖范围的源要放大最后一级，否则会拿到「无数据」占位图
    maxNativeZoom: mapTileMaxNativeZoom(style),
    // OpenTopoMap 只有 a–c 子域；不含 {s} 的源会忽略此选项。
    subdomains: 'abc',
  }).addTo(map);
  base.setZIndex(1);

  const referenceUrl = mapReferenceOverlayUrl(style);
  if (!referenceUrl) return { base };

  const reference = L.tileLayer(referenceUrl, { maxZoom }).addTo(map);
  reference.setZIndex(2);
  return { base, reference };
}
