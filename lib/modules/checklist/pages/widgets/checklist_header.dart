import 'package:flutter/material.dart';
import '../../../../core/services/localization_service.dart';
import '../../../../core/theme/app_theme_data.dart';
import '../../models/flight_checklist.dart';
import '../../providers/checklist_provider.dart';
import '../../localization/checklist_localization_keys.dart';

class ChecklistHeader extends StatelessWidget {
  final ChecklistProvider provider;

  const ChecklistHeader({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final aircraft = provider.selectedAircraft!;

    return Container(
      padding: const EdgeInsets.all(AppThemeData.spacingLarge),
      child: Row(
        children: [
          Icon(
            aircraft.family == AircraftFamily.a320
                ? Icons.airplanemode_active
                : Icons.flight,
            color: theme.colorScheme.primary,
            size: 32,
          ),
          const SizedBox(width: AppThemeData.spacingMedium),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: aircraft.id,
                    isExpanded: true,
                    icon: const Icon(Icons.arrow_drop_down),
                    items: provider.aircraftList
                        .map(
                          (item) => DropdownMenuItem<String>(
                            value: item.id,
                            child: Text(item.name, overflow: TextOverflow.fade),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      provider.selectAircraft(value);
                    },
                    hint: Text(
                      ChecklistLocalizationKeys.selectAircraft.tr(context),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${ChecklistLocalizationKeys.currentPhase.tr(context)}: ${provider.currentPhase.labelKey.tr(context)}',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
