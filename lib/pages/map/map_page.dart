import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../apps/providers/simulator/simulator_provider.dart';
import '../../apps/providers/map_provider.dart';
import 'models/map_types.dart';
import 'utils/map_utils.dart';
import 'widgets/airport_bottom_console.dart';
import 'widgets/map_layer_picker.dart';
import 'widgets/map_right_controls.dart';
import 'widgets/map_top_panel.dart';
import 'widgets/airport_geometry_layers.dart';
import 'widgets/route_layers.dart';
import 'widgets/danger_overlay.dart';
import 'widgets/crash_overlay.dart';
import 'widgets/map_loading_overlay.dart';
import '../../core/widgets/common/warning_overlay.dart';
import 'widgets/aircraft_compass.dart';
import 'widgets/landing_report_dialog.dart';
import 'widgets/new_flight_prompt_dialog.dart';
import 'widgets/airport_layers/nearby_airports_layer.dart';
import 'widgets/airport_markers_layer.dart';
import '../../apps/services/flight_log_service.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final MapController _mapController = MapController();
  bool _followAircraft = true;
  bool _isMapReady = false;
  MapOrientationMode _orientationMode = MapOrientationMode.northUp;
  MapLayerType _layerType = MapLayerType.dark;
  bool _showParkings = true;
  bool _showTaxiways = true;
  bool _showRunways = true;
  bool _showRouteDistance = false;
  bool _showAircraftCompass = true;
  bool _showNearbyAirports = false; // 新增：显示附近机场图钉
  bool _isFilterExpanded = true;
  double _scale = 1.0;
  DateTime? _lastMoveUpdate;
  final _weatherRadarTransformer = TileUpdateTransformers.throttle(
    const Duration(milliseconds: 100),
  );
  StreamSubscription? _landingSubscription;

  String? _lastFlightPhase;

  @override
  void initState() {
    super.initState();
    _landingSubscription = FlightLogService().landingStream.listen((data) {
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => LandingReportDialog(data: data),
        );
      }
    });
  }

  @override
  void dispose() {
    _landingSubscription?.cancel();
    super.dispose();
  }

  void _updateAutoFilterLogic(SimulatorProvider sim, MapProvider map) {
    if (!sim.isConnected) {
      if (_showAircraftCompass) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() {
            _showAircraftCompass = false;
          });
        });
      }
      _lastFlightPhase = null;
      return;
    }

    final phase = sim.flightPhase;
    if (phase == _lastFlightPhase) return;
    _lastFlightPhase = phase;

    final isFlying = phase != '地面停留' && phase != '起飞中';
    final onGround = phase == '地面停留' || phase == '起飞中';

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        if (isFlying) {
          // 飞行状态：隐藏滑行道、停机位，收起区域
          _showTaxiways = false;
          _showParkings = false;
          _isFilterExpanded = false;
          // 自动勾选气象雷达
          if (!map.showWeatherRadar) {
            map.toggleWeatherRadar();
          }
        } else if (onGround) {
          // 地面状态：自动勾选滑行道、停机位
          _showTaxiways = true;
          _showParkings = true;
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<SimulatorProvider, MapProvider>(
      builder: (context, simProvider, mapProvider, child) {
        final size = MediaQuery.sizeOf(context);
        _scale = (size.width / 1280).clamp(0.8, 1.4);

        final data = simProvider.simulatorData;
        final aircraftPos = LatLng(data.latitude ?? 0, data.longitude ?? 0);
        final heading = data.heading ?? 0.0;

        // 自动过滤逻辑
        _updateAutoFilterLogic(simProvider, mapProvider);

        // 新飞行提示检测逻辑
        if (mapProvider.shouldPromptNewFlight(data)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              NewFlightPromptDialog.show(context, mapProvider);
            }
          });
        }

        // Determine which airport to show info for
        // 逻辑修改：如果有搜索的TargetAirport，则专注于TargetAirport，不自动切换到Center/Current
        final airport =
            mapProvider.targetAirport ??
            mapProvider.centerAirport ??
            mapProvider.currentAirport;

        // 仅当没有搜索目标时，才展示当前飞行相关的辅助信息（跑道/滑行道）
        // 如果正在查看搜索的机场，只显示搜索机场的地图细节
        final airportForMapDetails = mapProvider.targetAirport != null
            ? ([mapProvider.targetAirport!])
            : mapProvider.allDetailedAirports;

        // Handle Map Update safely
        if (_isMapReady && data.latitude != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;

            if (_followAircraft) {
              _mapController.move(aircraftPos, _mapController.camera.zoom);
            }

            if (_orientationMode == MapOrientationMode.trackUp) {
              _mapController.rotate(-heading);
            }
          });
        }

        final isApproach =
            simProvider.flightPhase == '进近中' ||
            ((data.altitude ?? 0) < 5000 &&
                (simProvider.remainingDistance ?? 100) < 25);
        final onGround = data.onGround ?? true;
        final zoom = _isMapReady ? _mapController.camera.zoom : 15.0;
        final tileSubdomains = const ['a', 'b', 'c', 'd'];

        if (!simProvider.isConnected && _isMapReady) {
          final center = _mapController.camera.center;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            mapProvider.updateCenterAirport(
              center.latitude,
              center.longitude,
              zoom: zoom,
            );
          });
        }

        // Danger Detection
        String? dangerMsg;
        String? dangerSub;
        final pitch = data.pitch ?? 0;
        final roll = data.roll ?? 0;
        final g = data.gForce ?? 1.0;

        if (pitch > 25) {
          dangerMsg = 'PITCH HIGH';
          dangerSub = '俯仰角过高';
        } else if (pitch < -15) {
          dangerMsg = 'PITCH LOW';
          dangerSub = '俯仰角过低';
        } else if (roll.abs() > 45) {
          dangerMsg = 'BANK ANGLE';
          dangerSub = '坡度过大';
        } else if (g > 2.5 || g < 0.2) {
          dangerMsg = 'G-LOAD EXCEEDED';
          dangerSub = '过载超出限制';
        }

        final aviationOverlayUrl = getAviationOverlayUrl(_layerType);
        final showAirportDetailTiles =
            aviationOverlayUrl != null &&
            (_layerType == MapLayerType.taxiway ||
                _layerType == MapLayerType.taxiwayDark) &&
            zoom >= 14;

        return Scaffold(
          body: Stack(
            children: [
              // 1. Map Layer
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: aircraftPos,
                  initialZoom: 15,
                  maxZoom: 18,
                  minZoom: 3,
                  onMapReady: () => setState(() => _isMapReady = true),
                  onPositionChanged: (pos, hasGesture) {
                    if (hasGesture) {
                      if (_followAircraft) {
                        setState(() => _followAircraft = false);
                      }

                      // 节流处理，避免缩放动效中触发过多的重绘和数据库查询
                      final now = DateTime.now();
                      if (_lastMoveUpdate == null ||
                          now.difference(_lastMoveUpdate!).inMilliseconds >
                              100) {
                        _lastMoveUpdate = now;
                        mapProvider.updateCenterAirport(
                          pos.center.latitude,
                          pos.center.longitude,
                          zoom: pos.zoom,
                        );
                        setState(() {});
                      }
                    }
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate: getTileUrl(_layerType),
                    subdomains: tileSubdomains,
                    userAgentPackageName: 'com.owo.flight_assistant',
                    tileDisplay: const TileDisplay.fadeIn(),
                  ),
                  if (showAirportDetailTiles)
                    Opacity(
                      opacity: _layerType == MapLayerType.taxiway ? 0.35 : 0.25,
                      child: TileLayer(
                        urlTemplate: aviationOverlayUrl,
                        subdomains: const ['a', 'b', 'c'],
                        userAgentPackageName: 'com.owo.flight_assistant',
                        maxNativeZoom: 19,
                        minZoom: 3,
                        tileDisplay: const TileDisplay.fadeIn(
                          duration: Duration(milliseconds: 300),
                        ),
                        errorTileCallback: (tile, error, stackTrace) {
                          // 静默处理 404 错误，避免影响用户体验
                        },
                      ),
                    ),

                  if (mapProvider.showWeatherRadar &&
                      mapProvider.weatherRadarTimestamp != null)
                    Opacity(
                      opacity: 0.6,
                      child: TileLayer(
                        urlTemplate:
                            'https://tilecache.rainviewer.com/v2/radar/${mapProvider.weatherRadarTimestamp}/256/{z}/{x}/{y}/4/1_1.png',
                        userAgentPackageName: 'com.owo.flight_assistant',
                        tileUpdateTransformer: _weatherRadarTransformer,
                        maxNativeZoom: 7, // RainViewer 免费版最高支持到 Zoom 7
                        minZoom: 3,
                      ),
                    ),

                  if (airportForMapDetails.isNotEmpty && zoom > 10.5)
                    ...buildAirportGeometryLayers(
                      airports: airportForMapDetails,
                      zoom: zoom,
                      showTaxiways: _showTaxiways,
                      showRunways: _showRunways,
                      showParkings: _showParkings,
                      layerType: _layerType,
                      scale: _scale,
                    ),

                  // 附近机场图钉图层
                  if (_showNearbyAirports && _isMapReady && zoom > 8)
                    NearbyAirportsLayer(
                      minLat: _mapController.camera.visibleBounds.south,
                      maxLat: _mapController.camera.visibleBounds.north,
                      minLon: _mapController.camera.visibleBounds.west,
                      maxLon: _mapController.camera.visibleBounds.east,
                      scale: _scale,
                      zoom: zoom,
                      mapProvider: mapProvider,
                      excludeIcaoCodes: {
                        if (mapProvider.currentAirport != null)
                          mapProvider.currentAirport!.icaoCode,
                        if (mapProvider.destinationAirport != null)
                          mapProvider.destinationAirport!.icaoCode,
                        if (mapProvider.alternateAirport != null)
                          mapProvider.alternateAirport!.icaoCode,
                        if (mapProvider.targetAirport != null)
                          mapProvider.targetAirport!.icaoCode,
                        if (mapProvider.departureAirport != null)
                          mapProvider.departureAirport!.icaoCode,
                      },
                    ),

                  ...buildRouteLayers(
                    provider: mapProvider,
                    showRouteDistance: _showRouteDistance,
                  ),

                  // 机场标记图层（使用组件化）
                  AirportMarkersLayer(mapProvider: mapProvider, scale: _scale),

                  MarkerLayer(
                    rotate: false,
                    markers: [
                      // Compass
                      if (_showAircraftCompass && simProvider.isConnected)
                        Marker(
                          point: aircraftPos,
                          width: 200 * _scale,
                          height: 200 * _scale,
                          child: AircraftCompass(
                            heading: heading,
                            scale: _scale,
                            mapRotation: _isMapReady
                                ? _mapController.camera.rotation
                                : 0,
                          ),
                        ),
                      // Aircraft
                      Marker(
                        point: aircraftPos,
                        width: 80,
                        height: 80,
                        child: Transform.rotate(
                          angle:
                              (heading +
                                  (_isMapReady
                                      ? _mapController.camera.rotation
                                      : 0)) *
                              (math.pi / 180),
                          child: const Icon(
                            Icons.flight,
                            color: Colors.orangeAccent,
                            size: 44,
                            shadows: [
                              Shadow(color: Colors.black, blurRadius: 15),
                            ],
                          ),
                        ),
                      ),

                      // Takeoff Point
                      if (mapProvider.takeoffPoint != null)
                        Marker(
                          point: mapProvider.takeoffPoint!,
                          width: 80,
                          height: 80,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blueAccent.withValues(
                                    alpha: 0.9,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'TAKEOFF',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.flight_takeoff,
                                color: Colors.blueAccent,
                                size: 36,
                              ),
                            ],
                          ),
                        ),

                      // Landing Point
                      if (mapProvider.landingPoint != null)
                        Marker(
                          point: mapProvider.landingPoint!,
                          width: 80,
                          height: 80,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.greenAccent.withValues(
                                    alpha: 0.9,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'LANDING',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.flight_land,
                                color: Colors.greenAccent,
                                size: 36,
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),

              // 2. HUD Panels
              MapTopPanel(
                scale: _scale,
                mapController: _mapController,
                sim: simProvider,
                mapProvider: mapProvider,
                followAircraft: _followAircraft,
                onFollowAircraftChanged: (v) =>
                    setState(() => _followAircraft = v),
                showRunways: _showRunways,
                showTaxiways: _showTaxiways,
                showParkings: _showParkings,
                showRouteDistance: _showRouteDistance,
                showAircraftCompass: _showAircraftCompass,
                showNearbyAirports: _showNearbyAirports,
                onShowRunwaysChanged: (v) => setState(() => _showRunways = v),
                onShowTaxiwaysChanged: (v) => setState(() => _showTaxiways = v),
                onShowParkingsChanged: (v) => setState(() => _showParkings = v),
                onShowRouteDistanceChanged: (v) =>
                    setState(() => _showRouteDistance = v),
                onShowAircraftCompassChanged: (v) =>
                    setState(() => _showAircraftCompass = v),
                onShowNearbyAirportsChanged: (v) =>
                    setState(() => _showNearbyAirports = v),
                isFilterExpanded: _isFilterExpanded,
                onFilterExpandedChanged: (v) =>
                    setState(() => _isFilterExpanded = v),
              ),
              MapRightControls(
                scale: _scale,
                mapController: _mapController,
                followAircraft: _followAircraft,
                onFollowAircraftChanged: (v) =>
                    setState(() => _followAircraft = v),
                orientationMode: _orientationMode,
                onOrientationChanged: (m) =>
                    setState(() => _orientationMode = m),
                onShowLayerPicker: () => MapLayerPicker.show(
                  context,
                  current: _layerType,
                  onSelected: (t) => setState(() => _layerType = t),
                ),
                isMapReady: _isMapReady,
                isConnected: simProvider.isConnected,
              ),
              AirportBottomConsole(
                scale: _scale,
                airport: airport,
                onGround: onGround,
                compact: !(isApproach || onGround),
              ),

              if (dangerMsg != null)
                DangerOverlay(message: dangerMsg, subMessage: dangerSub!),

              WarningOverlay(
                isStall: data.isStall ?? false,
                isOverspeed: data.isOverspeed ?? false,
              ),

              if (simProvider.showCrashOverlay)
                Positioned.fill(
                  child: CrashOverlay(
                    onDismiss: () => simProvider.dismissCrashOverlay(),
                  ),
                ),

              MapLoadingOverlay(isLoading: mapProvider.isLoadingAirport),
            ],
          ),
        );
      },
    );
  }
}
