import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme_data.dart';
import 'airac_info_tag.dart';

class DataPathItem extends StatelessWidget {
  final String label;
  final String? path;
  final String? airac;
  final String? expiry;
  final bool isExpired;
  final VoidCallback onSelect;

  const DataPathItem({
    super.key,
    required this.label,
    this.path,
    this.airac,
    this.expiry,
    this.isExpired = false,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isSet = path != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (isSet)
              AiracInfoTag(airac: airac, expiry: expiry, isExpired: isExpired),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isSet
                      ? Colors.green.withValues(alpha: 0.05)
                      : theme.colorScheme.surfaceContainerHighest.withValues(
                          alpha: 0.1,
                        ),
                  borderRadius: BorderRadius.circular(
                    AppThemeData.borderRadiusSmall,
                  ),
                  border: Border.all(
                    color: isSet
                        ? Colors.green.withValues(alpha: 0.3)
                        : AppThemeData.getBorderColor(
                            theme,
                          ).withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  path ?? '未设置',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isSet
                        ? Colors.green[700]
                        : theme.colorScheme.outline,
                    fontFamily: isSet ? 'monospace' : null,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              onPressed: onSelect,
              icon: const Icon(Icons.folder_open_rounded, size: 20),
              tooltip: '选择路径',
              style: IconButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    AppThemeData.borderRadiusSmall,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
