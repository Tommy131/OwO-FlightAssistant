import 'package:flutter/material.dart';
import '../../../apps/models/simulator_data.dart';
import '../../../core/theme/app_theme_data.dart';
import 'flight_data_widgets.dart';

class SystemStatusPanel extends StatelessWidget {
  final SimulatorData data;

  const SystemStatusPanel({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // 定义专业的颜色方案
    // 警告系统 - 红色系
    const warningColor = Color(0xFFD32F2F); // 主警告 - 深红色
    const cautionColor = Color(0xFFFFA000); // 主告警 - 橙色
    const fireColor = Color(0xFFFF5252); // 火警 - 鲜红色

    // 外部警示灯光 - 红色系
    const beaconColor = Color(0xFFE53935); // 信标灯 - 鲜红色
    const strobeColor = Color(0xFFFFFFFF); // 频闪灯 - 纯白色

    // 导航/位置灯光 - 蓝绿色系
    const navLightsColor = Color(0xFF1E88E5); // 导航灯 - 蓝色
    const logoLightsColor = Color(0xFF26C6DA); // Logo灯 - 青色
    const wingLightsColor = Color(0xFF66BB6A); // 机翼灯 - 绿色

    // 地面操作灯光 - 黄色系
    const taxiLightsColor = Color(0xFFFDD835); // 滑行灯 - 亮黄色
    const runwayTurnoffColor = Color(0xFFFFB300); // 跑道脱离灯 - 琥珀色
    const wheelWellColor = Color(0xFFFFCA28); // 轮舱灯 - 橙黄色/琥珀

    // 着陆灯光 - 白绿色系
    const landingLightsColor = Color(0xFF7CB342); // 着陆灯 - 草绿色

    // 飞行控制系统
    const gearColor = Color(0xFF5E35B1); // 起落架 - 深紫蓝
    const parkingBrakeColor = Color(0xFFFF6F00); // 停机刹车 - 深橙色
    const speedBrakeColor = Color(0xFFE91E63); // 减速板 - 粉红色
    const autoBrakeColor = Color(0xFF00BCD4); // 自动刹车 - 青色
    const flapsColor = Color(0xFF9C27B0); // 襟翼 - 紫色

    // 动力系统 - 紫色/绿色系
    const apuColor = Color(0xFF8E24AA); // APU - 紫色
    const engineColor = Color(0xFF43A047); // 发动机 - 深绿色

    // 自动化系统 - 青色系
    const autopilotColor = Color(0xFF00ACC1); // 自动驾驶 - 深青色
    const autothrottleColor = Color(0xFF00897B); // 自动油门 - 青绿色

    // 飞行状态 - 棕色系
    const onGroundColor = Color(0xFF6D4C41); // 地面状态 - 棕色

    return Container(
      padding: const EdgeInsets.all(AppThemeData.spacingLarge),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppThemeData.borderRadiusMedium),
        border: Border.all(color: AppThemeData.getBorderColor(theme)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.dashboard, color: theme.colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                '系统状态',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppThemeData.spacingLarge),

          // 分类别显示
          Wrap(
            spacing: AppThemeData.spacingLarge,
            runSpacing: AppThemeData.spacingLarge,
            children: [
              // === 警告系统(最优先显示) ===
              _buildStatusSection(theme, '警告系统', [
                if (data.masterWarning == true)
                  const StatusBadge(label: '主警告', color: warningColor),
                if (data.masterCaution == true)
                  const StatusBadge(label: '主告警', color: cautionColor),
                if (data.fireWarningEngine1 == true)
                  const StatusBadge(label: '左发火警', color: fireColor),
                if (data.fireWarningEngine2 == true)
                  const StatusBadge(label: '右发火警', color: fireColor),
                if (data.fireWarningAPU == true)
                  const StatusBadge(label: 'APU火警', color: fireColor),
              ]),

              // === 飞行与控制组 ===
              _buildStatusSection(theme, '飞行与控制', [
                if (data.onGround == true)
                  const StatusBadge(label: '地面', color: onGroundColor),
                if (data.parkingBrake == true)
                  const StatusBadge(label: '停机刹车', color: parkingBrakeColor),
                if (data.speedBrake == true)
                  StatusBadge(
                    label:
                        '减速板 ${((data.speedBrakePosition ?? 0) * 100).toStringAsFixed(0)}%',
                    color: speedBrakeColor,
                  ),
                if (data.spoilersDeployed == true)
                  const StatusBadge(label: '扰流板', color: speedBrakeColor),
                StatusBadge(
                  label:
                      '自动刹车 ${data.autoBrakeLevel == -1
                          ? 'RTO'
                          : data.autoBrakeLevel == 4
                          ? 'MAX'
                          : data.autoBrakeLevel == 0
                          ? 'OFF'
                          : data.autoBrakeLevel}',
                  color: autoBrakeColor,
                ),
              ]),

              // === 起落架组 ===
              _buildStatusSection(theme, '起落架', [
                if (data.gearDown == true)
                  const StatusBadge(label: '起落架', color: gearColor),
                if (data.noseGearDown == true)
                  const StatusBadge(label: '前轮', color: gearColor),
                if (data.leftGearDown == true)
                  const StatusBadge(label: '左主轮', color: gearColor),
                if (data.rightGearDown == true)
                  const StatusBadge(label: '右主轮', color: gearColor),
              ]),

              // === 襟翼状态组 ===
              _buildStatusSection(theme, '襟翼状态', [
                if (data.flapsDeployed == true)
                  StatusBadge(
                    label: data.flapsLabel != null
                        ? '襟翼 ${data.flapsLabel}'
                        : (data.flapsAngle != null && data.flapsAngle! > 0)
                        ? '襟翼 ${data.flapsAngle!.toInt()}°'
                        : '襟翼 ${((data.flapsDeployRatio ?? 0) * 100).toStringAsFixed(0)}%',
                    color: flapsColor,
                  ),
              ]),

              // === 动力与自动化组 ===
              _buildStatusSection(theme, '动力与自动化', [
                if (data.apuRunning == true)
                  const StatusBadge(label: 'APU', color: apuColor),
                if (data.engine1Running == true)
                  const StatusBadge(label: '左发动机', color: engineColor),
                if (data.engine2Running == true)
                  const StatusBadge(label: '右发动机', color: engineColor),
                if (data.autopilotEngaged == true)
                  const StatusBadge(label: '自动驾驶', color: autopilotColor),
                if (data.autothrottleEngaged == true)
                  const StatusBadge(label: '自动油门', color: autothrottleColor),
              ]),

              // === 外部灯光组 ===
              _buildStatusSection(theme, '外部灯光', [
                if (data.beacon == true)
                  const StatusBadge(label: '信标灯', color: beaconColor),
                if (data.strobes == true)
                  const StatusBadge(label: '频闪灯', color: strobeColor),
                if (data.navLights == true)
                  const StatusBadge(label: '导航灯', color: navLightsColor),
                if (data.logoLights == true)
                  const StatusBadge(label: 'Logo灯', color: logoLightsColor),
                if (data.wingLights == true)
                  const StatusBadge(label: '机翼灯', color: wingLightsColor),
                if (data.landingLights == true)
                  const StatusBadge(label: '着陆灯', color: landingLightsColor),
                if (data.taxiLights == true)
                  const StatusBadge(label: '滑行灯', color: taxiLightsColor),
                if (data.runwayTurnoffLights == true)
                  const StatusBadge(label: '跑道脱离灯', color: runwayTurnoffColor),
                if (data.wheelWellLights == true)
                  const StatusBadge(label: '轮舱灯', color: wheelWellColor),
              ]),
            ].whereType<Widget>().toList(),
          ),
        ],
      ),
    );
  }

  Widget? _buildStatusSection(
    ThemeData theme,
    String title,
    List<Widget> children,
  ) {
    if (children.isEmpty) return null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.hintColor,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: children),
      ],
    );
  }
}
