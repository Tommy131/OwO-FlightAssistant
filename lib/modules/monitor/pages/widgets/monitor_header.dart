import 'package:flutter/material.dart';
import '../../../../core/services/localization_service.dart';
import '../../localization/monitor_localization_keys.dart';
import '../../models/monitor_data.dart';
import 'monitor_warning_banner.dart';

/// 监控页面顶部标题栏组件
///
/// 显示以下内容（从上到下）：
/// 1. 主警告 / 主告警横幅（仅在告警激活时显示，由 [MonitorWarningBanner] 负责）
/// 2. 页面标题与连接状态副标题
/// 3. 暂停状态徽章（仅在已连接且模拟器暂停时显示）
class MonitorHeader extends StatelessWidget {
  /// 当前飞行数据快照
  final MonitorData data;

  const MonitorHeader({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 警告横幅（主警告 / 主告警），无告警时不渲染
        MonitorWarningBanner(data: data),

        // 标题行：左侧标题 + 副标题，右侧暂停徽章
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // 左侧：页面标题与连接状态描述
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  MonitorLocalizationKeys.pageTitle.tr(context),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  data.isConnected
                      ? MonitorLocalizationKeys.pageSubtitleConnected.tr(
                          context,
                        )
                      : MonitorLocalizationKeys.pageSubtitleDisconnected.tr(
                          context,
                        ),
                  style: TextStyle(color: theme.hintColor),
                ),
              ],
            ),

            // 右侧：暂停徽章（仅在已连接且模拟器暂停时显示）
            if (data.isConnected && data.isPaused == true)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(
                    alpha: 0.3,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.pause, size: 16, color: Colors.orange),
                    const SizedBox(width: 4),
                    Text(
                      MonitorLocalizationKeys.pausedLabel.tr(context),
                      style: const TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}
