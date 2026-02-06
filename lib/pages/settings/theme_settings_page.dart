import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flex_color_picker/flex_color_picker.dart';

import '../../core/theme/app_theme_data.dart';
import '../../core/theme/theme_provider.dart';

/// 统一的主题设置页面
class ThemeSettingsPage extends StatelessWidget {
  final VoidCallback? onBack;

  const ThemeSettingsPage({super.key, this.onBack});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('个性化'),
        centerTitle: false,
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        leading: onBack != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: onBack,
              )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: '重置为默认',
            onPressed: () {
              context.read<ThemeProvider>().resetToDefault();
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('已重置为默认主题')));
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppThemeData.spacingMedium),
        children: [
          // 当前主题信息
          const _CurrentThemeCard(),
          const SizedBox(height: AppThemeData.spacingLarge),

          // 预设主题
          const _PresetThemesSection(),
          const SizedBox(height: AppThemeData.spacingLarge),

          // 自定义主题
          const _CustomThemeSection(),
          const SizedBox(height: AppThemeData.spacingLarge),
        ],
      ),
    );
  }
}

// ==================== 公共组件 ====================

/// 主题颜色圆圈组件
class _ThemeColorCircle extends StatelessWidget {
  final Color color;
  final double size;
  final bool showCheck;
  final bool showShadow;

  const _ThemeColorCircle({
    required this.color,
    this.size = 48,
    this.showCheck = false,
    this.showShadow = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: showShadow
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.3),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: showCheck
          ? Icon(
              Icons.check_rounded,
              color: AppThemeData.getContrastColor(color),
              size: size * 0.5,
            )
          : null,
    );
  }
}

// ==================== 页面区块 ====================

/// 当前主题信息卡片
class _CurrentThemeCard extends StatelessWidget {
  const _CurrentThemeCard();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ThemeProvider>();
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppThemeData.spacingMedium),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '当前外观',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppThemeData.spacingMedium),
          Row(
            children: [
              _ThemeColorCircle(
                color: provider.currentTheme.primaryColor,
                size: 60,
                showShadow: true,
              ),
              const SizedBox(width: AppThemeData.spacingMedium),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      provider.currentTheme.name,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      provider.getThemeModeName(provider.themeMode),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                provider.getThemeModeIcon(provider.themeMode),
                size: 28,
                color: theme.colorScheme.primary,
              ),
            ],
          ),
          const SizedBox(height: AppThemeData.spacingLarge),
          _QuickActionButtons(),
        ],
      ),
    );
  }
}

/// 快速操作按钮
class _QuickActionButtons extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ThemeProvider>();

    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => provider.toggleThemeMode(),
            icon: Icon(provider.getThemeModeIcon(provider.themeMode), size: 18),
            label: const Text('循环切换模式'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  AppThemeData.borderRadiusSmall,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: AppThemeData.spacingSmall),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => provider.toggleDarkMode(),
            icon: Icon(
              provider.isDarkMode
                  ? Icons.light_mode_rounded
                  : Icons.dark_mode_rounded,
              size: 18,
            ),
            label: Text(provider.isDarkMode ? '浅色' : '深色'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  AppThemeData.borderRadiusSmall,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 预设主题区域
class _PresetThemesSection extends StatelessWidget {
  const _PresetThemesSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppThemeData.spacingMedium),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppThemeData.borderRadiusMedium),
        border: Border.all(
          color: AppThemeData.getBorderColor(theme).withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '色彩方案',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '选择预设的主题配色',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: AppThemeData.spacingMedium),
          const _PresetThemeGrid(),
        ],
      ),
    );
  }
}

/// 预设主题网格
class _PresetThemeGrid extends StatelessWidget {
  const _PresetThemeGrid();

  @override
  Widget build(BuildContext context) {
    final currentTheme = context.watch<ThemeProvider>().currentTheme;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        crossAxisSpacing: AppThemeData.spacingSmall,
        mainAxisSpacing: AppThemeData.spacingSmall,
        childAspectRatio: 0.85,
      ),
      itemCount: AppThemeData.presetThemes.length,
      itemBuilder: (context, index) {
        final theme = AppThemeData.presetThemes[index];
        final isSelected = currentTheme == theme;

        return _ThemeCard(
          theme: theme,
          isSelected: isSelected,
          onTap: () {
            context.read<ThemeProvider>().setTheme(theme);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('已应用 ${theme.name}'),
                duration: const Duration(seconds: 1),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
        );
      },
    );
  }
}

/// 主题卡片
class _ThemeCard extends StatelessWidget {
  final AppThemeData theme;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeCard({
    required this.theme,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final parentTheme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppThemeData.borderRadiusMedium),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppThemeData.borderRadiusMedium),
          border: Border.all(
            color: isSelected
                ? theme.primaryColor
                : AppThemeData.getBorderColor(
                    parentTheme,
                  ).withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
          color: isSelected ? theme.primaryColor.withValues(alpha: 0.05) : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _ThemeColorCircle(
              color: theme.primaryColor,
              size: 40,
              showCheck: isSelected,
              showShadow: isSelected,
            ),
            const SizedBox(height: 8),
            Text(
              theme.name,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? theme.primaryColor
                    : parentTheme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// 自定义主题区域
class _CustomThemeSection extends StatelessWidget {
  const _CustomThemeSection();

  @override
  Widget build(BuildContext context) {
    final currentTheme = context.watch<ThemeProvider>().currentTheme;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppThemeData.spacingMedium),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppThemeData.borderRadiusMedium),
        border: Border.all(
          color: AppThemeData.getBorderColor(theme).withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '自定义配色',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '创造属于你的独特视野',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
              if (currentTheme.isCustom)
                const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.orange,
                  size: 20,
                ),
            ],
          ),
          const SizedBox(height: AppThemeData.spacingMedium),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showColorPicker(context),
              icon: const Icon(Icons.colorize_rounded, size: 18),
              label: const Text('打开取色器'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    AppThemeData.borderRadiusSmall,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showColorPicker(BuildContext context) {
    Color selectedColor = context
        .read<ThemeProvider>()
        .currentTheme
        .primaryColor;
    final nameController = TextEditingController(text: '我的主题');

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('自定义主题色'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppThemeData.borderRadiusMedium),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: '主题名称',
                  hintText: '例如：烈焰红',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      AppThemeData.borderRadiusSmall,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppThemeData.spacingMedium),
              ColorPicker(
                color: selectedColor,
                onColorChanged: (color) => selectedColor = color,
                width: 40,
                height: 40,
                borderRadius: 20,
                spacing: 8,
                runSpacing: 8,
                heading: const Text('选择基准色'),
                subheading: const Text('微调色调'),
                pickersEnabled: const {
                  ColorPickerType.both: false,
                  ColorPickerType.primary: true,
                  ColorPickerType.accent: false,
                  ColorPickerType.wheel: true,
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<ThemeProvider>().createCustomTheme(
                selectedColor,
                nameController.text.isEmpty ? '自定义主题' : nameController.text,
              );
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('自定义主题已成功应用')));
            },
            child: const Text('应用'),
          ),
        ],
      ),
    );
  }
}
