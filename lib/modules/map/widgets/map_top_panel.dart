import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../../core/services/localization_service.dart';
import '../../../core/theme/app_theme_data.dart';
import '../localization/map_localization_keys.dart';
import '../models/map_models.dart';
import '../providers/map_provider.dart';
import 'map_button.dart';

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
                        (alert) => FlightAlertChip(alert: alert, scale: scale),
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

class MapInfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final double scale;

  const MapInfoChip({
    super.key,
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

class FilterToggleButton extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color activeColor;
  final Color? inactiveColor;
  final double scale;

  const FilterToggleButton({
    super.key,
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

class AirportSearchBar extends StatefulWidget {
  final List<MapAirportMarker> airports;
  final ValueChanged<MapAirportMarker> onSelect;
  final int clearToken;
  final ValueChanged<bool> onSearchInputChanged;

  const AirportSearchBar({
    super.key,
    required this.airports,
    required this.onSelect,
    required this.clearToken,
    required this.onSearchInputChanged,
  });

  @override
  State<AirportSearchBar> createState() => _AirportSearchBarState();
}

class _AirportSearchBarState extends State<AirportSearchBar> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  Timer? _searchDebounce;
  List<MapAirportMarker> _results = [];
  bool _isSearching = false;

  @override
  void didUpdateWidget(covariant AirportSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.clearToken != oldWidget.clearToken) {
      _clearSearchInputState(notifyParent: false);
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
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
                  ? (_isSearching
                        ? const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Center(
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          )
                        : Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(
                              MapLocalizationKeys.searchNoResult.tr(context),
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.outline,
                                  ),
                            ),
                          ))
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
                            _controller.text = airport.code;
                            _controller.selection = TextSelection.collapsed(
                              offset: _controller.text.length,
                            );
                            _notifySearchInputChanged();
                            setState(() {
                              _results = [];
                              _isSearching = false;
                            });
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

  void _notifySearchInputChanged() {
    widget.onSearchInputChanged(_controller.text.trim().isNotEmpty);
  }

  void _clearSearchInputState({bool notifyParent = true}) {
    _controller.clear();
    setState(() {
      _results = [];
      _isSearching = false;
    });
    _hideOverlay();
    if (notifyParent) {
      _notifySearchInputChanged();
    }
  }

  void _onSearch(String value) {
    _searchDebounce?.cancel();
    final query = value.trim();
    _notifySearchInputChanged();
    if (query.isEmpty) {
      setState(() {
        _results = [];
        _isSearching = false;
      });
      _hideOverlay();
      return;
    }
    setState(() {
      _isSearching = true;
    });
    if (_overlayEntry == null) {
      _showOverlay();
    } else {
      _overlayEntry!.markNeedsBuild();
    }
    _searchDebounce = Timer(const Duration(milliseconds: 260), () async {
      final remoteResults = await context.read<MapProvider>().searchAirports(
        query,
      );
      final localResults = widget.airports.where((airport) {
        final name = airport.name?.toLowerCase() ?? '';
        final lowerQuery = query.toLowerCase();
        return airport.code.toLowerCase().contains(lowerQuery) ||
            name.contains(lowerQuery);
      }).toList();
      final merged = <MapAirportMarker>[
        ...remoteResults,
        ...localResults.where(
          (local) => !remoteResults.any((remote) => remote.code == local.code),
        ),
      ];
      if (!mounted) return;
      setState(() {
        _results = merged;
        _isSearching = false;
      });
      if (_overlayEntry == null) {
        _showOverlay();
      } else {
        _overlayEntry!.markNeedsBuild();
      }
    });
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
          hintText: MapLocalizationKeys.searchHint.tr(context),
          hintStyle: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.outline,
          ),
          prefixIcon: const Icon(Icons.search, size: 20),
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

class FlightAlertChip extends StatelessWidget {
  final MapFlightAlert alert;
  final double scale;

  const FlightAlertChip({super.key, required this.alert, required this.scale});

  @override
  Widget build(BuildContext context) {
    final (bg, border, icon) = switch (alert.level) {
      MapFlightAlertLevel.danger => (
        Colors.redAccent.withValues(alpha: 0.2),
        Colors.redAccent,
        Icons.warning_amber_rounded,
      ),
      MapFlightAlertLevel.warning => (
        Colors.orangeAccent.withValues(alpha: 0.2),
        Colors.orangeAccent,
        Icons.report_problem_outlined,
      ),
      MapFlightAlertLevel.caution => (
        Colors.yellowAccent.withValues(alpha: 0.2),
        Colors.yellowAccent,
        Icons.info_outline,
      ),
    };
    return Container(
      margin: EdgeInsets.only(right: 8 * scale),
      padding: EdgeInsets.symmetric(
        horizontal: 10 * scale,
        vertical: 6 * scale,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10 * scale),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14 * scale, color: border),
          SizedBox(width: 6 * scale),
          Text(
            alert.message.tr(context),
            style: TextStyle(
              color: Colors.white,
              fontSize: 11 * scale,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
