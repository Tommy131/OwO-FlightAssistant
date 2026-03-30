import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../../core/services/back_handler_service.dart';
import '../../../core/localization/localization_keys.dart';
import '../../../core/services/localization_service.dart';
import '../../../core/widgets/common/dialog.dart';
import '../../common/models/common_models.dart';
import '../../common/providers/common_provider.dart';
import '../localization/map_localization_keys.dart';
import '../models/map_models.dart';
import '../providers/map_provider.dart';
import 'dialogs/map_taxiway_auto_load_dialog.dart';
import 'dialogs/map_taxiway_dialogs.dart';
import 'widgets/map_hud.dart';
import 'widgets/map_layer_picker.dart';
import 'widgets/map_markers.dart';
import 'widgets/map_page_widgets.dart';
import 'widgets/map_right_controls.dart';
import 'widgets/map_taxiway_drawing_controls.dart';
import 'widgets/map_taxiway_route_layers.dart';
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
  static const double _aircraftMarkerLift = 18;
  static const double _aircraftCompassLift = 12;
  static const double _aiAircraftMarkerLift = 14;
  // 颜色调色板已迁移至 map_taxiway_dialogs.dart（kTaxiwayColorHexPalette）

  final MapController _mapController = MapController();
  final GlobalKey _mapKey = GlobalKey();
  final Distance _distance = const Distance();
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
  String? _hoveredAIAircraftId;
  Timer? _airportFetchTimer;
  LatLngBounds? _lastFetchBounds;
  int? _selectedTaxiwayNodeIndex;
  int? _draggingTaxiwayNodeIndex;
  int? _hoveredTaxiwayNodeIndex;
  Offset? _hoveredTaxiwayNodeGlobalPosition;
  int? _hoveredTaxiwaySegmentIndex;
  Offset? _hoveredTaxiwaySegmentGlobalPosition;
  bool _isTaxiwayLoadPromptShowing = false;
  bool _isSavingTaxiwayRoute = false;
  final Set<String> _taxiwayAutoPromptedAirports = <String>{};
   Map<String, dynamic>? _selectedRestrictedAirspaceZone;
  Map<String, dynamic>? _hoveredRestrictedAirspaceZone;
  Offset? _hoveredRestrictedAirspaceGlobalPosition;

  @override
  void initState() {
    super.initState();
    BackHandlerService().register(_onBack);
  }

  @override
  void dispose() {
    BackHandlerService().unregister(_onBack);
    _airportFetchTimer?.cancel();
    super.dispose();
  }

  bool _onBack() {
    if (!mounted) return false;
    // 1. 如果选中了机场，则先关闭机场详情卡片
    if (_selectedAirport != null) {
      setState(() {
        _selectedAirport = null;
        _selectedAirportDetail = null;
      });
      return true;
    }
    if (_selectedRestrictedAirspaceZone != null) {
      setState(() {
        _selectedRestrictedAirspaceZone = null;
      });
      return true;
    }
    // 2. 如果显示了飞机详情面板，则先关闭面板
    if (_showAircraftInfoPanel) {
      setState(() {
        _showAircraftInfoPanel = false;
      });
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MapProvider>(
      builder: (context, provider, child) {
        final homeProvider = context.watch<HomeProvider>();
        _handleReconnectPrompt(provider);
        _handleTaxiwayAutoLoadPrompt(provider);
        final theme = Theme.of(context);
        final size = MediaQuery.sizeOf(context);
        final scale = (size.width / 1280).clamp(0.8, 1.2);
        final aircraft = provider.aircraft;
        final center = _resolveCenter(provider);
        final zoom = _cameraZoom;
        final aviationOverlayUrl = _aviationOverlayUrl(provider.layerStyle);
        final showNearbyAirportMarkers =
            provider.showAirports && zoom >= _nearbyAirportMinZoom;
        final showPressureLayer =
            provider.showWeather && provider.showWeatherPressure;
        final showWindLayer = provider.showWeather && provider.showWeatherWind;
        final showTemperatureLayer =
            provider.showWeather &&
            provider.showWeatherTemperature &&
            !showPressureLayer;
        final showWeatherLegend =
            showPressureLayer || showTemperatureLayer || showWindLayer;
        final canUseRadarRainLayer =
            provider.weatherRadarTileUrlTemplate != null &&
            !provider.isWeatherRadarCoolingDown;
        final rainLayerUrlTemplate = canUseRadarRainLayer
            ? provider.weatherRadarTileUrlTemplate!
            : provider.weatherRainfallTileUrlTemplate;
        final restrictedAirspaceCircles = _buildRestrictedAirspaceCircles(
          provider: provider,
          center: center,
          zoom: zoom,
        );
        final restrictedAirspaceHitNotifier =
            ValueNotifier<LayerHitResult<int>?>(null);
        final selectedAirspaceZone = _resolveSelectedAirspaceZone(provider);
        final hoverHintLocalOffset = _resolveHoverHintLocalOffset();
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
        final isTouchSegmentEditMode =
            !kIsWeb &&
            (defaultTargetPlatform == TargetPlatform.android ||
                defaultTargetPlatform == TargetPlatform.iOS);
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
        final plannedRouteLegs = _buildPlannedRouteLegs(homeProvider);
        final plannedRouteTotalNm = plannedRouteLegs.fold<double>(
          0,
          (sum, leg) => sum + leg.distanceNm,
        );
        final aircraftScreenOffset = _mapReady && aircraft != null
            ? _mapController.camera.latLngToScreenOffset(
                LatLng(aircraft.position.latitude, aircraft.position.longitude),
              )
            : null;
        final hoveredAIAircraft = _resolveHoveredAIAircraft(
          provider.aiAircraft,
        );
        final hoveredAIAircraftScreenOffset =
            _mapReady && hoveredAIAircraft != null
            ? _mapController.camera.latLngToScreenOffset(
                LatLng(
                  hoveredAIAircraft.position.latitude,
                  hoveredAIAircraft.position.longitude,
                ),
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
        final taxiwayNodes = provider.taxiwayNodes;
        final showTaxiwayControls =
            taxiwayNodes.isNotEmpty || provider.isTaxiwayDrawingActive;
        final showTaxiwayEditStatus =
            provider.isTaxiwayDrawingActive &&
            provider.hasUnsavedTaxiwayChanges;
        final showPlannedRouteChip =
            provider.showPlannedRoute && plannedRouteTotalNm > 0;
        final mapRenderObject = _mapKey.currentContext?.findRenderObject();
        final mapRenderBox = mapRenderObject is RenderBox
            ? mapRenderObject
            : null;
        Offset? hoveredNodeLocalOffset;
        Offset? hoveredSegmentLocalOffset;
        if (_hoveredTaxiwayNodeIndex != null &&
            _hoveredTaxiwayNodeIndex! >= 0 &&
            _hoveredTaxiwayNodeIndex! < taxiwayNodes.length &&
            _hoveredTaxiwayNodeGlobalPosition != null &&
            mapRenderBox != null) {
          hoveredNodeLocalOffset = mapRenderBox.globalToLocal(
            _hoveredTaxiwayNodeGlobalPosition!,
          );
        }
        if (_hoveredTaxiwaySegmentIndex != null &&
            _hoveredTaxiwaySegmentIndex! >= 0 &&
            _hoveredTaxiwaySegmentIndex! < taxiwayNodes.length - 1 &&
            _hoveredTaxiwaySegmentGlobalPosition != null &&
            mapRenderBox != null) {
          hoveredSegmentLocalOffset = mapRenderBox.globalToLocal(
            _hoveredTaxiwaySegmentGlobalPosition!,
          );
        }

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
                key: _mapKey,
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
                    final visibleBounds = _mapController.camera.visibleBounds;
                    provider.updateMapViewport(
                      center: MapCoordinate(
                        latitude: _mapController.camera.center.latitude,
                        longitude: _mapController.camera.center.longitude,
                      ),
                      minLat: visibleBounds.southWest.latitude,
                      maxLat: visibleBounds.northEast.latitude,
                      minLon: visibleBounds.southWest.longitude,
                      maxLon: visibleBounds.northEast.longitude,
                    );
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

                    final nextCenter = position.center;
                    final visibleBounds = position.visibleBounds;
                    provider.updateMapViewport(
                      center: MapCoordinate(
                        latitude: nextCenter.latitude,
                        longitude: nextCenter.longitude,
                      ),
                      minLat: visibleBounds.southWest.latitude,
                      maxLat: visibleBounds.northEast.latitude,
                      minLon: visibleBounds.southWest.longitude,
                      maxLon: visibleBounds.northEast.longitude,
                    );
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
                  onTap: (_, point) {
                    if (!provider.isTaxiwayDrawingActive) {
                      return;
                    }
                    setState(() {
                      _selectedTaxiwayNodeIndex = null;
                    });
                    provider.addTaxiwayRoutePoint(
                      MapCoordinate(
                        latitude: point.latitude,
                        longitude: point.longitude,
                      ),
                    );
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
                  if (provider.showWeather && provider.showWeatherRainfall)
                    Opacity(
                      opacity: 0.6,
                      child: TileLayer(
                        key: ValueKey(
                          'weather-rain-${canUseRadarRainLayer ? 'radar-${provider.weatherRadarTimestamp}' : 'overlay'}-${provider.tileReloadToken}',
                        ),
                        urlTemplate: rainLayerUrlTemplate,
                        userAgentPackageName: 'com.owo.flight_assistant',
                        tileUpdateTransformer: _weatherRadarTransformer,
                        maxNativeZoom: canUseRadarRainLayer ? 7 : 11,
                        minZoom: 3,
                        errorTileCallback: (tile, error, stackTrace) {
                          if (canUseRadarRainLayer) {
                            provider.handleWeatherRadarTileError(error);
                          }
                        },
                      ),
                    ),
                  if (showPressureLayer)
                    Opacity(
                      opacity: 0.42,
                      child: TileLayer(
                        key: ValueKey(
                          'weather-pressure-${provider.tileReloadToken}',
                        ),
                        urlTemplate: provider.weatherPressureTileUrlTemplate,
                        userAgentPackageName: 'com.owo.flight_assistant',
                        tileUpdateTransformer: _weatherRadarTransformer,
                        maxNativeZoom: 11,
                        minZoom: 3,
                        errorTileCallback: (tile, error, stackTrace) {
                          provider.handleWeatherRadarTileError(error);
                        },
                      ),
                    ),
                  if (showTemperatureLayer)
                    Opacity(
                      opacity: 0.36,
                      child: TileLayer(
                        key: ValueKey(
                          'weather-temp-${provider.tileReloadToken}',
                        ),
                        urlTemplate: provider.weatherTemperatureTileUrlTemplate,
                        userAgentPackageName: 'com.owo.flight_assistant',
                        tileUpdateTransformer: _weatherRadarTransformer,
                        maxNativeZoom: 11,
                        minZoom: 3,
                        errorTileCallback: (tile, error, stackTrace) {
                          provider.handleWeatherRadarTileError(error);
                        },
                      ),
                    ),
                  if (showWindLayer)
                    Opacity(
                      opacity: 0.5,
                      child: TileLayer(
                        key: ValueKey(
                          'weather-wind-${provider.tileReloadToken}',
                        ),
                        urlTemplate: provider.weatherWindTileUrlTemplate,
                        userAgentPackageName: 'com.owo.flight_assistant',
                        tileUpdateTransformer: _weatherRadarTransformer,
                        maxNativeZoom: 11,
                        minZoom: 3,
                        errorTileCallback: (tile, error, stackTrace) {
                          provider.handleWeatherRadarTileError(error);
                        },
                      ),
                    ),
                  if (showWindLayer)
                    MarkerLayer(
                      markers: _buildHighAltitudeWindMarkers(
                        provider: provider,
                        scale: scale,
                      ),
                    ),
                  if (provider.showRestrictedAirspace)
                    MouseRegion(
                      onHover: (event) {
                        final hitResult = restrictedAirspaceHitNotifier.value;
                        final hitIndex = hitResult?.hitValues.isNotEmpty == true
                            ? hitResult!.hitValues.first
                            : null;
                        final zone = _resolveRestrictedAirspaceZoneByHitIndex(
                          provider,
                          hitIndex,
                        );
                        if (zone == null) {
                          if (_hoveredRestrictedAirspaceZone != null ||
                              _hoveredRestrictedAirspaceGlobalPosition !=
                                  null) {
                            setState(() {
                              _hoveredRestrictedAirspaceZone = null;
                              _hoveredRestrictedAirspaceGlobalPosition = null;
                            });
                          }
                          return;
                        }
                        setState(() {
                          _hoveredRestrictedAirspaceZone = zone;
                          _hoveredRestrictedAirspaceGlobalPosition =
                              event.position;
                        });
                      },
                      onExit: (_) {
                        if (_hoveredRestrictedAirspaceZone != null ||
                            _hoveredRestrictedAirspaceGlobalPosition != null) {
                          setState(() {
                            _hoveredRestrictedAirspaceZone = null;
                            _hoveredRestrictedAirspaceGlobalPosition = null;
                          });
                        }
                      },
                      child: GestureDetector(
                        behavior: HitTestBehavior.deferToChild,
                        onTapDown: (_) {
                          final hitResult = restrictedAirspaceHitNotifier.value;
                          if (hitResult == null ||
                              hitResult.hitValues.isEmpty) {
                            return;
                          }
                          final hitIndex = hitResult.hitValues.first;
                          final zone = _resolveRestrictedAirspaceZoneByHitIndex(
                            provider,
                            hitIndex,
                          );
                          if (zone == null) {
                            return;
                          }
                          setState(() {
                            _selectedRestrictedAirspaceZone = zone;
                          });
                        },
                        child: CircleLayer<int>(
                          circles: restrictedAirspaceCircles,
                          hitNotifier: restrictedAirspaceHitNotifier,
                        ),
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
                  if (provider.showPlannedRoute && plannedRouteLegs.isNotEmpty)
                    PolylineLayer(
                      polylines: plannedRouteLegs
                          .map(
                            (leg) => Polyline(
                              points: _buildPlannedRouteCurvePoints(leg),
                              color: Colors.amberAccent.withValues(alpha: 0.82),
                              strokeWidth: (3.2 * scale).clamp(2.2, 4.6),
                            ),
                          )
                          .toList(),
                    ),
                  if (provider.showPlannedRoute && plannedRouteLegs.isNotEmpty)
                    MarkerLayer(
                      markers: _buildPlannedRouteDistanceMarkers(
                        legs: plannedRouteLegs,
                        scale: scale,
                      ),
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
                  if (provider.takeoffPoint != null ||
                      provider.landingPoint != null)
                    _buildFlightEventLayer(provider, context),
                  if (provider.aiAircraft.isNotEmpty)
                    _buildAIAircraftLayer(
                      provider: provider,
                      scale: scale,
                      brightMapBackground: brightMapBackground,
                      layerStyle: provider.layerStyle,
                    ),
                  if (provider.showCustomTaxiwayRoute &&
                      provider.taxiwayRoutePoints.isNotEmpty)
                    TaxiwayRoutePolylineLayer(
                      nodes: taxiwayNodes,
                      segments: provider.taxiwaySegments,
                      completedSegmentIndexes:
                          provider.completedTaxiwaySegmentIndexes,
                      scale: scale,
                      enableSegmentMenu: provider.isTaxiwayDrawingActive,
                      onSegmentSecondaryTap: (segmentIndex, globalPosition) {
                        _showTaxiwaySegmentContextMenu(
                          provider: provider,
                          segmentIndex: segmentIndex,
                          globalPosition: globalPosition,
                        );
                      },
                      onSegmentTap:
                          !provider.isTaxiwayDrawingActive &&
                              isTouchSegmentEditMode
                          ? (segmentIndex, _) {
                              _showTaxiwaySegmentDetail(provider, segmentIndex);
                            }
                          : null,
                      onSegmentHover: !isTouchSegmentEditMode
                          ? (segmentIndex, globalPosition) {
                              _onTaxiwaySegmentHover(
                                segmentIndex: segmentIndex,
                                globalPosition: globalPosition,
                              );
                            }
                          : null,
                      onSegmentHoverEnd: !isTouchSegmentEditMode
                          ? _clearTaxiwaySegmentHover
                          : null,
                      onSegmentLongPress: provider.isTaxiwayDrawingActive
                          ? (segmentIndex, globalPosition) {
                              _showTaxiwaySegmentContextMenu(
                                provider: provider,
                                segmentIndex: segmentIndex,
                                globalPosition: globalPosition,
                              );
                            }
                          : null,
                    ),
                  if (provider.showCustomTaxiwayRoute &&
                      provider.taxiwayRoutePoints.isNotEmpty)
                    TaxiwayRoutePointMarkerLayer(
                      nodes: taxiwayNodes,
                      completedNodeIndexes:
                          provider.completedTaxiwayNodeIndexes,
                      scale: scale,
                      selectedIndex: _selectedTaxiwayNodeIndex,
                      draggingIndex: provider.isTaxiwayDrawingActive
                          ? _draggingTaxiwayNodeIndex
                          : null,
                      onNodeTap: provider.isTaxiwayDrawingActive
                          ? (index) {
                              _showTaxiwayNodeEditor(provider, index);
                            }
                          : (!provider.isTaxiwayDrawingActive &&
                                isTouchSegmentEditMode)
                          ? (index) {
                              _showTaxiwayNodeDetail(provider, index);
                            }
                          : null,
                      onNodeDragStart: provider.isTaxiwayDrawingActive
                          ? (index) {
                              setState(() {
                                _selectedTaxiwayNodeIndex = index;
                                _draggingTaxiwayNodeIndex = index;
                              });
                            }
                          : null,
                      onNodeDragUpdate: provider.isTaxiwayDrawingActive
                          ? (index, globalPosition) {
                              _onTaxiwayNodeDragUpdate(
                                provider: provider,
                                index: index,
                                globalPosition: globalPosition,
                              );
                            }
                          : null,
                      onNodeDragEnd: provider.isTaxiwayDrawingActive
                          ? () {
                              setState(() {
                                _draggingTaxiwayNodeIndex = null;
                              });
                              if (!mounted) {
                                return;
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    MapLocalizationKeys
                                        .taxiwayNodePositionUpdated
                                        .tr(context),
                                  ),
                                  duration: Duration(milliseconds: 900),
                                ),
                              );
                            }
                          : null,
                      onNodeHover: (index, globalPosition) {
                        _onTaxiwayNodeHover(
                          index: index,
                          globalPosition: globalPosition,
                        );
                      },
                      onNodeHoverEnd: _clearTaxiwayNodeHover,
                    ),
                  if (provider.showTerrainWarning && aircraft != null)
                    CircleLayer(
                      circles: _buildTerrainAwarenessCircles(
                        aircraft: aircraft,
                        activeAlerts: activeAlerts,
                      ),
                    ),
                  if (aircraft != null)
                    _buildPlayerAircraftLayer(
                      context: context,
                      provider: provider,
                      aircraft: aircraft,
                      scale: scale,
                      brightMapBackground: brightMapBackground,
                      isDarkTheme: theme.brightness == Brightness.dark,
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
              if (hoveredAIAircraft != null &&
                  hoveredAIAircraftScreenOffset != null)
                Positioned.fill(
                  child: AircraftInfoMiniPanel(
                    aircraftScreenOffset: hoveredAIAircraftScreenOffset,
                    viewportSize: size,
                    scale: scale,
                    brightBackground: brightMapBackground,
                    flightNumber: hoveredAIAircraft.type,
                    registration: hoveredAIAircraft.id,
                    altitude: hoveredAIAircraft.altitude,
                    groundSpeed: hoveredAIAircraft.groundSpeed,
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
                  onToggleWeatherRainfall: provider.toggleWeatherRainfall,
                  onToggleWeatherWind: provider.toggleWeatherWind,
                  onToggleWeatherPressure: provider.toggleWeatherPressure,
                  onToggleWeatherTemperature: provider.toggleWeatherTemperature,
                  onToggleRestrictedAirspace: provider.toggleRestrictedAirspace,
                  onToggleTerrainWarning: provider.toggleTerrainWarning,
                  onToggleCustomTaxiway: provider.toggleCustomTaxiway,
                  onToggleTaxiwayDrawing: provider.toggleTaxiwayDrawing,
                  showRoute: provider.showRoute,
                  showAirports: provider.showAirports,
                  showRunways: provider.showRunways,
                  showParkings: provider.showParkings,
                  showCompass: provider.showCompass,
                  showWeather: provider.showWeather,
                  showWeatherRainfall: provider.showWeatherRainfall,
                  showWeatherWind: provider.showWeatherWind,
                  showWeatherPressure: provider.showWeatherPressure,
                  showWeatherTemperature: provider.showWeatherTemperature,
                  showRestrictedAirspace: provider.showRestrictedAirspace,
                  showTerrainWarning: provider.showTerrainWarning,
                  showCustomTaxiway: provider.showCustomTaxiwayRoute,
                  isTaxiwayDrawingActive: provider.isTaxiwayDrawingActive,
                  showTaxiwayControls: showTaxiwayControls,
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
                  showPlannedRoute: provider.showPlannedRoute,
                  showPlannedRouteControl: plannedRouteLegs.isNotEmpty,
                  onFollowAircraftChanged: (value) {
                    if (provider.followAircraft != value) {
                      provider.toggleFollowAircraft();
                    }
                  },
                  onTogglePlannedRoute: provider.togglePlannedRoute,
                  onShowLayerPicker: () {
                    _showLayerPicker(context, provider);
                  },
                  isMapReady: _mapReady,
                  isConnected: provider.isConnected,
                ),
              ),
              if (provider.isTaxiwayDrawingActive)
                Positioned(
                  left: 20 * scale,
                  top: 250 * scale,
                  child: MapTaxiwayDrawingControls(
                    scale: scale,
                    canUndo: provider.canUndoTaxiwayRoute,
                    canRedo: provider.canRedoTaxiwayRoute,
                    hasRoute: provider.taxiwayRoutePoints.isNotEmpty,
                    canImport: true,
                    onUndo: provider.undoTaxiwayRoutePoint,
                    onRedo: provider.redoTaxiwayRoutePoint,
                    onClear: provider.clearTaxiwayRoute,
                    onSave: () => _saveCustomTaxiwayRoute(provider),
                    onImport: () => _importCustomTaxiwayRoute(provider),
                  ),
                ),
              if (showTaxiwayEditStatus ||
                  showPlannedRouteChip ||
                  showWeatherLegend)
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  bottom: _plannedRouteChipBottom(scale),
                  left: 20 * scale,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (showTaxiwayEditStatus)
                        Container(
                          constraints: BoxConstraints(maxWidth: 380 * scale),
                          padding: EdgeInsets.symmetric(
                            horizontal: 12 * scale,
                            vertical: 8 * scale,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(196),
                            borderRadius: BorderRadius.circular(12 * scale),
                            border: Border.all(
                              color: Colors.orangeAccent,
                              width: 1.2,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.edit_rounded,
                                size: 16 * scale,
                                color: Colors.orangeAccent,
                              ),
                              SizedBox(width: 8 * scale),
                              Text(
                                MapLocalizationKeys.taxiwayEditUnsaved.tr(
                                  context,
                                ),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12 * scale,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(width: 10 * scale),
                              FilledButton.icon(
                                onPressed:
                                    provider.taxiwayRoutePoints.isNotEmpty &&
                                        !_isSavingTaxiwayRoute
                                    ? () => _saveCustomTaxiwayRoute(provider)
                                    : null,
                                icon: _isSavingTaxiwayRoute
                                    ? SizedBox(
                                        width: 14 * scale,
                                        height: 14 * scale,
                                        child: const CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Icon(
                                        Icons.save_rounded,
                                        size: 14 * scale,
                                      ),
                                label: Text(
                                  _isSavingTaxiwayRoute
                                      ? MapLocalizationKeys
                                            .taxiwaySaveInProgress
                                            .tr(context)
                                      : LocalizationKeys.save.tr(context),
                                  style: TextStyle(fontSize: 11 * scale),
                                ),
                                style: FilledButton.styleFrom(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 10 * scale,
                                    vertical: 6 * scale,
                                  ),
                                  minimumSize: Size(0, 28 * scale),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (showTaxiwayEditStatus &&
                          (showWeatherLegend || showPlannedRouteChip))
                        SizedBox(width: 8 * scale),
                      if (showWeatherLegend || showPlannedRouteChip)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (showWeatherLegend)
                              _WeatherLegendChip(
                                scale: scale,
                                title: showPressureLayer
                                    ? MapLocalizationKeys.toggleWeatherPressure
                                          .tr(context)
                                    : showTemperatureLayer
                                    ? MapLocalizationKeys
                                          .toggleWeatherTemperature
                                          .tr(context)
                                    : MapLocalizationKeys.toggleWeatherWind.tr(
                                        context,
                                      ),
                                unit: showPressureLayer
                                    ? 'hPa'
                                    : showTemperatureLayer
                                    ? '°C'
                                    : 'kt',
                                startLabel: showPressureLayer
                                    ? '970'
                                    : showTemperatureLayer
                                    ? '-35'
                                    : '0',
                                endLabel: showPressureLayer
                                    ? '1045'
                                    : showTemperatureLayer
                                    ? '45'
                                    : '120',
                                colors: showPressureLayer
                                    ? const [
                                        Color(0xFF462080),
                                        Color(0xFF2B77AA),
                                        Color(0xFF4AA85E),
                                        Color(0xFFEDC948),
                                      ]
                                    : showTemperatureLayer
                                    ? const [
                                        Color(0xFF3252B9),
                                        Color(0xFF3DA7D8),
                                        Color(0xFF7BD06F),
                                        Color(0xFFF5C44B),
                                        Color(0xFFE0574A),
                                      ]
                                    : const [
                                        Color(0xFF173B8F),
                                        Color(0xFF2D7FC9),
                                        Color(0xFF5BC4CC),
                                        Color(0xFF7AD37C),
                                        Color(0xFFD6DE55),
                                      ],
                              ),
                            if (showWeatherLegend && showPlannedRouteChip)
                              SizedBox(height: 8 * scale),
                            if (showPlannedRouteChip)
                              _PlannedRouteTotalChip(
                                scale: scale,
                                text:
                                    '${MapLocalizationKeys.plannedRouteTotal.tr(context)}: ${plannedRouteTotalNm.toStringAsFixed(1)} NM',
                              ),
                          ],
                        ),
                    ],
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
              if (provider.showRestrictedAirspace &&
                  selectedAirspaceZone != null)
                Positioned.fill(
                  child: _RestrictedAirspaceDraggablePanel(
                    key: ValueKey(
                      selectedAirspaceZone['id']?.toString() ??
                          '${selectedAirspaceZone['center_lat']},${selectedAirspaceZone['center_lon']}',
                    ),
                    zone: selectedAirspaceZone,
                    scale: scale,
                    viewportSize: size,
                    anchorOffset: _resolveAirspaceZoneScreenOffset(
                      selectedAirspaceZone,
                    ),
                    onClose: () {
                      setState(() {
                        _selectedRestrictedAirspaceZone = null;
                      });
                    },
                  ),
                ),
              if (provider.showRestrictedAirspace &&
                  _hoveredRestrictedAirspaceZone != null &&
                  hoverHintLocalOffset != null)
                Positioned(
                  left: (hoverHintLocalOffset.dx + 14 * scale).clamp(
                    8.0,
                    size.width - 250 * scale,
                  ),
                  top: (hoverHintLocalOffset.dy - 52 * scale).clamp(
                    8.0,
                    size.height - 40 * scale,
                  ),
                  child: _RestrictedAirspaceHoverHint(
                    zone: _hoveredRestrictedAirspaceZone!,
                    scale: scale,
                  ),
                ),
              if (_hoveredTaxiwayNodeIndex != null &&
                  _hoveredTaxiwayNodeIndex! >= 0 &&
                  _hoveredTaxiwayNodeIndex! < taxiwayNodes.length &&
                  hoveredNodeLocalOffset != null)
                Positioned(
                  left: (hoveredNodeLocalOffset.dx + 16 * scale).clamp(
                    8.0,
                    size.width - 248 * scale,
                  ),
                  top: (hoveredNodeLocalOffset.dy - 108 * scale).clamp(
                    8.0,
                    size.height - 100 * scale,
                  ),
                  child: TaxiwayNodeInfoCard(
                    scale: scale,
                    index: _hoveredTaxiwayNodeIndex!,
                    node: taxiwayNodes[_hoveredTaxiwayNodeIndex!],
                    headingDeg: _computeTaxiwayNodeHeading(
                      taxiwayNodes,
                      _hoveredTaxiwayNodeIndex!,
                    ),
                  ),
                ),
              if (!isTouchSegmentEditMode &&
                  _hoveredTaxiwaySegmentIndex != null &&
                  _hoveredTaxiwaySegmentIndex! >= 0 &&
                  _hoveredTaxiwaySegmentIndex! < taxiwayNodes.length - 1 &&
                  hoveredSegmentLocalOffset != null)
                Positioned(
                  left: (hoveredSegmentLocalOffset.dx + 16 * scale).clamp(
                    8.0,
                    size.width - 308 * scale,
                  ),
                  top: (hoveredSegmentLocalOffset.dy - 126 * scale).clamp(
                    8.0,
                    size.height - 120 * scale,
                  ),
                  child: TaxiwaySegmentInfoCard(
                    scale: scale,
                    segmentIndex: _hoveredTaxiwaySegmentIndex!,
                    startNode: taxiwayNodes[_hoveredTaxiwaySegmentIndex!],
                    endNode: taxiwayNodes[_hoveredTaxiwaySegmentIndex! + 1],
                    segment: _resolveTaxiwaySegmentByIndex(
                      provider,
                      _hoveredTaxiwaySegmentIndex!,
                    ),
                    distanceMeters: _computeTaxiwaySegmentDistanceMeters(
                      taxiwayNodes[_hoveredTaxiwaySegmentIndex!],
                      taxiwayNodes[_hoveredTaxiwaySegmentIndex! + 1],
                    ),
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

  /// 处理滑行路线自动加载提示逻辑。
  ///
  /// 当检测到当前机场存在已保存的滑行路线文件时，弹出提示对话框。
  /// 对话框逻辑委托至 [showTaxiwayAutoLoadDialog]。
  void _handleTaxiwayAutoLoadPrompt(MapProvider provider) {
    final nearestIcao = provider.currentNearestAirportIcao
        ?.trim()
        .toUpperCase();
    final selectedIcao = _normalizeAirportCode(_selectedAirport?.code);
    final homeIcao = _normalizeAirportCode(provider.homeAirport?.code);
    final resolvedIcao = nearestIcao != null && nearestIcao.isNotEmpty
        ? nearestIcao
        : (selectedIcao.isNotEmpty
              ? selectedIcao
              : (homeIcao.isNotEmpty ? homeIcao : null));
    if (resolvedIcao == null || resolvedIcao.isEmpty) {
      return;
    }
    if (provider.hasLoadedCustomTaxiwayForAirport(resolvedIcao)) {
      _taxiwayAutoPromptedAirports.add(resolvedIcao);
      return;
    }
    if (_isTaxiwayLoadPromptShowing ||
        _taxiwayAutoPromptedAirports.contains(resolvedIcao)) {
      return;
    }
    _isTaxiwayLoadPromptShowing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        if (!mounted) {
          return;
        }
        final files = await provider.listTaxiwayRouteFilesForAirport(
          icao: resolvedIcao,
        );
        if (!mounted || files.isEmpty) {
          return;
        }
        _taxiwayAutoPromptedAirports.add(resolvedIcao);
        // 委托对话框逻辑至专属函数
        await showTaxiwayAutoLoadDialog(
          context: context,
          resolvedIcao: resolvedIcao,
          files: files,
          provider: provider,
          onLoadResult: (message) {
            if (mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(message)));
            }
          },
        );
      } finally {
        _isTaxiwayLoadPromptShowing = false;
      }
    });
  }

  Widget _buildFlightEventLayer(MapProvider provider, BuildContext context) {
    return MarkerLayer(
      markers: [
        if (provider.takeoffPoint != null)
          Marker(
            point: LatLng(
              provider.takeoffPoint!.latitude,
              provider.takeoffPoint!.longitude,
            ),
            width: 78,
            height: 68,
            child: FlightEventMarker(
              icon: Icons.flight_takeoff,
              label: MapLocalizationKeys.labelTakeoff.tr(context),
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
            child: FlightEventMarker(
              icon: Icons.flight_land,
              label: MapLocalizationKeys.labelLanding.tr(context),
              color: Colors.greenAccent,
            ),
          ),
      ],
    );
  }

  Widget _buildAIAircraftLayer({
    required MapProvider provider,
    required double scale,
    required bool brightMapBackground,
    required dynamic layerStyle,
  }) {
    final palette = _resolveAIAircraftLabelPalette(
      brightMapBackground: brightMapBackground,
      layerStyle: layerStyle,
      themeBrightness: Theme.of(context).brightness,
    );
    return MarkerLayer(
      markers: provider.aiAircraft
          .map(
            (ai) => Marker(
              point: LatLng(ai.position.latitude, ai.position.longitude),
              width: 140 * scale,
              height: 80 * scale,
              child: Transform.translate(
                offset: Offset(0, -_aiAircraftMarkerLift * scale),
                child: MouseRegion(
                  onEnter: (_) {
                    if (_hoveredAIAircraftId == ai.id) {
                      return;
                    }
                    setState(() {
                      _hoveredAIAircraftId = ai.id;
                    });
                  },
                  onExit: (_) {
                    if (_hoveredAIAircraftId != ai.id) {
                      return;
                    }
                    setState(() {
                      _hoveredAIAircraftId = null;
                    });
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6 * scale,
                          vertical: 2 * scale,
                        ),
                        decoration: BoxDecoration(
                          color: palette.metricsBackground,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${_formatAltitudeFeet(ai.altitude)} · ${_formatHeadingDeg(ai.heading)} · ${_formatGroundSpeedKts(ai.groundSpeed)}',
                          style: TextStyle(
                            fontSize: 9 * scale,
                            color: palette.metricsText,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      SizedBox(height: 3 * scale),
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: 96 * scale),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 6 * scale,
                            vertical: 2 * scale,
                          ),
                          decoration: BoxDecoration(
                            color: palette.identityBackground,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: palette.identityBorder,
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            _resolveAIAircraftLabel(ai),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 8.5 * scale,
                              color: palette.identityText,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 4 * scale),
                      SizedBox(
                        width: 26 * scale,
                        height: 26 * scale,
                        child: _buildAIAircraftMarkerIcon(
                          heading: ai.heading,
                          scale: scale,
                          brightMapBackground: brightMapBackground,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
          .toList(growable: false),
    );
  }

  Widget _buildPlayerAircraftLayer({
    required BuildContext context,
    required MapProvider provider,
    required MapAircraftState aircraft,
    required double scale,
    required bool brightMapBackground,
    required bool isDarkTheme,
  }) {
    return MarkerLayer(
      markers: [
        if (provider.showCompass)
          Marker(
            point: LatLng(
              aircraft.position.latitude,
              aircraft.position.longitude,
            ),
            width: 190 * scale,
            height: 190 * scale,
            child: Transform.translate(
              offset: Offset(0, -_aircraftCompassLift * scale),
              child: AircraftCompassRing(
                heading: aircraft.heading,
                headingTarget: aircraft.headingTarget,
                mapRotation: _mapReady ? _mapController.camera.rotation : 0,
                scale: scale,
                highContrastOnBrightBackground: brightMapBackground,
              ),
            ),
          ),
        Marker(
          point: LatLng(
            aircraft.position.latitude,
            aircraft.position.longitude,
          ),
          width: 40,
          height: 40,
          child: Transform.translate(
            offset: Offset(0, -_aircraftMarkerLift * scale),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _showAircraftInfoPanel = !_showAircraftInfoPanel;
                });
              },
              child: Tooltip(
                message: _showAircraftInfoPanel
                    ? MapLocalizationKeys.tooltipHideDetail.tr(context)
                    : MapLocalizationKeys.tooltipShowDetail.tr(context),
                waitDuration: const Duration(milliseconds: 500),
                child: AircraftMarker(
                  heading: aircraft.heading,
                  isDark: isDarkTheme,
                  highContrastOnBrightBackground: brightMapBackground,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _formatAltitudeFeet(double? altitude) {
    if (altitude == null || altitude.isNaN || altitude.isInfinite) {
      return '-- ft';
    }
    return '${altitude.round()} ft';
  }

  String _formatHeadingDeg(double? heading) {
    if (heading == null || heading.isNaN || heading.isInfinite) {
      return '--°';
    }
    final normalized = ((heading % 360) + 360) % 360;
    return '${normalized.round()}°';
  }

  String _formatGroundSpeedKts(double? speed) {
    if (speed == null || speed.isNaN || speed.isInfinite) {
      return '-- kt';
    }
    return '${speed.round()} kt';
  }

  String _resolveAIAircraftLabel(MapAIAircraftState aircraft) {
    final id = aircraft.id.trim();
    final type = aircraft.type?.trim();
    if (id.isNotEmpty && type != null && type.isNotEmpty) {
      return '${id.toUpperCase()} / ${type.toUpperCase()}';
    }
    if (id.isNotEmpty) {
      return id.toUpperCase();
    }
    if (type != null && type.isNotEmpty) {
      return type.toUpperCase();
    }
    return 'AI';
  }

  _AIAircraftLabelPalette _resolveAIAircraftLabelPalette({
    required bool brightMapBackground,
    required dynamic layerStyle,
    required Brightness themeBrightness,
  }) {
    final lowerStyle = layerStyle.toString().toLowerCase();
    Color estimatedMapSurface;
    if (lowerStyle.contains('dark')) {
      estimatedMapSurface = const Color(0xFF232934);
    } else if (lowerStyle.contains('taxiway')) {
      estimatedMapSurface = const Color(0xFFDDE2E9);
    } else if (lowerStyle.contains('terrain')) {
      estimatedMapSurface = const Color(0xFFB3C2A5);
    } else if (lowerStyle.contains('satellite')) {
      estimatedMapSurface = const Color(0xFF7B8A71);
    } else {
      estimatedMapSurface = brightMapBackground
          ? const Color(0xFFDCE2EA)
          : const Color(0xFF2B3240);
    }
    final toneFilter = themeBrightness == Brightness.dark
        ? Colors.black.withValues(alpha: 0.08)
        : Colors.white.withValues(alpha: 0.08);
    final backdrop = Color.alphaBlend(toneFilter, estimatedMapSurface);
    final whiteContrast = _contrastRatio(Colors.white, backdrop);
    final blackContrast = _contrastRatio(Colors.black, backdrop);
    final useDarkText = blackContrast >= whiteContrast;

    final metricsBackground = useDarkText
        ? Colors.white.withValues(alpha: 0.88)
        : Colors.black.withValues(alpha: 0.74);
    final metricsText = useDarkText ? Colors.black87 : Colors.white;
    final identityBackground = useDarkText
        ? Colors.white.withValues(alpha: 0.7)
        : Colors.black.withValues(alpha: 0.52);
    final identityText = useDarkText ? Colors.black87 : Colors.white70;
    final identityBorder = useDarkText
        ? Colors.black.withValues(alpha: 0.18)
        : Colors.white.withValues(alpha: 0.32);

    return _AIAircraftLabelPalette(
      metricsBackground: metricsBackground,
      metricsText: metricsText,
      identityBackground: identityBackground,
      identityText: identityText,
      identityBorder: identityBorder,
    );
  }

  double _contrastRatio(Color a, Color b) {
    final luminanceA = a.computeLuminance();
    final luminanceB = b.computeLuminance();
    final light = math.max(luminanceA, luminanceB);
    final dark = math.min(luminanceA, luminanceB);
    return (light + 0.05) / (dark + 0.05);
  }

  MapAIAircraftState? _resolveHoveredAIAircraft(
    List<MapAIAircraftState> items,
  ) {
    final hoveredId = _hoveredAIAircraftId;
    if (hoveredId == null || hoveredId.isEmpty) {
      return null;
    }
    for (final item in items) {
      if (item.id == hoveredId) {
        return item;
      }
    }
    return null;
  }

  Widget _buildAIAircraftMarkerIcon({
    required double? heading,
    required double scale,
    required bool brightMapBackground,
  }) {
    final backgroundColor = brightMapBackground
        ? const Color(0xFF2B4C7E)
        : const Color(0xFF1A365D);
    final borderColor = brightMapBackground
        ? Colors.white.withValues(alpha: 0.8)
        : Colors.black.withValues(alpha: 0.45);
    final iconColor = Colors.white;
    final angle = heading == null ? 0.0 : heading * (math.pi / 180.0);
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: backgroundColor,
        border: Border.all(color: borderColor, width: 1.2 * scale),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 6 * scale,
            offset: Offset(0, 2 * scale),
          ),
        ],
      ),
      child: Center(
        child: Transform.rotate(
          angle: angle,
          child: Icon(
            Icons.airplanemode_active_rounded,
            size: 16 * scale,
            color: iconColor,
          ),
        ),
      ),
    );
  }

  Future<void> _showReconnectPromptDialog(MapProvider provider) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(MapLocalizationKeys.reconnectPromptTitle.tr(context)),
          content: Text(MapLocalizationKeys.reconnectPromptContent.tr(context)),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: Text(MapLocalizationKeys.reconnectKeepRoute.tr(context)),
            ),
            TextButton(
              onPressed: () {
                provider.clearRoute();
                Navigator.of(dialogContext).pop();
              },
              style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
              child: Text(MapLocalizationKeys.clearRoute.tr(context)),
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

  Future<void> _saveCustomTaxiwayRoute(MapProvider provider) async {
    if (_isSavingTaxiwayRoute) {
      return;
    }
    setState(() {
      _isSavingTaxiwayRoute = true;
    });
    try {
      final result = await provider.exportTaxiwayRouteToFile();
      if (!mounted) {
        return;
      }
      final messenger = ScaffoldMessenger.of(context);
      if (result > 0) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(MapLocalizationKeys.taxiwayExportSuccess.tr(context)),
          ),
        );
        return;
      }
      if (result < 0) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(MapLocalizationKeys.taxiwayNoRouteToSave.tr(context)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSavingTaxiwayRoute = false;
        });
      } else {
        _isSavingTaxiwayRoute = false;
      }
    }
  }

  Future<void> _importCustomTaxiwayRoute(MapProvider provider) async {
    try {
      final result = await provider.importTaxiwayRouteFromFile();
      if (!mounted) {
        return;
      }
      final messenger = ScaffoldMessenger.of(context);
      if (result > 0) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(MapLocalizationKeys.taxiwayImportSuccess.tr(context)),
          ),
        );
        return;
      }
      if (result == 0) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(MapLocalizationKeys.taxiwayImportInvalid.tr(context)),
          ),
        );
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(MapLocalizationKeys.taxiwayImportInvalid.tr(context)),
        ),
      );
    }
  }

  void _onTaxiwayNodeDragUpdate({
    required MapProvider provider,
    required int index,
    required Offset globalPosition,
  }) {
    if (!provider.isTaxiwayDrawingActive) {
      return;
    }
    final mapContext = _mapKey.currentContext;
    if (!_mapReady || mapContext == null) {
      return;
    }
    final renderBox = mapContext.findRenderObject();
    if (renderBox is! RenderBox) {
      return;
    }
    final localOffset = renderBox.globalToLocal(globalPosition);
    final nextLatLng = _mapController.camera.screenOffsetToLatLng(localOffset);
    provider.updateTaxiwayNodePosition(
      index,
      MapCoordinate(
        latitude: nextLatLng.latitude,
        longitude: nextLatLng.longitude,
      ),
    );
    if (_selectedTaxiwayNodeIndex != index) {
      setState(() {
        _selectedTaxiwayNodeIndex = index;
      });
    }
  }

  void _onTaxiwayNodeHover({
    required int index,
    required Offset globalPosition,
  }) {
    if (_hoveredTaxiwayNodeIndex == index &&
        _hoveredTaxiwayNodeGlobalPosition == globalPosition) {
      return;
    }
    setState(() {
      _hoveredTaxiwayNodeIndex = index;
      _hoveredTaxiwayNodeGlobalPosition = globalPosition;
    });
  }

  void _clearTaxiwayNodeHover() {
    if (_hoveredTaxiwayNodeIndex == null &&
        _hoveredTaxiwayNodeGlobalPosition == null) {
      return;
    }
    setState(() {
      _hoveredTaxiwayNodeIndex = null;
      _hoveredTaxiwayNodeGlobalPosition = null;
    });
  }

  void _onTaxiwaySegmentHover({
    required int segmentIndex,
    required Offset globalPosition,
  }) {
    if (_hoveredTaxiwaySegmentIndex == segmentIndex &&
        _hoveredTaxiwaySegmentGlobalPosition == globalPosition) {
      return;
    }
    setState(() {
      _hoveredTaxiwaySegmentIndex = segmentIndex;
      _hoveredTaxiwaySegmentGlobalPosition = globalPosition;
    });
  }

  void _clearTaxiwaySegmentHover() {
    if (_hoveredTaxiwaySegmentIndex == null &&
        _hoveredTaxiwaySegmentGlobalPosition == null) {
      return;
    }
    setState(() {
      _hoveredTaxiwaySegmentIndex = null;
      _hoveredTaxiwaySegmentGlobalPosition = null;
    });
  }

  MapTaxiwaySegment _resolveTaxiwaySegmentByIndex(
    MapProvider provider,
    int segmentIndex,
  ) {
    final segments = provider.taxiwaySegments;
    if (segmentIndex >= 0 && segmentIndex < segments.length) {
      return segments[segmentIndex];
    }
    return const MapTaxiwaySegment();
  }

  double _computeTaxiwaySegmentDistanceMeters(
    MapTaxiwayNode startNode,
    MapTaxiwayNode endNode,
  ) {
    return _distance.as(
      LengthUnit.Meter,
      LatLng(startNode.latitude, startNode.longitude),
      LatLng(endNode.latitude, endNode.longitude),
    );
  }

  Future<void> _showTaxiwaySegmentContextMenu({
    required MapProvider provider,
    required int segmentIndex,
    required Offset globalPosition,
  }) async {
    if (!provider.isTaxiwayDrawingActive ||
        segmentIndex < 0 ||
        segmentIndex >= provider.taxiwayNodes.length - 1) {
      return;
    }
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPosition.dx,
        globalPosition.dy,
        globalPosition.dx,
        globalPosition.dy,
      ),
      items: [
        PopupMenuItem<String>(
          value: 'insert',
          child: Text(MapLocalizationKeys.taxiwayInsertNode.tr(context)),
        ),
        PopupMenuItem<String>(
          value: 'edit',
          child: Text(MapLocalizationKeys.taxiwayEditConnection.tr(context)),
        ),
      ],
    );
    if (!mounted || selected == null) {
      return;
    }
    if (selected == 'insert') {
      final insertCoordinate = _resolveMapCoordinateFromGlobalPosition(
        globalPosition,
      );
      provider.insertTaxiwayNodeBetween(
        segmentIndex,
        coordinate: insertCoordinate,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              MapLocalizationKeys.taxiwayInsertNodeSuccess.tr(context),
            ),
          ),
        );
      }
      return;
    }
    await _showTaxiwaySegmentEditor(provider, segmentIndex);
  }

  MapCoordinate? _resolveMapCoordinateFromGlobalPosition(
    Offset globalPosition,
  ) {
    final mapContext = _mapKey.currentContext;
    if (!_mapReady || mapContext == null) {
      return null;
    }
    final renderBox = mapContext.findRenderObject();
    if (renderBox is! RenderBox) {
      return null;
    }
    final localOffset = renderBox.globalToLocal(globalPosition);
    final latLng = _mapController.camera.screenOffsetToLatLng(localOffset);
    return MapCoordinate(
      latitude: latLng.latitude,
      longitude: latLng.longitude,
    );
  }

  /// 显示滑行路线线段编辑对话框。
  ///
  /// 内部委托至 [showTaxiwaySegmentEditorDialog]，不再内联大量对话框构建逻辑。
  Future<void> _showTaxiwaySegmentEditor(
    MapProvider provider,
    int segmentIndex,
  ) async {
    await showTaxiwaySegmentEditorDialog(
      context: context,
      provider: provider,
      segmentIndex: segmentIndex,
    );
  }

  /// 显示滑行路线节点编辑对话框。
  ///
  /// 内部委托至 [showTaxiwayNodeEditorDialog]，不再内联大量对话框构建逻辑。
  Future<void> _showTaxiwayNodeEditor(MapProvider provider, int index) async {
    // 实发对话前同步选中索引状态
    setState(() {
      _selectedTaxiwayNodeIndex = index;
    });
    await showTaxiwayNodeEditorDialog(
      context: context,
      provider: provider,
      index: index,
      onSelectedIndexChanged: (newIndex) {
        setState(() {
          _selectedTaxiwayNodeIndex = newIndex;
        });
      },
    );
  }

  Future<void> _showTaxiwayNodeDetail(MapProvider provider, int index) async {
    final nodes = provider.taxiwayNodes;
    if (index < 0 || index >= nodes.length || !mounted) {
      return;
    }
    final node = nodes[index];
    final headingDeg = _computeTaxiwayNodeHeading(nodes, index);
    final name = node.name?.trim() ?? '';
    final note = node.note?.trim() ?? '';
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            '${MapLocalizationKeys.taxiwayNode.tr(dialogContext)} ${index + 1}',
          ),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${MapLocalizationKeys.labelLatitudeLongitude.tr(dialogContext)}: '
                  '${node.latitude.toStringAsFixed(6)}, ${node.longitude.toStringAsFixed(6)}',
                ),
                const SizedBox(height: 8),
                Text(
                  '${MapLocalizationKeys.labelHeading.tr(dialogContext)}: '
                  '${headingDeg == null ? '--' : headingDeg.toStringAsFixed(1)}°',
                ),
                if (name.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${MapLocalizationKeys.taxiwayNodeName.tr(dialogContext)}: $name',
                  ),
                ],
                if (note.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${MapLocalizationKeys.taxiwayNodeNote.tr(dialogContext)}: $note',
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(LocalizationKeys.confirm.tr(dialogContext)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showTaxiwaySegmentDetail(
    MapProvider provider,
    int segmentIndex,
  ) async {
    final nodes = provider.taxiwayNodes;
    if (segmentIndex < 0 || segmentIndex >= nodes.length - 1 || !mounted) {
      return;
    }
    final segments = provider.taxiwaySegments;
    final segment = segmentIndex < segments.length
        ? segments[segmentIndex]
        : const MapTaxiwaySegment();
    final startNode = nodes[segmentIndex];
    final endNode = nodes[segmentIndex + 1];
    final distanceMeters = _distance.as(
      LengthUnit.Meter,
      LatLng(startNode.latitude, startNode.longitude),
      LatLng(endNode.latitude, endNode.longitude),
    );
    final lineTypeLabel = segment.lineType == MapTaxiwaySegmentLineType.straight
        ? MapLocalizationKeys.taxiwayConnectionLineTypeStraight.tr(context)
        : MapLocalizationKeys.taxiwayConnectionLineTypeMapMatching.tr(context);
    final directionLabel =
        segment.curveDirection == MapTaxiwaySegmentCurveDirection.left
        ? MapLocalizationKeys.taxiwayConnectionCurveDirectionLeft.tr(context)
        : MapLocalizationKeys.taxiwayConnectionCurveDirectionRight.tr(context);
    final name = segment.name?.trim() ?? '';
    final note = segment.note?.trim() ?? '';

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            '${MapLocalizationKeys.taxiwayConnection.tr(dialogContext)} ${segmentIndex + 1}',
          ),
          content: SizedBox(
            width: 340,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${MapLocalizationKeys.taxiwayConnectionRange.tr(dialogContext)}: '
                  '${segmentIndex + 1} → ${segmentIndex + 2}',
                ),
                const SizedBox(height: 8),
                Text(
                  '${MapLocalizationKeys.labelLatitudeLongitude.tr(dialogContext)}: '
                  '${startNode.latitude.toStringAsFixed(6)}, ${startNode.longitude.toStringAsFixed(6)} ↔ '
                  '${endNode.latitude.toStringAsFixed(6)}, ${endNode.longitude.toStringAsFixed(6)}',
                ),
                const SizedBox(height: 8),
                Text(
                  '${MapLocalizationKeys.distance.tr(dialogContext)}: '
                  '${distanceMeters.toStringAsFixed(1)} m',
                ),
                const SizedBox(height: 8),
                Text(
                  '${MapLocalizationKeys.taxiwayConnectionLineType.tr(dialogContext)}: $lineTypeLabel',
                ),
                if (segment.lineType ==
                    MapTaxiwaySegmentLineType.mapMatching) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${MapLocalizationKeys.taxiwayConnectionCurvature.tr(dialogContext)}: '
                    '${segment.curvature.toStringAsFixed(2)}',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${MapLocalizationKeys.taxiwayConnectionCurveDirection.tr(dialogContext)}: '
                    '$directionLabel',
                  ),
                ],
                if (name.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${MapLocalizationKeys.taxiwayConnectionName.tr(dialogContext)}: $name',
                  ),
                ],
                if (note.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${MapLocalizationKeys.taxiwayConnectionNote.tr(dialogContext)}: $note',
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(LocalizationKeys.confirm.tr(dialogContext)),
            ),
          ],
        );
      },
    );
  }

  /// 计算滑行路线节点朝向角（度）。
  ///
  /// 委托至 [map_taxiway_dialogs.dart] 内的公广工具方法。
  double? _computeTaxiwayNodeHeading(List<MapTaxiwayNode> nodes, int index) {
    if (nodes.length < 2 || index < 0 || index >= nodes.length) return null;
    final MapTaxiwayNode fromNode;
    final MapTaxiwayNode toNode;
    if (index < nodes.length - 1) {
      fromNode = nodes[index];
      toNode = nodes[index + 1];
    } else {
      fromNode = nodes[index - 1];
      toNode = nodes[index];
    }
    final raw = _distance.bearing(
      LatLng(fromNode.latitude, fromNode.longitude),
      LatLng(toNode.latitude, toNode.longitude),
    );
    return (raw + 360) % 360;
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
    return MapLocalizationKeys.taxiwayDangerGeneric.tr(context);
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
    required VoidCallback onTap,
  }) {
    return Marker(
      point: LatLng(airport.position.latitude, airport.position.longitude),
      width: 138 * scale,
      height: 88 * scale,
      child: GestureDetector(
        onTap: onTap,
        child: HomeAirportPin(
          code: _normalizeAirportCode(airport.code),
          scale: scale,
        ),
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
      final pinnedAirport = MapAirportMarker(
        code: bundle.code,
        position: MapCoordinate(
          latitude: bundle.latitude,
          longitude: bundle.longitude,
        ),
      );
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
            onTap: () => _handleSelectAirport(provider, pinnedAirport),
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
            child: GestureDetector(
              onTap: () => _handleSelectAirport(provider, pinnedAirport),
              child: AirportRolePin(
                code: displayCode,
                title: rolePin.title,
                icon: rolePin.icon,
                color: rolePin.color,
                scale: scale,
              ),
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
          child: GestureDetector(
            onTap: () => _handleSelectAirport(provider, pinnedAirport),
            child: CombinedAirportPin(
              code: displayCode,
              tags: tags,
              icon: combinedPin.icon,
              color: combinedPin.color,
              scale: scale,
            ),
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

  double _plannedRouteChipBottom(double scale) {
    if (_selectedAirport == null) {
      return 20 * scale;
    }
    if (_isAirportDetailExpanded) {
      return 240 * scale;
    }
    return 104 * scale;
  }

  List<_PlannedRouteLeg> _buildPlannedRouteLegs(HomeProvider homeProvider) {
    final departure = homeProvider.departureAirport;
    final destination = homeProvider.destinationAirport;
    if (departure == null || destination == null) {
      return const [];
    }
    final alternate = homeProvider.alternateAirport;
    final result = <_PlannedRouteLeg>[];

    void addLeg({required HomeAirportInfo from, required HomeAirportInfo to}) {
      if (!_isValidCoordinate(from.latitude, from.longitude) ||
          !_isValidCoordinate(to.latitude, to.longitude)) {
        return;
      }
      final fromLatLng = LatLng(from.latitude, from.longitude);
      final toLatLng = LatLng(to.latitude, to.longitude);
      final distanceMeters = const Distance().as(
        LengthUnit.Meter,
        fromLatLng,
        toLatLng,
      );
      final distanceNm = distanceMeters / 1852.0;
      if (distanceNm <= 0.01) {
        return;
      }
      result.add(
        _PlannedRouteLeg(
          fromCode: _normalizeAirportCode(from.icaoCode),
          toCode: _normalizeAirportCode(to.icaoCode),
          from: MapCoordinate(
            latitude: from.latitude,
            longitude: from.longitude,
          ),
          to: MapCoordinate(latitude: to.latitude, longitude: to.longitude),
          distanceNm: distanceNm,
        ),
      );
    }

    if (alternate != null) {
      addLeg(from: departure, to: alternate);
      addLeg(from: alternate, to: destination);
    } else {
      addLeg(from: departure, to: destination);
    }

    return result;
  }

  List<LatLng> _buildPlannedRouteCurvePoints(_PlannedRouteLeg leg) {
    final start = LatLng(leg.from.latitude, leg.from.longitude);
    final end = LatLng(leg.to.latitude, leg.to.longitude);
    final deltaLat = end.latitude - start.latitude;
    final deltaLon = end.longitude - start.longitude;
    final length = math.sqrt(deltaLat * deltaLat + deltaLon * deltaLon);
    if (length < 0.00001) {
      return [start, end];
    }
    final midLat = (start.latitude + end.latitude) / 2;
    final midLon = (start.longitude + end.longitude) / 2;
    final normalLat = -deltaLon / length;
    final normalLon = deltaLat / length;
    final curvature = (0.18 * length).clamp(0.02, 3.6);
    final controlLat = midLat + normalLat * curvature;
    final controlLon = midLon + normalLon * curvature;
    const segments = 32;
    final points = <LatLng>[];
    for (var i = 0; i <= segments; i += 1) {
      final t = i / segments;
      final oneMinusT = 1 - t;
      final lat =
          oneMinusT * oneMinusT * start.latitude +
          2 * oneMinusT * t * controlLat +
          t * t * end.latitude;
      final lon =
          oneMinusT * oneMinusT * start.longitude +
          2 * oneMinusT * t * controlLon +
          t * t * end.longitude;
      points.add(LatLng(lat, lon));
    }
    return points;
  }

  List<Marker> _buildPlannedRouteDistanceMarkers({
    required List<_PlannedRouteLeg> legs,
    required double scale,
  }) {
    return legs.map((leg) {
      final curvePoints = _buildPlannedRouteCurvePoints(leg);
      final centerPoint = curvePoints[curvePoints.length ~/ 2];
      final fromCode = leg.fromCode.isEmpty ? 'DEP' : leg.fromCode;
      final toCode = leg.toCode.isEmpty ? 'ARR' : leg.toCode;
      return Marker(
        point: centerPoint,
        width: 180 * scale,
        height: 46 * scale,
        child: _PlannedRouteLegLabel(
          scale: scale,
          text: '$fromCode → $toCode  ${leg.distanceNm.toStringAsFixed(1)} NM',
        ),
      );
    }).toList();
  }

  List<CircleMarker<int>> _buildRestrictedAirspaceCircles({
    required MapProvider provider,
    required LatLng center,
    required double zoom,
  }) {
    final zones = provider.restrictedAirspaceZones;
    if (zones.isNotEmpty) {
      return zones
          .asMap()
          .entries
          .map((entry) {
            final zone = entry.value;
            final latitude = (zone['center_lat'] as num?)?.toDouble();
            final longitude = (zone['center_lon'] as num?)?.toDouble();
            final radiusMeters = (zone['radius_meters'] as num?)?.toDouble();
            final severity =
                zone['severity']?.toString().trim().toLowerCase() ?? '';
            if (latitude == null || longitude == null || radiusMeters == null) {
              return null;
            }
            Color borderColor;
            Color fillColor;
            double borderWidth;
            switch (severity) {
              case 'critical':
                borderColor = Colors.redAccent.withValues(alpha: 0.94);
                fillColor = Colors.red.withValues(alpha: 0.16);
                borderWidth = 2.6;
                break;
              case 'warning':
                borderColor = Colors.orangeAccent.withValues(alpha: 0.9);
                fillColor = Colors.orange.withValues(alpha: 0.14);
                borderWidth = 2.0;
                break;
              default:
                borderColor = Colors.amberAccent.withValues(alpha: 0.86);
                fillColor = Colors.amber.withValues(alpha: 0.1);
                borderWidth = 1.5;
                break;
            }
            return CircleMarker<int>(
              point: LatLng(latitude, longitude),
              useRadiusInMeter: true,
              radius: radiusMeters.clamp(1200.0, 18000.0),
              borderColor: borderColor,
              borderStrokeWidth: borderWidth,
              color: fillColor,
              hitValue: entry.key,
            );
          })
          .whereType<CircleMarker<int>>()
          .toList(growable: false);
    }
    if (provider.airports.isEmpty) {
      return const [];
    }
    final maxCount = zoom >= 9 ? 6 : 3;
    final sorted = [...provider.airports]
      ..sort((a, b) {
        final dA = const Distance().as(
          LengthUnit.Meter,
          center,
          LatLng(a.position.latitude, a.position.longitude),
        );
        final dB = const Distance().as(
          LengthUnit.Meter,
          center,
          LatLng(b.position.latitude, b.position.longitude),
        );
        return dA.compareTo(dB);
      });
    final circles = <CircleMarker<int>>[];
    for (var i = 0; i < sorted.length && i < maxCount; i += 1) {
      final airport = sorted[i];
      final radiusMeters = airport.isPrimary
          ? 12000.0
          : i == 0
          ? 9000.0
          : 6500.0;
      circles.add(
        CircleMarker<int>(
          point: LatLng(airport.position.latitude, airport.position.longitude),
          useRadiusInMeter: true,
          radius: radiusMeters,
          borderColor: airport.isPrimary
              ? Colors.redAccent.withValues(alpha: 0.9)
              : Colors.orangeAccent.withValues(alpha: 0.85),
          borderStrokeWidth: airport.isPrimary ? 2.2 : 1.6,
          color: airport.isPrimary
              ? Colors.red.withValues(alpha: 0.1)
              : Colors.orange.withValues(alpha: 0.08),
        ),
      );
    }
    return circles;
  }

  Map<String, dynamic>? _resolveSelectedAirspaceZone(MapProvider provider) {
    if (_selectedRestrictedAirspaceZone == null ||
        !provider.showRestrictedAirspace) {
      return null;
    }
    final selected = _selectedRestrictedAirspaceZone!;
    final selectedId = selected['id']?.toString().trim() ?? '';
    final selectedLat = (selected['center_lat'] as num?)?.toDouble();
    final selectedLon = (selected['center_lon'] as num?)?.toDouble();
    final selectedRadius = (selected['radius_meters'] as num?)?.toDouble();
    for (final zone in provider.restrictedAirspaceZones) {
      final zoneId = zone['id']?.toString().trim() ?? '';
      if (selectedId.isNotEmpty && zoneId == selectedId) {
        return zone;
      }
      final lat = (zone['center_lat'] as num?)?.toDouble();
      final lon = (zone['center_lon'] as num?)?.toDouble();
      final radius = (zone['radius_meters'] as num?)?.toDouble();
      if (selectedLat != null &&
          selectedLon != null &&
          selectedRadius != null &&
          lat != null &&
          lon != null &&
          radius != null &&
          (lat - selectedLat).abs() < 0.0001 &&
          (lon - selectedLon).abs() < 0.0001 &&
          (radius - selectedRadius).abs() < 1.0) {
        return zone;
      }
    }
    return null;
  }

  Map<String, dynamic>? _resolveRestrictedAirspaceZoneByHitIndex(
    MapProvider provider,
    int? hitIndex,
  ) {
    if (hitIndex == null) {
      return null;
    }
    final zones = provider.restrictedAirspaceZones;
    if (zones.isEmpty || hitIndex < 0 || hitIndex >= zones.length) {
      return null;
    }
    return zones[hitIndex];
  }

  Offset? _resolveHoverHintLocalOffset() {
    final globalPosition = _hoveredRestrictedAirspaceGlobalPosition;
    if (globalPosition == null) {
      return null;
    }
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox) {
      return null;
    }
    return renderObject.globalToLocal(globalPosition);
  }

  Offset? _resolveAirspaceZoneScreenOffset(Map<String, dynamic> zone) {
    if (!_mapReady) {
      return null;
    }
    final lat = (zone['center_lat'] as num?)?.toDouble();
    final lon = (zone['center_lon'] as num?)?.toDouble();
    if (lat == null || lon == null) {
      return null;
    }
    return _mapController.camera.latLngToScreenOffset(LatLng(lat, lon));
  }

  List<Marker> _buildHighAltitudeWindMarkers({
    required MapProvider provider,
    required double scale,
  }) {
    final profile = provider.highAltitudeWindProfile;
    if (profile == null) {
      return const [];
    }
    final latitude = (profile['latitude'] as num?)?.toDouble();
    final longitude = (profile['longitude'] as num?)?.toDouble();
    final speedKt = (profile['estimated_speed_kt'] as num?)?.toDouble();
    final directionDeg = (profile['estimated_direction_deg'] as num?)
        ?.toDouble();
    if (latitude == null ||
        longitude == null ||
        speedKt == null ||
        directionDeg == null) {
      return const [];
    }
    final rotationRad = ((directionDeg + 180.0) % 360.0) * math.pi / 180.0;
    return [
      Marker(
        point: LatLng(latitude, longitude),
        width: 164 * scale,
        height: 52 * scale,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: 8 * scale,
            vertical: 6 * scale,
          ),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.52),
            borderRadius: BorderRadius.circular(10 * scale),
            border: Border.all(color: Colors.white.withValues(alpha: 0.26)),
          ),
          child: Row(
            children: [
              Transform.rotate(
                angle: rotationRad,
                child: Icon(
                  Icons.navigation,
                  size: 15 * scale,
                  color: Colors.lightBlueAccent,
                ),
              ),
              SizedBox(width: 6 * scale),
              Text(
                '${speedKt.toStringAsFixed(0)}KT  ${directionDeg.toStringAsFixed(0)}°',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: (11 * scale).clamp(9, 13),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    ];
  }

  List<CircleMarker> _buildTerrainAwarenessCircles({
    required MapAircraftState aircraft,
    required List<MapFlightAlert> activeAlerts,
  }) {
    final radioAltitude = aircraft.radioAltitude;
    if (radioAltitude == null || !radioAltitude.isFinite) {
      return const [];
    }
    final isDanger = activeAlerts.any(
      (alert) => alert.id.trim().toLowerCase() == 'terrain_pull_up_danger',
    );
    final isWarning = activeAlerts.any(
      (alert) => alert.id.trim().toLowerCase() == 'terrain_pull_up_warning',
    );
    final ringRadiusMeters = (radioAltitude * 0.48).clamp(120.0, 1200.0);
    final borderColor = isDanger
        ? Colors.redAccent.withValues(alpha: 0.94)
        : isWarning
        ? Colors.orangeAccent.withValues(alpha: 0.9)
        : Colors.lightGreenAccent.withValues(alpha: 0.85);
    final fillColor = isDanger
        ? Colors.red.withValues(alpha: 0.22)
        : isWarning
        ? Colors.orange.withValues(alpha: 0.16)
        : Colors.green.withValues(alpha: 0.12);
    return [
      CircleMarker(
        point: LatLng(aircraft.position.latitude, aircraft.position.longitude),
        useRadiusInMeter: true,
        radius: ringRadiusMeters,
        borderColor: borderColor,
        borderStrokeWidth: isDanger ? 2.8 : 2.2,
        color: fillColor,
      ),
    ];
  }

  bool _isValidCoordinate(double latitude, double longitude) {
    return latitude.isFinite &&
        longitude.isFinite &&
        latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180;
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

class _AIAircraftLabelPalette {
  final Color metricsBackground;
  final Color metricsText;
  final Color identityBackground;
  final Color identityText;
  final Color identityBorder;

  const _AIAircraftLabelPalette({
    required this.metricsBackground,
    required this.metricsText,
    required this.identityBackground,
    required this.identityText,
    required this.identityBorder,
  });
}

class _PlannedRouteLeg {
  final String fromCode;
  final String toCode;
  final MapCoordinate from;
  final MapCoordinate to;
  final double distanceNm;

  const _PlannedRouteLeg({
    required this.fromCode,
    required this.toCode,
    required this.from,
    required this.to,
    required this.distanceNm,
  });
}

class _PlannedRouteLegLabel extends StatelessWidget {
  final double scale;
  final String text;

  const _PlannedRouteLegLabel({required this.scale, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      padding: EdgeInsets.symmetric(
        horizontal: 10 * scale,
        vertical: 5 * scale,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(10 * scale),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Colors.white,
          fontSize: 12 * scale,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _RestrictedAirspaceHoverHint extends StatelessWidget {
  final Map<String, dynamic> zone;
  final double scale;

  const _RestrictedAirspaceHoverHint({required this.zone, required this.scale});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 10 * scale,
        vertical: 7 * scale,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(11 * scale),
        border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.65)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 8 * scale,
            offset: Offset(0, 2 * scale),
          ),
        ],
      ),
      child: Text(
        '${_RestrictedAirspaceDraggablePanelState._airspaceType(zone) ?? '空域'} · 点击查看更多信息',
        style: TextStyle(
          color: Colors.white,
          fontSize: 11 * scale,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _RestrictedAirspaceDraggablePanel extends StatefulWidget {
  final Map<String, dynamic> zone;
  final double scale;
  final Size viewportSize;
  final Offset? anchorOffset;
  final VoidCallback onClose;

  const _RestrictedAirspaceDraggablePanel({
    super.key,
    required this.zone,
    required this.scale,
    required this.viewportSize,
    required this.anchorOffset,
    required this.onClose,
  });

  @override
  State<_RestrictedAirspaceDraggablePanel> createState() =>
      _RestrictedAirspaceDraggablePanelState();
}

class _RestrictedAirspaceDraggablePanelState
    extends State<_RestrictedAirspaceDraggablePanel> {
  Offset _relativeOffset = const Offset(78, -108);

  @override
  Widget build(BuildContext context) {
    final scale = widget.scale;
    final panelWidth = (296.0 * scale).clamp(248.0, 360.0);
    final panelHeight = (212.0 * scale).clamp(178.0, 260.0);
    final margin = 10.0 * scale;
    final anchor =
        widget.anchorOffset ??
        Offset(
          widget.viewportSize.width * 0.36,
          widget.viewportSize.height * 0.72,
        );
    final panelLeft = (anchor.dx + _relativeOffset.dx)
        .clamp(margin, widget.viewportSize.width - panelWidth - margin)
        .toDouble();
    final panelTop = (anchor.dy + _relativeOffset.dy)
        .clamp(margin, widget.viewportSize.height - panelHeight - margin)
        .toDouble();
    final panelCenter = Offset(
      panelLeft + panelWidth / 2,
      panelTop + panelHeight / 2,
    );
    final lineEnd = panelCenter.dx >= anchor.dx
        ? Offset(panelLeft, panelCenter.dy)
        : Offset(panelLeft + panelWidth, panelCenter.dy);
    final detailRows = _buildDetailRows(widget.zone);
    final description = _buildDescription(widget.zone);
    final chips = _buildTagChips(widget.zone);

    return Stack(
      children: [
        IgnorePointer(
          child: CustomPaint(
            size: widget.viewportSize,
            painter: _AirspaceConnectorPainter(
              start: anchor,
              end: lineEnd,
              color: Colors.white.withValues(alpha: 0.3),
              strokeWidth: (1.3 * scale).clamp(1.0, 2.0),
            ),
          ),
        ),
        Positioned(
          left: panelLeft,
          top: panelTop,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanUpdate: (details) {
              setState(() {
                _relativeOffset += details.delta;
              });
            },
            child: Container(
              width: panelWidth,
              height: panelHeight,
              padding: EdgeInsets.fromLTRB(
                10 * scale,
                8 * scale,
                10 * scale,
                8 * scale,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(10 * scale),
                border: Border.all(
                  color: Colors.orangeAccent.withValues(alpha: 0.7),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 12 * scale,
                    offset: Offset(0, 4 * scale),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _airspaceTitle(widget.zone),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12 * scale,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: widget.onClose,
                        visualDensity: VisualDensity.compact,
                        iconSize: 15 * scale,
                        padding: EdgeInsets.zero,
                        color: Colors.white70,
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  SizedBox(height: 4 * scale),
                  if (chips.isNotEmpty)
                    Wrap(
                      spacing: 4 * scale,
                      runSpacing: 4 * scale,
                      children: chips
                          .map(
                            (text) => Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 6 * scale,
                                vertical: 3 * scale,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6 * scale),
                              ),
                              child: Text(
                                text,
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 9.8 * scale,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          )
                          .toList(growable: false),
                    ),
                  SizedBox(height: 6 * scale),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ...detailRows.map(
                            (entry) => Padding(
                              padding: EdgeInsets.only(bottom: 5 * scale),
                              child: RichText(
                                text: TextSpan(
                                  children: [
                                    TextSpan(
                                      text: '${entry.$1}: ',
                                      style: TextStyle(
                                        color: Colors.cyanAccent.withValues(
                                          alpha: 0.88,
                                        ),
                                        fontSize: 9.8 * scale,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    TextSpan(
                                      text: entry.$2,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 9.8 * scale,
                                        fontWeight: FontWeight.w500,
                                        height: 1.32,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          if (description != null) ...[
                            SizedBox(height: 4 * scale),
                            Text(
                              description,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.95),
                                fontSize: 10 * scale,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 4 * scale),
                  Text(
                    '拖动卡片可移动位置',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 10 * scale,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  static String _airspaceTitle(Map<String, dynamic> zone) {
    return _firstNonEmpty([
          zone['name']?.toString(),
          zone['title']?.toString(),
          zone['id']?.toString(),
        ]) ??
        'Restricted Airspace';
  }

  static String? _airspaceType(Map<String, dynamic> zone) {
    return _firstNonEmpty([
      zone['type']?.toString(),
      zone['zone_type']?.toString(),
      zone['airspace_type']?.toString(),
      zone['category']?.toString(),
    ]);
  }

  static String? _airspaceClass(Map<String, dynamic> zone) {
    return _firstNonEmpty([
      zone['classification']?.toString(),
      zone['class']?.toString(),
      zone['airspace_class']?.toString(),
    ]);
  }

  static String? _buildDescription(Map<String, dynamic> zone) {
    return _firstNonEmpty([
      zone['description']?.toString(),
      zone['remark']?.toString(),
      zone['notes']?.toString(),
      zone['restriction_reason']?.toString(),
      zone['advisory']?.toString(),
    ]);
  }

  static List<String> _buildTagChips(Map<String, dynamic> zone) {
    final seen = <String>{};
    final chips = <String>[];
    final classification = _airspaceClass(zone);
    final type = _airspaceType(zone);
    final status = _firstNonEmpty([
      zone['status']?.toString(),
      zone['active']?.toString(),
      zone['state']?.toString(),
    ]);
    void addChip(String prefix, String? value) {
      if (value == null) {
        return;
      }
      final normalized = value.trim().toLowerCase();
      if (normalized.isEmpty || seen.contains(normalized)) {
        return;
      }
      seen.add(normalized);
      chips.add('$prefix: $value');
    }

    addChip('等级', classification);
    addChip('类型', type);
    addChip('状态', status);
    return chips;
  }

  static List<(String, String)> _buildDetailRows(Map<String, dynamic> zone) {
    String? numField(List<String> keys, {String suffix = ''}) {
      for (final key in keys) {
        final value = (zone[key] as num?)?.toDouble();
        if (value != null) {
          if (value % 1 == 0) {
            return '${value.toStringAsFixed(0)}$suffix';
          }
          return '${value.toStringAsFixed(2)}$suffix';
        }
      }
      return null;
    }

    String? textField(List<String> keys) {
      for (final key in keys) {
        final value = zone[key]?.toString().trim();
        if (value != null && value.isNotEmpty) {
          return value;
        }
      }
      return null;
    }

    final rows = <(String, String)>[];
    final seenRows = <String>{};
    final id = textField(['id', 'zone_id', 'identifier']);
    final authority = textField(['authority', 'issuer', 'provider', 'source']);
    final country = textField(['country', 'country_code', 'region']);
    final city = textField(['city', 'area', 'district']);
    final upperLimit = textField([
      'upper_limit',
      'upper_altitude',
      'max_altitude',
      'max_altitude_ft',
      'ceiling',
    ]);
    final lowerLimit = textField([
      'lower_limit',
      'lower_altitude',
      'min_altitude',
      'min_altitude_ft',
      'floor',
    ]);
    final frequency = textField([
      'frequency',
      'contact_frequency',
      'tower_frequency',
    ]);
    final startTime = textField(['start_time', 'effective_from', 'valid_from']);
    final endTime = textField(['end_time', 'effective_to', 'valid_to']);
    final schedule = textField(['schedule', 'active_time', 'time_window']);
    final radiusMeters = numField(['radius_meters'], suffix: ' m');
    final centerLat = numField(['center_lat', 'latitude']);
    final centerLon = numField(['center_lon', 'longitude']);
    final minAltFt = numField(['min_altitude_ft', 'min_alt_ft'], suffix: ' ft');
    final maxAltFt = numField(['max_altitude_ft', 'max_alt_ft'], suffix: ' ft');
    final risk = textField(['risk_level', 'threat_level']);
    final geometry = textField(['geometry_type', 'shape', 'polygon_type']);
    final restriction = textField([
      'restriction',
      'restriction_type',
      'advisory_level',
    ]);
    final controllingUnit = textField([
      'controlling_unit',
      'control_center',
      'atc_unit',
    ]);
    final handledKeys = <String>{
      'id',
      'zone_id',
      'identifier',
      'type',
      'zone_type',
      'airspace_type',
      'category',
      'classification',
      'class',
      'airspace_class',
      'risk_level',
      'threat_level',
      'restriction',
      'restriction_type',
      'advisory_level',
      'authority',
      'issuer',
      'provider',
      'source',
      'controlling_unit',
      'control_center',
      'atc_unit',
      'country',
      'country_code',
      'region',
      'city',
      'area',
      'district',
      'radius_meters',
      'upper_limit',
      'upper_altitude',
      'max_altitude',
      'max_altitude_ft',
      'ceiling',
      'lower_limit',
      'lower_altitude',
      'min_altitude',
      'min_altitude_ft',
      'floor',
      'min_alt_ft',
      'max_alt_ft',
      'geometry_type',
      'shape',
      'polygon_type',
      'center_lat',
      'latitude',
      'center_lon',
      'longitude',
      'frequency',
      'contact_frequency',
      'tower_frequency',
      'start_time',
      'effective_from',
      'valid_from',
      'end_time',
      'effective_to',
      'valid_to',
      'schedule',
      'active_time',
      'time_window',
      'warning',
      'pilot_notice',
      'guidance',
      'description',
      'remark',
      'notes',
      'restriction_reason',
      'advisory',
      'status',
      'active',
      'state',
      'remarks',
      'metadata',
      'operation_rule',
      'entry_requirement',
      'exit_requirement',
      'exception',
      'penalty',
    };

    void addRow(String label, String? value) {
      if (value == null) {
        return;
      }
      final normalized = value.trim().toLowerCase();
      final dedupeKey = '$label|$normalized';
      if (normalized.isEmpty || seenRows.contains(dedupeKey)) {
        return;
      }
      seenRows.add(dedupeKey);
      rows.add((label, value));
    }

    addRow('空域ID', id);
    addRow('空域类型', _airspaceType(zone));
    addRow('空域分级', _airspaceClass(zone));
    addRow('风险等级', risk);
    addRow('限制属性', restriction);
    addRow('发布来源', authority);
    addRow('管制单位', controllingUnit);
    if (country != null || city != null) {
      addRow('区域范围', [country, city].whereType<String>().join(' / '));
    }
    addRow('影响半径', radiusMeters);
    if (lowerLimit != null || upperLimit != null) {
      addRow('高度范围', '${lowerLimit ?? '-'} ~ ${upperLimit ?? '-'}');
    } else if (minAltFt != null || maxAltFt != null) {
      addRow('高度范围', '${minAltFt ?? '-'} ~ ${maxAltFt ?? '-'}');
    }
    addRow('几何形态', geometry);
    if (centerLat != null && centerLon != null) {
      addRow('中心坐标', '$centerLat, $centerLon');
    }
    addRow('通信频率', frequency);
    if (startTime != null || endTime != null) {
      addRow('生效时段', '${startTime ?? '-'} ~ ${endTime ?? '-'}');
    }
    addRow('活动周期', schedule);
    final warning = textField(['warning', 'pilot_notice', 'guidance']);
    addRow('飞行建议', warning);

    final dynamicKeys = [
      'remarks',
      'metadata',
      'operation_rule',
      'entry_requirement',
      'exit_requirement',
      'exception',
      'penalty',
    ];
    for (final key in dynamicKeys) {
      final text = textField([key]);
      if (text != null) {
        addRow(key, text);
      }
    }
    for (final entry in zone.entries) {
      final key = entry.key.trim();
      if (key.isEmpty) {
        continue;
      }
      final normalizedKey = key.toLowerCase();
      if (handledKeys.contains(normalizedKey)) {
        continue;
      }
      final display = _formatZoneExtraValue(entry.value);
      if (display == null) {
        continue;
      }
      addRow(_formatZoneExtraLabel(key), display);
    }
    return rows;
  }

  static String _formatZoneExtraLabel(String rawKey) {
    final words = rawKey
        .replaceAll(RegExp(r'[_\-]+'), ' ')
        .replaceAllMapped(
          RegExp(r'([a-z])([A-Z])'),
          (match) => '${match.group(1)} ${match.group(2)}',
        )
        .trim();
    if (words.isEmpty) {
      return rawKey;
    }
    return words;
  }

  static String? _formatZoneExtraValue(dynamic raw) {
    if (raw == null) {
      return null;
    }
    if (raw is String) {
      final text = raw.trim();
      return text.isEmpty ? null : text;
    }
    if (raw is num || raw is bool) {
      return '$raw';
    }
    if (raw is List) {
      if (raw.isEmpty) {
        return null;
      }
      final texts = raw
          .map((item) => _formatZoneExtraValue(item))
          .whereType<String>()
          .where((item) => item.trim().isNotEmpty)
          .take(6)
          .toList(growable: false);
      if (texts.isEmpty) {
        return null;
      }
      return texts.join(' / ');
    }
    if (raw is Map) {
      if (raw.isEmpty) {
        return null;
      }
      final parts = <String>[];
      for (final entry in raw.entries.take(6)) {
        final value = _formatZoneExtraValue(entry.value);
        if (value == null) {
          continue;
        }
        parts.add('${entry.key}: $value');
      }
      if (parts.isEmpty) {
        return null;
      }
      return parts.join(' ; ');
    }
    final text = raw.toString().trim();
    return text.isEmpty ? null : text;
  }

  static String? _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      final text = value?.trim();
      if (text != null && text.isNotEmpty) {
        return text;
      }
    }
    return null;
  }
}

class _AirspaceConnectorPainter extends CustomPainter {
  final Offset start;
  final Offset end;
  final Color color;
  final double strokeWidth;

  const _AirspaceConnectorPainter({
    required this.start,
    required this.end,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final control = Offset(
      (start.dx + end.dx) / 2,
      (start.dy + end.dy) / 2 - 14,
    );
    final path = ui.Path()
      ..moveTo(start.dx, start.dy)
      ..quadraticBezierTo(control.dx, control.dy, end.dx, end.dy);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _AirspaceConnectorPainter oldDelegate) {
    return oldDelegate.start != start ||
        oldDelegate.end != end ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

class _WeatherLegendChip extends StatelessWidget {
  final double scale;
  final String title;
  final String unit;
  final String startLabel;
  final String endLabel;
  final List<Color> colors;

  const _WeatherLegendChip({
    required this.scale,
    required this.title,
    required this.unit,
    required this.startLabel,
    required this.endLabel,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 10 * scale,
        vertical: 8 * scale,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(10 * scale),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$title ($unit)',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11 * scale,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 6 * scale),
          Container(
            width: 140 * scale,
            height: 10 * scale,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6 * scale),
              gradient: LinearGradient(colors: colors),
            ),
          ),
          SizedBox(height: 4 * scale),
          SizedBox(
            width: 140 * scale,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  startLabel,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 10 * scale,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  endLabel,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 10 * scale,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlannedRouteTotalChip extends StatelessWidget {
  final double scale;
  final String text;

  const _PlannedRouteTotalChip({required this.scale, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 10 * scale,
        vertical: 7 * scale,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(10 * scale),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white,
          fontSize: 12 * scale,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
