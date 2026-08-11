import { useEffect, useRef } from 'react';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';

/**
 * Leaflet 地图基础封装
 *
 * 桌面版用 `flutter_map`（它本身就是 Leaflet 的移植），因此 Web 版直接用 Leaflet，
 * 图层 URL、缩放范围、attribution 都可以原样沿用。
 * 本组件只负责实例生命周期与底图；具体图层由调用方在 onReady 里挂载。
 */

/** 底图源，与桌面版 map 模块的图层列表一致 */
export const MAP_TILE_LAYERS = {
  osm: {
    url: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    attribution: '© OpenStreetMap contributors',
    maxZoom: 19,
    /** 浅色底图：标记需要用深色描边 */
    bright: true,
  },
  esriImagery: {
    url: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
    attribution: '© Esri, Maxar, Earthstar Geographics',
    maxZoom: 19,
    bright: false,
  },
  esriTerrain: {
    url: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Terrain_Base/MapServer/tile/{z}/{y}/{x}',
    attribution: '© Esri',
    maxZoom: 13,
    bright: true,
  },
  cartoDark: {
    url: 'https://basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
    attribution: '© OpenStreetMap contributors © CARTO',
    maxZoom: 20,
    bright: false,
  },
  cartoLight: {
    url: 'https://basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
    attribution: '© OpenStreetMap contributors © CARTO',
    maxZoom: 20,
    bright: true,
  },
} as const;

export type MapTileLayerId = keyof typeof MAP_TILE_LAYERS;

export interface LeafletMapProps {
  /** 初始中心 [lat, lon] */
  center?: [number, number];
  zoom?: number;
  tileLayer?: MapTileLayerId;
  height?: number | string;
  /** 绝对定位填满最近的定位宿主，用于 flex 容器内的响应式地图 */
  fill?: boolean;
  className?: string;
  /** 是否允许交互（缩放/拖拽） */
  interactive?: boolean;
  /** 地图就绪回调，返回清理函数用于卸载自定义图层 */
  onReady?: (map: L.Map) => void | (() => void);
}

export function LeafletMap({
  center = [39.9, 116.4],
  zoom = 6,
  tileLayer = 'cartoDark',
  height = 320,
  fill = false,
  className,
  interactive = true,
  onReady,
}: LeafletMapProps) {
  const containerRef = useRef<HTMLDivElement>(null);
  const mapRef = useRef<L.Map | null>(null);
  // 用 ref 持有回调，避免 onReady 每次重建导致地图反复销毁重建
  const onReadyRef = useRef(onReady);
  onReadyRef.current = onReady;

  useEffect(() => {
    const container = containerRef.current;
    if (!container) return;

    const map = L.map(container, {
      center,
      zoom,
      zoomControl: interactive,
      dragging: interactive,
      scrollWheelZoom: interactive,
      doubleClickZoom: interactive,
      touchZoom: interactive,
      attributionControl: true,
    });
    mapRef.current = map;

    const layer = MAP_TILE_LAYERS[tileLayer];
    L.tileLayer(layer.url, {
      attribution: layer.attribution,
      maxZoom: layer.maxZoom,
    }).addTo(map);

    const cleanup = onReadyRef.current?.(map);

    // 容器尺寸变化后 Leaflet 需要手动 invalidate 才能重算瓦片
    const observer = new ResizeObserver(() => map.invalidateSize());
    observer.observe(container);

    return () => {
      observer.disconnect();
      cleanup?.();
      map.remove();
      mapRef.current = null;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [tileLayer, interactive]);

  return (
    <div
      ref={containerRef}
      className={className}
      style={{
        width: '100%',
        ...(fill ? { position: 'absolute', inset: 0 } : { height }),
        borderRadius: 'var(--radius-sm)',
        overflow: 'hidden',
      }}
    />
  );
}
