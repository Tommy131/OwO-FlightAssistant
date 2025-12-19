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
      body: ListView(
        padding: const EdgeInsets.all(AppThemeData.spacingMedium),
        children: [
          Flex(
            direction: Axis.horizontal,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: onBack,
                  ),
                  Text('主题设置', style: theme.textTheme.headlineMedium),
                ],
              ),
              Row(
                children: [
                  _QuickThemeMenu(),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: '重置为默认',
                    onPressed: () {
                      context.read<ThemeProvider>().resetToDefault();
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(const SnackBar(content: Text('已重置为默认主题')));
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppThemeData.spacingSmall),

          // 当前主题信息
          const _CurrentThemeCard(),
          const SizedBox(height: AppThemeData.spacingLarge),

          // 预设主题
          const _PresetThemesSection(),
          const SizedBox(height: AppThemeData.spacingLarge),

          // 自定义主题
          const _CustomThemeSection(),
          const SizedBox(height: AppThemeData.spacingLarge),

          // 设计常量示例（可选）
          const _DesignConstantsSection(),
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
      tooltip: '快速切换主题',
      onSelected: (theme) {
        context.read<ThemeProvider>().setTheme(theme);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已切换到 ${theme.name}'),
            duration: const Duration(seconds: 1),
          ),
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
            Text('当前主题', style: theme.textTheme.headlineMedium),
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
                        provider.currentTheme.name,
                        style: theme.textTheme.displaySmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        provider.getThemeModeName(provider.themeMode),
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
          label: const Text('切换模式'),
        ),
        OutlinedButton.icon(
          onPressed: () => provider.toggleDarkMode(),
          icon: const Icon(Icons.brightness_6),
          label: Text(provider.isDarkMode ? '切换到浅色' : '切换到深色'),
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
            Text('主题配色', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: AppThemeData.spacingSmall),
            Text('选择你喜欢的颜色主题', style: Theme.of(context).textTheme.bodyMedium),
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
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('已切换到 ${theme.name}'),
                duration: const Duration(seconds: 1),
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
            Text('自定义主题', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: AppThemeData.spacingSmall),
            Text('创建你的专属配色方案', style: Theme.of(context).textTheme.bodyMedium),
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
                              '当前自定义主题',
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
                label: const Text('创建自定义主题'),
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
    final nameController = TextEditingController(text: '自定义主题');

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('自定义主题色'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: '主题名称',
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
                heading: const Text('选择主题色'),
                subheading: const Text('选择色调'),
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
              ).showSnackBar(const SnackBar(content: Text('自定义主题已应用')));
            },
            child: const Text('应用'),
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
            Text('设计常量', style: Theme.of(context).textTheme.headlineMedium),
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
