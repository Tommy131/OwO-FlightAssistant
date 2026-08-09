import { useEffect, useRef } from 'react';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';
import {
  isBrightMapBackground,
  mapReferenceOverlayUrl,
  mapTileAttribution,
  mapTileMaxNativeZoom,
  mapTileUrl,
  type MapAirportMarker,
  type MapCoordinate,
  type MapProcedure,
  type MapRoutePoint,
} from '../models/map-models';
import {
  useMapStore,
  weatherOverlayTileUrl,
  weatherRadarTileUrl,
} from '../providers/map-store';
import { escapeHtml } from '../../../core/utils/escape-html';
import {
  aiAircraftMarkerHtml,
  aircraftMarkerHtml,
  airportMarkerHtml,
  taxiwayNodeHtml,
} from '../services/map-marker-html';
// 各图层的绘制逻辑按职责拆到 layers/ 下，本文件只负责「什么时候画」
import { AEROWAY_MIN_ZOOM, renderAeroway } from './layers/aeroway-layer';
import {
  NEARBY_AIRPORT_MIN_ZOOM,
  NEARBY_OUTLINE_MIN_ZOOM,
  renderNearbyAirports,
} from './layers/nearby-airports-layer';
import {
  renderAirportDetail,
  renderApproachBeams,
  renderHoldings,
} from './layers/airport-detail-layer';
import { usePlannedRouteStore } from '../../common/providers/planned-route-store';
import { renderPlannedRoute } from './layers/planned-route-layer';
import { procedureKey, renderProcedure } from './layers/procedure-layer';
import { renderTaxiRoute } from './layers/taxi-route-layer';
import { AIRSPACE_SEVERITY_COLOR } from './layers/layer-style';

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

/**
 * 单段航迹的点数上限
 *
 * 航迹本身不限长，但 Leaflet 每次 addLatLng 都会把所在 polyline 的全部点
 * 重新投影一遍。分段之后，每帧的重投影量就被钉死在这个数以内，与总长无关。
 * 取 500：段太小则 polyline 对象过多，太大则单帧开销回升。
 */
const ROUTE_SEGMENT_POINTS = 500;

const ROUTE_STYLE = { color: '#2a78d6', weight: 3, opacity: 0.85 } as const;

/** 建一段航迹线 */
function newRouteSegment(points: readonly MapRoutePoint[]): L.Polyline {
  return L.polyline(
    points.map((point) => [point.latitude, point.longitude] as [number, number]),
    ROUTE_STYLE,
  );
}

/** 滑行路线两端的标签：起点固定，终点优先显示 hold short 的跑道号 */
function taxiLabelsOf(state: { taxiPlan: { holdShort?: string } | null }): {
  start: string;
  end: string;
} {
  return { start: 'START', end: state.taxiPlan?.holdShort ?? 'END' };
}

/** 从 store 状态里取出当前选中的程序 */
function selectedProcedureOf(state: {
  procedures: readonly MapProcedure[];
  selectedProcedureKey: string | null;
}): MapProcedure | null {
  if (!state.selectedProcedureKey) return null;
  return (
    state.procedures.find((item) => procedureKey(item) === state.selectedProcedureKey) ?? null
  );
}

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
  /** 航迹渲染进度：分段句柄 + 已画点数（靠首元素引用判断是不是同一条航迹） */
  const routeRenderedRef = useRef<{
    segments: L.Polyline[];
    count: number;
    head?: MapRoutePoint;
  }>({ segments: [], count: 0 });

  const layersRef = useRef<{
    base?: L.TileLayer;
    reference?: L.TileLayer;
    radar?: L.TileLayer;
    overlays: Partial<Record<'rain' | 'pressure' | 'wind' | 'temp', L.TileLayer>>;
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
    plannedGroup?: L.LayerGroup;
    procedureLayerGroup?: L.LayerGroup;
    taxiRouteGroup?: L.LayerGroup;
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
    // 计划航路：压在实际航迹之下，两者同屏时以实际航迹为主
    layersRef.current.plannedGroup = L.layerGroup().addTo(map);
    // 公布程序：与计划航路同层级，配色已刻意错开
    layersRef.current.procedureLayerGroup = L.layerGroup().addTo(map);
    // 滑行引导：压在标记之下，但要盖住地面结构，否则在机坪上看不清走向
    layersRef.current.taxiRouteGroup = L.layerGroup().addTo(map);
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
      renderPlannedRoute(
        map,
        layersRef.current.plannedGroup,
        usePlannedRouteStore.getState().plan,
        useMapStore.getState().showPlannedRoute,
      );
      const mapState = useMapStore.getState();
      renderProcedure(
        map,
        layersRef.current.procedureLayerGroup,
        selectedProcedureOf(mapState),
        mapState.showProcedures,
      );
      // 滑行路线两端的标签也按缩放级别显隐
      renderTaxiRoute(
        map,
        layersRef.current.taxiRouteGroup,
        mapState.taxiPlan?.points ?? null,
        mapState.showTaxiGuidance,
        taxiLabelsOf(mapState),
      );
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
      // map.remove() 已经销毁了所有图层，这里必须一并丢掉航迹分段的句柄，
      // 否则重新挂载时会拿着一堆失效的 polyline 继续往里 addLatLng
      routeRenderedRef.current = { segments: [], count: 0 };
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
        // 上一次 flyTo 还在飞的时候再次选中，getZoom() 会返回 NaN，
        // Math.max(NaN, 15) 仍是 NaN，Leaflet 随即抛 "Invalid LatLng object"。
        // 而这里是 Zustand 订阅回调 —— 一抛异常，**排在后面的订阅者全部收不到通知**
        // （包括各面板的 React 订阅），表现为「地图动了但底卡不出来」。
        const currentZoom = map.getZoom();
        const targetZoom = Number.isFinite(currentZoom) ? Math.max(currentZoom, 15) : 15;
        if (Number.isFinite(latitude) && Number.isFinite(longitude)) {
          map.flyTo([latitude, longitude], targetZoom, { duration: 0.8 });
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
              escapeHtml(zone.name || zone.id),
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

  // ── 滑行引导 ──
  useEffect(() =>
    useMapStore.subscribe((state, previous) => {
      const map = mapRef.current;
      if (!map) return;
      if (
        state.taxiPlan === previous.taxiPlan &&
        state.showTaxiGuidance === previous.showTaxiGuidance
      ) {
        return;
      }
      renderTaxiRoute(
        map,
        layersRef.current.taxiRouteGroup,
        state.taxiPlan?.points ?? null,
        state.showTaxiGuidance,
        taxiLabelsOf(state),
      );
      // 地面结构要跟着改弱化状态：有路线时压暗，清掉后恢复
      renderAeroway(map, layersRef.current.aerowayGroup);
    }),
  []);

  // ── 公布程序（SID/STAR/进近）──
  useEffect(() =>
    useMapStore.subscribe((state, previous) => {
      const map = mapRef.current;
      if (!map) return;
      if (
        state.procedures === previous.procedures &&
        state.selectedProcedureKey === previous.selectedProcedureKey &&
        state.showProcedures === previous.showProcedures
      ) {
        return;
      }
      renderProcedure(
        map,
        layersRef.current.procedureLayerGroup,
        selectedProcedureOf(state),
        state.showProcedures,
      );
    }),
  []);

  // ── 计划航路（SimBrief 导入）──
  //
  // 航路数据在 common store（简报也要用），是否显示在 map store，
  // 所以这里要订阅两处
  useEffect(() => {
    const redraw = () => {
      const map = mapRef.current;
      if (!map) return;
      renderPlannedRoute(
        map,
        layersRef.current.plannedGroup,
        usePlannedRouteStore.getState().plan,
        useMapStore.getState().showPlannedRoute,
      );
    };
    const unsubscribePlan = usePlannedRouteStore.subscribe((state, previous) => {
      if (state.plan !== previous.plan) redraw();
    });
    const unsubscribeToggle = useMapStore.subscribe((state, previous) => {
      if (state.showPlannedRoute !== previous.showPlannedRoute) redraw();
    });
    return () => {
      unsubscribePlan();
      unsubscribeToggle();
    };
  }, []);

  // ── 航迹 ──
  useEffect(() =>
    useMapStore.subscribe((state, previous) => {
      const map = mapRef.current;
      if (!map) return;
      if (state.route === previous.route && state.showRoute === previous.showRoute) return;

      const rendered = routeRenderedRef.current;

      if (!state.showRoute || state.route.length < 2) {
        for (const segment of rendered.segments) segment.remove();
        routeRenderedRef.current = { segments: [], count: 0, head: undefined };
        return;
      }

      // 航迹没有点数上限，一次长航线能到十万点级别。这里不能整条重建 ——
      // 那是 O(n) per tick，会把 UI 拖死，也违反 NFR-3。
      //
      // 但**只把新点 addLatLng 进去同样是 O(n)**：Leaflet 的 addLatLng 内部会
      // 调 redraw()，把整条线的所有点重新投影一遍。实测 6000 点时单帧渲染开销
      // 从 0.08ms 一路涨到 0.93ms，跟整条重建没有区别。
      //
      // 真正有效的办法是**分段**：写满的段就此冻结、再也不碰，只有末尾这一段
      // 在长。于是每帧的重投影量被钉死在 ROUTE_SEGMENT_POINTS 以内，与航迹
      // 总长无关。相邻段共用一个点，接缝处才不会断开。
      const sameTrack =
        rendered.count > 0 &&
        state.route.length >= rendered.count &&
        state.route[0] === rendered.head;

      if (!sameTrack) {
        // 清空 / 重连 / 载入别的航迹：整条重画（只发生一次，不在热路径上）
        for (const segment of rendered.segments) segment.remove();
        const segments: L.Polyline[] = [];
        for (let start = 0; start < state.route.length - 1; start += ROUTE_SEGMENT_POINTS - 1) {
          const chunk = state.route.slice(start, start + ROUTE_SEGMENT_POINTS);
          segments.push(newRouteSegment(chunk).addTo(map));
        }
        routeRenderedRef.current = {
          segments,
          count: state.route.length,
          head: state.route[0],
        };
        return;
      }

      // 同一条航迹在生长：只往末段追加；末段写满就冻结它、另起一段
      const segments = rendered.segments;
      for (let i = rendered.count; i < state.route.length; i++) {
        const active = segments[segments.length - 1];
        const point = state.route[i];
        if (!active || active.getLatLngs().length >= ROUTE_SEGMENT_POINTS) {
          // 新段从上一段的末点起头，避免接缝断开
          const previousPoint = state.route[i - 1];
          const seed = previousPoint ? [previousPoint, point] : [point];
          segments.push(newRouteSegment(seed).addTo(map));
        } else {
          active.addLatLng([point.latitude, point.longitude]);
        }
      }
      routeRenderedRef.current = { segments, count: state.route.length, head: state.route[0] };
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
            [segment.name ? escapeHtml(segment.name) : null, segment.speedLimitKt ? `${segment.speedLimitKt}kt` : null]
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
// 机场地面结构（跑道 / 滑行道 / 停机坪）
// ──────────────────────────────────────────────────────────────────────────



/** 一次最多为几个机场拉地面结构：每个都要打一次 Overpass，不能敞开 */
const NEARBY_AEROWAY_LIMIT = 3;




















/** 机场名/停机位名来自后端，插进 innerHTML 前必须转义 */

