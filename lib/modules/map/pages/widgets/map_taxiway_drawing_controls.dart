import 'package:flutter/material.dart';

import '../../../../core/services/localization_service.dart';
import '../../localization/map_localization_keys.dart';
import 'map_button.dart';

class MapTaxiwayDrawingControls extends StatelessWidget {
  final double scale;
  final bool canUndo;
  final bool canRedo;
  final bool hasRoute;
  final bool canImport;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onClear;
  final VoidCallback onSave;
  final VoidCallback onImport;

  const MapTaxiwayDrawingControls({
    super.key,
    required this.scale,
    required this.canUndo,
    required this.canRedo,
    required this.hasRoute,
    required this.canImport,
    required this.onUndo,
    required this.onRedo,
    required this.onClear,
    required this.onSave,
    required this.onImport,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Opacity(
          opacity: canUndo ? 1 : 0.45,
          child: MapButton(
            icon: Icons.undo_rounded,
            onPressed: canUndo ? onUndo : () {},
            tooltip: MapLocalizationKeys.tooltipTaxiwayUndo.tr(context),
            scale: scale,
          ),
        ),
        SizedBox(height: 12 * scale),
        Opacity(
          opacity: canRedo ? 1 : 0.45,
          child: MapButton(
            icon: Icons.redo_rounded,
            onPressed: canRedo ? onRedo : () {},
            tooltip: MapLocalizationKeys.tooltipTaxiwayRedo.tr(context),
            scale: scale,
          ),
        ),
        SizedBox(height: 12 * scale),
        Opacity(
          opacity: hasRoute ? 1 : 0.45,
          child: MapButton(
            icon: Icons.delete_sweep_rounded,
            onPressed: hasRoute ? onClear : () {},
            tooltip: MapLocalizationKeys.tooltipTaxiwayClear.tr(context),
            scale: scale,
          ),
        ),
        SizedBox(height: 12 * scale),
        Opacity(
          opacity: hasRoute ? 1 : 0.45,
          child: MapButton(
            icon: Icons.save_alt_rounded,
            onPressed: hasRoute ? onSave : () {},
            tooltip: MapLocalizationKeys.tooltipTaxiwaySave.tr(context),
            scale: scale,
          ),
        ),
        SizedBox(height: 12 * scale),
        Opacity(
          opacity: canImport ? 1 : 0.45,
          child: MapButton(
            icon: Icons.file_upload_rounded,
            onPressed: canImport ? onImport : () {},
            tooltip: MapLocalizationKeys.tooltipTaxiwayImport.tr(context),
            scale: scale,
          ),
        ),
      ],
    );
  }
}
