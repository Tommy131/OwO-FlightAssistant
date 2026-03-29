import 'dart:async';
import 'dart:math' as math;
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
                  if (provider.showWeather &&
                      provider.weatherRadarTileUrlTemplate != null &&
                      !provider.isWeatherRadarCoolingDown &&
                      zoom <= 7.9)
                    Opacity(
                      opacity: 0.6,
                      child: TileLayer(
                        key: ValueKey(
                          'weather-${provider.weatherRadarTimestamp}-${provider.tileReloadToken}',
                        ),
                        urlTemplate: provider.weatherRadarTileUrlTemplate!,
                        userAgentPackageName: 'com.owo.flight_assistant',
                        tileUpdateTransformer: _weatherRadarTransformer,
                        maxNativeZoom: 7,
                        minZoom: 3,
                        maxZoom: 7.9,
                        errorTileCallback: (tile, error, stackTrace) {
                          provider.handleWeatherRadarTileError(error);
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
                  onToggleCustomTaxiway: provider.toggleCustomTaxiway,
                  onToggleTaxiwayDrawing: provider.toggleTaxiwayDrawing,
                  showRoute: provider.showRoute,
                  showAirports: provider.showAirports,
                  showRunways: provider.showRunways,
                  showParkings: provider.showParkings,
                  showCompass: provider.showCompass,
                  showWeather: provider.showWeather,
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
              if (showTaxiwayEditStatus || showPlannedRouteChip)
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
                      if (showTaxiwayEditStatus && showPlannedRouteChip)
                        SizedBox(width: 8 * scale),
                      if (showPlannedRouteChip)
                        _PlannedRouteTotalChip(
                          scale: scale,
                          text:
                              '${MapLocalizationKeys.plannedRouteTotal.tr(context)}: ${plannedRouteTotalNm.toStringAsFixed(1)} NM',
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
