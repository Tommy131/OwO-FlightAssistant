import 'package:flutter/material.dart';

import '../../../../core/services/localization_service.dart';
import '../../localization/map_localization_keys.dart';
import '../../models/map_models.dart';
import '../../providers/map_provider.dart';

void showMapLayerPicker(BuildContext context, MapProvider provider) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) => Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            MapLocalizationKeys.layerTitle.tr(context),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              const spacing = 16.0;
              const columns = 4;
              final itemWidth =
                  (constraints.maxWidth - spacing * (columns - 1)) / columns;
              final optionSize = itemWidth.clamp(52.0, 72.0);
              final iconSize = (optionSize * 0.39).clamp(20.0, 28.0);
              final tileHeight = optionSize + 34;
              return GridView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: spacing,
                  mainAxisSpacing: spacing,
                  childAspectRatio: itemWidth / tileHeight,
                ),
                children: [
                  LayerOption(
                    label: MapLocalizationKeys.layerDark.tr(context),
                    icon: Icons.dark_mode,
                    selected: provider.layerStyle == MapLayerStyle.dark,
                    optionSize: optionSize,
                    iconSize: iconSize,
                    onTap: () {
                      provider.setLayerStyle(MapLayerStyle.dark);
                      Navigator.pop(context);
                    },
                  ),
                  LayerOption(
                    label: MapLocalizationKeys.layerSatellite.tr(context),
                    icon: Icons.satellite_alt,
                    selected: provider.layerStyle == MapLayerStyle.satellite,
                    optionSize: optionSize,
                    iconSize: iconSize,
                    onTap: () {
                      provider.setLayerStyle(MapLayerStyle.satellite);
                      Navigator.pop(context);
                    },
                  ),
                  LayerOption(
                    label: MapLocalizationKeys.layerTerrain.tr(context),
                    icon: Icons.landscape,
                    selected: provider.layerStyle == MapLayerStyle.terrain,
                    optionSize: optionSize,
                    iconSize: iconSize,
                    onTap: () {
                      provider.setLayerStyle(MapLayerStyle.terrain);
                      Navigator.pop(context);
                    },
                  ),
                  LayerOption(
                    label: MapLocalizationKeys.layerTaxiway.tr(context),
                    icon: Icons.flight,
                    selected: provider.layerStyle == MapLayerStyle.taxiway,
                    optionSize: optionSize,
                    iconSize: iconSize,
                    onTap: () {
                      provider.setLayerStyle(MapLayerStyle.taxiway);
                      Navigator.pop(context);
                    },
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    ),
  );
}

class LayerOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final double optionSize;
  final double iconSize;

  const LayerOption({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.optionSize = 72,
    this.iconSize = 28,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: optionSize,
            height: optionSize,
            decoration: BoxDecoration(
              color: selected
                  ? Colors.orangeAccent
                  : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(optionSize * 0.28),
              border: Border.all(
                color: selected ? Colors.white : Colors.white12,
                width: 2,
              ),
            ),
            child: Icon(
              icon,
              color: selected ? Colors.black : Colors.white,
              size: iconSize,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: selected ? Colors.orangeAccent : Colors.white70,
              fontSize: 13,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
