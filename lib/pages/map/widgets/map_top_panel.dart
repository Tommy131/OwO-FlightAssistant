import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../apps/providers/simulator/simulator_provider.dart';
import '../../home/widgets/airport_search_bar.dart';
import '../../../apps/providers/map_provider.dart';
import '../utils/map_utils.dart';
import 'map_button.dart';
import 'map_info_chip.dart';

/// 顶部 HUD 面板：搜索、数值、筛选项
class MapTopPanel extends StatelessWidget {
  final double scale;
  final MapController mapController;
  final SimulatorProvider sim;
  final MapProvider mapProvider;
  final bool followAircraft;
  final ValueChanged<bool> onFollowAircraftChanged;
  final bool showRunways;
  final bool showTaxiways;
  final bool showParkings;
  final bool showRouteDistance;
  final ValueChanged<bool> onShowRunwaysChanged;
  final ValueChanged<bool> onShowTaxiwaysChanged;
  final ValueChanged<bool> onShowParkingsChanged;
  final ValueChanged<bool> onShowRouteDistanceChanged;

  const MapTopPanel({
    super.key,
    required this.scale,
    required this.mapController,
    required this.sim,
    required this.mapProvider,
    required this.followAircraft,
    required this.onFollowAircraftChanged,
    required this.showRunways,
    required this.showTaxiways,
    required this.showParkings,
    required this.showRouteDistance,
    required this.onShowRunwaysChanged,
    required this.onShowTaxiwaysChanged,
    required this.onShowParkingsChanged,
    required this.onShowRouteDistanceChanged,
  });

  @override
  Widget build(BuildContext context) {
    final data = sim.simulatorData;

    return Positioned(
      top: 20 * scale,
      left: 20 * scale,
      right: 20 * scale,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: AirportSearchBar(
                  onSelect: (airport) {
                    mapProvider.selectTargetAirport(airport.icaoCode);
                    mapController.move(
                      LatLng(airport.latitude, airport.longitude),
                      15,
                    );
                    if (followAircraft) {
                      onFollowAircraftChanged(false);
                    }
                  },
                  hintText: '搜索并定位机场...',
                ),
              ),
              if (mapProvider.targetAirport != null) ...[
                SizedBox(width: 8 * scale),
                MapButton(
                  icon: Icons.close,
                  onPressed: () => mapProvider.clearTargetAirport(),
                  tooltip: '清除搜索记录',
                  mini: true,
                  scale: scale,
                ),
              ],
            ],
          ),
          if (sim.isConnected) ...[
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
                        '${(data.groundSpeed ?? 0).round()}',
                        'kt',
                      ),
                      _buildValue(
                        'ALT',
                        '${(data.altitude ?? 0).round()}',
                        'ft',
                      ),
                      _buildValue('HDG', '${(data.heading ?? 0).round()}°', ''),
                      _buildValue(
                        'VS',
                        '${(data.verticalSpeed ?? 0).round()}',
                        'fpm',
                        color: (data.verticalSpeed ?? 0).abs() > 800
                            ? Colors.redAccent
                            : Colors.tealAccent,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          if (sim.isConnected &&
              (data.baroPressure != null || data.windSpeed != null)) ...[
            SizedBox(height: 8 * scale),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  MapInfoChip(
                    icon: Icons.air,
                    label:
                        '${(data.windSpeed ?? 0).round()} kt / ${(data.windDirection ?? 0).round()}°',
                    scale: scale,
                  ),
                  SizedBox(width: 8 * scale),
                  MapInfoChip(
                    icon: Icons.cloud_outlined,
                    label:
                        '${data.baroPressure?.toStringAsFixed(2)} ${data.baroPressureUnit}',
                    scale: scale,
                  ),
                  if (data.outsideAirTemperature != null) ...[
                    SizedBox(width: 8 * scale),
                    MapInfoChip(
                      icon: Icons.thermostat,
                      label:
                          '${data.outsideAirTemperature?.toStringAsFixed(1)}°C',
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
              _buildFilterToggle('跑道', showRunways, onShowRunwaysChanged),
              SizedBox(width: 8 * scale),
              _buildFilterToggle('滑行道', showTaxiways, onShowTaxiwaysChanged),
              SizedBox(width: 8 * scale),
              _buildFilterToggle('停机位', showParkings, onShowParkingsChanged),
              if (sim.isConnected) ...[
                SizedBox(width: 8 * scale),
                _buildFilterToggle(
                  '气象雷达',
                  mapProvider.showWeatherRadar,
                  (val) => mapProvider.toggleWeatherRadar(),
                ),
              ],
              if (mapProvider.departureAirport != null &&
                  mapProvider.destinationAirport != null) ...[
                SizedBox(width: 8 * scale),
                _buildFilterToggle(
                  '航程: ${calculateTotalDistance(mapProvider)}NM',
                  showRouteDistance,
                  onShowRouteDistanceChanged,
                  activeColor: Colors.purpleAccent,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterToggle(
    String label,
    bool value,
    Function(bool) onChanged, {
    Color activeColor = Colors.orangeAccent,
  }) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: 10 * scale,
          vertical: 4 * scale,
        ),
        decoration: BoxDecoration(
          color: value ? activeColor.withValues(alpha: 0.2) : Colors.black54,
          borderRadius: BorderRadius.circular(16 * scale),
          border: Border.all(color: value ? activeColor : Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (value) ...[
              SizedBox(width: 4 * scale),
              Icon(Icons.check, size: 12 * scale, color: activeColor),
            ],
            SizedBox(width: value ? 4 * scale : 0),
            Text(
              label,
              style: TextStyle(
                color: value ? Colors.white : Colors.white70,
                fontSize: 10 * scale,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildValue(String label, String val, String unit, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white54,
            fontSize: 10 * scale,
            fontWeight: FontWeight.bold,
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              val,
              style: TextStyle(
                color: color ?? Colors.white,
                fontSize: 20 * scale,
                fontWeight: FontWeight.w900,
                fontFamily: 'monospace',
              ),
            ),
            SizedBox(width: 2 * scale),
            Text(
              unit,
              style: TextStyle(color: Colors.white38, fontSize: 9 * scale),
            ),
          ],
        ),
      ],
    );
  }
}
