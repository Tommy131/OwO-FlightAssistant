import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../apps/models/flight_log.dart';
import '../../../apps/models/airport_detail_data.dart';
import '../../../apps/services/airport_detail_service.dart';
import '../../map/widgets/airport_geometry_layers.dart';
import '../../map/models/map_types.dart';

class AnalysisTrackMap extends StatefulWidget {
  final FlightLog log;

  const AnalysisTrackMap({super.key, required this.log});

  @override
  State<AnalysisTrackMap> createState() => _AnalysisTrackMapState();
}

class _AnalysisTrackMapState extends State<AnalysisTrackMap> {
  // 默认使用暗色航空详情图 (Carto Dark)
  bool _showAviationDetails = false;
  List<AirportDetailData> _airportDetails = [];
  double _currentZoom = 10;

  @override
  void initState() {
    super.initState();
    _loadAirportDetails();
  }

  Future<void> _loadAirportDetails() async {
    final service = AirportDetailService();
    final airports = <AirportDetailData>[];

    // 加载起飞机场
    final dep = await service.fetchAirportDetail(widget.log.departureAirport);
    if (dep != null) airports.add(dep);

    // 加载着陆机场
    if (widget.log.arrivalAirport != null &&
        widget.log.arrivalAirport != widget.log.departureAirport) {
      final arr = await service.fetchAirportDetail(widget.log.arrivalAirport!);
      if (arr != null) airports.add(arr);
    }

    if (mounted) {
      setState(() {
        _airportDetails = airports;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.log.points.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final points = widget.log.points
        .map((p) => LatLng(p.latitude, p.longitude))
        .toList();

    // 计算中心点和缩放
    double minLat = points[0].latitude;
    double maxLat = points[0].latitude;
    double minLon = points[0].longitude;
    double maxLon = points[0].longitude;

    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLon) minLon = p.longitude;
      if (p.longitude > maxLon) maxLon = p.longitude;
    }

    final center = LatLng((minLat + maxLat) / 2, (minLon + maxLon) / 2);

    return Container(
      height: 400,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: center,
              initialZoom: 10,
              minZoom: 3,
              maxZoom: 18,
              onPositionChanged: (pos, hasGesture) {
                if (pos.zoom != _currentZoom) {
                  setState(() {
                    _currentZoom = pos.zoom;
                  });
                }
              },
            ),
            children: [
              // 基础底图：根据系统主题切换 (Carto 系列)
              TileLayer(
                urlTemplate: isDark
                    ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
                    : 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c'],
                userAgentPackageName: 'com.owo.flight_assistant',
              ),

              // OSM 航空详情叠加层 (仅在详情模式下显示)
              if (_showAviationDetails)
                Opacity(
                  opacity: isDark ? 0.3 : 0.6, // 深色模式下降低亮度以保持对比度
                  child: TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.owo.flight_assistant',
                  ),
                ),

              // 机场几何细节 (滑行道、跑道细节、停机位)
              if (_showAviationDetails && _airportDetails.isNotEmpty)
                ...buildAirportGeometryLayers(
                  airports: _airportDetails,
                  zoom: _currentZoom,
                  showTaxiways: true,
                  showRunways: true,
                  showParkings: true,
                  layerType: isDark
                      ? MapLayerType.taxiwayDark
                      : MapLayerType.taxiway,
                  scale: 1.0,
                ),

              PolylineLayer(
                polylines: [
                  Polyline(
                    points: points,
                    color: theme.colorScheme.primary,
                    strokeWidth: 4.0,
                  ),
                ],
              ),
              MarkerLayer(
                markers: [
                  // 录制开始点
                  Marker(
                    point: points.first,
                    width: 24,
                    height: 24,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.green, width: 2),
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.green,
                        size: 14,
                      ),
                    ),
                  ),
                  // 录制结束点
                  Marker(
                    point: points.last,
                    width: 24,
                    height: 24,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.red, width: 2),
                      ),
                      child: const Icon(
                        Icons.stop_rounded,
                        color: Colors.red,
                        size: 14,
                      ),
                    ),
                  ),
                  // 实际起飞点
                  if (widget.log.takeoffData != null)
                    Marker(
                      point: LatLng(
                        widget.log.takeoffData!.latitude,
                        widget.log.takeoffData!.longitude,
                      ),
                      width: 32,
                      height: 32,
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.flight_takeoff,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  // 实际接地（降落）点
                  if (widget.log.landingData != null)
                    Marker(
                      point: LatLng(
                        widget.log.landingData!.latitude,
                        widget.log.landingData!.longitude,
                      ),
                      width: 32,
                      height: 32,
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.orange,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.flight_land,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),

          // 图层切换按钮
          Positioned(
            top: 12,
            right: 12,
            child: Material(
              color: (isDark ? Colors.black : Colors.white).withValues(
                alpha: 0.8,
              ),
              borderRadius: BorderRadius.circular(12),
              elevation: 4,
              child: InkWell(
                onTap: () => setState(() {
                  _showAviationDetails = !_showAviationDetails;
                }),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _showAviationDetails
                            ? Icons.layers_rounded
                            : Icons.layers_outlined,
                        color: isDark ? Colors.white : Colors.black87,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _showAviationDetails ? '详情' : '简约',
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 记录时长/数据浮动提示
          Positioned(
            bottom: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: (isDark ? Colors.black : Colors.white).withValues(
                  alpha: 0.8,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'TRACK: ${widget.log.points.length} points',
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black54,
                  fontSize: 10,
                  fontFamily: 'Monospace',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
