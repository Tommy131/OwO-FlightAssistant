import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../../../../core/services/localization_service.dart';
import '../../localization/map_localization_keys.dart';
import 'map_button.dart';

class MapRightControls extends StatelessWidget {
  final double scale;
  final MapController mapController;
  final bool followAircraft;
  final ValueChanged<bool> onFollowAircraftChanged;
  final VoidCallback onShowLayerPicker;
  final bool isMapReady;
  final bool isConnected;

  const MapRightControls({
    super.key,
    required this.scale,
    required this.mapController,
    required this.followAircraft,
    required this.onFollowAircraftChanged,
    required this.onShowLayerPicker,
    required this.isMapReady,
    required this.isConnected,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                MapButton(
                  icon: Icons.layers_outlined,
                  onPressed: onShowLayerPicker,
                  tooltip: MapLocalizationKeys.tooltipLayer.tr(context),
                  scale: scale,
                ),
                const SizedBox(height: 12),
                if (isConnected) ...[
                  MapButton(
                    icon: followAircraft
                        ? Icons.gps_fixed
                        : Icons.gps_not_fixed,
                    onPressed: () => onFollowAircraftChanged(!followAircraft),
                    tooltip: MapLocalizationKeys.tooltipFollow.tr(context),
                    highlight: followAircraft,
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
                  tooltip: MapLocalizationKeys.tooltipZoomIn.tr(context),
                  scale: scale,
                ),
                const SizedBox(height: 12),
                MapButton(
                  icon: Icons.remove,
                  onPressed: () => mapController.move(
                    mapController.camera.center,
                    mapController.camera.zoom - 1,
                  ),
                  tooltip: MapLocalizationKeys.tooltipZoomOut.tr(context),
                  scale: scale,
                ),
              ],
            ),
          ),
        ),
        if (isMapReady)
          Positioned(right: 0, bottom: 0, child: const SizedBox.shrink()),
      ],
    );
  }
}
