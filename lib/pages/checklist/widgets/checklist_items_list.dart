import 'package:flutter/material.dart';
import '../../checklist/widgets/checklist_item_tile.dart';
import '../../../apps/models/flight_checklist.dart';
import '../../../apps/providers/checklist_provider.dart';
import '../../../core/theme/app_theme_data.dart';

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
            Text('该机型尚无此阶段数据', style: theme.textTheme.bodyLarge),
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
