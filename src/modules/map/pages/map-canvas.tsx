import { useEffect, useRef } from 'react';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';
import {
  isBrightMapBackground,
  mapReferenceOverlayUrl,
  mapTileAttribution,
  mapTileMaxNativeZoom,
  mapTileUrl,
  MAP_ALERT_LEVEL_COLOR,
  type MapAerowayFeature,
  type MapAirportMarker,
  type MapCoordinate,
  type MapHoldingPattern,
  type MapRunwayNavaid,
  type MapSelectedAirportDetail,
} from '../models/map-models';
import {
  useMapStore,
  weatherOverlayTileUrl,
  weatherRadarTileUrl,
} from '../providers/map-store';
import { computeAirportOutline } from '../services/airport-outline';
import { buildApproachBeam, type ApproachBeamKind } from '../services/approach-beam';
import { buildHoldingGeometry } from '../services/holding-geometry';

/**
 * 地图画布
 *
 * 对应 Flutter 版 `map_page.dart` 中的 FlutterMap 部分：
 * 底图 + 天气叠加 + 机场/跑道/停机位 + 航迹 + 本机与 AI 机 + 滑行道。
 *
 * 图层用命令式 Leaflet API 增量更新（而非每帧重建），
 * 这是高频遥测下保持流畅的关键 —— 与桌面版 flutter_map 的图层复用策略一致。
 */
/** 地图允许的最大缩放级别；底图（Carto / Esri / OSM）都能到 19 */
const MAP_MAX_ZOOM = 19;

/**
 * RainViewer 免费瓦片缓存的最大级别
 *
 * ⚠️ 超过这一级时上游**不是**返回 HTTP 错误，而是返回一张 200 的 PNG，
 * 图里画着 "Zoom Level Not Supported" 字样 —— 状态码检查完全发现不了，
 * 用户会直接在地图上看到满屏错误文字。
 * 因此必须用 maxNativeZoom 让 Leaflet 放大 z7 瓦片，而不是去请求 z8+。
 */
const RADAR_MAX_NATIVE_ZOOM = 7;

/**
 * 天气叠加层（雨/压/风/温）的最大原生级别
 *
 * 后端按 0.25° 网格向 Open-Meteo 取值，约 28km 一个格点；
 * 再往下放大取到的是同一个格点的同一个值，只是白白多打接口。
 * 这里到顶后同样交给 Leaflet 放大，不再请求新瓦片。
 */
const OVERLAY_MAX_NATIVE_ZOOM = 9;

export function MapCanvas({
  onAirportClick,
  onMapClick,
}: {
  onAirportClick: (airport: MapAirportMarker) => void;
  onMapClick: (point: MapCoordinate) => void;
}) {
  const containerRef = useRef<HTMLDivElement>(null);
  const mapRef = useRef<L.Map | null>(null);

  // 各图层句柄，便于增量更新
  const layersRef = useRef<{
    base?: L.TileLayer;
    reference?: L.TileLayer;
    radar?: L.TileLayer;
    overlays: Partial<Record<'rain' | 'pressure' | 'wind' | 'temp', L.TileLayer>>;
    route?: L.Polyline;
    aircraft?: L.Marker;
    aiGroup?: L.LayerGroup;
    airportGroup?: L.LayerGroup;
    taxiwayGroup?: L.LayerGroup;
    markerGroup?: L.LayerGroup;
    airspaceGroup?: L.LayerGroup;
    airportDetailGroup?: L.LayerGroup;
    nearbyGroup?: L.LayerGroup;
    aerowayGroup?: L.LayerGroup;
    procedureGroup?: L.LayerGroup;
  }>({ overlays: {} });

  // 回调放 ref，避免因 props 变化重建地图
  const onAirportClickRef = useRef(onAirportClick);
  onAirportClickRef.current = onAirportClick;
  const onMapClickRef = useRef(onMapClick);
  onMapClickRef.current = onMapClick;

  const layerStyle = useMapStore((s) => s.layerStyle);

  // ── 地图实例（仅创建一次）──
  useEffect(() => {
    const container = containerRef.current;
    if (!container) return;

    const map = L.map(container, {
      center: [39.9, 116.4],
      zoom: 8,
      zoomControl: false,
      attributionControl: true,
      // 惯性滚动在高频重绘下容易掉帧
      inertia: false,
    });
    mapRef.current = map;

    /*
     * 滑行道/停机坪专用 pane
     *
     * LayerGroup 并不隔离 z 序 —— 所有矢量共用同一个 <svg>，谁后调用 addTo
     * 谁压在上面。滑行道层和跑道层在不同时机重绘（前者随视野变，后者随选中
     * 机场/缩放变），共用一个 pane 的话叠放顺序就成了随机的，
     * 跑道时不时会被停机坪盖住。独立 pane + 固定 z-index 才稳定。
     * tilePane=200，overlayPane=400，取中间值让地面结构垫在跑道之下。
     */
    map.createPane('aeroway');
    const aerowayPane = map.getPane('aeroway');
    if (aerowayPane) {
      aerowayPane.style.zIndex = '380';
      // 地面结构只是背景，不该拦截地图拖拽
      aerowayPane.style.pointerEvents = 'none';
    }

    layersRef.current.airspaceGroup = L.layerGroup().addTo(map);
    // 机场地面结构（滑行道/停机坪）垫在最底下
    layersRef.current.aerowayGroup = L.layerGroup().addTo(map);
    // 视野内机场压在选中机场细节之下
    layersRef.current.nearbyGroup = L.layerGroup().addTo(map);
    // 机场细节压在机场标记之下，避免盖住可点击的标记
    layersRef.current.airportDetailGroup = L.layerGroup().addTo(map);
    // 进近波束与等待航线：压在机场细节之上、标记之下
    layersRef.current.procedureGroup = L.layerGroup().addTo(map);
    layersRef.current.aiGroup = L.layerGroup().addTo(map);
    layersRef.current.airportGroup = L.layerGroup().addTo(map);
    layersRef.current.taxiwayGroup = L.layerGroup().addTo(map);
    layersRef.current.markerGroup = L.layerGroup().addTo(map);

    map.on('click', (event: L.LeafletMouseEvent) => {
      onMapClickRef.current({ latitude: event.latlng.lat, longitude: event.latlng.lng });
    });

    // 跑道端点标签与停机位按缩放级别显隐，缩放后需要重画
    map.on('zoomend', () => {
      renderAirportDetail(map, layersRef.current.airportDetailGroup);
    });

    // 视野变化后按新边界拉取限制空域
    const fetchAirspace = () => {
      if (!useMapStore.getState().showRestrictedAirspace) return;
      const bounds = map.getBounds();
      void useMapStore.getState().refreshRestrictedAirspace({
        minLat: bounds.getSouth(),
        maxLat: bounds.getNorth(),
        minLon: bounds.getWest(),
        maxLon: bounds.getEast(),
      });
    };
    map.on('moveend', fetchAirspace);

    // 视野变化后按新边界拉取机场
    const fetchNearbyAirports = () => {
      const zoom = map.getZoom();
      if (zoom < NEARBY_AIRPORT_MIN_ZOOM) {
        useMapStore.setState({ nearbyAirports: [], nearbyOutlines: {} });
        return;
      }
      const bounds = map.getBounds();
      void useMapStore.getState().refreshNearbyAirports(
        {
          minLat: bounds.getSouth(),
          maxLat: bounds.getNorth(),
          minLon: bounds.getWest(),
          maxLon: bounds.getEast(),
        },
        { withOutlines: zoom >= NEARBY_OUTLINE_MIN_ZOOM },
      );

      // 缩到场面级别时，把屏幕上机场的滑行道网络也拉出来 ——
      // 不必先点中某个机场。限制个数：每个机场都要打一次 Overpass。
      if (zoom >= AEROWAY_MIN_ZOOM) {
        const visible = useMapStore
          .getState()
          .nearbyAirports.slice(0, NEARBY_AEROWAY_LIMIT)
          .map((airport) => airport.code);
        if (visible.length > 0) void useMapStore.getState().loadNearbyAeroway(visible);
      }
    };
    map.on('moveend', fetchNearbyAirports);
    fetchNearbyAirports();

    const observer = new ResizeObserver(() => map.invalidateSize());
    observer.observe(container);

    return () => {
      observer.disconnect();
      map.remove();
      mapRef.current = null;
      layersRef.current = { overlays: {} };
    };
  }, []);

  // ── 底图切换 ──
  useEffect(() => {
    const map = mapRef.current;
    if (!map) return;
    layersRef.current.base?.remove();
    layersRef.current.base = L.tileLayer(mapTileUrl(layerStyle), {
      attribution: mapTileAttribution(layerStyle),
      maxZoom: MAP_MAX_ZOOM,
      // 超出覆盖范围的源要放大最后一级，否则会拿到「无数据」占位图
      maxNativeZoom: mapTileMaxNativeZoom(layerStyle),
      // {s} 子域轮询。Carto 有 a–d 四个，OpenTopoMap 只有 a–c
      // （给它 'd' 会 404，整层随机缺瓦片）；不含 {s} 的源会忽略这个选项。
      subdomains: layerStyle === 'terrain' ? 'abc' : 'abcd',
    }).addTo(map);
    // 底图必须压在所有叠加层下面
    layersRef.current.base.setZIndex(1);

    // 卫星影像没有文字，补一层地名/边界注记
    layersRef.current.reference?.remove();
    layersRef.current.reference = undefined;
    const referenceUrl = mapReferenceOverlayUrl(layerStyle);
    if (referenceUrl) {
      layersRef.current.reference = L.tileLayer(referenceUrl, {
        maxZoom: MAP_MAX_ZOOM,
      }).addTo(map);
      layersRef.current.reference.setZIndex(2);
    }

    // 换底图后标记描边色要跟着明暗变，重画一次
    renderAirportDetail(map, layersRef.current.airportDetailGroup);
  }, [layerStyle]);

  // ── 天气雷达 ──
  useEffect(() =>
    useMapStore.subscribe((state, previous) => {
      const map = mapRef.current;
      if (!map) return;
      if (
        state.showWeather === previous.showWeather &&
        state.weatherRadarHost === previous.weatherRadarHost &&
        state.weatherRadarPath === previous.weatherRadarPath
      ) {
        return;
      }

      layersRef.current.radar?.remove();
      layersRef.current.radar = undefined;
      if (!state.showWeather) return;

      const url = weatherRadarTileUrl(state.weatherRadarHost, state.weatherRadarPath);
      if (!url) return;
      layersRef.current.radar = L.tileLayer(url, {
        opacity: 0.6,
        maxZoom: MAP_MAX_ZOOM,
        maxNativeZoom: RADAR_MAX_NATIVE_ZOOM,
      }).addTo(map);
      layersRef.current.radar.setZIndex(5);
    }),
  []);

  // ── 天气叠加层（雨/压/风/温）──
  useEffect(() =>
    useMapStore.subscribe((state, previous) => {
      const map = mapRef.current;
      if (!map) return;
      const pairs: [keyof typeof layersRef.current.overlays, boolean, boolean][] = [
        ['rain', state.showWeatherRainfall, previous.showWeatherRainfall],
        ['pressure', state.showWeatherPressure, previous.showWeatherPressure],
        ['wind', state.showWeatherWind, previous.showWeatherWind],
        ['temp', state.showWeatherTemperature, previous.showWeatherTemperature],
      ];
      for (const [layer, next, before] of pairs) {
        if (next === before) continue;
        layersRef.current.overlays[layer]?.remove();
        layersRef.current.overlays[layer] = undefined;
        if (!next) continue;
        const tile = L.tileLayer(weatherOverlayTileUrl(layer), {
          opacity: 0.55,
          maxZoom: MAP_MAX_ZOOM,
          maxNativeZoom: OVERLAY_MAX_NATIVE_ZOOM,
        }).addTo(map);
        tile.setZIndex(6);
        layersRef.current.overlays[layer] = tile;
      }
    }),
  []);

  // ── 机场标记 ──
  useEffect(() =>
    useMapStore.subscribe((state, previous) => {
      const group = layersRef.current.airportGroup;
      if (!group) return;
      if (
        state.airports === previous.airports &&
        state.showAirports === previous.showAirports &&
        state.homeAirport === previous.homeAirport &&
        state.layerStyle === previous.layerStyle
      ) {
        return;
      }

      group.clearLayers();
      if (!state.showAirports) return;

      const bright = isBrightMapBackground(state.layerStyle);
      const strokeColor = bright ? '#1a1a1a' : '#ffffff';

      for (const airport of state.airports) {
        const isHome = state.homeAirport?.code === airport.code;
        L.marker([airport.position.latitude, airport.position.longitude], {
          icon: L.divIcon({
            className: '',
            html: airportMarkerHtml(airport, isHome, strokeColor),
            iconSize: [airport.isPrimary ? 30 : 22, airport.isPrimary ? 30 : 22],
            iconAnchor: [airport.isPrimary ? 15 : 11, airport.isPrimary ? 15 : 11],
          }),
          title: `${airport.code}${airport.name ? ` · ${airport.name}` : ''}`,
        })
          .on('click', () => onAirportClickRef.current(airport))
          .addTo(group);
      }
    }),
  []);

  // ── 机场地面结构：跑道 / 滑行道 / 停机坪 ──
  useEffect(() => {
    const map = mapRef.current;
    if (!map) return;

    const render = () => renderAeroway(map, layersRef.current.aerowayGroup);
    // 按视野裁剪，所以平移之后也要重画
    map.on('zoomend', render);
    map.on('moveend', render);
    const unsubscribe = useMapStore.subscribe((state, previous) => {
      if (
        state.aerowayFeatures === previous.aerowayFeatures &&
        state.showAeroway === previous.showAeroway
      ) {
        return;
      }
      render();
    });
    render();

    return () => {
      map.off('zoomend', render);
      map.off('moveend', render);
      unsubscribe();
    };
  }, []);

  // ── 视野内机场：pin + ICAO + 机场范围 ──
  useEffect(() => {
    const map = mapRef.current;
    if (!map) return;

    const render = () => renderNearbyAirports(map, layersRef.current.nearbyGroup, (airport) =>
      onAirportClickRef.current(airport),
    );
    // 缩放会改变显示门槛，缩完要重画
    map.on('zoomend', render);
    const unsubscribe = useMapStore.subscribe((state, previous) => {
      if (
        state.nearbyAirports === previous.nearbyAirports &&
        state.nearbyOutlines === previous.nearbyOutlines &&
        state.showAirports === previous.showAirports &&
        state.selectedAirport === previous.selectedAirport &&
        state.layerStyle === previous.layerStyle
      ) {
        return;
      }
      render();
    });
    render();

    return () => {
      map.off('zoomend', render);
      unsubscribe();
    };
  }, []);

  // ── 选中机场：轮廓 / 跑道 / 停机位 + 相机定位 ──
  useEffect(() =>
    useMapStore.subscribe((state, previous) => {
      const map = mapRef.current;
      if (!map) return;

      const detailChanged = state.selectedAirport !== previous.selectedAirport;
      const togglesChanged =
        state.showRunways !== previous.showRunways ||
        state.showParkings !== previous.showParkings ||
        // 进近设施与下滑道也画在这一层里，开关变了同样要重画
        state.showRunwayNavaids !== previous.showRunwayNavaids ||
        state.showGlideslope !== previous.showGlideslope;
      if (!detailChanged && !togglesChanged) return;

      renderAirportDetail(map, layersRef.current.airportDetailGroup);

      // 新选中机场时把相机定位过去（zoom 15，与桌面版一致）
      if (detailChanged && state.selectedAirport) {
        const { latitude, longitude } = state.selectedAirport.marker.position;
        if (Number.isFinite(latitude) && Number.isFinite(longitude)) {
          map.flyTo([latitude, longitude], Math.max(map.getZoom(), 15), {
            duration: 0.8,
          });
        }
      }
    }),
  []);

  // ── 进近波束与等待航线 ──
  useEffect(() =>
    useMapStore.subscribe((state, previous) => {
      const group = layersRef.current.procedureGroup;
      if (!group) return;
      if (
        state.beamRunwayIdent === previous.beamRunwayIdent &&
        state.selectedAirport === previous.selectedAirport &&
        state.showHoldings === previous.showHoldings &&
        state.holdings === previous.holdings
      ) {
        return;
      }

      group.clearLayers();
      if (state.selectedAirport && state.beamRunwayIdent) {
        renderApproachBeams(group, state.selectedAirport, state.beamRunwayIdent);
      }
      if (state.showHoldings && state.holdings.length > 0) {
        renderHoldings(group, state.holdings);
      }
    }),
  []);

  // ── 限制空域 ──
  useEffect(() =>
    useMapStore.subscribe((state, previous) => {
      const group = layersRef.current.airspaceGroup;
      const map = mapRef.current;
      if (!group || !map) return;
      if (
        state.restrictedZones === previous.restrictedZones &&
        state.showRestrictedAirspace === previous.showRestrictedAirspace
      ) {
        return;
      }

      group.clearLayers();
      if (!state.showRestrictedAirspace) return;

      // 刚打开图层时立刻按当前视野拉一次
      if (!previous.showRestrictedAirspace && state.restrictedZones.length === 0) {
        const bounds = map.getBounds();
        void useMapStore.getState().refreshRestrictedAirspace({
          minLat: bounds.getSouth(),
          maxLat: bounds.getNorth(),
          minLon: bounds.getWest(),
          maxLon: bounds.getEast(),
        });
      }

      for (const zone of state.restrictedZones) {
        if (!zone.center) continue;
        const color = AIRSPACE_SEVERITY_COLOR[zone.category ?? 'advisory'] ?? '#fab219';
        L.circle([zone.center.latitude, zone.center.longitude], {
          radius: zone.radiusM ?? 5000,
          color,
          weight: 2,
          opacity: 0.85,
          fillColor: color,
          fillOpacity: 0.12,
        })
          .bindTooltip(
            [
              zone.name || zone.id,
              zone.lowerAltitudeFt !== undefined && zone.upperAltitudeFt !== undefined
                ? `${zone.lowerAltitudeFt}–${zone.upperAltitudeFt} ft`
                : null,
            ]
              .filter(Boolean)
              .join(' · '),
          )
          .addTo(group);
      }
    }),
  []);

  // ── 航迹 ──
  useEffect(() =>
    useMapStore.subscribe((state, previous) => {
      const map = mapRef.current;
      if (!map) return;
      if (state.route === previous.route && state.showRoute === previous.showRoute) return;

      layersRef.current.route?.remove();
      layersRef.current.route = undefined;
      if (!state.showRoute || state.route.length < 2) return;

      layersRef.current.route = L.polyline(
        state.route.map((point) => [point.latitude, point.longitude] as [number, number]),
        { color: '#2a78d6', weight: 3, opacity: 0.85 },
      ).addTo(map);
    }),
  []);

  // ── 本机 + AI 机 + 起降点 ──
  useEffect(() =>
    useMapStore.subscribe((state, previous) => {
      const map = mapRef.current;
      const aiGroup = layersRef.current.aiGroup;
      const markerGroup = layersRef.current.markerGroup;
      if (!map || !aiGroup || !markerGroup) return;

      // 本机
      if (state.aircraft !== previous.aircraft) {
        const aircraft = state.aircraft;
        if (!aircraft) {
          layersRef.current.aircraft?.remove();
          layersRef.current.aircraft = undefined;
        } else {
          const latlng: [number, number] = [
            aircraft.position.latitude,
            aircraft.position.longitude,
          ];
          const icon = L.divIcon({
            className: '',
            html: aircraftMarkerHtml(aircraft.heading ?? 0, state.activeAlerts[0]?.level),
            iconSize: [34, 34],
            iconAnchor: [17, 17],
          });
          if (layersRef.current.aircraft) {
            layersRef.current.aircraft.setLatLng(latlng).setIcon(icon);
          } else {
            layersRef.current.aircraft = L.marker(latlng, { icon, zIndexOffset: 1000 }).addTo(map);
          }
          if (state.followAircraft) map.panTo(latlng, { animate: true, duration: 0.4 });
        }
      }

      // AI 机
      if (state.aiAircraft !== previous.aiAircraft) {
        aiGroup.clearLayers();
        for (const ai of state.aiAircraft) {
          L.marker([ai.position.latitude, ai.position.longitude], {
            icon: L.divIcon({
              className: '',
              html: aiAircraftMarkerHtml(ai.heading ?? 0, ai.onGround === true),
              iconSize: [20, 20],
              iconAnchor: [10, 10],
            }),
            title: `${ai.id}${ai.type ? ` · ${ai.type}` : ''}`,
          }).addTo(aiGroup);
        }
      }

      // 起降点
      if (
        state.takeoffPoint !== previous.takeoffPoint ||
        state.landingPoint !== previous.landingPoint
      ) {
        markerGroup.clearLayers();
        if (state.takeoffPoint) {
          L.circleMarker([state.takeoffPoint.latitude, state.takeoffPoint.longitude], {
            radius: 6,
            color: '#ffffff',
            weight: 2,
            fillColor: '#0ca30c',
            fillOpacity: 1,
          }).addTo(markerGroup);
        }
        if (state.landingPoint) {
          L.circleMarker([state.landingPoint.latitude, state.landingPoint.longitude], {
            radius: 6,
            color: '#ffffff',
            weight: 2,
            fillColor: '#d03b3b',
            fillOpacity: 1,
          }).addTo(markerGroup);
        }
      }
    }),
  []);

  // ── 滑行道路线 ──
  useEffect(() =>
    useMapStore.subscribe((state, previous) => {
      const group = layersRef.current.taxiwayGroup;
      if (!group) return;
      if (
        state.taxiwayNodes === previous.taxiwayNodes &&
        state.taxiwaySegments === previous.taxiwaySegments &&
        state.showCustomTaxiwayRoute === previous.showCustomTaxiwayRoute &&
        state.isTaxiwayDrawingActive === previous.isTaxiwayDrawingActive &&
        state.completedTaxiwaySegmentIndexes === previous.completedTaxiwaySegmentIndexes
      ) {
        return;
      }

      group.clearLayers();
      if (!state.showCustomTaxiwayRoute || state.taxiwayNodes.length === 0) return;

      // 分段：已完成的用灰色，未完成的用主色
      state.taxiwaySegments.forEach((segment, index) => {
        const from = state.taxiwayNodes[segment.fromIndex];
        const to = state.taxiwayNodes[segment.toIndex];
        if (!from || !to) return;
        const completed = state.completedTaxiwaySegmentIndexes.includes(index);
        L.polyline(
          [
            [from.position.latitude, from.position.longitude],
            [to.position.latitude, to.position.longitude],
          ],
          {
            color: completed ? '#898781' : '#eb6834',
            weight: 4,
            opacity: completed ? 0.5 : 0.95,
            dashArray: completed ? '6 6' : undefined,
          },
        )
          .bindTooltip(
            [segment.name, segment.speedLimitKt ? `${segment.speedLimitKt}kt` : null]
              .filter(Boolean)
              .join(' · ') || `#${index + 1}`,
          )
          .addTo(group);
      });

      // 节点：绘制模式下可拖拽
      state.taxiwayNodes.forEach((node, index) => {
        const marker = L.marker([node.position.latitude, node.position.longitude], {
          draggable: state.isTaxiwayDrawingActive,
          icon: L.divIcon({
            className: '',
            html: taxiwayNodeHtml(index + 1, state.isTaxiwayDrawingActive),
            iconSize: [20, 20],
            iconAnchor: [10, 10],
          }),
          title: node.name ?? `#${index + 1}`,
        }).addTo(group);

        marker.on('dragend', () => {
          const position = marker.getLatLng();
          useMapStore
            .getState()
            .updateTaxiwayNodePosition(index, {
              latitude: position.lat,
              longitude: position.lng,
            });
        });
        // 右键删除节点（对应桌面版的右键菜单）
        marker.on('contextmenu', () => {
          useMapStore.getState().removeTaxiwayNodeAt(index);
        });
      });
    }),
  []);

  return <div ref={containerRef} className="map-canvas" style={{ width: '100%', height: '100%' }} />;
}

// ──────────────────────────────────────────────────────────────────────────
// 标记 HTML（divIcon 内容）
// ──────────────────────────────────────────────────────────────────────────

function aircraftMarkerHtml(heading: number, alertLevel?: 'caution' | 'warning' | 'danger'): string {
  const color = alertLevel ? MAP_ALERT_LEVEL_COLOR[alertLevel] : '#ffffff';
  return `<div style="transform:rotate(${heading}deg);width:34px;height:34px;display:flex;align-items:center;justify-content:center">
    <svg width="30" height="30" viewBox="0 0 24 24" fill="${color}" stroke="#000" stroke-width="0.7">
      <path d="M12 2 L14.2 10.5 L22 13.2 L22 15 L14.2 13.6 L13.4 19.4 L16 21.2 L16 22.4 L12 21.4 L8 22.4 L8 21.2 L10.6 19.4 L9.8 13.6 L2 15 L2 13.2 L9.8 10.5 Z"/>
    </svg>
  </div>`;
}

function aiAircraftMarkerHtml(heading: number, onGround: boolean): string {
  const color = onGround ? '#898781' : '#3987e5';
  return `<div style="transform:rotate(${heading}deg);width:20px;height:20px;display:flex;align-items:center;justify-content:center">
    <svg width="16" height="16" viewBox="0 0 24 24" fill="${color}" stroke="#000" stroke-width="0.8" opacity="0.9">
      <path d="M12 2 L14.2 10.5 L22 13.2 L22 15 L14.2 13.6 L13.4 19.4 L16 21.2 L16 22.4 L12 21.4 L8 22.4 L8 21.2 L10.6 19.4 L9.8 13.6 L2 15 L2 13.2 L9.8 10.5 Z"/>
    </svg>
  </div>`;
}

function airportMarkerHtml(
  airport: MapAirportMarker,
  isHome: boolean,
  strokeColor: string,
): string {
  const size = airport.isPrimary ? 30 : 22;
  const fill = isHome ? '#fab219' : airport.isPrimary ? '#eb6834' : '#199e70';
  const dot = airport.isPrimary ? 9 : 6;
  return `<div style="width:${size}px;height:${size}px;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:1px">
    <span style="width:${dot}px;height:${dot}px;border-radius:50%;background:${fill};border:2px solid ${strokeColor};box-shadow:0 1px 3px rgba(0,0,0,.5)"></span>
    ${
      airport.isPrimary
        ? `<span style="font-size:9px;font-weight:700;color:${strokeColor === '#ffffff' ? '#fff' : '#111'};text-shadow:0 1px 2px rgba(0,0,0,.7);white-space:nowrap">${airport.code}</span>`
        : ''
    }
  </div>`;
}

// ──────────────────────────────────────────────────────────────────────────
// 机场地面结构（跑道 / 滑行道 / 停机坪）
// ──────────────────────────────────────────────────────────────────────────

/** 画地面结构的最低缩放级别；再远这些线会糊成一团 */
const AEROWAY_MIN_ZOOM = 12;

/** 滑行道编号的显示门槛 */
const TAXIWAY_REF_MIN_ZOOM = 14;

/** 一次最多为几个机场拉地面结构：每个都要打一次 Overpass，不能敞开 */
const NEARBY_AEROWAY_LIMIT = 3;

/**
 * 地面要素配色 —— 照真实机场地面标线与标记牌来
 *
 * ── 道面标线 ──
 * 跑道上的标线是**白色**，滑行道与机坪上的标线是**黄色**，这是 ICAO Annex 14
 * 的硬规定，也是飞行员在座舱里唯一的判断依据。所以：
 *   跑道 = 深沥青色道面 + 白色中线
 *   滑行道 = 灰色道面 + 航空黄中线
 * 道面色（而不是纯黑描边）才让线看起来像铺装，浅底图上也压得住。
 *
 * ── 机位引导线 ──
 * 从停机位推出接入滑行道的那段（stand lead-in / taxilane）实际也是黄色，
 * 只是线更窄。这里保持在同一个黄色家族里、压暗一档并收窄，
 * 既没有编出现实中不存在的颜色，又能一眼分出主滑行道和机位引导线。
 */
const AEROWAY_COLORS = {
  /** 跑道沥青道面 */
  runwaySurface: '#24282e',
  /** 跑道标线：白色（Annex 14） */
  runwayCenterline: '#ffffff',
  /** 滑行道道面：混凝土灰 */
  taxiwayCasing: '#3c424b',
  /** 滑行道中线：航空黄 */
  taxiway: '#f0c420',
  /** 机位引导线：同族黄压暗一档 */
  taxilane: '#c9a227',
  apronFill: '#39404b',
  apronStroke: '#525c6b',
  helipad: '#4db7ff',
} as const;

/**
 * 滑行道标记牌配色
 *
 * 真机场的**位置牌**（告诉你「你正在 W1 上」）是：黑底 + 黄字 + 黄边框。
 * 我们这些标签正是位置牌的作用，所以照搬这套配色 ——
 * 既符合飞行员的既有认知，四十来个黑底小牌子也比一片纯黄块耐看得多。
 * （黄底黑字是**方向牌**，用于指路，含义不同，不能混用。）
 */
const TAXIWAY_SIGN = {
  background: '#101215',
  border: '#f0c420',
  text: '#f0c420',
  /** 机位引导线的牌子压暗一档，与道面同步 */
  laneBorder: '#a8862a',
  laneText: '#c9a227',
} as const;

/**
 * 画机场地面结构
 *
 * 数据来自 OSM 的 aeroway 标签，只有跑道、滑行道、停机坪，
 * 天然不含市政道路和商铺 —— 这正是通用底图瓦片做不到的。
 */
function renderAeroway(map: L.Map, group: L.LayerGroup | undefined): void {
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
      .bindTooltip(feature.ref ?? feature.name ?? '', { sticky: true })
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
function renderTaxiwayRefs(
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
function isStandLane(feature: MapAerowayFeature): boolean {
  if (feature.kind === 'taxilane') return true;
  return feature.kind === 'taxiway' && !feature.ref?.trim();
}

/** 要素的包围盒是否与视野相交 */
function intersectsBounds(feature: MapAerowayFeature, bounds: L.LatLngBounds): boolean {
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
function polylineLengthDeg(points: MapCoordinate[]): number {
  let total = 0;
  for (let i = 1; i < points.length; i++) {
    const dLat = points[i].latitude - points[i - 1].latitude;
    const dLon = points[i].longitude - points[i - 1].longitude;
    total += Math.hypot(dLat, dLon);
  }
  return total;
}

// ──────────────────────────────────────────────────────────────────────────
// 视野内机场
// ──────────────────────────────────────────────────────────────────────────

/** 缩放到这一级才开始画视野内的机场 pin，再远就是满屏小点 */
const NEARBY_AIRPORT_MIN_ZOOM = 8;

/** 缩放到这一级才补机场轮廓（要逐个拉机场明细，代价不低） */
const NEARBY_OUTLINE_MIN_ZOOM = 11;

/**
 * 画当前视野内的机场：pin + ICAO + 机场范围
 *
 * 点 pin 走的是和搜索一样的选中流程 —— 拉明细、填底卡、相机飞过去。
 */
function renderNearbyAirports(
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

/** 视野内机场的 pin：一个圆点 + 始终显示的 ICAO */
function nearbyAirportHtml(airport: MapAirportMarker, bright: boolean): string {
  const textColor = bright ? '#111' : '#fff';
  const haloColor = bright ? 'rgba(255,255,255,.85)' : 'rgba(0,0,0,.75)';
  return `<div style="position:absolute;left:0;top:0;transform:translate(-50%,-50%);
    display:flex;flex-direction:column;align-items:center;gap:1px;cursor:pointer;pointer-events:auto">
    <span style="width:8px;height:8px;border-radius:50%;background:#199e70;
      border:2px solid ${bright ? '#1a1a1a' : '#ffffff'};box-shadow:0 1px 3px rgba(0,0,0,.5)"></span>
    <span style="font-size:9px;font-weight:700;letter-spacing:.04em;white-space:nowrap;
      color:${textColor};text-shadow:0 0 3px ${haloColor},0 0 3px ${haloColor}">${escapeHtml(airport.code)}</span>
  </div>`;
}

// ──────────────────────────────────────────────────────────────────────────
// 选中机场细节：轮廓 / 跑道 / 停机位
// ──────────────────────────────────────────────────────────────────────────

/** 跑道端点标签、停机位的显示门槛（与桌面版一致） */
const RUNWAY_LABEL_MIN_ZOOM = 14;

/** 进近设施信息板的门槛：比编号高一级，否则远看一屏全是信息块 */
const RUNWAY_NAVAID_MIN_ZOOM = 15;

/**
 * 标记的叠放层级
 *
 * Leaflet 把同一个 pane 里的标记按**纬度**自动排 z-index（越靠南越上层），
 * 不给 zIndexOffset 的话，一个滑行道编号牌完全可能压在跑道进近信息板上 ——
 * 恰好那块牌子才是进近时最该看清的东西。这里按重要性显式分层。
 *
 * 只有**互相重叠**的标记才需要比较，而重叠意味着纬度几乎相同、
 * 自动 z 值只差几个像素，所以层间留几百的间距已经绰绰有余。
 * 本机图标用的是 1000（见上方 aircraft），保持在最顶层。
 */
const MARKER_Z = {
  /** 滑行道编号牌 */
  taxiwayRef: 300,
  /** 跑道端点 / 进近设施信息板：必须压过滑行道与停机位标签 */
  runwayEndpoint: 900,
} as const;
const PARKING_MIN_ZOOM = 14;
const PARKING_NAME_MIN_ZOOM = 16;

function renderAirportDetail(map: L.Map, group: L.LayerGroup | undefined): void {
  if (!group) return;
  group.clearLayers();

  const state = useMapStore.getState();
  const detail = state.selectedAirport;
  if (!detail) return;

  const zoom = map.getZoom();
  // 以 zoom 15 为基准缩放线宽
  const scale = Math.min(Math.max(2 ** (zoom - 15), 0.5), 2.2);

  // ── 机场轮廓 ──
  const outline = computeAirportOutline(detail);
  if (outline && outline.length >= 3) {
    L.polygon(
      outline.map((point) => [point.latitude, point.longitude] as [number, number]),
      {
        color: '#fab219',
        weight: 2,
        opacity: 0.75,
        dashArray: '8 6',
        fillColor: '#fab219',
        fillOpacity: 0.07,
        interactive: false,
      },
    )
      .bindTooltip(detail.marker.code, { sticky: true })
      .addTo(group);
  }

  if (state.showRunways) {
    // ── 跑道：深色沥青道面 + 白色虚线中线 ──
    //
    // 与滑行道图层里的画法同源（AEROWAY_COLORS），只是改由「跑道」开关控制：
    // 跑道标线按 ICAO Annex 14 是**白色**，道面画成沥青色才像铺装。
    // 原先那种蓝色光晕 + 白芯线只是发光条，既不写实也和滑行道那套对不上。
    for (const runway of detail.runwayGeometries) {
      const path: [number, number][] = [
        [runway.start.latitude, runway.start.longitude],
        [runway.end.latitude, runway.end.longitude],
      ];

      L.polyline(path, {
        color: AEROWAY_COLORS.runwaySurface,
        weight: clamp(14 * scale, 6, 26),
        opacity: 0.95,
        lineCap: 'butt',
        interactive: false,
      }).addTo(group);

      // 中线可点：点一下展开这条跑道两端的进近波束，再点收起
      L.polyline(path, {
        color: AEROWAY_COLORS.runwayCenterline,
        weight: clamp(1.4 * scale, 1, 3),
        opacity: 0.7,
        dashArray: '10 12',
      })
        .bindTooltip(
          [runway.ident, runway.lengthM ? `${Math.round(runway.lengthM)}m` : null]
            .filter(Boolean)
            .join(' · '),
          { sticky: true },
        )
        .on('click', (event) => {
          // 别让点击穿透到地图（绘制模式下会误加滑行道节点）
          L.DomEvent.stopPropagation(event);
          useMapStore.getState().setBeamRunway(runway.ident);
        })
        .addTo(group);

      // 中线太细不好点，叠一条透明的宽线专门接点击
      L.polyline(path, {
        color: '#ffffff',
        opacity: 0,
        weight: clamp(18 * scale, 12, 34),
      })
        .on('click', (event) => {
          L.DomEvent.stopPropagation(event);
          useMapStore.getState().setBeamRunway(runway.ident);
        })
        .addTo(group);
    }

    // ── 跑道端点编号 / 进近设施 ──
    if (zoom >= RUNWAY_LABEL_MIN_ZOOM) {
      // 放大到一定程度就把 CAT 类别、航向台频率、下滑角一并画在入口旁，
      // 跟真实进近图一样，不用再回头去翻卡片
      const withNavaids = zoom >= RUNWAY_NAVAID_MIN_ZOOM && state.showRunwayNavaids;
      for (const runway of detail.runwayGeometries) {
        if (runway.leIdent) {
          addRunwayEndpointLabel(
            group,
            runway.start,
            runway.leIdent,
            withNavaids ? detail.runwayNavaids?.[runway.leIdent.toUpperCase()] : undefined,
            state.showGlideslope,
          );
        }
        if (runway.heIdent) {
          addRunwayEndpointLabel(
            group,
            runway.end,
            runway.heIdent,
            withNavaids ? detail.runwayNavaids?.[runway.heIdent.toUpperCase()] : undefined,
            state.showGlideslope,
          );
        }
      }
    }
  }

  // ── 停机位 ──
  if (state.showParkings && zoom >= PARKING_MIN_ZOOM) {
    const showName = zoom >= PARKING_NAME_MIN_ZOOM;
    for (const spot of detail.parkingSpots) {
      const named = showName && !!spot.name;
      L.marker([spot.position.latitude, spot.position.longitude], {
        icon: L.divIcon({
          // 带名称的标签宽度交给 CSS 按内容自适应（见 .owo-map-autolabel）：
          // 原来按 `name.length * 8` 估宽，短名字白留一截、宽字符又装不下。
          className: named ? 'owo-map-autolabel' : '',
          html: parkingSpotHtml(named ? spot.name : undefined, spot.headingDeg),
          // iconSize 传 undefined，Leaflet 就不会把宽高写死在 style 上
          iconSize: named ? undefined : [16, 16],
          iconAnchor: named ? undefined : [8, 8],
        }),
        title: spot.name,
        interactive: false,
      }).addTo(group);
    }
  }
}

/**
 * 跑道入口标牌
 *
 * 只有编号时是一枚小方牌；带进近设施时展开成一小块信息板，
 * 排布照真实进近图：跑道号 + 类别在上，航向台频率、下滑角在下。
 */
function addRunwayEndpointLabel(
  group: L.LayerGroup,
  position: { latitude: number; longitude: number },
  label: string,
  navaid: MapRunwayNavaid | undefined,
  showGlideslope: boolean,
): void {
  const identChip = `<span style="display:inline-flex;align-items:center;justify-content:center;
    min-width:26px;padding:0 5px;border-radius:3px;
    background:rgba(10,10,10,.88);border:1px solid rgba(255,255,255,.55);
    color:#fff;font-size:10px;font-weight:800;letter-spacing:.04em">${escapeHtml(label)}</span>`;

  if (!navaid?.category) {
    L.marker([position.latitude, position.longitude], {
      icon: L.divIcon({ className: 'owo-map-autolabel', html: centeredBox(identChip) }),
      interactive: false,
      zIndexOffset: MARKER_Z.runwayEndpoint,
    }).addTo(group);
    return;
  }

  const categoryColor = ILS_CATEGORY_MAP_COLOR[navaid.category] ?? '#9aa4b2';
  const rows: string[] = [];

  if (navaid.locFrequency) {
    rows.push(
      `<span style="color:#d7dce4">${escapeHtml(navaid.locIdent ?? 'LOC')}</span>
       <span style="color:#fff;font-weight:700">${escapeHtml(navaid.locFrequency)}</span>` +
        (navaid.locCourse !== undefined
          ? `<span style="color:#98a2b3">${Math.round(navaid.locCourse)}°</span>`
          : ''),
    );
  }
  if (showGlideslope && navaid.glideslopeAngle !== undefined) {
    rows.push(
      `<span style="color:#7fd4ff;font-weight:700">GS ${navaid.glideslopeAngle.toFixed(2)}°</span>` +
        (navaid.hasDme ? `<span style="color:#98a2b3">DME</span>` : ''),
    );
  } else if (navaid.hasDme) {
    rows.push(`<span style="color:#98a2b3">DME</span>`);
  }

  const body = `<div style="display:flex;flex-direction:column;gap:2px;align-items:flex-start;
      padding:3px 5px;border-radius:4px;
      background:rgba(10,12,16,.9);border:1px solid rgba(255,255,255,.28);
      box-shadow:0 1px 4px rgba(0,0,0,.55);white-space:nowrap;font-size:9px;line-height:1.1">
      <div style="display:flex;align-items:center;gap:4px">
        ${identChip}
        <span style="padding:0 4px;border-radius:2px;font-size:8px;font-weight:800;
          color:${categoryColor};border:1px solid ${categoryColor}">${escapeHtml(navaid.category)}</span>
      </div>
      ${rows.map((row) => `<div style="display:flex;gap:4px">${row}</div>`).join('')}
    </div>`;

  L.marker([position.latitude, position.longitude], {
    icon: L.divIcon({ className: 'owo-map-autolabel', html: centeredBox(body) }),
    interactive: false,
    zIndexOffset: MARKER_Z.runwayEndpoint,
  }).addTo(group);
}

/** 包一层零尺寸容器，内容自己居中到锚点（配合 .owo-map-autolabel） */
function centeredBox(inner: string): string {
  return `<div style="position:absolute;left:0;top:0;transform:translate(-50%,-50%);
    display:flex;align-items:center;justify-content:center">${inner}</div>`;
}

/**
 * 进近波束配色
 *
 * 按导航源分色，和进近图上的习惯一致：
 * ILS 用青（无线电波束），GLS 用品红（GBAS/卫星），RNAV 用绿（GNSS）。
 */
const BEAM_STYLE: Record<ApproachBeamKind, { color: string; dash?: string }> = {
  ILS: { color: '#4db7ff' },
  GLS: { color: '#e879f9', dash: '10 6' },
  RNAV: { color: '#35d07f', dash: '6 6' },
};

/**
 * 画选中跑道的进近波束
 *
 * 只画被点开的那条跑道 —— 一次把所有跑道的波束都铺出来会糊成一片。
 * 一条跑道两端各画一束，因为两端的航道、类别、频率都不一样。
 */
function renderApproachBeams(group: L.LayerGroup, detail: MapSelectedAirportDetail, ident: string): void {
  const runway = detail.runwayGeometries.find((item) => item.ident === ident);
  if (!runway) return;

  const ends: { ident: string; threshold: MapCoordinate; far: MapCoordinate }[] = [];
  if (runway.leIdent) ends.push({ ident: runway.leIdent, threshold: runway.start, far: runway.end });
  if (runway.heIdent) ends.push({ ident: runway.heIdent, threshold: runway.end, far: runway.start });

  for (const end of ends) {
    const key = end.ident.toUpperCase();
    const navaid = detail.runwayNavaids?.[key];
    const published = detail.runwayApproaches?.[key] ?? [];

    // 公布了哪几类就画哪几类；都没有时按跑道走向给一条 RNAV 示意
    const kinds: ApproachBeamKind[] = [];
    if (published.includes('ILS') || navaid?.category) kinds.push('ILS');
    if (published.includes('GLS')) kinds.push('GLS');
    if (published.some((type) => type === 'RNAV' || type === 'RNP-AR' || type === 'GPS')) {
      kinds.push('RNAV');
    }
    if (kinds.length === 0) continue;

    // 宽的画在下面，窄的叠在上面，几束重叠时都能看见
    for (const kind of kinds.slice().reverse()) {
      const beam = buildApproachBeam(kind, end.ident, end.threshold, end.far, navaid);
      if (!beam) continue;
      const style = BEAM_STYLE[kind];

      L.polygon(
        beam.polygon.map((point) => [point.latitude, point.longitude] as [number, number]),
        {
          color: style.color,
          weight: 1,
          opacity: 0.55,
          dashArray: style.dash,
          fillColor: style.color,
          fillOpacity: 0.08,
          interactive: false,
        },
      ).addTo(group);

      L.polyline(
        beam.centerline.map((point) => [point.latitude, point.longitude] as [number, number]),
        {
          color: style.color,
          weight: 1.5,
          opacity: 0.85,
          dashArray: style.dash ?? '14 8',
          interactive: false,
        },
      ).addTo(group);

      // 波束末端挂一块标签，写明类型、航道、频率
      addBeamLabel(group, beam.centerline[1], kind, beam, style.color);
    }
  }
}

function addBeamLabel(
  group: L.LayerGroup,
  position: MapCoordinate,
  kind: ApproachBeamKind,
  beam: ReturnType<typeof buildApproachBeam> & object,
  color: string,
): void {
  const navaid = beam.navaid;
  const rows = [
    `${kind} ${beam.runway}`,
    `${Math.round(beam.course)}°${navaid?.locFrequency ? ` · ${navaid.locFrequency}` : ''}`,
    navaid?.glideslopeAngle !== undefined ? `GS ${navaid.glideslopeAngle.toFixed(2)}°` : null,
  ].filter((row): row is string => row !== null);

  L.marker([position.latitude, position.longitude], {
    icon: L.divIcon({
      className: 'owo-map-autolabel',
      html: centeredBox(`<div style="display:flex;flex-direction:column;gap:1px;
        padding:3px 6px;border-radius:4px;
        background:rgba(10,12,16,.9);border:1px solid ${color};
        box-shadow:0 1px 4px rgba(0,0,0,.55);white-space:nowrap;
        font-size:9px;font-weight:700;line-height:1.2;color:${color}">
        ${rows.map((row) => `<div>${escapeHtml(row)}</div>`).join('')}
      </div>`),
    }),
    interactive: false,
    zIndexOffset: MARKER_Z.runwayEndpoint,
  }).addTo(group);
}

/**
 * 画等待航线
 *
 * 画的是**航线本身**（那个跑道形的环圈），不是等待保护区 ——
 * 保护区还要叠风修正和导航容差，比航线大一大圈。
 */
function renderHoldings(group: L.LayerGroup, holdings: readonly MapHoldingPattern[]): void {
  for (const hold of holdings) {
    const geometry = buildHoldingGeometry(hold);
    if (!geometry) continue;

    L.polyline(
      geometry.path.map((point) => [point.latitude, point.longitude] as [number, number]),
      {
        color: HOLDING_COLOR,
        weight: 1.8,
        opacity: 0.9,
        interactive: false,
      },
    ).addTo(group);

    // 定位点画个小菱形，顺带标出入航道与转向
    const altitude =
      hold.minAltitudeFt > 0
        ? `${Math.round(hold.minAltitudeFt)}${hold.maxAltitudeFt > 0 ? `-${Math.round(hold.maxAltitudeFt)}` : '+'} ft`
        : '';
    L.marker([geometry.fixPosition.latitude, geometry.fixPosition.longitude], {
      icon: L.divIcon({
        className: 'owo-map-autolabel',
        html: centeredBox(`<div style="display:flex;align-items:center;gap:4px;
          padding:2px 6px;border-radius:4px;
          background:rgba(10,12,16,.88);border:1px solid ${HOLDING_COLOR};
          color:${HOLDING_COLOR};font-size:9px;font-weight:700;white-space:nowrap">
          <span>${escapeHtml(geometry.fix)}</span>
          <span style="opacity:.75">${Math.round(geometry.inboundCourse)}° ${geometry.turnDirection}</span>
          ${altitude ? `<span style="opacity:.6">${escapeHtml(altitude)}</span>` : ''}
        </div>`),
      }),
      interactive: false,
    }).addTo(group);
  }
}

/** 等待航线配色：进近图上等待航线通常与航路信息同色系 */
const HOLDING_COLOR = '#c084fc';

/** 地图上的 ILS 类别配色，与卡片保持一致 */
const ILS_CATEGORY_MAP_COLOR: Record<string, string> = {
  'CAT I': '#4db7ff',
  'CAT II': '#35d07f',
  'CAT III': '#a78bfa',
  ILS: '#4db7ff',
  LOC: '#9aa4b2',
};

function parkingSpotHtml(name: string | undefined, headingDeg: number | undefined): string {
  // 无名称时只画一个朝向小三角，密集机坪下不至于糊成一片
  if (!name) {
    return `<div style="width:16px;height:16px;display:flex;align-items:center;justify-content:center;
      transform:rotate(${headingDeg ?? 0}deg)">
      <span style="width:0;height:0;border-left:5px solid transparent;border-right:5px solid transparent;
        border-bottom:9px solid rgba(26,158,112,.95);filter:drop-shadow(0 1px 2px rgba(0,0,0,.6))"></span>
    </div>`;
  }
  // 外层零尺寸、内层用 translate(-50%,-50%) 自己居中 ——
  // 这样宽度可以完全由文字决定，不必事先估算（见 .owo-map-autolabel）
  return `<div style="position:absolute;left:0;top:0;transform:translate(-50%,-50%);
    display:flex;align-items:center;gap:3px;padding:2px 6px;border-radius:9px;
    background:rgba(25,158,112,.9);border:1px solid rgba(255,255,255,.5);
    color:#fff;font-size:9px;font-weight:700;white-space:nowrap;
    box-shadow:0 1px 3px rgba(0,0,0,.5)">
    <span style="width:5px;height:5px;border-radius:50%;background:#fff;flex-shrink:0"></span>${escapeHtml(name)}
  </div>`;
}

function clamp(value: number, min: number, max: number): number {
  return Math.min(Math.max(value, min), max);
}

/** 机场名/停机位名来自后端，插进 innerHTML 前必须转义 */
function escapeHtml(text: string): string {
  return text
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

/** 空域严重度配色，与中间件返回的 severity 字段对应 */
const AIRSPACE_SEVERITY_COLOR: Record<string, string> = {
  critical: '#d03b3b',
  warning: '#ec835a',
  advisory: '#fab219',
};

function taxiwayNodeHtml(index: number, draggable: boolean): string {
  return `<div style="width:20px;height:20px;display:flex;align-items:center;justify-content:center;
    border-radius:50%;background:${draggable ? '#eb6834' : 'rgba(235,104,52,.7)'};
    border:2px solid #fff;box-shadow:0 1px 3px rgba(0,0,0,.5);
    font-size:9px;font-weight:700;color:#fff;cursor:${draggable ? 'grab' : 'pointer'}">${index}</div>`;
}
