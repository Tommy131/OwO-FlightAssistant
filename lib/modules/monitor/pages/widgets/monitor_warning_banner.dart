import 'package:flutter/material.dart';
import '../../../../core/services/localization_service.dart';
import '../../../../core/theme/app_theme_data.dart';
import '../../localization/monitor_localization_keys.dart';
import '../../models/monitor_data.dart';

/// 主警告 / 主告警横幅组件
///
/// 当飞行数据中 [MonitorData.masterWarning] 或 [MonitorData.masterCaution]
/// 为 true 时显示该横幅，提示驾驶员检查告警系统。
///
/// - MASTER WARNING（主警告）：红色边框 + 警告图标
/// - MASTER CAUTION（主告警）：橙色边框 + 信息图标
///
/// 若两者均为 false，则此组件不渲染任何内容（[SizedBox.shrink]）。
class MonitorWarningBanner extends StatelessWidget {
  /// 当前飞行数据（用于读取警告状态）
  final MonitorData data;

  const MonitorWarningBanner({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    // 两个告警均未激活时，不占用任何空间
    if (data.masterWarning != true && data.masterCaution != true) {
      return const SizedBox.shrink();
    }

    // 主警告优先级高于主告警
    final isWarning = data.masterWarning == true;
    final bannerColor = isWarning ? Colors.red : Colors.orange;
    final message = isWarning
        ? MonitorLocalizationKeys.masterWarningMessage.tr(context)
        : MonitorLocalizationKeys.masterCautionMessage.tr(context);
    final icon = isWarning ? Icons.warning : Icons.info;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppThemeData.spacingMedium),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: bannerColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppThemeData.borderRadiusMedium),
        border: Border.all(
          color: bannerColor.withValues(alpha: 0.5),
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: bannerColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: bannerColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
