import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/services/localization_service.dart';
import '../../../../core/theme/app_theme_data.dart';
import '../../localization/briefing_localization_keys.dart';
import '../../providers/briefing_provider.dart';

class BriefingDisplayCard extends StatelessWidget {
  const BriefingDisplayCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Consumer<BriefingProvider>(
      builder: (context, provider, child) {
        return Container(
          padding: const EdgeInsets.all(AppThemeData.spacingMedium),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                BriefingLocalizationKeys.outputTitle.tr(context),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              if (provider.isLoading)
                const Center(child: CircularProgressIndicator())
              else if (provider.latest == null)
                Text(
                  BriefingLocalizationKeys.outputEmpty.tr(context),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.hintColor,
                  ),
                )
              else
                Text(
                  provider.latest!.content,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontFamily: 'Monospace',
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
