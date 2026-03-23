import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme_data.dart';
import '../../../core/services/localization_service.dart';
import '../providers/checklist_provider.dart';
import '../localization/checklist_localization_keys.dart';
import 'widgets/checklist_footer.dart';
import 'widgets/checklist_header.dart';
import 'widgets/checklist_items_list.dart';
import 'widgets/checklist_sidebar.dart';

class ChecklistPage extends StatelessWidget {
  const ChecklistPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Consumer2<ChecklistProvider, LocalizationService>(
      builder: (context, provider, localizationService, _) {
        final selectedAircraft = provider.selectedAircraft;

        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (selectedAircraft == null) {
          return Center(
            child: Text(ChecklistLocalizationKeys.emptyState.tr(context)),
          );
        }

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Row(
            children: [
              ChecklistSidebar(provider: provider),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.all(AppThemeData.spacingLarge),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(
                      AppThemeData.borderRadiusLarge,
                    ),
                    border: Border.all(
                      color: AppThemeData.getBorderColor(theme),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      ChecklistHeader(provider: provider),
                      const Divider(height: 1),
                      Expanded(child: ChecklistItemsList(provider: provider)),
                      ChecklistFooter(provider: provider),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
