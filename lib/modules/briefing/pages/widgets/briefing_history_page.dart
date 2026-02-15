import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/services/localization_service.dart';
import '../../../../core/theme/app_theme_data.dart';
import '../../../../core/widgets/common/snack_bar.dart';
import '../../localization/briefing_localization_keys.dart';
import '../../providers/briefing_provider.dart';

class BriefingHistoryPage extends StatelessWidget {
  final VoidCallback onBack;

  const BriefingHistoryPage({super.key, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(BriefingLocalizationKeys.historyTitle.tr(context)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: onBack,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: BriefingLocalizationKeys.refresh.tr(context),
            onPressed: () async {
              final provider =
                  context.read<BriefingProvider>();
              try {
                final count = await provider.reloadFromDirectory();
                if (count > 0) {
                  final message = BriefingLocalizationKeys.refreshSuccess
                      .tr(context)
                      .replaceAll('{}', count.toString());
                  SnackBarHelper.showSuccess(context, message);
                } else {
                  SnackBarHelper.showWarning(
                    context,
                    BriefingLocalizationKeys.refreshEmpty.tr(context),
                  );
                }
              } catch (_) {
                SnackBarHelper.showError(
                  context,
                  BriefingLocalizationKeys.refreshFailed.tr(context),
                );
              }
            },
          ),
          const SizedBox(width: AppThemeData.spacingSmall),
        ],
      ),
      body: Consumer<BriefingProvider>(
        builder: (context, provider, child) {
          if (provider.history.isEmpty) {
            return Center(
              child: Text(
                BriefingLocalizationKeys.historyEmpty.tr(context),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.hintColor,
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(AppThemeData.spacingMedium),
            itemCount: provider.history.length,
            itemBuilder: (context, index) {
              final record = provider.history[index];
              return Card(
                margin: const EdgeInsets.only(
                  bottom: AppThemeData.spacingSmall,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppThemeData.spacingMedium),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        record.createdAt.toLocal().toString(),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.hintColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        record.content,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontFamily: 'Monospace',
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
