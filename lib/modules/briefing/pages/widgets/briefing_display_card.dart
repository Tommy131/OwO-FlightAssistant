import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

    return Consumer<BriefingProvider>(
      builder: (context, provider, child) {
        final latest = provider.latest;
        final content = latest?.content ?? '';
        return Container(
          padding: const EdgeInsets.all(AppThemeData.spacingMedium),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: theme.dividerColor.withValues(alpha: 0.2),
            ),
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(
                  context,
                  title: BriefingLocalizationKeys.outputTitle.tr(context),
                  routeText: latest?.title ?? '--',
                  contentToCopy: content,
                ),
                const SizedBox(height: AppThemeData.spacingMedium),
                if (provider.isLoading)
                  const Center(child: CircularProgressIndicator())
                else if (latest == null)
                  _buildInfoSection(
                    context,
                    title: BriefingLocalizationKeys.outputTitle.tr(context),
                    icon: Icons.description_outlined,
                    color: Colors.blue,
                    child: Text(
                      BriefingLocalizationKeys.outputEmpty.tr(context),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.hintColor,
                      ),
                    ),
                  )
                else
                  _buildInfoSection(
                    context,
                    title: BriefingLocalizationKeys.outputTitle.tr(context),
                    icon: Icons.description_outlined,
                    color: Colors.blue,
                    child: _buildContentRows(context, content),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(
    BuildContext context, {
    required String title,
    required String routeText,
    required String contentToCopy,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppThemeData.spacingMedium),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primary.withValues(alpha: 0.72),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppThemeData.borderRadiusMedium),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.26),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.description, color: Colors.white, size: 24),
          ),
          const SizedBox(width: AppThemeData.spacingMedium),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  routeText,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: contentToCopy.trim().isEmpty
                ? null
                : () async {
                    await Clipboard.setData(ClipboardData(text: contentToCopy));
                    if (!context.mounted) return;
                    final messenger = ScaffoldMessenger.of(context);
                    messenger.hideCurrentSnackBar();
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          BriefingLocalizationKeys.copySuccess.tr(context),
                        ),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
            icon: const Icon(Icons.copy_rounded, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppThemeData.borderRadiusMedium),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1.8),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppThemeData.spacingMedium),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppThemeData.borderRadiusMedium - 2),
                topRight: Radius.circular(AppThemeData.borderRadiusMedium - 2),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 18, color: Colors.white),
                ),
                const SizedBox(width: AppThemeData.spacingSmall),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppThemeData.spacingMedium),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildContentRows(BuildContext context, String content) {
    final theme = Theme.of(context);
    final lines = content
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (lines.isEmpty) {
      return Text(
        BriefingLocalizationKeys.outputEmpty.tr(context),
        style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
      );
    }
    return Column(
      children: lines.map((line) => _buildContentRow(context, line)).toList(),
    );
  }

  Widget _buildContentRow(BuildContext context, String line) {
    final theme = Theme.of(context);
    final separator = line.indexOf(':');
    if (separator <= 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          line,
          style: theme.textTheme.bodyMedium?.copyWith(fontFamily: 'Monospace'),
        ),
      );
    }
    final label = line.substring(0, separator).trim();
    final value = line.substring(separator + 1).trim();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 98,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.hintColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFamily: 'Monospace',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
