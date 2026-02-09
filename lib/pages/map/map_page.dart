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
import 'widgets/map_labels.dart';
import 'widgets/map_layer_picker.dart';
import 'widgets/map_right_controls.dart';
import 'widgets/map_top_panel.dart';
import 'widgets/airport_geometry_layers.dart';
import 'widgets/route_layers.dart';

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
  double _scale = 1.0;
  DateTime? _lastMoveUpdate;
  final _weatherRadarTransformer = TileUpdateTransformers.throttle(
    const Duration(milliseconds: 100),
  );

  // 底图地址逻辑见 utils/getTileUrl

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => MapProvider(context.read<SimulatorProvider>()),
      child: Consumer2<SimulatorProvider, MapProvider>(
        builder: (context, simProvider, mapProvider, child) {
          final size = MediaQuery.sizeOf(context);
          _scale = (size.width / 1280).clamp(0.8, 1.4);

          final data = simProvider.simulatorData;
          final aircraftPos = LatLng(data.latitude ?? 0, data.longitude ?? 0);
          final heading = data.heading ?? 0.0;

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
                      subdomains: const ['a', 'b', 'c', 'd'],
                      userAgentPackageName: 'com.owo.flight_assistant',
                    ),

                    if (mapProvider.showWeatherRadar &&
                        mapProvider.weatherRadarTimestamp != null)
                      Opacity(
                        opacity: 0.6,
                        child: TileLayer(
                          urlTemplate:
                              'https://tilecache.rainviewer.com/v2/radar/${mapProvider.weatherRadarTimestamp}/256/{z}/{x}/{y}/4/1_1.png',
                          userAgentPackageName:
                              'com.owo.flight_assistant/1.0 (Radar Layer)',
                          tileUpdateTransformer: _weatherRadarTransformer,
                          maxNativeZoom: 7, // RainViewer 免费版最高支持到 Zoom 7
                          minZoom: 3,
                        ),
                      ),

                    if (airport != null && zoom > 10.5)
                      ...buildAirportGeometryLayers(
                        airports: airportForMapDetails,
                        zoom: zoom,
                        showTaxiways: _showTaxiways,
                        showRunways: _showRunways,
                        showParkings: _showParkings,
                        layerType: _layerType,
                        scale: _scale,
                      ),

                    ...buildRouteLayers(
                      provider: mapProvider,
                      showRouteDistance: _showRouteDistance,
                    ),

                    MarkerLayer(
                      markers: [
                        // Aircraft
                        Marker(
                          point: aircraftPos,
                          width: 80,
                          height: 80,
                          child: Transform.rotate(
                            angle: (heading) * (math.pi / 180),
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
                        // Destination Airport
                        if (mapProvider.destinationAirport != null)
                          Marker(
                            point: getAirportCenter(
                              mapProvider.destinationAirport!,
                            ),
                            width: 60,
                            height: 60,
                            child: AirportPin(
                              icon: Icons.flight_land,
                              color: Colors.purpleAccent,
                              label: 'DEST',
                            ),
                          ),
                        // Alternate Airport
                        if (mapProvider.alternateAirport != null)
                          Marker(
                            point: getAirportCenter(
                              mapProvider.alternateAirport!,
                            ),
                            width: 60,
                            height: 60,
                            child: AirportPin(
                              icon: Icons.directions_outlined,
                              color: Colors.cyanAccent,
                              label: 'ALTN',
                            ),
                          ),
                        // Target (Searched) Airport Center
                        if (mapProvider.targetAirport != null)
                          Marker(
                            point: getAirportCenter(
                              mapProvider.targetAirport!,
                            ),
                            width: 80,
                            height: 80,
                            child: AirportPin(
                              icon: Icons.location_on,
                              color: Colors.redAccent,
                              label: mapProvider.targetAirport!.icaoCode,
                              isBig: true,
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
                  onShowRunwaysChanged: (v) => setState(() => _showRunways = v),
                  onShowTaxiwaysChanged: (v) =>
                      setState(() => _showTaxiways = v),
                  onShowParkingsChanged: (v) =>
                      setState(() => _showParkings = v),
                  onShowRouteDistanceChanged: (v) =>
                      setState(() => _showRouteDistance = v),
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
              ],
            ),
          );
        },
      ),
    );
  }
}
