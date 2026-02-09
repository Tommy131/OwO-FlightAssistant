import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../apps/providers/simulator/simulator_provider.dart';
import '../../apps/models/airport_detail_data.dart';
import '../../apps/providers/map_provider.dart';

enum MapOrientationMode { northUp, trackUp }

enum MapLayerType { dark, satellite, street, terrain }

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
  double _scale = 1.0;

  String _getTileUrl(MapLayerType type) {
    switch (type) {
      case MapLayerType.satellite:
        // Esri World Imagery - Reliable Satellite Source
        return 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
      case MapLayerType.street:
        // MapTiler / Stadia / Carto Voyager are better than raw OSM for usage policies,
        // using Carto Voyager here as it's more permissive for light app usage
        return 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png';
      case MapLayerType.terrain:
        // Esri World Topo Map - Good for terrain
        return 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Topo_Map/MapServer/tile/{z}/{y}/{x}';
      case MapLayerType.dark:
        return 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png';
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => MapProvider(context.read<SimulatorProvider>()),
      child: Consumer2<SimulatorProvider, MapProvider>(
        builder: (context, simProvider, mapProvider, child) {
          final size = MediaQuery.sizeOf(context);
          _scale = (size.width / 1280).clamp(0.8, 1.4);

          final data = simProvider.simulatorData;
          final airport = mapProvider.currentAirport;
          final aircraftPos = LatLng(data.latitude ?? 0, data.longitude ?? 0);
          final heading = data.heading ?? 0.0;

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
                        if (_followAircraft)
                          setState(() => _followAircraft = false);
                        setState(() {});
                      }
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: _getTileUrl(_layerType),
                      subdomains: const ['a', 'b', 'c', 'd'],
                      userAgentPackageName: 'com.owo.flight_assistant',
                    ),

                    if (airport != null) ...[
                      // Taxiways
                      PolylineLayer(
                        polylines: airport.taxiways
                            .where((t) => t.points.isNotEmpty)
                            .map(
                              (t) => Polyline(
                                points: t.points
                                    .map((p) => LatLng(p.latitude, p.longitude))
                                    .toList(),
                                color: _layerType == MapLayerType.satellite
                                    ? Colors.yellowAccent.withValues(alpha: 0.5)
                                    : Colors.blueGrey.withValues(alpha: 0.3),
                                strokeWidth: 3,
                              ),
                            )
                            .toList(),
                      ),
                      // Runways
                      PolylineLayer(
                        polylines: airport.runways
                            .where((r) => r.leLat != null && r.leLon != null)
                            .map(
                              (r) => Polyline(
                                points: [
                                  LatLng(r.leLat!, r.leLon!),
                                  LatLng(r.heLat!, r.heLon!),
                                ],
                                color: Colors.white.withValues(alpha: 0.7),
                                strokeWidth: 10,
                              ),
                            )
                            .toList(),
                      ),

                      // Runway Threshold Identifiers
                      if (zoom > 13)
                        MarkerLayer(
                          markers: airport.runways.expand((r) {
                            final markers = <Marker>[];
                            if (r.leLat != null &&
                                r.leLon != null &&
                                r.leIdent != null) {
                              markers.add(
                                Marker(
                                  point: LatLng(r.leLat!, r.leLon!),
                                  width: 50,
                                  height: 50,
                                  child: _buildMapLabel(
                                    r.leIdent!,
                                    Colors.white,
                                    Colors.black87,
                                  ),
                                ),
                              );
                            }
                            if (r.heLat != null &&
                                r.heLon != null &&
                                r.heIdent != null) {
                              markers.add(
                                Marker(
                                  point: LatLng(r.heLat!, r.heLon!),
                                  width: 50,
                                  height: 50,
                                  child: _buildMapLabel(
                                    r.heIdent!,
                                    Colors.white,
                                    Colors.black87,
                                  ),
                                ),
                              );
                            }
                            return markers;
                          }).toList(),
                        ),

                      // Parking Spots / Apron Numbers
                      if (zoom > 14.5 && _showParkings)
                        MarkerLayer(
                          markers: airport.parkings
                              .map(
                                (p) => Marker(
                                  point: LatLng(p.latitude, p.longitude),
                                  width: 80,
                                  height: 80,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          // Highlight glow
                                          Container(
                                            width: 12,
                                            height: 12,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: Colors.orangeAccent
                                                  .withValues(alpha: 0.3),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.orangeAccent
                                                      .withValues(alpha: 0.4),
                                                  blurRadius: 8,
                                                  spreadRadius: 2,
                                                ),
                                              ],
                                            ),
                                          ),
                                          Icon(
                                            Icons.circle,
                                            size: 6,
                                            color: Colors.orangeAccent
                                                .withValues(alpha: 0.9),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      _buildMapLabel(
                                        p.name,
                                        Colors.orangeAccent,
                                        Colors.black.withValues(alpha: 0.8),
                                        fontSize: 9 * _scale,
                                      ),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                    ],

                    if (mapProvider.path.isNotEmpty)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: mapProvider.path,
                            color: Colors.orangeAccent.withValues(alpha: 0.7),
                            strokeWidth: 2,
                          ),
                        ],
                      ),

                    MarkerLayer(
                      markers: [
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
                      ],
                    ),
                  ],
                ),

                // 2. HUD Panels
                _buildTopPanel(simProvider, airport),
                _buildRightControls(),
                if (isApproach || onGround)
                  _buildBottomConsole(simProvider, airport, onGround)
                else
                  _buildShortBottom(simProvider, airport),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMapLabel(
    String text,
    Color textColor,
    Color bgColor, {
    double fontSize = 10,
  }) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: textColor.withValues(alpha: 0.4), width: 1),
          boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 4)],
        ),
        child: Text(
          text,
          style: TextStyle(
            color: textColor,
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildTopPanel(SimulatorProvider sim, AirportDetailData? airport) {
    final data = sim.simulatorData;
    return Positioned(
      top: 20 * _scale,
      left: 20 * _scale,
      right: 20 * _scale,
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16 * _scale),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 20 * _scale,
                  vertical: 12 * _scale,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildValue(
                      'GS',
                      '${(data.groundSpeed ?? 0).round()}',
                      'kt',
                    ),
                    _buildValue('ALT', '${(data.altitude ?? 0).round()}', 'ft'),
                    _buildValue('HDG', '${(data.heading ?? 0).round()}°', ''),
                    _buildValue(
                      'VS',
                      '${(data.verticalSpeed ?? 0).round()}',
                      'fpm',
                      color: (data.verticalSpeed ?? 0).abs() > 800
                          ? Colors.redAccent
                          : Colors.tealAccent,
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: 8 * _scale),
          if (data.baroPressure != null || data.windSpeed != null)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildChip(
                    Icons.air,
                    '${(data.windSpeed ?? 0).round()} kt / ${(data.windDirection ?? 0).round()}°',
                  ),
                  SizedBox(width: 8 * _scale),
                  _buildChip(
                    Icons.cloud_outlined,
                    '${data.baroPressure?.toStringAsFixed(2)} ${data.baroPressureUnit}',
                  ),
                  if (data.outsideAirTemperature != null) ...[
                    SizedBox(width: 8 * _scale),
                    _buildChip(
                      Icons.thermostat,
                      '${data.outsideAirTemperature?.toStringAsFixed(1)}°C',
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildChip(IconData icon, String label) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 10 * _scale,
        vertical: 4 * _scale,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(8 * _scale),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white54, size: 12 * _scale),
          SizedBox(width: 4 * _scale),
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 11 * _scale,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildValue(String label, String val, String unit, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white54,
            fontSize: 10 * _scale,
            fontWeight: FontWeight.bold,
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              val,
              style: TextStyle(
                color: color ?? Colors.white,
                fontSize: 20 * _scale,
                fontWeight: FontWeight.w900,
                fontFamily: 'monospace',
              ),
            ),
            SizedBox(width: 2 * _scale),
            Text(
              unit,
              style: TextStyle(color: Colors.white38, fontSize: 9 * _scale),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRightControls() {
    return Positioned(
      right: 20,
      bottom: 250,
      child: Column(
        children: [
          _buildMapBtn(
            icon: Icons.layers_outlined,
            onPressed: _showLayerPicker,
            tooltip: '地图图层',
          ),
          const SizedBox(height: 12),
          Consumer<MapProvider>(
            builder: (context, provider, _) => _buildMapBtn(
              icon: provider.isLoadingAirport ? Icons.sync : Icons.refresh,
              onPressed: () => provider.refreshAirport(),
              highlight: provider.isLoadingAirport,
              tooltip: '刷新机场数据',
            ),
          ),
          const SizedBox(height: 12),
          _buildMapBtn(
            icon: _showParkings
                ? Icons.local_parking
                : Icons.local_parking_outlined,
            onPressed: () => setState(() => _showParkings = !_showParkings),
            highlight: _showParkings,
            tooltip: '显示停机位',
          ),
          const SizedBox(height: 12),
          _buildMapBtn(
            icon: _followAircraft ? Icons.gps_fixed : Icons.gps_not_fixed,
            onPressed: () => setState(() => _followAircraft = !_followAircraft),
            highlight: _followAircraft,
            tooltip: '追随飞机',
          ),
          const SizedBox(height: 12),
          _buildMapBtn(
            icon: _orientationMode == MapOrientationMode.northUp
                ? Icons.explore_outlined
                : Icons.navigation_outlined,
            onPressed: () {
              setState(() {
                if (_orientationMode == MapOrientationMode.northUp) {
                  _orientationMode = MapOrientationMode.trackUp;
                } else {
                  _orientationMode = MapOrientationMode.northUp;
                  _mapController.rotate(0);
                }
              });
            },
            highlight: _orientationMode == MapOrientationMode.trackUp,
            tooltip: _orientationMode == MapOrientationMode.northUp
                ? '北向上'
                : '航向向上',
          ),
          const SizedBox(height: 12),
          _buildMapBtn(
            icon: Icons.add,
            onPressed: () => _mapController.move(
              _mapController.camera.center,
              _mapController.camera.zoom + 1,
            ),
          ),
          const SizedBox(height: 12),
          _buildMapBtn(
            icon: Icons.remove,
            onPressed: () => _mapController.move(
              _mapController.camera.center,
              _mapController.camera.zoom - 1,
            ),
          ),
          const SizedBox(height: 12),
          if (_isMapReady)
            GestureDetector(
              onTap: () {
                _mapController.rotate(0);
                setState(() => _orientationMode = MapOrientationMode.northUp);
              },
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24),
                ),
                child: Center(
                  child: Transform.rotate(
                    angle: _mapController.camera.rotation * (math.pi / 180),
                    child: const Icon(
                      Icons.north,
                      color: Colors.orangeAccent,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showLayerPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.95),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '选择地图图层',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildLayerOption(MapLayerType.dark, '暗色', Icons.dark_mode),
                  const SizedBox(width: 16),
                  _buildLayerOption(
                    MapLayerType.satellite,
                    '卫星',
                    Icons.satellite_alt,
                  ),
                  const SizedBox(width: 16),
                  _buildLayerOption(MapLayerType.street, '街道', Icons.map),
                  const SizedBox(width: 16),
                  _buildLayerOption(
                    MapLayerType.terrain,
                    '地形',
                    Icons.landscape,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildLayerOption(MapLayerType type, String label, IconData icon) {
    final isSelected = _layerType == type;
    return GestureDetector(
      onTap: () {
        setState(() => _layerType = type);
        Navigator.pop(context);
      },
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.orangeAccent
                  : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? Colors.white : Colors.white12,
                width: 2,
              ),
            ),
            child: Icon(
              icon,
              color: isSelected ? Colors.black : Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.orangeAccent : Colors.white70,
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapBtn({
    required IconData icon,
    required VoidCallback onPressed,
    bool highlight = false,
    String? tooltip,
  }) {
    final btnSize = 48.0 * _scale;
    return Container(
      width: btnSize,
      height: btnSize,
      decoration: BoxDecoration(
        color: highlight
            ? Colors.orangeAccent
            : Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12 * _scale),
        border: Border.all(color: Colors.white10),
      ),
      child: IconButton(
        icon: Icon(
          icon,
          color: highlight ? Colors.black : Colors.white,
          size: 20 * _scale,
        ),
        onPressed: onPressed,
        tooltip: tooltip,
      ),
    );
  }

  Widget _buildBottomConsole(
    SimulatorProvider sim,
    AirportDetailData? airport,
    bool onGround,
  ) {
    final rwy = airport?.runways.isNotEmpty == true
        ? airport!.runways.first
        : null;

    return Positioned(
      bottom: 24 * _scale,
      left: 24 * _scale,
      right: 24 * _scale,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24 * _scale),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: EdgeInsets.all(20 * _scale),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.8),
              border: Border.all(
                color: Colors.orangeAccent.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            airport?.icaoCode ?? 'TRANSIT',
                            style: const TextStyle(
                              color: Colors.orangeAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              letterSpacing: 2,
                            ),
                          ),
                          Text(
                            airport?.name ?? 'Flying in Open Air',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (rwy != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'RWY ${rwy.ident}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
                if (!onGround) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 80,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: _buildApproachChart(sim),
                          ),
                        ),
                        const SizedBox(width: 16),
                        _buildGlideSlopeIndicator(sim),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShortBottom(SimulatorProvider sim, AirportDetailData? airport) {
    return Positioned(
      bottom: 24,
      left: 24,
      right: 24,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              airport?.icaoCode ?? 'ENROUTE',
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            Text(
              '${sim.remainingDistance?.toStringAsFixed(1) ?? '--'} NM TO DEST',
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApproachChart(SimulatorProvider sim) {
    return CustomPaint(
      painter: ApproachProfilePainter(
        altitude: sim.simulatorData.altitude ?? 0,
        distToRwy: (sim.remainingDistance ?? 0) * 1.852, // km
      ),
    );
  }

  Widget _buildGlideSlopeIndicator(SimulatorProvider sim) {
    final distM = (sim.remainingDistance ?? 0) * 1852;
    final targetAlt = distM * math.tan(3 * math.pi / 180);
    final diff = (sim.simulatorData.altitude ?? 0) - targetAlt;
    final dev = (diff / 200).clamp(-1.0, 1.0);

    return Column(
      children: [
        const Text(
          'G/S',
          style: TextStyle(
            color: Colors.white38,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: Container(
            width: 24,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                for (int i = -2; i <= 2; i++)
                  if (i != 0)
                    Positioned(
                      top: 40 + (i * 15.0) - 1,
                      child: Container(
                        width: 4,
                        height: 1,
                        color: Colors.white24,
                      ),
                    ),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white38, width: 1),
                    shape: BoxShape.circle,
                  ),
                ),
                Positioned(
                  bottom: 40 - (dev * 30) - 5,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Colors.pinkAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class ApproachProfilePainter extends CustomPainter {
  final double altitude;
  final double distToRwy;

  ApproachProfilePainter({required this.altitude, required this.distToRwy});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final gsPath = ui.Path();
    gsPath.moveTo(size.width, size.height - 10);
    gsPath.lineTo(0, size.height - 10 - (size.width * 0.3));
    canvas.drawPath(gsPath, paint);

    final aircraftX = (distToRwy / 20 * size.width).clamp(0.0, size.width);
    final aircraftY = (size.height - 10 - (altitude / 5000 * size.height))
        .clamp(0.0, size.height);

    final planePaint = Paint()..color = Colors.orangeAccent;
    canvas.drawCircle(Offset(aircraftX, aircraftY), 3.5, planePaint);

    final groundPaint = Paint()..color = Colors.white.withValues(alpha: 0.24);
    canvas.drawLine(
      Offset(0, size.height - 5),
      Offset(size.width, size.height - 5),
      groundPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
