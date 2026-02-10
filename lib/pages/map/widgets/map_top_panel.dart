import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../apps/models/flight_log/flight_log.dart';
import '../../../apps/providers/simulator/simulator_provider.dart';
import '../../home/widgets/airport_search_bar.dart';
import '../../../apps/providers/map_provider.dart';
import '../utils/map_utils.dart';
import 'map_button.dart';
import 'map_info_chip.dart';
import 'filter_toggle_button.dart';

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
  final bool showAircraftCompass;
  final bool showNearbyAirports;
  final bool isFilterExpanded;
  final ValueChanged<bool> onFilterExpandedChanged;
  final ValueChanged<bool> onShowRunwaysChanged;
  final ValueChanged<bool> onShowTaxiwaysChanged;
  final ValueChanged<bool> onShowParkingsChanged;
  final ValueChanged<bool> onShowRouteDistanceChanged;
  final ValueChanged<bool> onShowAircraftCompassChanged;
  final ValueChanged<bool> onShowNearbyAirportsChanged;

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
    required this.showAircraftCompass,
    required this.showNearbyAirports,
    required this.isFilterExpanded,
    required this.onFilterExpandedChanged,
    required this.onShowRunwaysChanged,
    required this.onShowTaxiwaysChanged,
    required this.onShowParkingsChanged,
    required this.onShowRouteDistanceChanged,
    required this.onShowAircraftCompassChanged,
    required this.onShowNearbyAirportsChanged,
  });

  @override
  Widget build(BuildContext context) {
    final data = sim.simulatorData;

    return StreamBuilder<int>(
      stream: Stream.periodic(const Duration(seconds: 1), (i) => i),
      builder: (context, snapshot) {
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
                          _buildValue(
                            'HDG',
                            '${(data.heading ?? 0).round()}°',
                            '',
                          ),
                          _buildValue(
                            'TIME',
                            _formatDuration(sim.currentFlightLog),
                            '',
                            color: Colors.cyanAccent,
                            trailWidget: sim.currentFlightLog != null
                                ? GestureDetector(
                                    onTap: () => sim.resetFlightTime(),
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        color: Colors.cyanAccent.withValues(
                                          alpha: 0.2,
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Icon(
                                        Icons.refresh_rounded,
                                        size: 10 * scale,
                                        color: Colors.cyanAccent,
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                          _buildValue(
                            'VS',
                            '${(data.verticalSpeed ?? 0).round()}',
                            'fpm',
                            color: _getVSColor(data.verticalSpeed ?? 0),
                            icon: _getVSIcon(data.verticalSpeed ?? 0),
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
                  // 展开/收起按钮
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
                            FilterToggleButton(
                              label: '跑道',
                              value: showRunways,
                              onChanged: onShowRunwaysChanged,
                              scale: scale,
                            ),
                            SizedBox(width: 8 * scale),
                            if (sim.simulatorData.onGround ?? true) ...[
                              FilterToggleButton(
                                label: '滑行道',
                                value: showTaxiways,
                                onChanged: onShowTaxiwaysChanged,
                                scale: scale,
                              ),
                              SizedBox(width: 8 * scale),
                              FilterToggleButton(
                                label: '停机位',
                                value: showParkings,
                                onChanged: onShowParkingsChanged,
                                scale: scale,
                              ),
                              SizedBox(width: 8 * scale),
                            ],
                            FilterToggleButton(
                              label: '附近机场',
                              value: showNearbyAirports,
                              onChanged: onShowNearbyAirportsChanged,
                              activeColor: Colors.blueGrey,
                              scale: scale,
                            ),
                            SizedBox(width: 8 * scale),
                            if (sim.isConnected) ...[
                              FilterToggleButton(
                                label: '罗盘',
                                value: showAircraftCompass,
                                onChanged: onShowAircraftCompassChanged,
                                activeColor: Colors.blueAccent,
                                scale: scale,
                              ),
                            ],
                            if (sim.isConnected) ...[
                              SizedBox(width: 8 * scale),
                              FilterToggleButton(
                                label: '气象雷达',
                                value: mapProvider.showWeatherRadar,
                                onChanged: (val) =>
                                    mapProvider.toggleWeatherRadar(),
                                scale: scale,
                              ),
                            ],
                            if (mapProvider.departureAirport != null &&
                                mapProvider.destinationAirport != null) ...[
                              SizedBox(width: 8 * scale),
                              FilterToggleButton(
                                label:
                                    '航程: ${calculateTotalDistance(mapProvider)}NM',
                                value: showRouteDistance,
                                onChanged: onShowRouteDistanceChanged,
                                activeColor: Colors.purpleAccent,
                                scale: scale,
                              ),
                            ],
                            if (mapProvider.path.isNotEmpty) ...[
                              SizedBox(width: 8 * scale),
                              FilterToggleButton(
                                label: '清除轨迹',
                                value: false,
                                onChanged: (val) =>
                                    _showClearConfirmation(context),
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
          ),
        );
      },
    );
  }

  String _formatDuration(FlightLog? log) {
    if (log == null) return '00:00:00';
    final duration = log.duration;
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  void _showClearConfirmation(BuildContext context) {
    // 只有在地图 Tab 且路径不为空时才显示确认弹窗。
    // 这里不再由 MapTopPanel 决定是否显示，而是增加一个逻辑判断。
    if (!context.mounted || mapProvider.path.isEmpty) return;

    // 获取当前路由名称或通过上下文判断是否在地图页面
    // 这里的优化是针对“切换 tab 页面时提示频繁”的问题。
    // 原逻辑是在 build 中渲染“清除轨迹”按钮，点击触发此方法。
    // 如果用户只是切换 Tab，不应该触发此方法。

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清除飞行数据'),
        content: const Text('确定要清除当前的飞行轨迹、起飞/降落标记点及起飞机场信息吗？该操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              mapProvider.clearFlightData();
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('确定清除'),
          ),
        ],
      ),
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
                color: Colors.white54,
                fontSize: 10 * scale,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (trailWidget != null) ...[
              SizedBox(width: 4 * scale),
              trailWidget,
            ],
          ],
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            if (icon != null) ...[
              Icon(icon, color: color ?? Colors.white, size: 14 * scale),
              SizedBox(width: 2 * scale),
            ],
            Text(
              value,
              style: TextStyle(
                color: color ?? Colors.white,
                fontSize: 20 * scale,
                fontWeight: FontWeight.w900,
                fontFamily: 'monospace',
              ),
            ),
            if (unit.isNotEmpty) ...[
              SizedBox(width: 2 * scale),
              Text(
                unit,
                style: TextStyle(color: Colors.white38, fontSize: 9 * scale),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
