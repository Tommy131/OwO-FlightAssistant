import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/services/localization_service.dart';
import '../../localization/map_localization_keys.dart';
import '../../models/map_models.dart';
import 'map_button.dart';
import 'top_panel/airport_search_bar.dart';
import 'top_panel/flight_status_panel.dart';
import 'top_panel/taxiway_draw_controls.dart';
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
  final VoidCallback onToggleWeatherRainfall;
  final VoidCallback onToggleWeatherWind;
  final VoidCallback onToggleWeatherPressure;
  final VoidCallback onToggleWeatherTemperature;
  final VoidCallback onToggleRestrictedAirspace;
  final VoidCallback onToggleTerrainWarning;
  final VoidCallback onToggleCustomTaxiway;
  final VoidCallback onToggleTaxiwayDrawing;
  final bool showRoute;
  final bool showAirports;
  final bool showRunways;
  final bool showParkings;
  final bool showCompass;
  final bool showWeather;
  final bool showWeatherRainfall;
  final bool showWeatherWind;
  final bool showWeatherPressure;
  final bool showWeatherTemperature;
  final bool showRestrictedAirspace;
  final bool showTerrainWarning;
  final bool showCustomTaxiway;
  final bool isTaxiwayDrawingActive;
  final bool showTaxiwayControls;
  final bool isConnected;
  final List<MapFlightAlert> activeAlerts;
  final VoidCallback onClearRoute;
  final VoidCallback onToggleHudTimer;
  final VoidCallback onResetHudTimer;
  final int searchClearToken;
  final bool showSearchClearButton;
  final VoidCallback onClearSearchInput;
  final ValueChanged<bool> onSearchInputChanged;
  final Duration hudElapsed;
  final bool isHudTimerRunning;
  final bool hasHudTimerStarted;

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
    required this.onToggleWeatherRainfall,
    required this.onToggleWeatherWind,
    required this.onToggleWeatherPressure,
    required this.onToggleWeatherTemperature,
    required this.onToggleRestrictedAirspace,
    required this.onToggleTerrainWarning,
    required this.onToggleCustomTaxiway,
    required this.onToggleTaxiwayDrawing,
    required this.showRoute,
    required this.showAirports,
    required this.showRunways,
    required this.showParkings,
    required this.showCompass,
    required this.showWeather,
    required this.showWeatherRainfall,
    required this.showWeatherWind,
    required this.showWeatherPressure,
    required this.showWeatherTemperature,
    required this.showRestrictedAirspace,
    required this.showTerrainWarning,
    required this.showCustomTaxiway,
    required this.isTaxiwayDrawingActive,
    required this.showTaxiwayControls,
    required this.isConnected,
    required this.activeAlerts,
    required this.onClearRoute,
    required this.onToggleHudTimer,
    required this.onResetHudTimer,
    required this.searchClearToken,
    required this.showSearchClearButton,
    required this.onClearSearchInput,
    required this.onSearchInputChanged,
    required this.hudElapsed,
    required this.isHudTimerRunning,
    required this.hasHudTimerStarted,
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
                isHudTimerRunning: isHudTimerRunning,
                showPauseIndicator: hasHudTimerStarted && !isHudTimerRunning,
              ),
            ],
            if (route.isNotEmpty || distanceNm > 0) ...[
              SizedBox(height: 8 * scale),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    if (route.isNotEmpty)
                      MapInfoChip(
                        icon: Icons.timeline,
                        label:
                            '${MapLocalizationKeys.routePoints.tr(context)}: ${route.length}',
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
                SizedBox(width: 8 * scale),
                Expanded(
                  child: Row(
                    children: [
                      if (isFilterExpanded)
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
                                  label: MapLocalizationKeys
                                      .toggleNearbyAirports
                                      .tr(context),
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
                                if (showWeather) ...[
                                  SizedBox(width: 8 * scale),
                                  FilterToggleButton(
                                    label: MapLocalizationKeys
                                        .toggleWeatherRainfall
                                        .tr(context),
                                    value: showWeatherRainfall,
                                    onChanged: (value) =>
                                        onToggleWeatherRainfall(),
                                    activeColor: Colors.lightBlueAccent,
                                    scale: scale,
                                  ),
                                  if (isConnected) ...[
                                    SizedBox(width: 8 * scale),
                                    FilterToggleButton(
                                      label: MapLocalizationKeys
                                          .toggleWeatherWind
                                          .tr(context),
                                      value: showWeatherWind,
                                      onChanged: (value) =>
                                          onToggleWeatherWind(),
                                      activeColor: Colors.cyanAccent,
                                      scale: scale,
                                    ),
                                  ],
                                  SizedBox(width: 8 * scale),
                                  FilterToggleButton(
                                    label: MapLocalizationKeys
                                        .toggleWeatherPressure
                                        .tr(context),
                                    value: showWeatherPressure,
                                    onChanged: (value) =>
                                        onToggleWeatherPressure(),
                                    activeColor: Colors.purpleAccent,
                                    scale: scale,
                                  ),
                                  SizedBox(width: 8 * scale),
                                  FilterToggleButton(
                                    label: MapLocalizationKeys
                                        .toggleWeatherTemperature
                                        .tr(context),
                                    value: showWeatherTemperature,
                                    onChanged: (value) =>
                                        onToggleWeatherTemperature(),
                                    activeColor: Colors.deepOrangeAccent,
                                    scale: scale,
                                  ),
                                ],
                                SizedBox(width: 8 * scale),
                                FilterToggleButton(
                                  label: MapLocalizationKeys
                                      .toggleRestrictedAirspace
                                      .tr(context),
                                  value: showRestrictedAirspace,
                                  onChanged: (value) =>
                                      onToggleRestrictedAirspace(),
                                  activeColor: Colors.orangeAccent,
                                  scale: scale,
                                ),
                                if (isConnected) ...[
                                  SizedBox(width: 8 * scale),
                                  FilterToggleButton(
                                    label: MapLocalizationKeys
                                        .toggleTerrainWarning
                                        .tr(context),
                                    value: showTerrainWarning,
                                    onChanged: (value) =>
                                        onToggleTerrainWarning(),
                                    activeColor: Colors.redAccent,
                                    scale: scale,
                                  ),
                                ],
                                SizedBox(width: 8 * scale),
                                TaxiwayDrawControls(
                                  showCustomTaxiwayButton: showTaxiwayControls,
                                  showCustomTaxiway: showCustomTaxiway,
                                  isTaxiwayDrawingActive:
                                      isTaxiwayDrawingActive,
                                  onToggleCustomTaxiway: onToggleCustomTaxiway,
                                  onToggleTaxiwayDrawing:
                                      onToggleTaxiwayDrawing,
                                  scale: scale,
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        const Spacer(),
                      if (isConnected) ...[
                        SizedBox(width: 18 * scale),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              FilterToggleButton(
                                label: isHudTimerRunning
                                    ? MapLocalizationKeys.tooltipTimerPause.tr(
                                        context,
                                      )
                                    : MapLocalizationKeys.tooltipTimerStart.tr(
                                        context,
                                      ),
                                value: isHudTimerRunning,
                                onChanged: (_) => onToggleHudTimer(),
                                activeColor: Colors.lightGreenAccent,
                                inactiveColor: Colors.greenAccent,
                                leadingIcon: isHudTimerRunning
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                showActiveCheck: false,
                                scale: scale,
                              ),
                              SizedBox(width: 8 * scale),
                              FilterToggleButton(
                                label: MapLocalizationKeys.tooltipTimerReset.tr(
                                  context,
                                ),
                                value: false,
                                onChanged: (_) => onResetHudTimer(),
                                activeColor: Colors.amberAccent,
                                inactiveColor: Colors.amberAccent,
                                leadingIcon: Icons.restart_alt_rounded,
                                leadingIconColor: Colors.amberAccent,
                                showActiveCheck: false,
                                scale: scale,
                              ),
                              SizedBox(width: 8 * scale),
                              FilterToggleButton(
                                label: MapLocalizationKeys.clearRoute.tr(
                                  context,
                                ),
                                value: false,
                                onChanged: (_) => onClearRoute(),
                                activeColor: Colors.redAccent,
                                inactiveColor: Colors.redAccent,
                                leadingIcon: Icons.delete_outline_rounded,
                                leadingIconColor: Colors.redAccent,
                                showActiveCheck: false,
                                scale: scale,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
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
