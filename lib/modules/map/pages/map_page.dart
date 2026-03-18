import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../../core/localization/localization_keys.dart';
import '../../../core/services/localization_service.dart';
import '../../../core/widgets/common/dialog.dart';
import '../localization/map_localization_keys.dart';
import '../models/map_models.dart';
import '../providers/map_provider.dart';
import 'widgets/map_hud.dart';
import 'widgets/map_layer_picker.dart';
import 'widgets/map_markers.dart';
import 'widgets/map_right_controls.dart';
import 'widgets/map_top_panel.dart';
import 'widgets/selected_airport_bottom_card.dart';

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
  bool _isCrashOverlayDismissed = false;
  bool _isReconnectPromptShowing = false;
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
        _handleReconnectPrompt(provider);
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
        final crashDetected = _isCrashDetected(aircraft, activeAlerts);
        final showCrashOverlay = crashDetected && !_isCrashOverlayDismissed;
        if (!crashDetected && _isCrashOverlayDismissed) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() {
              _isCrashOverlayDismissed = false;
            });
          });
        }
        final showDangerOverlay =
            _shouldShowDangerOverlay(provider, aircraft, activeAlerts) &&
            !showCrashOverlay;

        if (_mapReady) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            if (provider.followAircraft && aircraft != null) {
              _mapController.move(center, _mapController.camera.zoom);
            }
            _mapController.rotate(0);
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
                            width: 190 * scale,
                            height: 190 * scale,
                            child: AircraftCompassRing(
                              heading: aircraft.heading,
                              headingTarget: aircraft.headingTarget,
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
                  onClearRoute: () => _confirmClearRoute(provider),
                  onToggleHudTimer: provider.toggleHudTimer,
                  onResetHudTimer: provider.resetHudTimer,
                  searchClearToken: _airportSearchClearToken,
                  showSearchClearButton: _hasSearchInput,
                  hudElapsed: provider.hudElapsed,
                  isHudTimerRunning: provider.isHudTimerRunning,
                ),
              ),
              Positioned(
                right: 20 * scale,
                top: 250 * scale,
                child: MapRightControls(
                  scale: scale,
                  mapController: _mapController,
                  followAircraft: provider.followAircraft,
                  onFollowAircraftChanged: (value) {
                    if (provider.followAircraft != value) {
                      provider.toggleFollowAircraft();
                    }
                  },
                  onShowLayerPicker: () {
                    _showLayerPicker(context, provider);
                  },
                  isMapReady: _mapReady,
                  isConnected: provider.isConnected,
                ),
              ),
              if (_selectedAirport != null)
                Positioned(
                  left: 20 * scale,
                  right: 20 * scale,
                  bottom: 20 * scale,
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
              if (showDangerOverlay)
                Positioned.fill(
                  child: DangerOverlay(
                    message: 'DANGER',
                    subMessage: _buildDangerSubMessage(
                      context,
                      activeAlerts,
                      aircraft,
                    ),
                  ),
                ),
              if (showCrashOverlay)
                Positioned.fill(
                  child: CrashOverlay(
                    onDismiss: () {
                      setState(() {
                        _isCrashOverlayDismissed = true;
                      });
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _handleReconnectPrompt(MapProvider provider) {
    if (!provider.shouldShowReconnectPrompt() || _isReconnectPromptShowing) {
      return;
    }
    _isReconnectPromptShowing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        _isReconnectPromptShowing = false;
        return;
      }
      await _showReconnectPromptDialog(provider);
      if (!mounted) {
        _isReconnectPromptShowing = false;
        return;
      }
      setState(() {
        _isReconnectPromptShowing = false;
      });
      provider.markReconnectPromptHandled();
    });
  }

  Future<void> _showReconnectPromptDialog(MapProvider provider) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('检测到新的飞行连接'),
          content: const Text('当前地图存在上一次飞行轨迹，是否清除后开始本次飞行？'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('保留轨迹'),
            ),
            TextButton(
              onPressed: () {
                provider.clearRoute();
                Navigator.of(dialogContext).pop();
              },
              style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
              child: const Text('清除轨迹'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmClearRoute(MapProvider provider) async {
    final confirmed = await showAdvancedConfirmDialog(
      context: context,
      title: MapLocalizationKeys.clearRouteConfirmTitle.tr(context),
      content: MapLocalizationKeys.clearRouteConfirmContent.tr(context),
      icon: Icons.warning_amber_rounded,
      confirmColor: Colors.redAccent,
      confirmText: LocalizationKeys.confirm.tr(context),
      cancelText: LocalizationKeys.cancel.tr(context),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    provider.clearRoute();
  }

  bool _shouldShowDangerOverlay(
    MapProvider provider,
    MapAircraftState? aircraft,
    List<MapFlightAlert> activeAlerts,
  ) {
    if (!provider.isConnected || aircraft == null) {
      return false;
    }
    final pitch = aircraft.pitch ?? 0;
    final bank = aircraft.bank?.abs() ?? 0;
    final verticalSpeed = aircraft.verticalSpeed ?? 0;
    final speed = aircraft.groundSpeed ?? 0;
    final canEvaluateRisk =
        aircraft.onGround != true ||
        speed >= 20 ||
        verticalSpeed.abs() >= 800 ||
        pitch.abs() >= 12 ||
        bank >= 30;
    final hasAlertRisk = activeAlerts.any(
      (alert) =>
          alert.level == MapFlightAlertLevel.danger ||
          alert.level == MapFlightAlertLevel.warning,
    );
    final pitchRisk = pitch >= 18 || pitch <= -15;
    final bankRisk = bank >= 35;
    final sinkRateRisk = verticalSpeed <= -1500;
    final climbRateRisk = verticalSpeed >= 2200;
    final stallRisk = aircraft.stallWarning == true;
    return canEvaluateRisk &&
        (pitchRisk ||
            bankRisk ||
            sinkRateRisk ||
            climbRateRisk ||
            stallRisk ||
            hasAlertRisk);
  }

  bool _isCrashDetected(
    MapAircraftState? aircraft,
    List<MapFlightAlert> activeAlerts,
  ) {
    if (aircraft == null || aircraft.onGround != true) {
      return false;
    }
    final verticalSpeed = aircraft.verticalSpeed ?? 0;
    final pitch = aircraft.pitch ?? 0;
    final hasSinkDanger =
        activeAlerts.any((alert) => alert.id == 'sink_rate_danger') ||
        verticalSpeed <= -1800;
    return hasSinkDanger && pitch <= -8;
  }

  String _buildDangerSubMessage(
    BuildContext context,
    List<MapFlightAlert> activeAlerts,
    MapAircraftState? aircraft,
  ) {
    final prioritizedAlert = activeAlerts.firstWhere(
      (alert) =>
          alert.level == MapFlightAlertLevel.danger ||
          alert.level == MapFlightAlertLevel.warning,
      orElse: () => const MapFlightAlert(
        id: '__none__',
        level: MapFlightAlertLevel.caution,
        message: '',
      ),
    );
    if (prioritizedAlert.id != '__none__') {
      return prioritizedAlert.message.tr(context);
    }
    final pitch = aircraft?.pitch;
    final bank = aircraft?.bank;
    final verticalSpeed = aircraft?.verticalSpeed;
    if (pitch != null && (pitch >= 18 || pitch <= -15)) {
      return pitch >= 18 ? '俯仰角过大，请修正姿态' : '机头下俯过大，请抬头';
    }
    if (bank != null && bank.abs() >= 35) {
      return '倾斜角过大，请尽快改平';
    }
    if (verticalSpeed != null && verticalSpeed <= -1500) {
      return '下降率过大，请立即减小下沉';
    }
    if (verticalSpeed != null && verticalSpeed >= 2200) {
      return '爬升率过大，请柔和抬升';
    }
    return '飞行参数异常，请立即修正';
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
    MapAirportMarker? matchedAirport;
    for (final airport in airports) {
      if (_airportDedupeKey(airport) == selectedKey) {
        matchedAirport = airport;
        break;
      }
    }
    if (matchedAirport == null) {
      return;
    }
    final current = _selectedAirport!;
    final isSamePosition =
        current.position.latitude == matchedAirport.position.latitude &&
        current.position.longitude == matchedAirport.position.longitude;
    final isSameName = (current.name ?? '') == (matchedAirport.name ?? '');
    final isSameCode = current.code == matchedAirport.code;
    if (isSamePosition && isSameName && isSameCode) {
      return;
    }
    if (!mounted) {
      _selectedAirport = matchedAirport;
      return;
    }
    setState(() {
      _selectedAirport = matchedAirport;
    });
  }

  void _clearSelectedAirportIfNeeded() {
    if (_selectedAirport == null || _selectedAirportFromSearch) {
      return;
    }
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
}
