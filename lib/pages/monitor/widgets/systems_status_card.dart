import 'package:flutter/material.dart';
import '../../../apps/models/simulator_data.dart';
import '../../../core/theme/app_theme_data.dart';

class SystemsStatusCard extends StatelessWidget {
  final SimulatorData data;

  const SystemsStatusCard({super.key, required this.data});

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '飞行系统状态 (Systems Status)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 16),
          _buildStatusRow(
            context,
            '停机刹车 (Parking Brake)',
            data.parkingBrake == true ? 'SET' : 'RELEASED',
            isHighlight: data.parkingBrake == true,
            highlightColor: Colors.orangeAccent,
          ),
          const Divider(height: 20),
          _buildStatusRow(
            context,
            '自动刹车 (Auto Brake)',
            data.autoBrakeLevel != null
                ? 'LEVEL ${data.autoBrakeLevel}'
                : 'OFF',
            isHighlight: data.autoBrakeLevel != null,
            highlightColor: Colors.blueAccent,
          ),
          const Divider(height: 20),
          _buildStatusRow(
            context,
            '襟翼位置 (Flaps)',
            data.flapsLabel ?? 'UP',
            isHighlight: (data.flapsDeployRatio ?? 0) > 0.05,
            highlightColor: Colors.blueAccent,
          ),
          const Divider(height: 20),
          _buildStatusRow(
            context,
            '减速板 (Speed Brake)',
            data.speedBrake == true ? 'DEPLOYED' : 'RETRACTED',
            isHighlight: data.speedBrake == true,
            highlightColor: Colors.orangeAccent,
          ),
          if (data.fireWarningEngine1 == true ||
              data.fireWarningEngine2 == true ||
              data.fireWarningAPU == true) ...[
            const Divider(height: 20),
            _buildStatusRow(
              context,
              '火警警告 (FIRE)',
              '${[if (data.fireWarningEngine1 == true) 'ENG1', if (data.fireWarningEngine2 == true) 'ENG2', if (data.fireWarningAPU == true) 'APU'].join(' ')} FIRE',
              isHighlight: true,
              highlightColor: Colors.redAccent,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusRow(
    BuildContext context,
    String label,
    String value, {
    bool isHighlight = false,
    Color highlightColor = Colors.orangeAccent,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color:
                Theme.of(
                  context,
                ).textTheme.bodySmall?.color?.withValues(alpha: 0.7) ??
                Colors.grey,
            fontSize: 13,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: (isHighlight ? highlightColor : Colors.blueAccent)
                .withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            value,
            style: TextStyle(
              color: isHighlight ? highlightColor : Colors.blueAccent,
              fontWeight: FontWeight.bold,
              fontSize: 13,
              fontFamily: 'Monospace',
            ),
          ),
        ),
      ],
    );
  }
}
