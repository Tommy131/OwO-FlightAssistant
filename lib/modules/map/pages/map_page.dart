import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../../core/services/localization_service.dart';
import '../../../core/theme/app_theme_data.dart';
import '../localization/map_localization_keys.dart';
import '../models/map_models.dart';
import '../providers/map_provider.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final MapController _mapController = MapController();
  final _weatherRadarTransformer = TileUpdateTransformers.throttle(
    const Duration(milliseconds: 100),
  );
  bool _mapReady = false;
  bool _isFilterExpanded = true;
  MapAirportMarker? _selectedAirport;

  @override
  Widget build(BuildContext context) {
    return Consumer<MapProvider>(
      builder: (context, provider, child) {
        final theme = Theme.of(context);
        final size = MediaQuery.sizeOf(context);
        final scale = (size.width / 1280).clamp(0.8, 1.2);
        final aircraft = provider.aircraft;
        final center = _resolveCenter(provider);
        final zoom = _mapReady ? _mapController.camera.zoom : 12;
        final aviationOverlayUrl = _aviationOverlayUrl(provider.layerStyle);

        if (_mapReady && provider.followAircraft && aircraft != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _mapController.move(center, _mapController.camera.zoom);
            if (provider.orientationMode == MapOrientationMode.trackUp &&
                aircraft.heading != null) {
              _mapController.rotate(-aircraft.heading!);
            } else {
              _mapController.rotate(0);
            }
          });
        }

        return Scaffold(
          body: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: 12,
                  minZoom: 3,
                  maxZoom: 18,
                  onMapReady: () => setState(() => _mapReady = true),
                  onPositionChanged: (position, hasGesture) {
                    if (hasGesture && provider.followAircraft) {
                      provider.toggleFollowAircraft();
                    }
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate: mapTileUrl(provider.layerStyle),
                    subdomains: const ['a', 'b', 'c'],
                    userAgentPackageName: 'com.owo.flight_assistant',
                    tileDisplay: const TileDisplay.fadeIn(),
                  ),
                  if (aviationOverlayUrl != null && zoom >= 14)
                    Opacity(
                      opacity: provider.layerStyle == MapLayerStyle.taxiway
                          ? 0.35
                          : 0.25,
                      child: TileLayer(
                        urlTemplate: aviationOverlayUrl,
                        subdomains: const ['a', 'b', 'c'],
                        userAgentPackageName: 'com.owo.flight_assistant',
                        maxNativeZoom: 19,
                        minZoom: 3,
                        tileDisplay: const TileDisplay.fadeIn(
                          duration: Duration(milliseconds: 300),
                        ),
                        errorTileCallback: (tile, error, stackTrace) {},
                      ),
                    ),
                  if (provider.showWeather &&
                      provider.weatherRadarTimestamp != null &&
                      !provider.isWeatherRadarCoolingDown &&
                      zoom <= 8)
                    Opacity(
                      opacity: 0.6,
                      child: TileLayer(
                        urlTemplate:
                            'https://tilecache.rainviewer.com/v2/radar/${provider.weatherRadarTimestamp}/256/{z}/{x}/{y}/4/1_1.png',
                        userAgentPackageName: 'com.owo.flight_assistant',
                        tileUpdateTransformer: _weatherRadarTransformer,
                        maxNativeZoom: 7,
                        minZoom: 3,
                        errorTileCallback: (tile, error, stackTrace) {
                          final message = error.toString();
                          if (message.contains('statusCode: 429')) {
                            provider.handleWeatherRadarRateLimit();
                          }
                        },
                      ),
                    ),
                  if (provider.showRoute && provider.route.isNotEmpty)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: provider.route
                              .map((p) => LatLng(p.latitude, p.longitude))
                              .toList(),
                          color: theme.colorScheme.primary,
                          strokeWidth: 3,
                        ),
                      ],
                    ),
                  if (provider.showAirports && provider.airports.isNotEmpty)
                    MarkerLayer(
                      markers: provider.airports
                          .map(
                            (airport) => Marker(
                              point: LatLng(
                                airport.position.latitude,
                                airport.position.longitude,
                              ),
                              width: 28,
                              height: 28,
                              child: _AirportMarker(airport: airport),
                            ),
                          )
                          .toList(),
                    ),
                  if (aircraft != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: LatLng(
                            aircraft.position.latitude,
                            aircraft.position.longitude,
                          ),
                          width: 40,
                          height: 40,
                          child: _AircraftMarker(
                            heading: aircraft.heading,
                            isDark: theme.brightness == Brightness.dark,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              Positioned(
                top: 20 * scale,
                left: 20 * scale,
                right: 20 * scale,
                child: _MapTopPanel(
                  scale: scale,
                  aircraft: aircraft,
                  route: provider.route,
                  airports: provider.airports,
                  selectedAirport: _selectedAirport,
                  onSelectAirport: (airport) {
                    setState(() => _selectedAirport = airport);
                    _mapController.move(
                      LatLng(
                        airport.position.latitude,
                        airport.position.longitude,
                      ),
                      15,
                    );
                    if (provider.followAircraft) {
                      provider.toggleFollowAircraft();
                    }
                  },
                  onClearSelectedAirport: () {
                    setState(() => _selectedAirport = null);
                  },
                  isFilterExpanded: _isFilterExpanded,
                  onFilterExpandedChanged: (value) {
                    setState(() => _isFilterExpanded = value);
                  },
                  onToggleRoute: provider.toggleRoute,
                  onToggleAirports: provider.toggleAirports,
                  onToggleCompass: provider.toggleCompass,
                  onToggleWeather: provider.toggleWeather,
                  showRoute: provider.showRoute,
                  showAirports: provider.showAirports,
                  showCompass: provider.showCompass,
                  showWeather: provider.showWeather,
                  onClearRoute: () {
                    provider.clearRoute();
                  },
                ),
              ),
              Positioned(
                right: 20 * scale,
                top: 250 * scale,
                bottom: 250 * scale,
                child: _MapRightControls(
                  scale: scale,
                  mapController: _mapController,
                  followAircraft: provider.followAircraft,
                  onFollowAircraftChanged: (value) {
                    if (provider.followAircraft != value) {
                      provider.toggleFollowAircraft();
                    }
                  },
                  orientationMode: provider.orientationMode,
                  onOrientationChanged: provider.setOrientationMode,
                  onShowLayerPicker: () {
                    _showLayerPicker(context, provider);
                  },
                  isMapReady: _mapReady,
                  isConnected: provider.isConnected,
                ),
              ),
              if (provider.showCompass && _mapReady)
                Positioned(
                  right: 20 * scale,
                  bottom: 120 * scale,
                  child: GestureDetector(
                    onTap: () {
                      _mapController.rotate(0);
                      provider.setOrientationMode(MapOrientationMode.northUp);
                    },
                    child: Container(
                      width: 48 * scale,
                      height: 48 * scale,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Center(
                        child: Transform.rotate(
                          angle:
                              _mapController.camera.rotation *
                              (3.1415926 / 180),
                          child: Icon(
                            Icons.north,
                            color: Colors.orangeAccent,
                            size: 24 * scale,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              if (provider.isLoading)
                const Positioned.fill(child: _MapLoadingOverlay()),
            ],
          ),
        );
      },
    );
  }

  void _showLayerPicker(BuildContext context, MapProvider provider) {
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
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              MapLocalizationKeys.layerTitle.tr(context),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 16,
              runSpacing: 16,
              children: [
                _LayerOption(
                  label: MapLocalizationKeys.layerDark.tr(context),
                  icon: Icons.dark_mode,
                  selected: provider.layerStyle == MapLayerStyle.dark,
                  onTap: () {
                    provider.setLayerStyle(MapLayerStyle.dark);
                    Navigator.pop(context);
                  },
                ),
                _LayerOption(
                  label: MapLocalizationKeys.layerSatellite.tr(context),
                  icon: Icons.satellite_alt,
                  selected: provider.layerStyle == MapLayerStyle.satellite,
                  onTap: () {
                    provider.setLayerStyle(MapLayerStyle.satellite);
                    Navigator.pop(context);
                  },
                ),
                _LayerOption(
                  label: MapLocalizationKeys.layerTerrain.tr(context),
                  icon: Icons.landscape,
                  selected: provider.layerStyle == MapLayerStyle.terrain,
                  onTap: () {
                    provider.setLayerStyle(MapLayerStyle.terrain);
                    Navigator.pop(context);
                  },
                ),
                _LayerOption(
                  label: MapLocalizationKeys.layerTaxiway.tr(context),
                  icon: Icons.flight,
                  selected: provider.layerStyle == MapLayerStyle.taxiway,
                  onTap: () {
                    provider.setLayerStyle(MapLayerStyle.taxiway);
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  LatLng _resolveCenter(MapProvider provider) {
    if (provider.aircraft != null) {
      final pos = provider.aircraft!.position;
      return LatLng(pos.latitude, pos.longitude);
    }
    if (provider.route.isNotEmpty) {
      final point = provider.route.last;
      return LatLng(point.latitude, point.longitude);
    }
    if (provider.airports.isNotEmpty) {
      final point = provider.airports.first.position;
      return LatLng(point.latitude, point.longitude);
    }
    return const LatLng(0, 0);
  }

  String? _aviationOverlayUrl(MapLayerStyle style) {
    switch (style) {
      case MapLayerStyle.taxiway:
        return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
      default:
        return null;
    }
  }
}

class _MapTopPanel extends StatelessWidget {
  final double scale;
  final MapAircraftState? aircraft;
  final List<MapRoutePoint> route;
  final List<MapAirportMarker> airports;
  final MapAirportMarker? selectedAirport;
  final ValueChanged<MapAirportMarker> onSelectAirport;
  final VoidCallback onClearSelectedAirport;
  final bool isFilterExpanded;
  final ValueChanged<bool> onFilterExpandedChanged;
  final VoidCallback onToggleRoute;
  final VoidCallback onToggleAirports;
  final VoidCallback onToggleCompass;
  final VoidCallback onToggleWeather;
  final bool showRoute;
  final bool showAirports;
  final bool showCompass;
  final bool showWeather;
  final VoidCallback onClearRoute;

  const _MapTopPanel({
    required this.scale,
    required this.aircraft,
    required this.route,
    required this.airports,
    required this.selectedAirport,
    required this.onSelectAirport,
    required this.onClearSelectedAirport,
    required this.isFilterExpanded,
    required this.onFilterExpandedChanged,
    required this.onToggleRoute,
    required this.onToggleAirports,
    required this.onToggleCompass,
    required this.onToggleWeather,
    required this.showRoute,
    required this.showAirports,
    required this.showCompass,
    required this.showWeather,
    required this.onClearRoute,
  });

  @override
  Widget build(BuildContext context) {
    final groundSpeed = aircraft?.groundSpeed;
    final altitude = aircraft?.altitude;
    final heading = aircraft?.heading;
    final duration = _formatDuration(route);
    final vs = _calculateVerticalSpeed(route);
    final distanceNm = _calculateRouteDistance(route);

    return StreamBuilder<int>(
      stream: Stream.periodic(const Duration(seconds: 1), (i) => i),
      builder: (context, snapshot) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _AirportSearchBar(
                    airports: airports,
                    onSelect: onSelectAirport,
                  ),
                ),
                if (selectedAirport != null) ...[
                  SizedBox(width: 8 * scale),
                  _MapButton(
                    icon: Icons.close,
                    onPressed: onClearSelectedAirport,
                    tooltip: '清除搜索记录',
                    mini: true,
                    scale: scale,
                  ),
                ],
              ],
            ),
            if (aircraft != null) ...[
              SizedBox(height: 12 * scale),
              ClipRRect(
                borderRadius: BorderRadius.circular(16 * scale),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 20 * scale,
                      vertical: 12 * scale,
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
                          groundSpeed != null ? '${groundSpeed.round()}' : '--',
                          'kt',
                        ),
                        _buildValue(
                          'ALT',
                          altitude != null ? '${altitude.round()}' : '--',
                          'ft',
                        ),
                        _buildValue(
                          'HDG',
                          heading != null ? '${heading.round()}°' : '--',
                          '',
                        ),
                        _buildValue(
                          'TIME',
                          duration,
                          '',
                          color: Colors.cyanAccent,
                        ),
                        _buildValue(
                          'VS',
                          vs != null ? '${vs.round()}' : '--',
                          'fpm',
                          color: _getVSColor(vs ?? 0),
                          icon: _getVSIcon(vs ?? 0),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            if (route.isNotEmpty || airports.isNotEmpty) ...[
              SizedBox(height: 8 * scale),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    if (route.isNotEmpty)
                      _MapInfoChip(
                        icon: Icons.timeline,
                        label: '轨迹点: ${route.length}',
                        scale: scale,
                      ),
                    if (route.isNotEmpty) SizedBox(width: 8 * scale),
                    if (airports.isNotEmpty)
                      _MapInfoChip(
                        icon: Icons.flight_takeoff,
                        label: '机场: ${airports.length}',
                        scale: scale,
                      ),
                    if (distanceNm > 0) ...[
                      SizedBox(width: 8 * scale),
                      _MapInfoChip(
                        icon: Icons.route,
                        label: '航程: ${distanceNm.round()}NM',
                        scale: scale,
                      ),
                    ],
                  ],
                ),
              ),
            ],
            SizedBox(height: 8 * scale),
            Row(
              children: [
                GestureDetector(
                  onTap: () => onFilterExpandedChanged(!isFilterExpanded),
                  child: Container(
                    padding: EdgeInsets.all(4 * scale),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8 * scale),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Icon(
                      isFilterExpanded
                          ? Icons.chevron_left_rounded
                          : Icons.chevron_right_rounded,
                      color: Colors.white,
                      size: 16 * scale,
                    ),
                  ),
                ),
                if (isFilterExpanded) ...[
                  SizedBox(width: 8 * scale),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _FilterToggleButton(
                            label: '轨迹',
                            value: showRoute,
                            onChanged: (value) => onToggleRoute(),
                            scale: scale,
                          ),
                          SizedBox(width: 8 * scale),
                          _FilterToggleButton(
                            label: '附近机场',
                            value: showAirports,
                            onChanged: (value) => onToggleAirports(),
                            activeColor: Colors.blueGrey,
                            scale: scale,
                          ),
                          SizedBox(width: 8 * scale),
                          _FilterToggleButton(
                            label: '罗盘',
                            value: showCompass,
                            onChanged: (value) => onToggleCompass(),
                            activeColor: Colors.blueAccent,
                            scale: scale,
                          ),
                          SizedBox(width: 8 * scale),
                          _FilterToggleButton(
                            label: '气象雷达',
                            value: showWeather,
                            onChanged: (value) => onToggleWeather(),
                            scale: scale,
                          ),
                          if (distanceNm > 0) ...[
                            SizedBox(width: 8 * scale),
                            _FilterToggleButton(
                              label: '航程: ${distanceNm.round()}NM',
                              value: showRoute,
                              onChanged: (value) => onToggleRoute(),
                              activeColor: Colors.purpleAccent,
                              scale: scale,
                            ),
                          ],
                          if (route.isNotEmpty) ...[
                            SizedBox(width: 8 * scale),
                            _FilterToggleButton(
                              label: '清除轨迹',
                              value: false,
                              onChanged: (value) => onClearRoute(),
                              activeColor: Colors.redAccent,
                              inactiveColor: Colors.redAccent.withValues(
                                alpha: 0.6,
                              ),
                              scale: scale,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        );
      },
    );
  }

  String _formatDuration(List<MapRoutePoint> route) {
    if (route.length < 2) return '00:00:00';
    final start = route.first.timestamp;
    final end = route.last.timestamp;
    if (start == null || end == null) return '00:00:00';
    final duration = end.difference(start);
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  double _calculateRouteDistance(List<MapRoutePoint> route) {
    if (route.length < 2) return 0;
    const distance = Distance();
    double totalMeters = 0;
    for (var i = 1; i < route.length; i += 1) {
      final prev = route[i - 1];
      final current = route[i];
      totalMeters += distance(
        LatLng(prev.latitude, prev.longitude),
        LatLng(current.latitude, current.longitude),
      );
    }
    return totalMeters * 0.000539957;
  }

  double? _calculateVerticalSpeed(List<MapRoutePoint> route) {
    if (route.length < 2) return null;
    final last = route[route.length - 1];
    final previous = route[route.length - 2];
    if (last.altitude == null || previous.altitude == null) return null;
    if (last.timestamp == null || previous.timestamp == null) return null;
    final seconds = last.timestamp!
        .difference(previous.timestamp!)
        .inSeconds
        .toDouble();
    if (seconds <= 0) return null;
    final delta = last.altitude! - previous.altitude!;
    return (delta / seconds) * 60;
  }

  Widget _buildValue(
    String label,
    String value,
    String unit, {
    Color? color,
    IconData? icon,
    Widget? trailWidget,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 10 * scale,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (icon != null) ...[
              SizedBox(width: 4 * scale),
              Icon(icon, size: 12 * scale, color: color ?? Colors.white70),
            ],
          ],
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            Text(
              value,
              style: TextStyle(
                color: color ?? Colors.white,
                fontSize: 14 * scale,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (unit.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(left: 4 * scale),
                child: Text(
                  unit,
                  style: TextStyle(color: Colors.white70, fontSize: 10 * scale),
                ),
              ),
            if (trailWidget != null) ...[
              SizedBox(width: 6 * scale),
              trailWidget,
            ],
          ],
        ),
      ],
    );
  }

  Color _getVSColor(double vs) {
    if (vs.abs() > 2000) return Colors.redAccent;
    if (vs.abs() > 1000) return Colors.orangeAccent;
    if (vs.abs() > 100) return Colors.tealAccent;
    return Colors.white70;
  }

  IconData? _getVSIcon(double vs) {
    if (vs > 100) return Icons.arrow_upward;
    if (vs < -100) return Icons.arrow_downward;
    return null;
  }
}

class _MapInfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final double scale;

  const _MapInfoChip({
    required this.icon,
    required this.label,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 10 * scale,
        vertical: 4 * scale,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(8 * scale),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white54, size: 12 * scale),
          SizedBox(width: 4 * scale),
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 11 * scale,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterToggleButton extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color activeColor;
  final Color? inactiveColor;
  final double scale;

  const _FilterToggleButton({
    required this.label,
    required this.value,
    required this.onChanged,
    this.activeColor = Colors.orangeAccent,
    this.inactiveColor,
    this.scale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: 10 * scale,
          vertical: 4 * scale,
        ),
        decoration: BoxDecoration(
          color: value
              ? activeColor.withValues(alpha: 0.2)
              : (inactiveColor?.withValues(alpha: 0.2) ?? Colors.black54),
          borderRadius: BorderRadius.circular(16 * scale),
          border: Border.all(
            color: value ? activeColor : (inactiveColor ?? Colors.white24),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (value) ...[
              SizedBox(width: 4 * scale),
              Icon(Icons.check, size: 12 * scale, color: activeColor),
            ],
            SizedBox(width: (value || inactiveColor != null) ? 4 * scale : 0),
            Text(
              label,
              style: TextStyle(
                color: (value || inactiveColor != null)
                    ? Colors.white
                    : Colors.white70,
                fontSize: 10 * scale,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapRightControls extends StatelessWidget {
  final double scale;
  final MapController mapController;
  final bool followAircraft;
  final ValueChanged<bool> onFollowAircraftChanged;
  final MapOrientationMode orientationMode;
  final ValueChanged<MapOrientationMode> onOrientationChanged;
  final VoidCallback onShowLayerPicker;
  final bool isMapReady;
  final bool isConnected;

  const _MapRightControls({
    required this.scale,
    required this.mapController,
    required this.followAircraft,
    required this.onFollowAircraftChanged,
    required this.orientationMode,
    required this.onOrientationChanged,
    required this.onShowLayerPicker,
    required this.isMapReady,
    required this.isConnected,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _MapButton(
                  icon: Icons.layers_outlined,
                  onPressed: onShowLayerPicker,
                  tooltip: '地图图层',
                  scale: scale,
                ),
                const SizedBox(height: 12),
                if (isConnected) ...[
                  _MapButton(
                    icon: followAircraft
                        ? Icons.gps_fixed
                        : Icons.gps_not_fixed,
                    onPressed: () => onFollowAircraftChanged(!followAircraft),
                    tooltip: '追随飞机',
                    highlight: followAircraft,
                    scale: scale,
                  ),
                  const SizedBox(height: 12),
                  _MapButton(
                    icon: orientationMode == MapOrientationMode.northUp
                        ? Icons.explore_outlined
                        : Icons.navigation_outlined,
                    onPressed: () {
                      if (orientationMode == MapOrientationMode.northUp) {
                        onOrientationChanged(MapOrientationMode.trackUp);
                      } else {
                        onOrientationChanged(MapOrientationMode.northUp);
                        mapController.rotate(0);
                      }
                    },
                    tooltip: orientationMode == MapOrientationMode.northUp
                        ? '北向上'
                        : '航向向上',
                    highlight: orientationMode == MapOrientationMode.trackUp,
                    scale: scale,
                  ),
                  const SizedBox(height: 12),
                ],
                _MapButton(
                  icon: Icons.add,
                  onPressed: () => mapController.move(
                    mapController.camera.center,
                    mapController.camera.zoom + 1,
                  ),
                  tooltip: '放大',
                  scale: scale,
                ),
                const SizedBox(height: 12),
                _MapButton(
                  icon: Icons.remove,
                  onPressed: () => mapController.move(
                    mapController.camera.center,
                    mapController.camera.zoom - 1,
                  ),
                  tooltip: '缩小',
                  scale: scale,
                ),
              ],
            ),
          ),
        ),
        if (isMapReady)
          Positioned(right: 0, bottom: 0, child: const SizedBox.shrink()),
      ],
    );
  }
}

class _MapButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final bool highlight;
  final String? tooltip;
  final bool mini;
  final double scale;

  const _MapButton({
    required this.icon,
    required this.onPressed,
    this.highlight = false,
    this.tooltip,
    this.mini = false,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    final btnSize = (mini ? 40.0 : 48.0) * scale;
    return Container(
      width: btnSize,
      height: btnSize,
      decoration: BoxDecoration(
        color: highlight
            ? Colors.orangeAccent
            : Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular((mini ? 10 : 12) * scale),
        border: Border.all(color: Colors.white10),
      ),
      child: IconButton(
        icon: Icon(
          icon,
          color: highlight ? Colors.black : Colors.white,
          size: (mini ? 18 : 20) * scale,
        ),
        padding: mini ? EdgeInsets.zero : const EdgeInsets.all(8.0),
        onPressed: onPressed,
        tooltip: tooltip,
      ),
    );
  }
}

class _AirportSearchBar extends StatefulWidget {
  final List<MapAirportMarker> airports;
  final ValueChanged<MapAirportMarker> onSelect;

  const _AirportSearchBar({required this.airports, required this.onSelect});

  @override
  State<_AirportSearchBar> createState() => _AirportSearchBarState();
}

class _AirportSearchBarState extends State<_AirportSearchBar> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  List<MapAirportMarker> _results = [];

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _hideOverlay();
    super.dispose();
  }

  void _showOverlay() {
    if (_overlayEntry != null) return;
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final size = renderBox.size;
    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0, size.height + 6),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(8),
            clipBehavior: Clip.antiAlias,
            child: Container(
              constraints: const BoxConstraints(maxHeight: 280),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withAlpha(50),
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: _results.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        '未找到相关机场',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: _results.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final airport = _results[index];
                        return ListTile(
                          dense: true,
                          title: Text(
                            airport.code,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            airport.name ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Text(
                            '${airport.position.latitude.toStringAsFixed(2)}, ${airport.position.longitude.toStringAsFixed(2)}',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                          ),
                          onTap: () {
                            widget.onSelect(airport);
                            _controller.clear();
                            _hideOverlay();
                            _focusNode.unfocus();
                          },
                        );
                      },
                    ),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _onSearch(String value) {
    final query = value.trim().toLowerCase();
    if (query.isEmpty) {
      _hideOverlay();
      return;
    }
    setState(() {
      _results = widget.airports.where((airport) {
        final name = airport.name?.toLowerCase() ?? '';
        return airport.code.toLowerCase().contains(query) ||
            name.contains(query);
      }).toList();
    });
    if (_overlayEntry == null) {
      _showOverlay();
    } else {
      _overlayEntry!.markNeedsBuild();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        autofocus: false,
        decoration: InputDecoration(
          hintText: '搜索机场 (ICAO/IATA/名称)',
          hintStyle: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.outline,
          ),
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: _controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    _controller.clear();
                    _hideOverlay();
                  },
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppThemeData.spacingMedium,
            vertical: AppThemeData.spacingSmall,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: theme.colorScheme.outline.withAlpha(50),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: theme.colorScheme.outline.withAlpha(50),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
          ),
          filled: true,
          fillColor: theme.colorScheme.surface,
        ),
        onChanged: _onSearch,
        onTap: () {
          if (_controller.text.isNotEmpty) {
            _onSearch(_controller.text);
          }
        },
      ),
    );
  }
}

class _LayerOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _LayerOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: selected
                  ? Colors.orangeAccent
                  : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected ? Colors.white : Colors.white12,
                width: 2,
              ),
            ),
            child: Icon(
              icon,
              color: selected ? Colors.black : Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: selected ? Colors.orangeAccent : Colors.white70,
              fontSize: 13,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

class _MapLoadingOverlay extends StatelessWidget {
  const _MapLoadingOverlay();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surface.withValues(alpha: 0.6),
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

class _AircraftMarker extends StatelessWidget {
  final double? heading;
  final bool isDark;

  const _AircraftMarker({this.heading, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final angle = (heading ?? 0) * (math.pi / 180);
    return Transform.rotate(
      angle: angle,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? Colors.black : Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 6,
            ),
          ],
        ),
        child: const Icon(Icons.flight, color: Colors.blue, size: 22),
      ),
    );
  }
}

class _AirportMarker extends StatelessWidget {
  final MapAirportMarker airport;

  const _AirportMarker({required this.airport});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = airport.isPrimary
        ? theme.colorScheme.primary
        : theme.colorScheme.secondary;
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Center(
        child: Text(
          airport.code,
          style: theme.textTheme.labelSmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
