import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flex_color_picker/flex_color_picker.dart';

import '../theme/app_theme_data.dart';
import '../theme/theme_provider.dart';
import '../widgets/common/snack_bar.dart';
import '../localization/localization_keys.dart';
import '../services/localization_service.dart';

/// 统一的主题设置页面
class ThemeSettingsPage extends StatelessWidget {
  final VoidCallback? onBack;

  const ThemeSettingsPage({super.key, this.onBack});

  @override
  Widget build(BuildContext context) {
    context.watch<LocalizationService>();
    final theme = Theme.of(context);
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(AppThemeData.spacingMedium),
        children: [
          Flex(
            direction: Axis.horizontal,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  if (onBack != null)
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      tooltip: LocalizationKeys.back.tr(context),
                      onPressed: onBack,
                    ),
                  const SizedBox(width: AppThemeData.spacingSmall),
                  Text(
                    LocalizationKeys.themeSettings.tr(context),
                    style: theme.textTheme.headlineMedium,
                  ),
                ],
              ),
              Row(
                children: [
                  _QuickThemeMenu(),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: LocalizationKeys.resetToDefault.tr(context),
                    onPressed: () {
                      context.read<ThemeProvider>().resetToDefault();
                      SnackBarHelper.showSuccess(
                        context,
                        LocalizationKeys.resetToDefaultSuccess.tr(context),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppThemeData.spacingSmall),

          // 当前主题信息
          const _CurrentThemeCard(),
          const SizedBox(height: AppThemeData.spacingSmall),

          // 预设主题
          const _PresetThemesSection(),
          const SizedBox(height: AppThemeData.spacingSmall),

          // 自定义主题
          const _CustomThemeSection(),
          const SizedBox(height: AppThemeData.spacingSmall),

          // 对比度调整
          const _ContrastAdjustmentSection(),
          const SizedBox(height: AppThemeData.spacingSmall),

          // 设计常量示例
          const _DesignConstantsSection(),
          const SizedBox(height: AppThemeData.spacingSmall),
        ],
      ),
    );
  }
}

/// 对比度调整（亮度/昏暗度）
class _ContrastAdjustmentSection extends StatelessWidget {
  const _ContrastAdjustmentSection();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ThemeProvider>();
    final theme = Theme.of(context);
    final isDark =
        provider.isDarkMode ||
        (provider.isSystemMode &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppThemeData.spacingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  LocalizationKeys.contrastAdjustment.tr(context),
                  style: theme.textTheme.headlineMedium,
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isDark
                        ? LocalizationKeys.darkModeEnhanced.tr(context)
                        : LocalizationKeys.lightModePurified.tr(context),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppThemeData.spacingSmall),
            Text(
              isDark
                  ? LocalizationKeys.darkContrastDesc.tr(context)
                  : LocalizationKeys.lightContrastDesc.tr(context),
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppThemeData.spacingMedium),
            Row(
              children: [
                Icon(
                  isDark ? Icons.brightness_medium : Icons.wb_sunny_outlined,
                  size: 20,
                ),
                Expanded(
                  child: Slider(
                    value: isDark
                        ? provider.darkContrastAdjustment
                        : provider.lightContrastAdjustment,
                    min: 0.0,
                    max: 1.0,
                    divisions: 10,
                    label:
                        '${((isDark ? provider.darkContrastAdjustment : provider.lightContrastAdjustment) * 100).toInt()}%',
                    onChanged: (value) {
                      if (isDark) {
                        provider.setDarkContrastAdjustment(value);
                      } else {
                        provider.setLightContrastAdjustment(value);
                      }
                    },
                  ),
                ),
                Icon(isDark ? Icons.brightness_low : Icons.wb_sunny, size: 20),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    LocalizationKeys.defaultLabel.tr(context),
                    style: theme.textTheme.bodySmall,
                  ),
                  Text(
                    isDark
                        ? LocalizationKeys.extremeDark.tr(context)
                        : LocalizationKeys.pureLight.tr(context),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
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
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: showCheck
          ? Icon(
              Icons.check,
              color: AppThemeData.getContrastColor(color),
              size: size * 0.5,
            )
          : null,
    );
  }
}

/// 快速主题切换菜单
class _QuickThemeMenu extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final currentTheme = context.watch<ThemeProvider>().currentTheme;

    return PopupMenuButton<AppThemeData>(
      icon: const Icon(Icons.palette_outlined),
      tooltip: LocalizationKeys.switchThemeMode.tr(context),
      onSelected: (theme) {
        context.read<ThemeProvider>().setTheme(theme);
        SnackBarHelper.showSuccess(
          context,
          LocalizationKeys.themeChangedTo
              .tr(context)
              .replaceFirst('{}', theme.name),
        );
      },
      itemBuilder: (context) {
        return AppThemeData.presetThemes.map((theme) {
          final isSelected = currentTheme == theme;
          return PopupMenuItem(
            value: theme,
            child: Row(
              children: [
                _ThemeColorCircle(
                  color: theme.primaryColor,
                  size: 24,
                  showCheck: isSelected,
                ),
                const SizedBox(width: 12),
                Text(
                  theme.name,
                  style: TextStyle(
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
          );
        }).toList();
      },
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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppThemeData.spacingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              LocalizationKeys.currentTheme.tr(context),
              style: theme.textTheme.headlineMedium,
            ),
            const SizedBox(height: AppThemeData.spacingMedium),
            Row(
              children: [
                _ThemeColorCircle(
                  color: provider.currentTheme.primaryColor,
                  size: 56,
                  showShadow: true,
                ),
                const SizedBox(width: AppThemeData.spacingMedium),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        provider.currentTheme.getLocalizedName(context),
                        style: theme.textTheme.displaySmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        provider.getThemeModeName(context, provider.themeMode),
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                Icon(
                  provider.getThemeModeIcon(provider.themeMode),
                  size: 32,
                  color: theme.primaryColor,
                ),
              ],
            ),
            const SizedBox(height: AppThemeData.spacingMedium),
            _QuickActionButtons(),
          ],
        ),
      ),
    );
  }
}

/// 快速操作按钮
class _QuickActionButtons extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ThemeProvider>();

    return Wrap(
      spacing: AppThemeData.spacingSmall,
      runSpacing: AppThemeData.spacingSmall,
      children: [
        ElevatedButton.icon(
          onPressed: () => provider.toggleThemeMode(),
          icon: Icon(provider.getThemeModeIcon(provider.themeMode)),
          label: Text(LocalizationKeys.switchThemeMode.tr(context)),
        ),
        OutlinedButton.icon(
          onPressed: () => provider.toggleDarkMode(),
          icon: const Icon(Icons.brightness_6),
          label: Text(
            provider.isDarkMode
                ? LocalizationKeys.switchToLightMode.tr(context)
                : LocalizationKeys.switchToDarkMode.tr(context),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppThemeData.spacingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              LocalizationKeys.themeColors.tr(context),
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: AppThemeData.spacingSmall),
            Text(
              LocalizationKeys.themeColorsDesc.tr(context),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppThemeData.spacingMedium),
            _PresetThemeGrid(),
          ],
        ),
      ),
    );
  }
}

/// 预设主题网格
class _PresetThemeGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final currentTheme = context.watch<ThemeProvider>().currentTheme;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 6,
        crossAxisSpacing: AppThemeData.spacingSmall,
        mainAxisSpacing: AppThemeData.spacingSmall,
        childAspectRatio: 1.1,
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
            SnackBarHelper.showSuccess(
              context,
              LocalizationKeys.themeChangedTo
                  .tr(context)
                  .replaceFirst('{}', theme.name),
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
    return Card(
      elevation: isSelected ? 2 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppThemeData.borderRadiusMedium),
        side: BorderSide(
          color: isSelected
              ? theme.primaryColor
              : AppThemeData.getBorderColor(Theme.of(context)),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppThemeData.borderRadiusMedium),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _ThemeColorCircle(
              color: theme.primaryColor,
              size: 48,
              showCheck: isSelected,
              showShadow: isSelected,
            ),
            const SizedBox(height: AppThemeData.spacingSmall),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                theme.name,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppThemeData.spacingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              LocalizationKeys.customTheme.tr(context),
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: AppThemeData.spacingSmall),
            Text(
              LocalizationKeys.customThemeDesc.tr(context),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppThemeData.spacingMedium),
            if (currentTheme.isCustom) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppThemeData.spacingMedium),
                  child: Row(
                    children: [
                      _ThemeColorCircle(
                        color: currentTheme.primaryColor,
                        size: 48,
                        showCheck: true,
                      ),
                      const SizedBox(width: AppThemeData.spacingMedium),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentTheme.name,
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              LocalizationKeys.currentCustomTheme.tr(context),
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppThemeData.spacingSmall),
            ],
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showColorPicker(context),
                icon: const Icon(Icons.palette),
                label: Text(LocalizationKeys.createCustomTheme.tr(context)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showColorPicker(BuildContext context) {
    Color selectedColor = context
        .read<ThemeProvider>()
        .currentTheme
        .primaryColor;
    final nameController = TextEditingController(
      text: LocalizationKeys.customTheme.tr(context),
    );

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(LocalizationKeys.customThemeColor.tr(context)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: LocalizationKeys.themeName.tr(context),
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
                wheelDiameter: 200,
                heading: Text(LocalizationKeys.selectThemeColor.tr(context)),
                subheading: Text(LocalizationKeys.selectColorShade.tr(context)),
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
            child: Text(LocalizationKeys.cancel.tr(context)),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<ThemeProvider>().createCustomTheme(
                selectedColor,
                nameController.text.isEmpty
                    ? LocalizationKeys.customTheme.tr(context)
                    : nameController.text,
              );
              Navigator.pop(dialogContext);
              SnackBarHelper.showSuccess(
                context,
                LocalizationKeys.customThemeApplied.tr(context),
              );
            },
            child: Text(LocalizationKeys.confirm.tr(context)),
          ),
        ],
      ),
    );
  }
}

/// 设计常量示例区域（可选功能）
class _DesignConstantsSection extends StatelessWidget {
  const _DesignConstantsSection();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppThemeData.spacingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              LocalizationKeys.designConstants.tr(context),
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: AppThemeData.spacingMedium),
            const _ConstantItem('间距 - Small', '${AppThemeData.spacingSmall}px'),
            const _ConstantItem(
              '间距 - Medium',
              '${AppThemeData.spacingMedium}px',
            ),
            const _ConstantItem('间距 - Large', '${AppThemeData.spacingLarge}px'),
            const Divider(height: AppThemeData.spacingLarge),
            const _ConstantItem(
              '圆角 - Small',
              '${AppThemeData.borderRadiusSmall}px',
            ),
            const _ConstantItem(
              '圆角 - Medium',
              '${AppThemeData.borderRadiusMedium}px',
            ),
            const _ConstantItem(
              '圆角 - Large',
              '${AppThemeData.borderRadiusLarge}px',
            ),
          ],
        ),
      ),
    );
  }
}

class _ConstantItem extends StatelessWidget {
  final String label;
  final String value;

  const _ConstantItem(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}
