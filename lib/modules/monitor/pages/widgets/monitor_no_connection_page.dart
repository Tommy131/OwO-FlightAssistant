import 'package:flutter/material.dart';
import '../../../../core/services/localization_service.dart';
import '../../../../core/theme/app_theme_data.dart';
import '../../localization/monitor_localization_keys.dart';

/// 无连接占位页
///
/// 当监控模块检测到模拟器未连接时，替代仪表盘显示此页面。
/// 提供视觉引导步骤，指示用户如何建立连接。
class MonitorNoConnectionPage extends StatelessWidget {
  const MonitorNoConnectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppThemeData.spacingLarge * 2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 图标区域：带光晕效果的传感器离线图标
            _buildIconSection(theme),
            const SizedBox(height: 48),

            // 渐变色标题
            _buildGradientTitle(context, theme),
            const SizedBox(height: 16),

            // 说明副标题
            _buildSubtitle(context, theme),
            const SizedBox(height: 56),

            // 操作引导步骤条
            _buildStepRow(context, theme),
            const SizedBox(height: 80),

            // 底部：支持的模拟器平台列表（低透明度装饰）
            _buildSupportedSimulators(theme),
          ],
        ),
      ),
    );
  }

  /// 构建中央图标区域（双层圆形光晕 + 传感器离线图标）
  Widget _buildIconSection(ThemeData theme) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // 外层：径向渐变光晕背景
        Container(
          width: 180,
          height: 180,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                theme.colorScheme.primary.withValues(alpha: 0.15),
                theme.colorScheme.primary.withValues(alpha: 0),
              ],
            ),
          ),
        ),
        // 内层：带投影的圆形容器
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: theme.colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withValues(alpha: 0.2),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Icon(
            Icons.sensors_off_rounded,
            size: 60,
            color: theme.colorScheme.primary.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }

  /// 构建带线性渐变的标题文字
  Widget _buildGradientTitle(BuildContext context, ThemeData theme) {
    return ShaderMask(
      shaderCallback: (bounds) => LinearGradient(
        colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
      ).createShader(bounds),
      child: Text(
        MonitorLocalizationKeys.noConnectionTitle.tr(context),
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  /// 构建说明副标题
  Widget _buildSubtitle(BuildContext context, ThemeData theme) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 400),
      child: Text(
        MonitorLocalizationKeys.noConnectionSubtitle.tr(context),
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyLarge?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          height: 1.6,
        ),
      ),
    );
  }

  /// 构建三步操作引导横排步骤条
  Widget _buildStepRow(BuildContext context, ThemeData theme) {
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildStep(
          context,
          MonitorLocalizationKeys.noConnectionStepHome.tr(context),
          Icons.home_outlined,
        ),
        _buildArrow(theme),
        _buildStep(
          context,
          MonitorLocalizationKeys.noConnectionStepConnect.tr(context),
          Icons.link_rounded,
        ),
        _buildArrow(theme),
        _buildStep(
          context,
          MonitorLocalizationKeys.noConnectionStepStart.tr(context),
          Icons.check_circle_outline_rounded,
        ),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) => SizedBox(
        width: constraints.maxWidth,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.center,
          child: content,
        ),
      ),
    );
  }

  /// 构建单个引导步骤（图标 + 文字标签）
  Widget _buildStep(BuildContext context, String label, IconData icon) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(AppThemeData.spacingMedium),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
            ),
          ),
          child: Icon(icon, color: theme.colorScheme.primary),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  /// 构建步骤间分隔箭头
  Widget _buildArrow(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      margin: const EdgeInsets.only(bottom: 24),
      child: Icon(
        Icons.chevron_right_rounded,
        color: theme.colorScheme.primary.withValues(alpha: 0.3),
      ),
    );
  }

  /// 构建底部支持平台列表（低透明度装饰性区域）
  Widget _buildSupportedSimulators(ThemeData theme) {
    final content = Opacity(
      opacity: 0.3,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(width: 24),
          _buildStatusDot(theme, 'X-Plane 11/12', true),
          const SizedBox(width: 24),
          _buildStatusDot(theme, 'MSFS 2020/2024', true),
        ],
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) => SizedBox(
        width: constraints.maxWidth,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.center,
          child: content,
        ),
      ),
    );
  }

  /// 构建单个平台状态指示点（绿色 = 已支持，灰色 = 不支持）
  Widget _buildStatusDot(ThemeData theme, String label, bool supported) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: supported ? Colors.greenAccent : Colors.grey,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
