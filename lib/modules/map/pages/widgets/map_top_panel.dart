import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/services/localization_service.dart';
import '../../localization/map_localization_keys.dart';
import '../../models/map_models.dart';
import 'map_button.dart';
import 'top_panel/airport_search_bar.dart';
import 'top_panel/flight_status_panel.dart';
import 'top_panel/top_panel_chips.dart';

class MapTopPanel extends StatelessWidget {
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
  final VoidCallback onToggleRunways;
  final VoidCallback onToggleParkings;
  final VoidCallback onToggleCompass;
  final VoidCallback onToggleWeather;
  final bool showRoute;
  final bool showAirports;
  final bool showRunways;
  final bool showParkings;
  final bool showCompass;
  final bool showWeather;
  final bool isConnected;
  final List<MapFlightAlert> activeAlerts;
  final VoidCallback onClearRoute;
  final int searchClearToken;
  final bool showSearchClearButton;
  final VoidCallback onClearSearchInput;
  final ValueChanged<bool> onSearchInputChanged;
  final Duration hudElapsed;
  final bool isSimulatorPaused;
  final bool isFlightLogRecording;

  const MapTopPanel({
    super.key,
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
    required this.onToggleRunways,
    required this.onToggleParkings,
    required this.onToggleCompass,
    required this.onToggleWeather,
    required this.showRoute,
    required this.showAirports,
    required this.showRunways,
    required this.showParkings,
    required this.showCompass,
    required this.showWeather,
    required this.isConnected,
    required this.activeAlerts,
    required this.onClearRoute,
    required this.searchClearToken,
    required this.showSearchClearButton,
    required this.onClearSearchInput,
    required this.onSearchInputChanged,
    required this.hudElapsed,
    required this.isSimulatorPaused,
    required this.isFlightLogRecording,
  });

  @override
  Widget build(BuildContext context) {
    final groundSpeed = aircraft?.groundSpeed;
    final altitude = aircraft?.altitude;
    final heading = aircraft?.heading;
    final duration = _formatDuration(hudElapsed);
    final vs = aircraft?.verticalSpeed ?? _calculateVerticalSpeed(route);
    final distanceNm = _calculateRouteDistance(route);

    return StreamBuilder<int>(
      stream: Stream.periodic(const Duration(seconds: 1), (i) => i),
      builder: (context, snapshot) {
        final blinkOn = ((snapshot.data ?? 0) % 2) == 0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: AirportSearchBar(
                    airports: airports,
                    onSelect: onSelectAirport,
                    clearToken: searchClearToken,
                    onSearchInputChanged: onSearchInputChanged,
                  ),
                ),
                if (showSearchClearButton) ...[
                  SizedBox(width: 8 * scale),
                  MapButton(
                    icon: Icons.close,
                    onPressed: onClearSearchInput,
                    tooltip: MapLocalizationKeys.clearSearch.tr(context),
                    mini: true,
                    scale: scale,
                  ),
                ],
              ],
            ),
            if (aircraft != null) ...[
              SizedBox(height: 12 * scale),
              MapFlightStatusPanel(
                scale: scale,
                groundSpeed: groundSpeed,
                altitude: altitude,
                heading: heading,
                duration: duration,
                verticalSpeed: vs,
                isSimulatorPaused: isSimulatorPaused,
                blinkOn: blinkOn,
              ),
            ],
            if (isFlightLogRecording ||
                route.isNotEmpty ||
                airports.isNotEmpty) ...[
              SizedBox(height: 8 * scale),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    if (isFlightLogRecording)
                      MapInfoChip(
                        icon: Icons.fiber_manual_record_rounded,
                        label: 'REC',
                        scale: scale,
                        backgroundColor: Colors.redAccent.withValues(
                          alpha: blinkOn ? 0.35 : 0.18,
                        ),
                        borderColor: Colors.redAccent.withValues(
                          alpha: blinkOn ? 1 : 0.6,
                        ),
                        iconColor: Colors.redAccent.withValues(
                          alpha: blinkOn ? 1 : 0.7,
                        ),
                        textColor: Colors.redAccent.withValues(
                          alpha: blinkOn ? 1 : 0.85,
                        ),
                      ),
                    if (isFlightLogRecording) SizedBox(width: 8 * scale),
                    if (route.isNotEmpty)
                      MapInfoChip(
                        icon: Icons.timeline,
                        label:
                            '${MapLocalizationKeys.routePoints.tr(context)}: ${route.length}',
                        scale: scale,
                      ),
                    if (route.isNotEmpty) SizedBox(width: 8 * scale),
                    if (airports.isNotEmpty)
                      MapInfoChip(
                        icon: Icons.flight_takeoff,
                        label:
                            '${MapLocalizationKeys.airports.tr(context)}: ${airports.length}',
                        scale: scale,
                      ),
                    if (distanceNm > 0) ...[
                      SizedBox(width: 8 * scale),
                      MapInfoChip(
                        icon: Icons.route,
                        label:
                            '${MapLocalizationKeys.distance.tr(context)}: ${distanceNm.round()}NM',
                        scale: scale,
                      ),
                    ],
                  ],
                ),
              ),
            ],
            if (activeAlerts.isNotEmpty) ...[
              SizedBox(height: 8 * scale),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: activeAlerts
                      .map(
                        (alert) => FlightAlertChip(
                          alert: alert,
                          scale: scale,
                          blinkOn: blinkOn,
                        ),
                      )
                      .toList(),
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
                          if (isConnected) ...[
                            FilterToggleButton(
                              label: MapLocalizationKeys.toggleRoute.tr(
                                context,
                              ),
                              value: showRoute,
                              onChanged: (value) => onToggleRoute(),
                              scale: scale,
                            ),
                            SizedBox(width: 8 * scale),
                          ],
                          FilterToggleButton(
                            label: MapLocalizationKeys.toggleNearbyAirports.tr(
                              context,
                            ),
                            value: showAirports,
                            onChanged: (value) => onToggleAirports(),
                            activeColor: Colors.blueGrey,
                            scale: scale,
                          ),
                          SizedBox(width: 8 * scale),
                          FilterToggleButton(
                            label: MapLocalizationKeys.toggleRunways.tr(
                              context,
                            ),
                            value: showRunways,
                            onChanged: (value) => onToggleRunways(),
                            activeColor: Colors.deepOrangeAccent,
                            scale: scale,
                          ),
                          SizedBox(width: 8 * scale),
                          FilterToggleButton(
                            label: MapLocalizationKeys.toggleParkings.tr(
                              context,
                            ),
                            value: showParkings,
                            onChanged: (value) => onToggleParkings(),
                            activeColor: Colors.lightBlueAccent,
                            scale: scale,
                          ),
                          if (isConnected) ...[
                            SizedBox(width: 8 * scale),
                            FilterToggleButton(
                              label: MapLocalizationKeys.toggleCompass.tr(
                                context,
                              ),
                              value: showCompass,
                              onChanged: (value) => onToggleCompass(),
                              activeColor: Colors.blueAccent,
                              scale: scale,
                            ),
                          ],
                          SizedBox(width: 8 * scale),
                          FilterToggleButton(
                            label: MapLocalizationKeys.toggleWeather.tr(
                              context,
                            ),
                            value: showWeather,
                            onChanged: (value) => onToggleWeather(),
                            scale: scale,
                          ),
                          if (isConnected && distanceNm > 0) ...[
                            SizedBox(width: 8 * scale),
                            FilterToggleButton(
                              label:
                                  '${MapLocalizationKeys.distance.tr(context)}: ${distanceNm.round()}NM',
                              value: showRoute,
                              onChanged: (value) => onToggleRoute(),
                              activeColor: Colors.purpleAccent,
                              scale: scale,
                            ),
                          ],
                          if (isConnected && route.isNotEmpty) ...[
                            SizedBox(width: 8 * scale),
                            FilterToggleButton(
                              label: MapLocalizationKeys.clearRoute.tr(context),
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

  String _formatDuration(Duration duration) {
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
}
