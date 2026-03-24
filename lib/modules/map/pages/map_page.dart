import 'dart:async';
import 'dart:math' as math;
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
  static const List<String> _taxiwayColorHexPalette = [
    '#00E5FF',
    '#4CAF50',
    '#FFC107',
    '#FF7043',
    '#EC407A',
    '#7E57C2',
    '#42A5F5',
    '#FFFFFF',
  ];

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
  Timer? _airportFetchTimer;
  LatLngBounds? _lastFetchBounds;
  int? _selectedTaxiwayNodeIndex;
  int? _draggingTaxiwayNodeIndex;
  int? _draggingTaxiwaySegmentIndex;
  int? _hoveredTaxiwayNodeIndex;
  Offset? _hoveredTaxiwayNodeGlobalPosition;
  bool _isTaxiwayLoadPromptShowing = false;
  bool _isSavingTaxiwayRoute = false;
  final Set<String> _taxiwayAutoPromptedAirports = <String>{};

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
        if (_hoveredTaxiwayNodeIndex != null &&
            _hoveredTaxiwayNodeIndex! >= 0 &&
            _hoveredTaxiwayNodeIndex! < taxiwayNodes.length &&
            _hoveredTaxiwayNodeGlobalPosition != null &&
            mapRenderBox != null) {
          hoveredNodeLocalOffset = mapRenderBox.globalToLocal(
            _hoveredTaxiwayNodeGlobalPosition!,
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
                                  ? MapLocalizationKeys.tooltipHideDetail.tr(
                                      context,
                                    )
                                  : MapLocalizationKeys.tooltipShowDetail.tr(
                                      context,
                                    ),
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
                            child: FlightEventMarker(
                              icon: Icons.flight_takeoff,
                              label: MapLocalizationKeys.labelTakeoff.tr(
                                context,
                              ),
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
                              label: MapLocalizationKeys.labelLanding.tr(
                                context,
                              ),
                              color: Colors.greenAccent,
                            ),
                          ),
                      ],
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
                      onSegmentCurveDragStart: provider.isTaxiwayDrawingActive
                          ? (segmentIndex, globalPosition) {
                              setState(() {
                                _draggingTaxiwaySegmentIndex = segmentIndex;
                              });
                              _updateTaxiwaySegmentCurveByDrag(
                                provider: provider,
                                segmentIndex: segmentIndex,
                                globalPosition: globalPosition,
                              );
                            }
                          : null,
                      onSegmentCurveDragUpdate: provider.isTaxiwayDrawingActive
                          ? (segmentIndex, globalPosition) {
                              _updateTaxiwaySegmentCurveByDrag(
                                provider: provider,
                                segmentIndex: segmentIndex,
                                globalPosition: globalPosition,
                              );
                            }
                          : null,
                      onSegmentCurveDragEnd: provider.isTaxiwayDrawingActive
                          ? (_) {
                              if (_draggingTaxiwaySegmentIndex != null) {
                                setState(() {
                                  _draggingTaxiwaySegmentIndex = null;
                                });
                              }
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
                  child: _TaxiwayNodeInfoCard(
                    scale: scale,
                    index: _hoveredTaxiwayNodeIndex!,
                    node: taxiwayNodes[_hoveredTaxiwayNodeIndex!],
                    headingDeg: _computeTaxiwayNodeHeading(
                      taxiwayNodes,
                      _hoveredTaxiwayNodeIndex!,
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
        String selectedPath = files.first.filePath;
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return StatefulBuilder(
              builder: (context, setModalState) {
                return AlertDialog(
                  title: Text(
                    '${MapLocalizationKeys.taxiwayAutoLoadTitle.tr(context)} ($resolvedIcao)',
                  ),
                  content: SizedBox(
                    width: 520,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          MapLocalizationKeys.taxiwayAutoLoadPrompt.tr(context),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 320,
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: files.length,
                            itemBuilder: (context, index) {
                              final item = files[index];
                              final selected = selectedPath == item.filePath;
                              final modifiedText = _formatDateTime(
                                item.lastModified,
                              );
                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 0,
                                ),
                                onTap: () {
                                  setModalState(() {
                                    selectedPath = item.filePath;
                                  });
                                },
                                leading: Icon(
                                  selected
                                      ? Icons.radio_button_checked
                                      : Icons.radio_button_unchecked,
                                  size: 20,
                                ),
                                title: Text(item.fileName),
                                subtitle: Text(
                                  '${MapLocalizationKeys.labelLastEdited.tr(context)}: $modifiedText  ·  ${MapLocalizationKeys.labelNodeCount.tr(context)}: ${item.nodeCount}',
                                ),
                                selected: selected,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                      child: Text(
                        MapLocalizationKeys.taxiwayAutoLoadSkip.tr(context),
                      ),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.of(dialogContext).pop(true),
                      child: Text(
                        MapLocalizationKeys.taxiwayAutoLoadLoad.tr(context),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
        if (confirmed == true) {
          final loadedCount = await provider.importTaxiwayRouteFromPath(
            selectedPath,
          );
          if (mounted) {
            final message = loadedCount > 0
                ? '${MapLocalizationKeys.taxiwayAutoLoadLoaded.tr(context)}: $loadedCount'
                : MapLocalizationKeys.taxiwayAutoLoadInvalid.tr(context);
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(message)));
          }
        }
      } finally {
        _isTaxiwayLoadPromptShowing = false;
      }
    });
  }

  String _formatDateTime(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute';
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

  void _updateTaxiwaySegmentCurveByDrag({
    required MapProvider provider,
    required int segmentIndex,
    required Offset globalPosition,
  }) {
    if (!provider.isTaxiwayDrawingActive) {
      return;
    }
    final nodes = provider.taxiwayNodes;
    if (segmentIndex < 0 || segmentIndex >= nodes.length - 1) {
      return;
    }
    final segments = provider.taxiwaySegments;
    if (segmentIndex < 0 || segmentIndex >= segments.length) {
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
    final start = nodes[segmentIndex];
    final end = nodes[segmentIndex + 1];
    final startOffset = _mapController.camera.latLngToScreenOffset(
      LatLng(start.latitude, start.longitude),
    );
    final endOffset = _mapController.camera.latLngToScreenOffset(
      LatLng(end.latitude, end.longitude),
    );
    final pointerOffset = renderBox.globalToLocal(globalPosition);
    final vector = endOffset - startOffset;
    final length = vector.distance;
    if (length <= 0.01) {
      return;
    }
    final relative = pointerOffset - startOffset;
    final cross = vector.dx * relative.dy - vector.dy * relative.dx;
    final distanceToLine = cross.abs() / length;
    final offsetFactor = (distanceToLine / length).clamp(0.0, 0.57).toDouble();
    final nextCurvature = ((offsetFactor - 0.12) / 0.45).clamp(0.0, 1.0);
    final nextDirection = cross < 0
        ? MapTaxiwaySegmentCurveDirection.left
        : MapTaxiwaySegmentCurveDirection.right;
    final target = segments[segmentIndex];
    provider.updateTaxiwaySegmentInfo(
      segmentIndex,
      name: target.name,
      colorHex: target.colorHex,
      note: target.note,
      lineType: MapTaxiwaySegmentLineType.mapMatching,
      curvature: nextCurvature.toDouble(),
      curveDirection: nextDirection,
    );
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

  Future<void> _showTaxiwaySegmentEditor(
    MapProvider provider,
    int segmentIndex,
  ) async {
    final nodes = provider.taxiwayNodes;
    if (segmentIndex < 0 || segmentIndex >= nodes.length - 1) {
      return;
    }
    final segments = provider.taxiwaySegments;
    final target = segmentIndex < segments.length
        ? segments[segmentIndex]
        : const MapTaxiwaySegment();
    final nameController = TextEditingController(text: target.name ?? '');
    final noteController = TextEditingController(text: target.note ?? '');
    var selectedColorHex = target.colorHex ?? '#FFD54F';
    var selectedLineType = target.lineType;
    var selectedCurvature = target.curvature;
    var selectedCurveDirection = target.curveDirection;
    final startNode = nodes[segmentIndex];
    final endNode = nodes[segmentIndex + 1];
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: Text(
                '${MapLocalizationKeys.taxiwayConnection.tr(context)} ${segmentIndex + 1}',
              ),
              content: SizedBox(
                width: 360,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${MapLocalizationKeys.taxiwayConnectionRange.tr(context)}：${segmentIndex + 1} → ${segmentIndex + 2}\n'
                          '${MapLocalizationKeys.labelLatitudeLongitude.tr(context)}：${startNode.latitude.toStringAsFixed(6)}, ${startNode.longitude.toStringAsFixed(6)} ↔ ${endNode.latitude.toStringAsFixed(6)}, ${endNode.longitude.toStringAsFixed(6)}',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: nameController,
                        decoration: InputDecoration(
                          labelText: MapLocalizationKeys.taxiwayConnectionName
                              .tr(context),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: noteController,
                        decoration: InputDecoration(
                          labelText: MapLocalizationKeys.taxiwayConnectionNote
                              .tr(context),
                        ),
                        minLines: 2,
                        maxLines: 3,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        MapLocalizationKeys.taxiwayConnectionColor.tr(context),
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _taxiwayColorHexPalette
                            .map(
                              (hex) => GestureDetector(
                                onTap: () {
                                  setModalState(() {
                                    selectedColorHex = hex;
                                  });
                                },
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: _colorFromHex(hex),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: selectedColorHex == hex
                                          ? Colors.white
                                          : Colors.black.withValues(
                                              alpha: 0.45,
                                            ),
                                      width: selectedColorHex == hex ? 2 : 1,
                                    ),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${MapLocalizationKeys.taxiwayNodeCurrentColor.tr(context)}：$selectedColorHex',
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        MapLocalizationKeys.taxiwayConnectionLineType.tr(
                          context,
                        ),
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<MapTaxiwaySegmentLineType>(
                        initialValue: selectedLineType,
                        decoration: const InputDecoration(),
                        items: [
                          DropdownMenuItem<MapTaxiwaySegmentLineType>(
                            value: MapTaxiwaySegmentLineType.straight,
                            child: Text(
                              MapLocalizationKeys
                                  .taxiwayConnectionLineTypeStraight
                                  .tr(context),
                            ),
                          ),
                          DropdownMenuItem<MapTaxiwaySegmentLineType>(
                            value: MapTaxiwaySegmentLineType.mapMatching,
                            child: Text(
                              MapLocalizationKeys
                                  .taxiwayConnectionLineTypeMapMatching
                                  .tr(context),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }
                          setModalState(() {
                            selectedLineType = value;
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${MapLocalizationKeys.taxiwayConnectionCurvature.tr(context)}：${selectedCurvature.toStringAsFixed(2)}',
                      ),
                      Slider(
                        value: selectedCurvature.clamp(0.0, 1.0).toDouble(),
                        min: 0.0,
                        max: 1.0,
                        divisions: 20,
                        onChanged:
                            selectedLineType ==
                                MapTaxiwaySegmentLineType.mapMatching
                            ? (value) {
                                setModalState(() {
                                  selectedCurvature = value;
                                });
                              }
                            : null,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        MapLocalizationKeys.taxiwayConnectionCurveDirection.tr(
                          context,
                        ),
                      ),
                      DropdownButtonFormField<MapTaxiwaySegmentCurveDirection>(
                        initialValue: selectedCurveDirection,
                        decoration: const InputDecoration(),
                        items: [
                          DropdownMenuItem<MapTaxiwaySegmentCurveDirection>(
                            value: MapTaxiwaySegmentCurveDirection.left,
                            child: Text(
                              MapLocalizationKeys
                                  .taxiwayConnectionCurveDirectionLeft
                                  .tr(context),
                            ),
                          ),
                          DropdownMenuItem<MapTaxiwaySegmentCurveDirection>(
                            value: MapTaxiwaySegmentCurveDirection.right,
                            child: Text(
                              MapLocalizationKeys
                                  .taxiwayConnectionCurveDirectionRight
                                  .tr(context),
                            ),
                          ),
                        ],
                        onChanged:
                            selectedLineType ==
                                MapTaxiwaySegmentLineType.mapMatching
                            ? (value) {
                                if (value == null) {
                                  return;
                                }
                                setModalState(() {
                                  selectedCurveDirection = value;
                                });
                              }
                            : null,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        MapLocalizationKeys.taxiwayConnectionDragHint.tr(
                          context,
                        ),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                  child: Text(LocalizationKeys.cancel.tr(context)),
                ),
                FilledButton(
                  onPressed: () {
                    provider.updateTaxiwaySegmentInfo(
                      segmentIndex,
                      name: nameController.text,
                      colorHex: selectedColorHex,
                      note: noteController.text,
                      lineType: selectedLineType,
                      curvature: selectedCurvature,
                      curveDirection: selectedCurveDirection,
                    );
                    Navigator.of(dialogContext).pop();
                  },
                  child: Text(LocalizationKeys.save.tr(context)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showTaxiwayNodeEditor(MapProvider provider, int index) async {
    final nodes = provider.taxiwayNodes;
    if (index < 0 || index >= nodes.length) {
      return;
    }
    setState(() {
      _selectedTaxiwayNodeIndex = index;
    });
    final target = nodes[index];
    final nameController = TextEditingController(text: target.name ?? '');
    final noteController = TextEditingController(text: target.note ?? '');
    final headingDeg = _computeTaxiwayNodeHeading(nodes, index);
    var selectedColorHex = target.colorHex ?? '#00E5FF';
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: Text(
                '${MapLocalizationKeys.taxiwayNode.tr(context)} ${index + 1} ${MapLocalizationKeys.taxiwayNodeSettings.tr(context)}',
              ),
              content: SizedBox(
                width: 360,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${MapLocalizationKeys.taxiwayNode.tr(context)} ${index + 1}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${MapLocalizationKeys.labelLatitudeLongitude.tr(context)}：${target.latitude.toStringAsFixed(6)}, ${target.longitude.toStringAsFixed(6)}',
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${MapLocalizationKeys.labelHeading.tr(context)}：${headingDeg == null ? '--' : '${headingDeg.toStringAsFixed(0)}°'}',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: nameController,
                        decoration: InputDecoration(
                          labelText: MapLocalizationKeys.taxiwayNodeName.tr(
                            context,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: noteController,
                        decoration: InputDecoration(
                          labelText: MapLocalizationKeys.taxiwayNodeNote.tr(
                            context,
                          ),
                        ),
                        minLines: 2,
                        maxLines: 3,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        MapLocalizationKeys.taxiwayNodeColor.tr(context),
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _taxiwayColorHexPalette
                            .map(
                              (hex) => GestureDetector(
                                onTap: () {
                                  setModalState(() {
                                    selectedColorHex = hex;
                                  });
                                },
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: _colorFromHex(hex),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: selectedColorHex == hex
                                          ? Colors.white
                                          : Colors.black.withValues(
                                              alpha: 0.45,
                                            ),
                                      width: selectedColorHex == hex ? 2 : 1,
                                    ),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${MapLocalizationKeys.taxiwayNodeCurrentColor.tr(context)}：$selectedColorHex',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                  child: Text(LocalizationKeys.cancel.tr(context)),
                ),
                TextButton(
                  onPressed: () {
                    provider.removeTaxiwayNodeAt(index);
                    setState(() {
                      final nextLength = provider.taxiwayNodes.length;
                      if (nextLength <= 0) {
                        _selectedTaxiwayNodeIndex = null;
                      } else {
                        _selectedTaxiwayNodeIndex = index >= nextLength
                            ? nextLength - 1
                            : index;
                      }
                    });
                    Navigator.of(dialogContext).pop();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                  ),
                  child: Text(
                    MapLocalizationKeys.taxiwayDeleteNode.tr(context),
                  ),
                ),
                FilledButton(
                  onPressed: () {
                    provider.updateTaxiwayNodeInfo(
                      index,
                      name: nameController.text,
                      colorHex: selectedColorHex,
                      note: noteController.text,
                    );
                    Navigator.of(dialogContext).pop();
                  },
                  child: Text(LocalizationKeys.save.tr(context)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  double? _computeTaxiwayNodeHeading(List<MapTaxiwayNode> nodes, int index) {
    if (nodes.length < 2 || index < 0 || index >= nodes.length) {
      return null;
    }
    LatLng from;
    LatLng to;
    if (index < nodes.length - 1) {
      from = LatLng(nodes[index].latitude, nodes[index].longitude);
      to = LatLng(nodes[index + 1].latitude, nodes[index + 1].longitude);
    } else {
      from = LatLng(nodes[index - 1].latitude, nodes[index - 1].longitude);
      to = LatLng(nodes[index].latitude, nodes[index].longitude);
    }
    final raw = _distance.bearing(from, to);
    return (raw + 360) % 360;
  }

  Color _colorFromHex(String hex) {
    final normalized = hex.trim().toUpperCase().replaceAll('#', '');
    if (RegExp(r'^[0-9A-F]{6}$').hasMatch(normalized)) {
      return Color(int.parse('FF$normalized', radix: 16));
    }
    if (RegExp(r'^[0-9A-F]{8}$').hasMatch(normalized)) {
      return Color(int.parse(normalized, radix: 16));
    }
    return Colors.cyanAccent;
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

class _TaxiwayNodeInfoCard extends StatelessWidget {
  final double scale;
  final int index;
  final MapTaxiwayNode node;
  final double? headingDeg;

  const _TaxiwayNodeInfoCard({
    required this.scale,
    required this.index,
    required this.node,
    required this.headingDeg,
  });

  @override
  Widget build(BuildContext context) {
    final headingText = headingDeg == null
        ? '--'
        : '${headingDeg!.toStringAsFixed(0)}°';
    return Container(
      width: 240 * scale,
      padding: EdgeInsets.symmetric(
        horizontal: 12 * scale,
        vertical: 10 * scale,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(10 * scale),
        border: Border.all(color: Colors.white24),
      ),
      child: DefaultTextStyle(
        style: TextStyle(color: Colors.white, fontSize: 12 * scale),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              (node.name ?? '').trim().isEmpty
                  ? '${MapLocalizationKeys.taxiwayNode.tr(context)} ${index + 1}'
                  : '${node.name} (${MapLocalizationKeys.taxiwayNode.tr(context)} ${index + 1})',
              style: TextStyle(
                fontSize: 13 * scale,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 6 * scale),
            Text(
              '${MapLocalizationKeys.labelLatitudeLongitude.tr(context)}：${node.latitude.toStringAsFixed(6)}, ${node.longitude.toStringAsFixed(6)}',
            ),
            SizedBox(height: 3 * scale),
            Text(
              '${MapLocalizationKeys.labelHeading.tr(context)}：$headingText',
            ),
          ],
        ),
      ),
    );
  }
}
