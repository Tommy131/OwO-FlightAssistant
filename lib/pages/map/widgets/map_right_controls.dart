import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:provider/provider.dart';
import '../../../apps/providers/map_provider.dart';
import '../models/map_types.dart';
import 'map_button.dart';

/// 右侧浮动控制按钮组：图层、刷新、追随、朝向、缩放、指南针
class MapRightControls extends StatelessWidget {
  final double scale;
  final MapController mapController;
  final bool followAircraft;
  final ValueChanged<bool> onFollowAircraftChanged;
  final MapOrientationMode orientationMode;
  final ValueChanged<MapOrientationMode> onOrientationChanged;
  final VoidCallback onShowLayerPicker;
  final bool isMapReady;
  final bool isConnected;

  const MapRightControls({
    super.key,
    required this.scale,
    required this.mapController,
    required this.followAircraft,
    required this.onFollowAircraftChanged,
    required this.orientationMode,
    required this.onOrientationChanged,
    required this.onShowLayerPicker,
    required this.isMapReady,
    required this.isConnected,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          right: 20 * scale,
          top: 250 * scale,
          bottom: 250 * scale,
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  MapButton(
                    icon: Icons.layers_outlined,
                    onPressed: onShowLayerPicker,
                    tooltip: '地图图层',
                    scale: scale,
                  ),
                  const SizedBox(height: 12),
                  Consumer<MapProvider>(
                    builder: (context, provider, _) {
                      // 检查是否有可刷新的机场
                      final hasAirportToRefresh =
                          provider.targetAirport != null ||
                          provider.centerAirport != null ||
                          provider.currentAirport != null;

                      return MapButton(
                        icon: provider.isLoadingAirport
                            ? Icons.sync
                            : Icons.refresh,
                        onPressed: hasAirportToRefresh
                            ? () async {
                                showDialog(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (c) => const Center(
                                    child: Card(
                                      child: Padding(
                                        padding: EdgeInsets.all(20),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            CircularProgressIndicator(),
                                            SizedBox(height: 16),
                                            Text("正在刷新数据..."),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                                await provider.refreshAirport();
                                if (context.mounted) Navigator.pop(context);
                              }
                            : () {
                                // 没有可刷新的机场时显示提示
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('请先搜索或移动地图到机场位置'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              },
                        highlight: provider.isLoadingAirport,
                        tooltip: '刷新机场数据',
                        scale: scale,
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  if (isConnected) ...[
                    MapButton(
                      icon: followAircraft
                          ? Icons.gps_fixed
                          : Icons.gps_not_fixed,
                      onPressed: () {
                        if (!followAircraft) {
                          context.read<MapProvider>().clearTargetAirport();
                        }
                        onFollowAircraftChanged(!followAircraft);
                      },
                      highlight: followAircraft,
                      tooltip: '追随飞机',
                      scale: scale,
                    ),
                    const SizedBox(height: 12),
                    MapButton(
                      icon: orientationMode == MapOrientationMode.northUp
                          ? Icons.explore_outlined
                          : Icons.navigation_outlined,
                      onPressed: () {
                        if (orientationMode == MapOrientationMode.northUp) {
                          onOrientationChanged(MapOrientationMode.trackUp);
                        } else {
                          onOrientationChanged(MapOrientationMode.northUp);
                          mapController.rotate(0);
                        }
                      },
                      highlight: orientationMode == MapOrientationMode.trackUp,
                      tooltip: orientationMode == MapOrientationMode.northUp
                          ? '北向上'
                          : '航向向上',
                      scale: scale,
                    ),
                    const SizedBox(height: 12),
                  ],
                  MapButton(
                    icon: Icons.add,
                    onPressed: () => mapController.move(
                      mapController.camera.center,
                      mapController.camera.zoom + 1,
                    ),
                    tooltip: '放大',
                    scale: scale,
                  ),
                  const SizedBox(height: 12),
                  MapButton(
                    icon: Icons.remove,
                    onPressed: () => mapController.move(
                      mapController.camera.center,
                      mapController.camera.zoom - 1,
                    ),
                    tooltip: '缩小',
                    scale: scale,
                  ),
                ],
              ),
            ),
          ),
        ),
        // 固定指南针
        if (isMapReady)
          Positioned(
            right: 20 * scale,
            bottom: 120 * scale,
            child: GestureDetector(
              onTap: () {
                mapController.rotate(0);
                onOrientationChanged(MapOrientationMode.northUp);
              },
              child: Container(
                width: 48 * scale,
                height: 48 * scale,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24),
                ),
                child: Center(
                  child: Transform.rotate(
                    angle: mapController.camera.rotation * (3.1415926 / 180),
                    child: Icon(
                      Icons.north,
                      color: Colors.orangeAccent,
                      size: 24 * scale,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
