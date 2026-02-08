import 'package:flutter/material.dart';
import '../../../apps/models/flight_checklist.dart';
import '../../../core/theme/app_theme_data.dart';

class ChecklistItemTile extends StatelessWidget {
  final ChecklistItem item;
  final VoidCallback onTap;

  const ChecklistItemTile({super.key, required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppThemeData.borderRadiusSmall),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: item.isChecked
              ? theme.colorScheme.primary.withValues(alpha: 0.05)
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppThemeData.borderRadiusSmall),
          border: Border.all(
            color: item.isChecked
                ? theme.colorScheme.primary.withValues(alpha: 0.3)
                : AppThemeData.getBorderColor(theme),
          ),
        ),
        child: Row(
          children: [
            AnimatedScale(
              scale: item.isChecked ? 1.1 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                item.isChecked
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                color: item.isChecked
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                item.task,
                style: theme.textTheme.bodyLarge?.copyWith(
                  decoration: item.isChecked
                      ? TextDecoration.lineThrough
                      : null,
                  color: isDark
                      ? (item.isChecked ? Colors.white54 : Colors.white)
                      : (item.isChecked ? Colors.black54 : Colors.black87),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                item.response,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
