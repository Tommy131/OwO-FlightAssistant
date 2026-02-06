import 'package:flutter/material.dart';
import '../../../core/theme/app_theme_data.dart';

/// 通用设置卡片容器
class SettingsCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final String? subtitle;

  const SettingsCard({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: AppThemeData.spacingMedium),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppThemeData.borderRadiusMedium),
        border: Border.all(
          color: AppThemeData.getBorderColor(theme).withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppThemeData.spacingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(theme, icon, title, subtitle),
            if (subtitle != null || title.isNotEmpty)
              const SizedBox(height: AppThemeData.spacingMedium),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    ThemeData theme,
    IconData icon,
    String title,
    String? subtitle,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.primary.withValues(alpha: 0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(
                  AppThemeData.borderRadiusSmall,
                ),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: AppThemeData.spacingMedium),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// 输入框配置项
class SettingsInputField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final IconData? icon;
  final bool obscureText;
  final VoidCallback? onSave;
  final String? helperText;

  const SettingsInputField({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    this.icon,
    this.obscureText = false,
    this.onSave,
    this.helperText,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) ...[
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 8),
        ],
        TextField(
          controller: controller,
          obscureText: obscureText,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: icon != null ? Icon(icon, size: 20) : null,
            suffixIcon: onSave != null
                ? IconButton(
                    icon: const Icon(Icons.save_rounded),
                    onPressed: onSave,
                    tooltip: '保存',
                  )
                : null,
            filled: true,
            fillColor: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.1,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                AppThemeData.borderRadiusSmall,
              ),
              borderSide: BorderSide(
                color: AppThemeData.getBorderColor(
                  theme,
                ).withValues(alpha: 0.5),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                AppThemeData.borderRadiusSmall,
              ),
              borderSide: BorderSide(
                color: theme.colorScheme.primary,
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            helperText: helperText,
            helperStyle: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline.withValues(alpha: 0.7),
            ),
          ),
        ),
      ],
    );
  }
}
