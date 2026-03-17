import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../models/map_models.dart';
import '../providers/map_provider.dart';
import '../widgets/map_hud.dart';
import '../widgets/map_layer_picker.dart';
import '../widgets/map_markers.dart';
import '../widgets/map_right_controls.dart';
import '../widgets/map_top_panel.dart';
import '../widgets/selected_airport_bottom_card.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  static const double _nearbyAirportMinZoom = 8.5;
  static const double _airportIcaoLabelMinZoom = 10.8;

  final MapController _mapController = MapController();
  final _weatherRadarTransformer = TileUpdateTransformers.throttle(
    const Duration(milliseconds: 100),
  );

  bool _mapReady = false;
  bool _isFilterExpanded = true;
  bool _isAirportDetailExpanded = true;
  MapAirportMarker? _selectedAirport;
  MapSelectedAirportDetail? _selectedAirportDetail;
  bool _isSelectedAirportDetailLoading = false;
  bool _selectedAirportFromSearch = false;
  bool _hasSearchInput = false;
  int _airportSearchClearToken = 0;
  int _selectedAirportRequestToken = 0;
  List<MapAirportMarker> _nearbyAirports = const [];
  double _cameraZoom = 12;
  Timer? _airportFetchTimer;
  LatLngBounds? _lastFetchBounds;

  @override
  void dispose() {
    _airportFetchTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MapProvider>(
      builder: (context, provider, child) {
        final theme = Theme.of(context);
        final size = MediaQuery.sizeOf(context);
        final scale = (size.width / 1280).clamp(0.8, 1.2);
        final aircraft = provider.aircraft;
        final center = _resolveCenter(provider);
        final zoom = _cameraZoom;
        final aviationOverlayUrl = _aviationOverlayUrl(provider.layerStyle);
        final showNearbyAirportMarkers =
            provider.showAirports && zoom >= _nearbyAirportMinZoom;
        final showAirportIcaoLabel = zoom >= _airportIcaoLabelMinZoom;
        final activeAlerts = provider.activeAlerts;

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
                  onMapReady: () {
                    setState(() {
                      _mapReady = true;
                      _cameraZoom = _mapController.camera.zoom;
                    });
                    if (provider.showAirports &&
                        _cameraZoom >= _nearbyAirportMinZoom) {
                      _onMapBoundsChanged(
                        _mapController.camera.visibleBounds,
                        provider,
                      );
                    }
                  },
                  onPositionChanged: (position, hasGesture) {
                    final nextZoom = position.zoom;
                    if ((nextZoom - _cameraZoom).abs() > 0.001) {
                      setState(() {
                        _cameraZoom = nextZoom;
                      });
                    }
                    if (hasGesture && provider.followAircraft) {
                      provider.toggleFollowAircraft();
                    }

                    if (provider.showAirports &&
                        nextZoom >= _nearbyAirportMinZoom) {
                      _onMapBoundsChanged(position.visibleBounds, provider);
                    } else if (nextZoom < _nearbyAirportMinZoom) {
                      setState(() {
                        _nearbyAirports = const [];
                        _lastFetchBounds = null;
                      });
                      _clearSelectedAirportIfNeeded();
                    }
                  },
                ),
                children: [
                  TileLayer(
                    key: ValueKey(
                      'base-${provider.layerStyle.name}-${provider.tileReloadToken}',
                    ),
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
                        key: ValueKey(
                          'overlay-${provider.layerStyle.name}-${provider.tileReloadToken}',
                        ),
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
                  if (showNearbyAirportMarkers && _nearbyAirports.isNotEmpty)
                    MarkerLayer(
                      markers: _nearbyAirports
                          .where(_shouldRenderNearbyAirport)
                          .map(
                            (airport) => Marker(
                              point: LatLng(
                                airport.position.latitude,
                                airport.position.longitude,
                              ),
                              width: showAirportIcaoLabel ? 108 : 28,
                              height: showAirportIcaoLabel ? 56 : 28,
                              child: GestureDetector(
                                onTap: () =>
                                    _handleSelectAirport(provider, airport),
                                child: AirportMarker(
                                  airport: airport,
                                  showLabel: showAirportIcaoLabel,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  if (_selectedAirportDetail != null &&
                      provider.showRunways &&
                      _selectedAirportDetail!.runwayGeometries.isNotEmpty)
                    PolylineLayer(
                      polylines: _selectedAirportDetail!.runwayGeometries
                          .map(
                            (runway) => Polyline(
                              points: [
                                LatLng(
                                  runway.start.latitude,
                                  runway.start.longitude,
                                ),
                                LatLng(
                                  runway.end.latitude,
                                  runway.end.longitude,
                                ),
                              ],
                              color: Colors.lightBlueAccent.withValues(
                                alpha: 0.26,
                              ),
                              strokeWidth: (12.0 * scale).clamp(10.0, 17.0),
                            ),
                          )
                          .toList(),
                    ),
                  if (_selectedAirportDetail != null &&
                      provider.showRunways &&
                      _selectedAirportDetail!.runwayGeometries.isNotEmpty)
                    PolylineLayer(
                      polylines: _selectedAirportDetail!.runwayGeometries
                          .map(
                            (runway) => Polyline(
                              points: [
                                LatLng(
                                  runway.start.latitude,
                                  runway.start.longitude,
                                ),
                                LatLng(
                                  runway.end.latitude,
                                  runway.end.longitude,
                                ),
                              ],
                              color: Colors.white.withValues(alpha: 0.92),
                              strokeWidth: (5.2 * scale).clamp(4.0, 8.0),
                            ),
                          )
                          .toList(),
                    ),
                  if (_selectedAirportDetail != null &&
                      provider.showRunways &&
                      _selectedAirportDetail!.runwayGeometries.isNotEmpty &&
                      zoom >= 14)
                    MarkerLayer(
                      markers: _selectedAirportDetail!.runwayGeometries
                          .expand(
                            (runway) => [
                              if ((runway.leIdent ?? '').isNotEmpty)
                                Marker(
                                  point: LatLng(
                                    runway.start.latitude,
                                    runway.start.longitude,
                                  ),
                                  width: 50 * scale,
                                  height: 20 * scale,
                                  child: RunwayEndpointLabel(
                                    label: runway.leIdent!,
                                    scale: scale,
                                  ),
                                ),
                              if ((runway.heIdent ?? '').isNotEmpty)
                                Marker(
                                  point: LatLng(
                                    runway.end.latitude,
                                    runway.end.longitude,
                                  ),
                                  width: 50 * scale,
                                  height: 20 * scale,
                                  child: RunwayEndpointLabel(
                                    label: runway.heIdent!,
                                    scale: scale,
                                  ),
                                ),
                            ],
                          )
                          .toList(),
                    ),
                  if (_selectedAirportDetail != null &&
                      provider.showParkings &&
                      _selectedAirportDetail!.parkingSpots.isNotEmpty &&
                      zoom >= 14)
                    MarkerLayer(
                      markers: _selectedAirportDetail!.parkingSpots
                          .map(
                            (spot) => Marker(
                              point: LatLng(
                                spot.position.latitude,
                                spot.position.longitude,
                              ),
                              width: zoom >= 16
                                  ? _parkingMarkerWidth(spot.name, scale)
                                  : 20 * scale,
                              height: zoom >= 16 ? 26 * scale : 20 * scale,
                              child: ParkingSpotMarker(
                                scale: scale,
                                name: zoom >= 16 ? spot.name : null,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  if (_selectedAirport != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: LatLng(
                            _selectedAirport!.position.latitude,
                            _selectedAirport!.position.longitude,
                          ),
                          width: 120,
                          height: 84,
                          child: SelectedAirportPin(
                            airport: _selectedAirport!,
                            scale: scale,
                          ),
                        ),
                      ],
                    ),
                  if (aircraft != null)
                    MarkerLayer(
                      markers: [
                        if (provider.showCompass)
                          Marker(
                            point: LatLng(
                              aircraft.position.latitude,
                              aircraft.position.longitude,
                            ),
                            width: 140 * scale,
                            height: 140 * scale,
                            child: AircraftCompassRing(
                              heading: aircraft.heading,
                              mapRotation: _mapReady
                                  ? _mapController.camera.rotation
                                  : 0,
                              scale: scale,
                            ),
                          ),
                        Marker(
                          point: LatLng(
                            aircraft.position.latitude,
                            aircraft.position.longitude,
                          ),
                          width: 40,
                          height: 40,
                          child: AircraftMarker(
                            heading: aircraft.heading,
                            isDark: theme.brightness == Brightness.dark,
                          ),
                        ),
                        if (provider.takeoffPoint != null)
                          Marker(
                            point: LatLng(
                              provider.takeoffPoint!.latitude,
                              provider.takeoffPoint!.longitude,
                            ),
                            width: 78,
                            height: 68,
                            child: const FlightEventMarker(
                              icon: Icons.flight_takeoff,
                              label: 'TAKEOFF',
                              color: Colors.blueAccent,
                            ),
                          ),
                        if (provider.landingPoint != null)
                          Marker(
                            point: LatLng(
                              provider.landingPoint!.latitude,
                              provider.landingPoint!.longitude,
                            ),
                            width: 78,
                            height: 68,
                            child: const FlightEventMarker(
                              icon: Icons.flight_land,
                              label: 'LANDING',
                              color: Colors.greenAccent,
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
                child: MapTopPanel(
                  scale: scale,
                  aircraft: aircraft,
                  route: provider.route,
                  airports: provider.airports,
                  selectedAirport: _selectedAirport,
                  onSelectAirport: (airport) async {
                    await _handleSelectAirport(
                      provider,
                      airport,
                      fromSearch: true,
                    );
                  },
                  onClearSelectedAirport: () {
                    _clearSelectedAirportCard();
                  },
                  onClearSearchInput: () {
                    setState(() {
                      _hasSearchInput = false;
                      _airportSearchClearToken += 1;
                    });
                  },
                  onSearchInputChanged: (hasInput) {
                    if (_hasSearchInput == hasInput) {
                      return;
                    }
                    setState(() {
                      _hasSearchInput = hasInput;
                    });
                  },
                  isFilterExpanded: _isFilterExpanded,
                  onFilterExpandedChanged: (value) {
                    setState(() => _isFilterExpanded = value);
                  },
                  onToggleRoute: provider.toggleRoute,
                  onToggleAirports: provider.toggleAirports,
                  onToggleRunways: provider.toggleRunways,
                  onToggleParkings: provider.toggleParkings,
                  onToggleCompass: provider.toggleCompass,
                  onToggleWeather: provider.toggleWeather,
                  showRoute: provider.showRoute,
                  showAirports: provider.showAirports,
                  showRunways: provider.showRunways,
                  showParkings: provider.showParkings,
                  showCompass: provider.showCompass,
                  showWeather: provider.showWeather,
                  isConnected: provider.isConnected,
                  activeAlerts: activeAlerts,
                  onClearRoute: provider.clearRoute,
                  searchClearToken: _airportSearchClearToken,
                  showSearchClearButton: _hasSearchInput,
                ),
              ),
              Positioned(
                right: 20 * scale,
                top: 250 * scale,
                bottom: 250 * scale,
                child: MapRightControls(
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
                      width: 62 * scale,
                      height: 62 * scale,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Transform.rotate(
                            angle:
                                _mapController.camera.rotation *
                                (3.1415926 / 180),
                            child: Icon(
                              Icons.north,
                              color: Colors.orangeAccent,
                              size: 22 * scale,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_mapController.camera.rotation.round()}°',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 9 * scale,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (provider.isConnected && aircraft != null)
                Positioned(
                  left: 20 * scale,
                  right: 20 * scale,
                  bottom: 20 * scale,
                  child: VirtualHudPanel(
                    scale: scale,
                    aircraft: aircraft,
                    verticalSpeed: _calculateHudVerticalSpeed(provider.route),
                  ),
                ),
              if (_selectedAirport != null)
                Positioned(
                  left: 20 * scale,
                  right: 20 * scale,
                  bottom: provider.isConnected && aircraft != null
                      ? 124 * scale
                      : 20 * scale,
                  child: SelectedAirportBottomCard(
                    scale: scale,
                    airport: _selectedAirport!,
                    detail: _selectedAirportDetail,
                    isLoading: _isSelectedAirportDetailLoading,
                    isExpanded: _isAirportDetailExpanded,
                    onExpandedChanged: (value) {
                      setState(() {
                        _isAirportDetailExpanded = value;
                      });
                    },
                  ),
                ),
              if (provider.isLoading)
                const Positioned.fill(child: MapLoadingOverlay()),
            ],
          ),
        );
      },
    );
  }

  void _onMapBoundsChanged(LatLngBounds? bounds, MapProvider provider) {
    if (bounds == null) return;
    final last = _lastFetchBounds;
    if (last != null &&
        (last.north - bounds.north).abs() < 0.005 &&
        (last.south - bounds.south).abs() < 0.005 &&
        (last.east - bounds.east).abs() < 0.005 &&
        (last.west - bounds.west).abs() < 0.005) {
      return;
    }
    _airportFetchTimer?.cancel();
    _airportFetchTimer = Timer(const Duration(milliseconds: 500), () async {
      final airports = await provider.fetchAirportsByBounds(
        minLat: bounds.south,
        maxLat: bounds.north,
        minLon: bounds.west,
        maxLon: bounds.east,
      );
      _lastFetchBounds = bounds;
      if (mounted) {
        setState(() {
          _nearbyAirports = airports;
        });
      }
      _syncSelectedAirportWithNearby(airports);

      if (airports.length == 1 && mounted) {
        final airport = airports.first;
        final selectedCode = _normalizeAirportCode(_selectedAirport?.code);
        final airportCode = _normalizeAirportCode(airport.code);
        if (selectedCode != airportCode) {
          _handleSelectAirport(provider, airport, moveCamera: false);
        }
      }
    });
  }

  Future<void> _handleSelectAirport(
    MapProvider provider,
    MapAirportMarker airport, {
    bool moveCamera = true,
    bool fromSearch = false,
  }) async {
    if (provider.followAircraft) {
      provider.toggleFollowAircraft();
    }
    final requestToken = ++_selectedAirportRequestToken;
    setState(() {
      _selectedAirport = airport;
      _selectedAirportDetail = null;
      _isSelectedAirportDetailLoading = true;
      _isAirportDetailExpanded = true;
      _selectedAirportFromSearch = fromSearch;
    });
    final detail = await provider.fetchSelectedAirportDetail(airport);
    if (!mounted) return;
    if (requestToken != _selectedAirportRequestToken) {
      return;
    }
    final resolvedAirport = detail.marker;
    setState(() {
      _selectedAirport = resolvedAirport;
      _selectedAirportDetail = detail;
      _isSelectedAirportDetailLoading = false;
    });
    if (moveCamera) {
      _mapController.move(
        LatLng(
          resolvedAirport.position.latitude,
          resolvedAirport.position.longitude,
        ),
        15,
      );
    }
  }

  void _syncSelectedAirportWithNearby(List<MapAirportMarker> airports) {
    if (_selectedAirport == null || _selectedAirportFromSearch) {
      return;
    }
    final selectedKey = _airportDedupeKey(_selectedAirport!);
    final existsInNearby = airports.any(
      (airport) => _airportDedupeKey(airport) == selectedKey,
    );
    if (!existsInNearby) {
      _clearSelectedAirportCard();
    }
  }

  void _clearSelectedAirportIfNeeded() {
    if (_selectedAirport == null || _selectedAirportFromSearch) {
      return;
    }
    _clearSelectedAirportCard();
  }

  void _clearSelectedAirportCard() {
    _selectedAirportRequestToken += 1;
    if (!mounted) {
      _selectedAirport = null;
      _selectedAirportDetail = null;
      _isSelectedAirportDetailLoading = false;
      _isAirportDetailExpanded = true;
      _selectedAirportFromSearch = false;
      return;
    }
    setState(() {
      _selectedAirport = null;
      _selectedAirportDetail = null;
      _isSelectedAirportDetailLoading = false;
      _isAirportDetailExpanded = true;
      _selectedAirportFromSearch = false;
    });
  }

  bool _shouldRenderNearbyAirport(MapAirportMarker airport) {
    final selected = _selectedAirport;
    if (selected == null) {
      return true;
    }
    return _airportDedupeKey(airport) != _airportDedupeKey(selected);
  }

  String _airportDedupeKey(MapAirportMarker airport) {
    final normalizedCode = _normalizeAirportCode(airport.code);
    if (normalizedCode.isNotEmpty) {
      return normalizedCode;
    }
    final lat = airport.position.latitude.toStringAsFixed(6);
    final lon = airport.position.longitude.toStringAsFixed(6);
    return '$lat,$lon';
  }

  String _normalizeAirportCode(String? code) {
    if (code == null) {
      return '';
    }
    return code.trim().toUpperCase();
  }

  double _parkingMarkerWidth(String? name, double scale) {
    final trimmed = (name ?? '').trim();
    if (trimmed.isEmpty) {
      return 20 * scale;
    }
    final approxLabelWidth = (trimmed.length * 7.4 + 28)
        .clamp(74, 220)
        .toDouble();
    return approxLabelWidth * scale;
  }

  void _showLayerPicker(BuildContext context, MapProvider provider) {
    showMapLayerPicker(context, provider);
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

  double? _calculateHudVerticalSpeed(List<MapRoutePoint> route) {
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
    return ((last.altitude! - previous.altitude!) / seconds) * 60;
  }
}
