import 'package:flutter/material.dart';

import '../../../../../core/services/localization_service.dart';
import '../../../localization/map_localization_keys.dart';
import 'top_panel_chips.dart';

class TaxiwayDrawControls extends StatelessWidget {
  final bool showCustomTaxiwayButton;
  final bool showCustomTaxiway;
  final bool isTaxiwayDrawingActive;
  final VoidCallback onToggleCustomTaxiway;
  final VoidCallback onToggleTaxiwayDrawing;
  final double scale;

  const TaxiwayDrawControls({
    super.key,
    required this.showCustomTaxiwayButton,
    required this.showCustomTaxiway,
    required this.isTaxiwayDrawingActive,
    required this.onToggleCustomTaxiway,
    required this.onToggleTaxiwayDrawing,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (showCustomTaxiwayButton) ...[
          FilterToggleButton(
            label: MapLocalizationKeys.toggleCustomTaxiway.tr(context),
            value: showCustomTaxiway,
            onChanged: (_) => onToggleCustomTaxiway(),
            activeColor: Colors.amberAccent,
            scale: scale,
          ),
          SizedBox(width: 8 * scale),
        ],
        FilterToggleButton(
          label: MapLocalizationKeys.toggleTaxiwayDrawing.tr(context),
          value: isTaxiwayDrawingActive,
          onChanged: (_) => onToggleTaxiwayDrawing(),
          activeColor: Colors.greenAccent,
          leadingIcon: Icons.draw_rounded,
          showActiveCheck: false,
          scale: scale,
        ),
      ],
    );
  }
}
