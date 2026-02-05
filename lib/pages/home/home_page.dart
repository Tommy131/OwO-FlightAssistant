import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme_data.dart';
import '../../apps/providers/checklist_provider.dart';
import '../../apps/providers/simulator_provider.dart';
import '../../apps/models/simulator_data.dart';
import '../../core/widgets/common/dialog.dart';

/// 首页 - 模拟器数据仪表盘
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      color: theme.scaffoldBackgroundColor,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppThemeData.spacingLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 欢迎卡片
            _buildWelcomeCard(theme),

            const SizedBox(height: AppThemeData.spacingLarge),

            // 模拟器连接状态和检查阶段
            _buildStatusRow(context, theme),

            const SizedBox(height: AppThemeData.spacingLarge),

            // 飞行数据仪表盘
            _buildFlightDataDashboard(context, theme),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeCard(ThemeData theme) {
    return Consumer<SimulatorProvider>(
      builder: (context, simProvider, _) {
        final isConnected = simProvider.isConnected;
        final aircraftTitle = simProvider.simulatorData.aircraftTitle;
        final isPaused = simProvider.simulatorData.isPaused ?? false;

        String title;
        String subtitle;
        Widget? statusIndicator;

        if (!isConnected) {
          title = '未连接模拟器！';
          subtitle = '等待建立数据链路...';
        } else if (isPaused) {
          title = '模拟器已暂停';
          subtitle = '检测到模拟器处于暂停状态 ($aircraftTitle)';
          statusIndicator = Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.yellow.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.pause_circle_filled,
              color: Colors.yellow,
              size: 32,
            ),
          );
        } else {
          title = '飞行准备就绪';
          subtitle = aircraftTitle != null
              ? '当前机型: $aircraftTitle'
              : '等待识别机型...';
          statusIndicator = Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.greenAccent.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle,
              color: Colors.greenAccent,
              size: 32,
            ),
          );
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppThemeData.spacingLarge),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppThemeData.borderRadiusLarge),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (statusIndicator != null) statusIndicator,
                ],
              ),
              const SizedBox(height: AppThemeData.spacingSmall),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: AppThemeData.spacingLarge),
              Row(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    color: Colors.white.withValues(alpha: 0.8),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '支持 MSFS 2020/2024 & X-Plane 11/12',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusRow(BuildContext context, ThemeData theme) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 模拟器连接状态
          Expanded(child: _buildSimulatorConnectionCard(context, theme)),
          const SizedBox(width: AppThemeData.spacingMedium),
          // 当前检查阶段
          Expanded(child: _buildChecklistPhaseCard(context, theme)),
        ],
      ),
    );
  }

  Widget _buildSimulatorConnectionCard(BuildContext context, ThemeData theme) {
    return Consumer<SimulatorProvider>(
      builder: (context, simProvider, _) {
        final isConnected = simProvider.isConnected;
        final simulatorType = simProvider.currentSimulator;

        return Container(
          padding: const EdgeInsets.all(AppThemeData.spacingLarge),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(
              AppThemeData.borderRadiusMedium,
            ),
            border: Border.all(
              color: isConnected
                  ? Colors.green.withValues(alpha: 0.5)
                  : AppThemeData.getBorderColor(theme),
              width: isConnected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isConnected ? Icons.link : Icons.link_off,
                    color: isConnected ? Colors.green : Colors.grey,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '模拟器连接',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                isConnected
                    ? '已连接到 ${_getSimulatorName(simulatorType)}'
                    : '未连接',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isConnected ? Colors.green : Colors.grey,
                ),
              ),
              const Spacer(),
              const SizedBox(height: 12),
              // 连接/断开按钮
              if (isConnected)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await simProvider.disconnect();
                    },
                    icon: const Icon(Icons.link_off, size: 16),
                    label: const Text('断开'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: PopupMenuButton<String>(
                    onSelected: (value) async {
                      _handleConnect(context, simProvider, value);
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'msfs',
                        child: Row(
                          children: [
                            Icon(Icons.flight, size: 18),
                            SizedBox(width: 8),
                            Text('连接 MSFS'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'xplane',
                        child: Row(
                          children: [
                            Icon(Icons.airplanemode_active, size: 18),
                            SizedBox(width: 8),
                            Text('连接 X-Plane'),
                          ],
                        ),
                      ),
                    ],
                    child: ElevatedButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.link, size: 16),
                      label: const Text('连接'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  /// 处理模拟器连接逻辑（带弹窗反馈）
  Future<void> _handleConnect(
    BuildContext context,
    SimulatorProvider simProvider,
    String type,
  ) async {
    final theme = Theme.of(context);
    final isXPlane = type == 'xplane';
    final name = isXPlane ? 'X-Plane' : 'MSFS';

    // 1. 显示“连接中”弹窗
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 20),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 20),
                Text(
                  '正在建立与 $name 的连接...',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '请确保模拟器已启动并处于飞行状态',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // 2. 执行连接
    bool success = false;
    if (isXPlane) {
      success = await simProvider.connectToXPlane();
    } else {
      success = await simProvider.connectToMSFS();
    }

    // 3. 关闭“连接中”弹窗
    if (context.mounted) {
      Navigator.of(context).pop();
    }

    // 4. 如果失败，显示错误弹窗
    if (!success && context.mounted) {
      showAdvancedConfirmDialog(
        context: context,
        style: ConfirmDialogStyle.material,
        title: '连接失败',
        content: simProvider.errorMessage ?? '原因不明，请检查模拟器设置或网络连接。',
        icon: Icons.error_outline,
        confirmColor: Colors.red,
        confirmText: '确定',
        cancelText: '', // 只显示确定按钮
      );
    }
  }

  Widget _buildChecklistPhaseCard(BuildContext context, ThemeData theme) {
    return Consumer<ChecklistProvider>(
      builder: (context, provider, _) {
        final progress = provider.getPhaseProgress(provider.currentPhase);

        return Container(
          padding: const EdgeInsets.all(AppThemeData.spacingLarge),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(
              AppThemeData.borderRadiusMedium,
            ),
            border: Border.all(color: AppThemeData.getBorderColor(theme)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    provider.currentPhase.icon,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '当前检查阶段',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                provider.currentPhase.label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
              const Spacer(),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: theme.colorScheme.outline.withValues(
                        alpha: 0.1,
                      ),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${(progress * 100).toInt()}%',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFlightDataDashboard(BuildContext context, ThemeData theme) {
    return Consumer<SimulatorProvider>(
      builder: (context, simProvider, _) {
        if (!simProvider.isConnected) {
          return _buildNoConnectionPlaceholder(theme);
        }

        final data = simProvider.simulatorData;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '实时飞行数据',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppThemeData.spacingMedium),

            // 主要飞行参数
            _buildPrimaryFlightData(theme, data),

            const SizedBox(height: AppThemeData.spacingMedium),

            // 导航和位置
            _buildNavigationData(theme, data),

            const SizedBox(height: AppThemeData.spacingMedium),

            // 环境数据
            _buildEnvironmentData(theme, data),

            const SizedBox(height: AppThemeData.spacingMedium),

            // 发动机和燃油
            _buildEngineAndFuelData(theme, data),

            const SizedBox(height: AppThemeData.spacingMedium),

            // 系统状态
            _buildSystemStatus(theme, data),
          ],
        );
      },
    );
  }

  Widget _buildNoConnectionPlaceholder(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(AppThemeData.spacingLarge * 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppThemeData.borderRadiusMedium),
        border: Border.all(color: AppThemeData.getBorderColor(theme)),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.flight_takeoff,
              size: 64,
              color: theme.colorScheme.outline.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              '连接模拟器以查看实时飞行数据',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '点击上方"连接"按钮开始',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrimaryFlightData(ThemeData theme, SimulatorData data) {
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: AppThemeData.spacingMedium,
      mainAxisSpacing: AppThemeData.spacingMedium,
      childAspectRatio: 1.5,
      children: [
        _buildDataCard(
          theme,
          Icons.speed,
          '指示空速',
          data.airspeed != null
              ? '${data.airspeed!.toStringAsFixed(0)} kt'
              : 'N/A',
          Colors.blue,
        ),
        _buildDataCard(
          theme,
          Icons.height,
          '高度',
          data.altitude != null
              ? '${data.altitude!.toStringAsFixed(0)} ft'
              : 'N/A',
          Colors.green,
        ),
        _buildDataCard(
          theme,
          Icons.explore,
          '航向',
          data.heading != null ? '${data.heading!.toStringAsFixed(0)}°' : 'N/A',
          Colors.purple,
        ),
        _buildDataCard(
          theme,
          Icons.trending_up,
          '垂直速度',
          data.verticalSpeed != null
              ? '${data.verticalSpeed!.toStringAsFixed(0)} fpm'
              : 'N/A',
          Colors.orange,
        ),
      ],
    );
  }

  Widget _buildNavigationData(ThemeData theme, SimulatorData data) {
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
              Icon(Icons.map, color: theme.colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                '导航与位置',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppThemeData.spacingMedium),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              _buildInfoChip(
                theme,
                '地速',
                data.groundSpeed != null
                    ? '${data.groundSpeed!.toStringAsFixed(0)} kt'
                    : 'N/A',
              ),
              _buildInfoChip(
                theme,
                '真空速',
                data.trueAirspeed != null
                    ? '${data.trueAirspeed!.toStringAsFixed(0)} kt'
                    : 'N/A',
              ),
              _buildInfoChip(
                theme,
                '纬度',
                data.latitude != null
                    ? data.latitude!.toStringAsFixed(4)
                    : 'N/A',
              ),
              _buildInfoChip(
                theme,
                '经度',
                data.longitude != null
                    ? data.longitude!.toStringAsFixed(4)
                    : 'N/A',
              ),
              if (data.departureAirport != null)
                _buildInfoChip(theme, '起飞机场', data.departureAirport!),
              if (data.arrivalAirport != null)
                _buildInfoChip(theme, '目的机场', data.arrivalAirport!),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEnvironmentData(ThemeData theme, SimulatorData data) {
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
              Icon(Icons.wb_sunny, color: theme.colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                '环境数据',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppThemeData.spacingMedium),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              _buildInfoChip(
                theme,
                '外部温度',
                data.outsideAirTemperature != null
                    ? '${data.outsideAirTemperature!.toStringAsFixed(1)}°C'
                    : 'N/A',
              ),
              _buildInfoChip(
                theme,
                '总温度',
                data.totalAirTemperature != null
                    ? '${data.totalAirTemperature!.toStringAsFixed(1)}°C'
                    : 'N/A',
              ),
              _buildInfoChip(
                theme,
                '风速',
                data.windSpeed != null
                    ? '${data.windSpeed!.toStringAsFixed(0)} kt'
                    : 'N/A',
              ),
              _buildInfoChip(
                theme,
                '风向',
                data.windDirection != null
                    ? '${data.windDirection!.toStringAsFixed(0)}°'
                    : 'N/A',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEngineAndFuelData(ThemeData theme, SimulatorData data) {
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
              Icon(Icons.settings, color: theme.colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                '发动机与燃油',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppThemeData.spacingMedium),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              _buildInfoChip(
                theme,
                '燃油总量',
                data.fuelQuantity != null
                    ? '${data.fuelQuantity!.toStringAsFixed(0)} kg'
                    : 'N/A',
              ),
              _buildInfoChip(
                theme,
                '燃油流量',
                data.fuelFlow != null
                    ? '${data.fuelFlow!.toStringAsFixed(1)} kg/h'
                    : 'N/A',
              ),
              _buildInfoChip(
                theme,
                'ENG1 N1',
                data.engine1N1 != null
                    ? '${data.engine1N1!.toStringAsFixed(1)}%'
                    : 'N/A',
              ),
              _buildInfoChip(
                theme,
                'ENG2 N1',
                data.engine2N1 != null
                    ? '${data.engine2N1!.toStringAsFixed(1)}%'
                    : 'N/A',
              ),
              _buildInfoChip(
                theme,
                'ENG1 EGT',
                data.engine1EGT != null
                    ? '${data.engine1EGT!.toStringAsFixed(0)}°C'
                    : 'N/A',
              ),
              _buildInfoChip(
                theme,
                'ENG2 EGT',
                data.engine2EGT != null
                    ? '${data.engine2EGT!.toStringAsFixed(0)}°C'
                    : 'N/A',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSystemStatus(ThemeData theme, SimulatorData data) {
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
                  _buildStatusBadge(theme, '主警告', warningColor),
                if (data.masterCaution == true)
                  _buildStatusBadge(theme, '主告警', cautionColor),
                if (data.fireWarningEngine1 == true)
                  _buildStatusBadge(theme, '左发火警', fireColor),
                if (data.fireWarningEngine2 == true)
                  _buildStatusBadge(theme, '右发火警', fireColor),
                if (data.fireWarningAPU == true)
                  _buildStatusBadge(theme, 'APU火警', fireColor),
              ]),

              // === 飞行与控制组 ===
              _buildStatusSection(theme, '飞行与控制', [
                if (data.onGround == true)
                  _buildStatusBadge(theme, '地面', onGroundColor),
                if (data.parkingBrake == true)
                  _buildStatusBadge(theme, '停机刹车', parkingBrakeColor),
                if (data.speedBrake == true)
                  _buildStatusBadge(
                    theme,
                    '减速板 ${((data.speedBrakePosition ?? 0) * 100).toStringAsFixed(0)}%',
                    speedBrakeColor,
                  ),
                if (data.spoilersDeployed == true)
                  _buildStatusBadge(theme, '扰流板', speedBrakeColor),
                if (data.autoBrakeLevel != null && data.autoBrakeLevel! > 0)
                  _buildStatusBadge(
                    theme,
                    data.autoBrakeLevel == 5
                        ? '自动刹车 RTO'
                        : data.autoBrakeLevel == 4
                        ? '自动刹车 MAX'
                        : '自动刹车 ${data.autoBrakeLevel}',
                    autoBrakeColor,
                  ),
              ]),

              // === 起落架组 ===
              _buildStatusSection(theme, '起落架', [
                if (data.gearDown == true)
                  _buildStatusBadge(theme, '起落架', gearColor),
                if (data.noseGearDown == true)
                  _buildStatusBadge(theme, '前轮', gearColor),
                if (data.leftGearDown == true)
                  _buildStatusBadge(theme, '左主轮', gearColor),
                if (data.rightGearDown == true)
                  _buildStatusBadge(theme, '右主轮', gearColor),
              ]),

              // === 襟翼状态组 ===
              _buildStatusSection(theme, '襟翼状态', [
                if (data.flapsDeployed == true)
                  _buildStatusBadge(
                    theme,
                    data.flapsLabel != null
                        ? '襟翼 ${data.flapsLabel}'
                        : (data.flapsAngle != null && data.flapsAngle! > 0)
                        ? '襟翼 ${data.flapsAngle!.toInt()}°'
                        : '襟翼 ${((data.flapsDeployRatio ?? 0) * 100).toStringAsFixed(0)}%',
                    flapsColor,
                  ),
              ]),

              // === 动力与自动化组 ===
              _buildStatusSection(theme, '动力与自动化', [
                if (data.apuRunning == true)
                  _buildStatusBadge(theme, 'APU', apuColor),
                if (data.engine1Running == true)
                  _buildStatusBadge(theme, '左发动机', engineColor),
                if (data.engine2Running == true)
                  _buildStatusBadge(theme, '右发动机', engineColor),
                if (data.autopilotEngaged == true)
                  _buildStatusBadge(theme, '自动驾驶', autopilotColor),
                if (data.autothrottleEngaged == true)
                  _buildStatusBadge(theme, '自动油门', autothrottleColor),
              ]),

              // === 外部灯光组 ===
              _buildStatusSection(theme, '外部灯光', [
                if (data.beacon == true)
                  _buildStatusBadge(theme, '信标灯', beaconColor),
                if (data.strobes == true)
                  _buildStatusBadge(theme, '频闪灯', strobeColor),
                if (data.navLights == true)
                  _buildStatusBadge(theme, '导航灯', navLightsColor),
                if (data.logoLights == true)
                  _buildStatusBadge(theme, 'Logo灯', logoLightsColor),
                if (data.wingLights == true)
                  _buildStatusBadge(theme, '机翼灯', wingLightsColor),
                if (data.landingLights == true)
                  _buildStatusBadge(theme, '着陆灯', landingLightsColor),
                if (data.taxiLights == true)
                  _buildStatusBadge(theme, '滑行灯', taxiLightsColor),
                if (data.runwayTurnoffLights == true)
                  _buildStatusBadge(theme, '跑道脱离灯', runwayTurnoffColor),
                if (data.wheelWellLights == true)
                  _buildStatusBadge(theme, '轮舱灯', wheelWellColor),
              ]),
            ].whereType<Widget>().toList(), // 核心修复：过滤掉 null，确保第一个显示的区块靠左
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
    if (children.isEmpty) return null; // 改为返回 null

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

  Widget _buildDataCard(
    ThemeData theme,
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppThemeData.spacingMedium),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppThemeData.borderRadiusSmall),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(ThemeData theme, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(ThemeData theme, String label, Color color) {
    // 检查颜色亮度，解决白色文字在浅色背景看不见的问题
    final isLightColor = color.computeLuminance() > 0.8;
    final textColor = isLightColor ? Colors.black87 : color;
    final borderColor = isLightColor
        ? Colors.black45
        : color.withValues(alpha: 0.3);
    final dotColor = color; // 圆点保持原色（如白色）
    final backgroundColor = isLightColor
        ? Colors.black12
        : color.withValues(alpha: 0.1);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
              border: isLightColor
                  ? Border.all(color: Colors.black26, width: 0.5)
                  : null,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _getSimulatorName(SimulatorType type) {
    switch (type) {
      case SimulatorType.msfs:
        return 'MSFS';
      case SimulatorType.xplane:
        return 'X-Plane';
      case SimulatorType.none:
        return '无';
    }
  }
}
