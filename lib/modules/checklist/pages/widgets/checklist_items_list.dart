import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme_data.dart';
import '../../../../core/services/localization_service.dart';
import '../../models/flight_checklist.dart';
import '../../providers/checklist_provider.dart';
import '../../localization/checklist_localization_keys.dart';
import 'checklist_item_tile.dart';

class ChecklistItemsList extends StatelessWidget {
  final ChecklistProvider provider;

  const ChecklistItemsList({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final aircraft = provider.selectedAircraft!;
    ChecklistSection? currentSection;
    try {
      currentSection = aircraft.sections.firstWhere(
        (s) => s.phase == provider.currentPhase,
      );
    } catch (e) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.checklist_rtl,
              size: 64,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
            ),
            const SizedBox(height: AppThemeData.spacingMedium),
            Text(
              ChecklistLocalizationKeys.emptyPhase.tr(context),
              style: theme.textTheme.bodyLarge,
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppThemeData.spacingLarge),
      itemCount: currentSection.items.length,
      separatorBuilder: (context, index) =>
          const SizedBox(height: AppThemeData.spacingSmall),
      itemBuilder: (context, index) {
        final item = currentSection!.items[index];
        return ChecklistItemTile(
          item: item,
          onTap: () => provider.toggleItem(item.id),
        );
      },
    );
  }
}
