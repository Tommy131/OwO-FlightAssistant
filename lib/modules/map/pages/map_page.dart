import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../../core/localization/localization_keys.dart';
import '../../../core/services/localization_service.dart';
import '../../../core/widgets/common/dialog.dart';
import '../../common/models/common_models.dart';
import '../../common/providers/common_provider.dart';
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
  bool _showAircraftInfoPanel = false;
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
        final homeProvider = context.watch<HomeProvider>();
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
        final prioritizedPinnedMarkers = _buildPrioritizedPinnedMarkers(
          provider: provider,
          homeProvider: homeProvider,
          scale: scale,
        );
        final departureCode = _normalizeAirportCode(
          homeProvider.departureAirport?.icaoCode,
        );
        final destinationCode = _normalizeAirportCode(
          homeProvider.destinationAirport?.icaoCode,
        );
        final alternateCode = _normalizeAirportCode(
          homeProvider.alternateAirport?.icaoCode,
        );
        final selectedCode = _normalizeAirportCode(_selectedAirport?.code);
        final isSelectedDeparture =
            selectedCode.isNotEmpty && selectedCode == departureCode;
        final isSelectedDestination =
            selectedCode.isNotEmpty && selectedCode == destinationCode;
        final isSelectedAlternate =
            selectedCode.isNotEmpty && selectedCode == alternateCode;
        final activeAlerts = provider.activeAlerts;
        final isHomeAirportCanvasState = _isHomeAirportCanvasState(
          provider,
          aircraft,
        );
        final brightMapBackground = _isBrightMapBackground(provider.layerStyle);
        final homeSnapshot = homeProvider.snapshot;
        final aircraftScreenOffset = _mapReady && aircraft != null
            ? _mapController.camera.latLngToScreenOffset(
                LatLng(aircraft.position.latitude, aircraft.position.longitude),
              )
            : null;
        final aircraftRegistration = _resolveAircraftRegistration(homeSnapshot);
        final crashDetected = _isCrashDetected(provider, activeAlerts);
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
            _shouldShowDangerOverlay(provider, activeAlerts) &&
            !showCrashOverlay;

        if (_mapReady) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            if (provider.followAircraft && aircraft != null) {
              _mapController.move(center, _mapController.camera.zoom);
            } else if (aircraft == null &&
                provider.route.isEmpty &&
                provider.airports.isEmpty &&
                provider.homeAirport != null) {
              final cameraCenter = _mapController.camera.center;
              final isZeroCenter =
                  cameraCenter.latitude.abs() < 0.0001 &&
                  cameraCenter.longitude.abs() < 0.0001;
              if (isZeroCenter) {
                _mapController.move(center, _mapController.camera.zoom);
              }
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
                  if (showNearbyAirportMarkers && _nearbyAirports.isNotEmpty)
                    MarkerLayer(
                      markers: _nearbyAirports
                          .where(
                            (airport) => _shouldRenderNearbyAirport(
                              airport,
                              provider,
                              homeProvider,
                            ),
                          )
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
                  if (prioritizedPinnedMarkers.isNotEmpty)
                    MarkerLayer(markers: prioritizedPinnedMarkers),
                  if (_selectedAirport != null &&
                      !_isSelectedAirportShownInPinnedLayer(
                        provider,
                        homeProvider,
                      ) &&
                      !isHomeAirportCanvasState)
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
                              highContrastOnBrightBackground:
                                  brightMapBackground,
                            ),
                          ),
                        Marker(
                          point: LatLng(
                            aircraft.position.latitude,
                            aircraft.position.longitude,
                          ),
                          width: 40,
                          height: 40,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _showAircraftInfoPanel =
                                    !_showAircraftInfoPanel;
                              });
                            },
                            child: Tooltip(
                              message: _showAircraftInfoPanel
                                  ? '点击隐藏详情'
                                  : '点击显示详情',
                              waitDuration: const Duration(milliseconds: 500),
                              child: AircraftMarker(
                                heading: aircraft.heading,
                                isDark: theme.brightness == Brightness.dark,
                                highContrastOnBrightBackground:
                                    brightMapBackground,
                              ),
                            ),
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
              if (aircraft != null &&
                  aircraftScreenOffset != null &&
                  _showAircraftInfoPanel)
                Positioned.fill(
                  child: AircraftInfoMiniPanel(
                    aircraftScreenOffset: aircraftScreenOffset,
                    viewportSize: size,
                    scale: scale,
                    brightBackground: brightMapBackground,
                    flightNumber: homeSnapshot.flightNumber,
                    registration: aircraftRegistration,
                    altitude:
                        aircraft.altitude ?? homeSnapshot.flightData.altitude,
                    groundSpeed:
                        aircraft.groundSpeed ??
                        homeSnapshot.flightData.groundSpeed,
                    transponderCode: homeSnapshot.transponderCode,
                    transponderState: homeSnapshot.transponderState,
                  ),
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
                  hasHudTimerStarted: provider.hasHudTimerStarted,
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
                    isDeparture: isSelectedDeparture,
                    isDestination: isSelectedDestination,
                    isAlternate: isSelectedAlternate,
                    setDepartureLabel: MapLocalizationKeys
                        .actionSetAsDepartureAirport
                        .tr(context),
                    setDestinationLabel: MapLocalizationKeys
                        .actionSetAsArrivalAirport
                        .tr(context),
                    setAlternateLabel: MapLocalizationKeys
                        .actionSetAsAlternateAirport
                        .tr(context),
                    onSetDeparture: () async {
                      await _toggleDepartureSelection(homeProvider);
                    },
                    onSetDestination: () async {
                      await _toggleDestinationSelection(homeProvider);
                    },
                    onSetAlternate: () async {
                      await _toggleAlternateSelection(homeProvider);
                    },
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
                    subMessage: _buildDangerSubMessage(context, activeAlerts),
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
    List<MapFlightAlert> activeAlerts,
  ) {
    if (!provider.isConnected) {
      return false;
    }
    return activeAlerts.any(
      (alert) =>
          alert.level == MapFlightAlertLevel.danger ||
          alert.level == MapFlightAlertLevel.warning,
    );
  }

  bool _isCrashDetected(
    MapProvider provider,
    List<MapFlightAlert> activeAlerts,
  ) {
    if (!provider.isConnected) {
      return false;
    }
    return activeAlerts.any((alert) => alert.id == 'crash_danger');
  }

  String _buildDangerSubMessage(
    BuildContext context,
    List<MapFlightAlert> activeAlerts,
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

  bool _shouldRenderNearbyAirport(
    MapAirportMarker airport,
    MapProvider provider,
    HomeProvider homeProvider,
  ) {
    final selected = _selectedAirport;
    if (selected != null &&
        _airportDedupeKey(selected) == _airportDedupeKey(airport)) {
      return false;
    }
    final pinnedKeys = _collectDisplayedPinnedKeys(provider, homeProvider);
    return !pinnedKeys.contains(_airportDedupeKey(airport));
  }

  Set<String> _collectDisplayedPinnedKeys(
    MapProvider provider,
    HomeProvider homeProvider,
  ) {
    final keys = <String>{}
      ..addAll(_collectRolePinnedAirportKeys(provider, homeProvider));
    return keys;
  }

  Set<String> _collectRolePinnedAirportKeys(
    MapProvider provider,
    HomeProvider homeProvider,
  ) {
    final keys = <String>{};
    final homeAirport = provider.homeAirport;
    if (homeAirport != null) {
      keys.add(_airportDedupeKey(homeAirport));
    }
    final departure = homeProvider.departureAirport;
    if (departure != null) {
      keys.add(_airportDedupeKeyFromHomeAirportInfo(departure));
    }
    final destination = homeProvider.destinationAirport;
    if (destination != null) {
      keys.add(_airportDedupeKeyFromHomeAirportInfo(destination));
    }
    final alternate = homeProvider.alternateAirport;
    if (alternate != null) {
      keys.add(_airportDedupeKeyFromHomeAirportInfo(alternate));
    }
    return keys;
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

  String _airportDedupeKeyFromHomeAirportInfo(HomeAirportInfo airport) {
    final normalizedCode = _normalizeAirportCode(airport.icaoCode);
    if (normalizedCode.isNotEmpty) {
      return normalizedCode;
    }
    final lat = airport.latitude.toStringAsFixed(6);
    final lon = airport.longitude.toStringAsFixed(6);
    return '$lat,$lon';
  }

  String _normalizeAirportCode(String? code) {
    if (code == null) {
      return '';
    }
    return code.trim().toUpperCase();
  }

  bool _isBrightMapBackground(MapLayerStyle style) {
    return style != MapLayerStyle.dark;
  }

  String? _resolveAircraftRegistration(HomeDataSnapshot snapshot) {
    final candidates = <String?>[
      snapshot.flightData.aircraftId,
      snapshot.flightData.aircraftIcao,
      snapshot.flightData.aircraftModel,
      snapshot.aircraftTitle,
    ];
    for (final candidate in candidates) {
      final text = candidate?.trim();
      if (text != null && text.isNotEmpty) {
        return text;
      }
    }
    return null;
  }

  HomeAirportInfo _toHomeAirportInfo(MapAirportMarker airport) {
    final displayName = (airport.name ?? '').trim();
    return HomeAirportInfo(
      icaoCode: _normalizeAirportCode(airport.code),
      iataCode: '',
      name: displayName,
      nameChinese: '',
      latitude: airport.position.latitude,
      longitude: airport.position.longitude,
    );
  }

  bool _isSelectedAirportShownInPinnedLayer(
    MapProvider provider,
    HomeProvider homeProvider,
  ) {
    final selected = _selectedAirport;
    if (selected == null) {
      return false;
    }
    final selectedKey = _airportDedupeKey(selected);
    final pinnedKeys = _collectDisplayedPinnedKeys(provider, homeProvider);
    return pinnedKeys.contains(selectedKey);
  }

  bool _isHomeAirportCanvasState(
    MapProvider provider,
    MapAircraftState? aircraft,
  ) {
    return aircraft == null &&
        provider.route.isEmpty &&
        provider.airports.isEmpty &&
        provider.homeAirport != null;
  }

  Marker _buildHomeAirportMarker({
    required MapAirportMarker airport,
    required double scale,
  }) {
    return Marker(
      point: LatLng(airport.position.latitude, airport.position.longitude),
      width: 138 * scale,
      height: 88 * scale,
      child: HomeAirportPin(
        code: _normalizeAirportCode(airport.code),
        scale: scale,
      ),
    );
  }

  List<Marker> _buildPrioritizedPinnedMarkers({
    required MapProvider provider,
    required HomeProvider homeProvider,
    required double scale,
  }) {
    final bundles = <String, _PinnedAirportBundle>{};

    void ensureBundle({
      required String dedupeKey,
      required String code,
      required double latitude,
      required double longitude,
    }) {
      bundles.putIfAbsent(
        dedupeKey,
        () => _PinnedAirportBundle(
          dedupeKey: dedupeKey,
          code: code,
          latitude: latitude,
          longitude: longitude,
        ),
      );
    }

    final homeAirport = provider.homeAirport;
    if (homeAirport != null) {
      final key = _airportDedupeKey(homeAirport);
      ensureBundle(
        dedupeKey: key,
        code: _normalizeAirportCode(homeAirport.code),
        latitude: homeAirport.position.latitude,
        longitude: homeAirport.position.longitude,
      );
      bundles[key]!.isHome = true;
    }

    final departure = homeProvider.departureAirport;
    if (departure != null) {
      final key = _airportDedupeKeyFromHomeAirportInfo(departure);
      ensureBundle(
        dedupeKey: key,
        code: _normalizeAirportCode(departure.icaoCode),
        latitude: departure.latitude,
        longitude: departure.longitude,
      );
      bundles[key]!.isDeparture = true;
    }

    final destination = homeProvider.destinationAirport;
    if (destination != null) {
      final key = _airportDedupeKeyFromHomeAirportInfo(destination);
      ensureBundle(
        dedupeKey: key,
        code: _normalizeAirportCode(destination.icaoCode),
        latitude: destination.latitude,
        longitude: destination.longitude,
      );
      bundles[key]!.isDestination = true;
    }

    final alternate = homeProvider.alternateAirport;
    if (alternate != null) {
      final key = _airportDedupeKeyFromHomeAirportInfo(alternate);
      ensureBundle(
        dedupeKey: key,
        code: _normalizeAirportCode(alternate.icaoCode),
        latitude: alternate.latitude,
        longitude: alternate.longitude,
      );
      bundles[key]!.isAlternate = true;
    }

    final markers = <Marker>[];
    final homeColor = Theme.of(context).colorScheme.tertiary;
    for (final bundle in bundles.values) {
      final tags = <AirportPinTag>[];
      if (bundle.isHome) {
        tags.add(
          AirportPinTag(
            label: MapLocalizationKeys.markerHomeAirport.tr(context),
            color: homeColor,
          ),
        );
      }
      if (bundle.isDeparture) {
        tags.add(
          AirportPinTag(
            label: MapLocalizationKeys.markerDepartureAirport.tr(context),
            color: Colors.blueAccent,
          ),
        );
      }
      if (bundle.isDestination) {
        tags.add(
          AirportPinTag(
            label: MapLocalizationKeys.markerArrivalAirport.tr(context),
            color: Colors.green,
          ),
        );
      }
      if (bundle.isAlternate) {
        tags.add(
          AirportPinTag(
            label: MapLocalizationKeys.markerAlternateAirport.tr(context),
            color: Colors.deepOrangeAccent,
          ),
        );
      }
      final displayCode = bundle.code.isEmpty ? 'AIRPORT' : bundle.code;
      if (tags.length <= 1 && bundle.isHome) {
        markers.add(
          _buildHomeAirportMarker(
            airport: MapAirportMarker(
              code: displayCode,
              position: MapCoordinate(
                latitude: bundle.latitude,
                longitude: bundle.longitude,
              ),
            ),
            scale: scale,
          ),
        );
        continue;
      }

      final rolePin = _resolveSingleRolePinData(bundle);
      if (tags.length <= 1 && rolePin != null) {
        markers.add(
          Marker(
            point: LatLng(bundle.latitude, bundle.longitude),
            width: 138 * scale,
            height: 88 * scale,
            child: AirportRolePin(
              code: displayCode,
              title: rolePin.title,
              icon: rolePin.icon,
              color: rolePin.color,
              scale: scale,
            ),
          ),
        );
        continue;
      }

      final combinedPin = _resolveCombinedPinData(bundle);
      final markerHeight = (96 + tags.length * 20) * scale;
      markers.add(
        Marker(
          point: LatLng(bundle.latitude, bundle.longitude),
          width: 138 * scale,
          height: markerHeight,
          child: CombinedAirportPin(
            code: displayCode,
            tags: tags,
            icon: combinedPin.icon,
            color: combinedPin.color,
            scale: scale,
          ),
        ),
      );
    }
    return markers;
  }

  _RolePinData? _resolveSingleRolePinData(_PinnedAirportBundle bundle) {
    if (bundle.isDeparture) {
      return _RolePinData(
        title: MapLocalizationKeys.markerDepartureAirport.tr(context),
        icon: Icons.flight_takeoff_rounded,
        color: Colors.blueAccent,
      );
    }
    if (bundle.isDestination) {
      return _RolePinData(
        title: MapLocalizationKeys.markerArrivalAirport.tr(context),
        icon: Icons.flag_rounded,
        color: Colors.green,
      );
    }
    if (bundle.isAlternate) {
      return _RolePinData(
        title: MapLocalizationKeys.markerAlternateAirport.tr(context),
        icon: Icons.alt_route_rounded,
        color: Colors.deepOrangeAccent,
      );
    }
    return null;
  }

  _CombinedPinData _resolveCombinedPinData(_PinnedAirportBundle bundle) {
    final tertiary = Theme.of(context).colorScheme.tertiary;
    if (bundle.isHome) {
      return _CombinedPinData(icon: Icons.home_rounded, color: tertiary);
    }
    if (bundle.isDeparture) {
      return const _CombinedPinData(
        icon: Icons.flight_takeoff_rounded,
        color: Colors.blueAccent,
      );
    }
    if (bundle.isDestination) {
      return const _CombinedPinData(
        icon: Icons.flag_rounded,
        color: Colors.green,
      );
    }
    if (bundle.isAlternate) {
      return const _CombinedPinData(
        icon: Icons.alt_route_rounded,
        color: Colors.deepOrangeAccent,
      );
    }
    return const _CombinedPinData(
      icon: Icons.local_airport_rounded,
      color: Colors.blueGrey,
    );
  }

  Future<void> _toggleDepartureSelection(HomeProvider homeProvider) async {
    final selected = _selectedAirport;
    if (selected == null) {
      return;
    }
    final selectedCode = _normalizeAirportCode(selected.code);
    final currentDeparture = _normalizeAirportCode(
      homeProvider.departureAirport?.icaoCode,
    );
    if (selectedCode.isNotEmpty && selectedCode == currentDeparture) {
      await homeProvider.setDeparture(null);
      return;
    }
    await homeProvider.setDeparture(_toHomeAirportInfo(selected));
  }

  Future<void> _toggleDestinationSelection(HomeProvider homeProvider) async {
    final selected = _selectedAirport;
    if (selected == null) {
      return;
    }
    final selectedCode = _normalizeAirportCode(selected.code);
    final currentDestination = _normalizeAirportCode(
      homeProvider.destinationAirport?.icaoCode,
    );
    if (selectedCode.isNotEmpty && selectedCode == currentDestination) {
      await homeProvider.setDestination(null);
      return;
    }
    await homeProvider.setDestination(_toHomeAirportInfo(selected));
  }

  Future<void> _toggleAlternateSelection(HomeProvider homeProvider) async {
    final selected = _selectedAirport;
    if (selected == null) {
      return;
    }
    final selectedCode = _normalizeAirportCode(selected.code);
    final currentAlternate = _normalizeAirportCode(
      homeProvider.alternateAirport?.icaoCode,
    );
    if (selectedCode.isNotEmpty && selectedCode == currentAlternate) {
      await homeProvider.setAlternate(null);
      return;
    }
    await homeProvider.setAlternate(_toHomeAirportInfo(selected));
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
    if (provider.homeAirport != null) {
      final point = provider.homeAirport!.position;
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

class _PinnedAirportBundle {
  final String dedupeKey;
  final String code;
  final double latitude;
  final double longitude;
  bool isHome = false;
  bool isDeparture = false;
  bool isDestination = false;
  bool isAlternate = false;

  _PinnedAirportBundle({
    required this.dedupeKey,
    required this.code,
    required this.latitude,
    required this.longitude,
  });
}

class _RolePinData {
  final String title;
  final IconData icon;
  final Color color;

  const _RolePinData({
    required this.title,
    required this.icon,
    required this.color,
  });
}

class _CombinedPinData {
  final IconData icon;
  final Color color;

  const _CombinedPinData({required this.icon, required this.color});
}
