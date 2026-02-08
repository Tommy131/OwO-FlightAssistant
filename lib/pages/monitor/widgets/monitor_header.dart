import 'package:flutter/material.dart';
import '../../../apps/models/simulator_data.dart';
import '../../../core/theme/app_theme_data.dart';

class MonitorHeader extends StatelessWidget {
  final SimulatorData data;

  const MonitorHeader({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (data.masterWarning == true || data.masterCaution == true)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: AppThemeData.spacingMedium),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: (data.masterWarning == true ? Colors.red : Colors.orange)
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(
                AppThemeData.borderRadiusMedium,
              ),
              border: Border.all(
                color: (data.masterWarning == true ? Colors.red : Colors.orange)
                    .withValues(alpha: 0.5),
                width: 2,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  data.masterWarning == true ? Icons.warning : Icons.info,
                  color: data.masterWarning == true
                      ? Colors.red
                      : Colors.orange,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    data.masterWarning == true
                        ? '主警告 (MASTER WARNING) - 请检查警报面板'
                        : '主告警 (MASTER CAUTION) - 系统异常',
                    style: TextStyle(
                      color: data.masterWarning == true
                          ? Colors.red
                          : Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '实时飞行监控',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                Text(
                  data.isConnected ? '正在接收来自模拟器的实时数据' : '模拟器未连接',
                  style: TextStyle(color: theme.hintColor),
                ),
              ],
            ),
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
                    const Text(
                      '已暂停',
                      style: TextStyle(
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
