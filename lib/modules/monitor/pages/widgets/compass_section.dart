import 'package:flutter/material.dart';
import '../../../../core/services/localization_service.dart';
import '../../../../core/theme/app_theme_data.dart';
import '../../localization/monitor_localization_keys.dart';
import '../../models/monitor_data.dart';
import 'heading_compass.dart';

/// 磁航向罗盘卡片组件
///
/// 以卡片形式展示当前飞机的磁航向，包含：
/// - 旋转式罗盘图形（由 [HeadingCompass] 绘制，飞机图标固定，刻度盘随航向旋转）
/// - 当前航向角度数值（度，精确到整数）
class CompassSection extends StatelessWidget {
  /// 当前飞行数据快照（读取 [MonitorData.heading]）
  final MonitorData data;

  const CompassSection({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppThemeData.spacingLarge),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(AppThemeData.borderRadiusLarge),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          // 卡片标题
          Text(
            MonitorLocalizationKeys.compassTitle.tr(context),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 20),

          // 罗盘绘制区域（固定高度，宽度自适应）
          SizedBox(
            height: 200,
            width: double.infinity,
            child: HeadingCompass(heading: data.heading ?? 0),
          ),
          const SizedBox(height: 10),

          // 数字航向显示（等宽字体，保持稳定宽度）
          Text(
            '${(data.heading ?? 0).toStringAsFixed(0)}°',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              fontFamily: 'Monospace',
            ),
          ),
        ],
      ),
    );
  }
}
