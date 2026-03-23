// 自动 HUD 计时器配置区块
//
// 负责单一职责：管理飞行计时器的自动启停行为配置。
// 包含：
// - 自动计时器总开关（SwitchListTile）
// - 计时器启动条件单选列表（MapAutoTimerStartMode）
// - 计时器停止条件单选列表（MapAutoTimerStopMode）
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../core/services/localization_service.dart';
import '../../../../../core/widgets/common/snack_bar.dart';
import '../../../localization/map_localization_keys.dart';
import '../../../models/map_models.dart';
import '../../../providers/map_provider.dart';
import 'map_settings_controls.dart';
import 'map_settings_section_card.dart';

/// 自动 HUD 计时器配置区块
///
/// 无复杂内部状态，所有操作均直接等待 [MapProvider] 的异步保存方法完成后显示 SnackBar。
/// 使用 [Consumer] 监听 [MapProvider] 的设置变更并即时反映到 UI。
class MapTimerSettingsSection extends StatefulWidget {
  const MapTimerSettingsSection({super.key});

  @override
  State<MapTimerSettingsSection> createState() =>
      _MapTimerSettingsSectionState();
}

class _MapTimerSettingsSectionState extends State<MapTimerSettingsSection> {
  // ── 内部操作方法 ──────────────────────────────────────────────────────────

  /// 切换自动计时器总开关，并保存到持久存储
  Future<void> _setAutoTimerEnabled(
    BuildContext context,
    bool value,
  ) async {
    final mapProvider = context.read<MapProvider?>();
    if (mapProvider == null) return;
    await mapProvider.setAutoHudTimerEnabled(value);
    if (!mounted) return;
    SnackBarHelper.showSuccess(
      context,
      MapLocalizationKeys.timerSettingsSaved.tr(context),
    );
  }

  /// 保存计时器启动条件
  Future<void> _setStartMode(
    BuildContext context,
    MapAutoTimerStartMode mode,
  ) async {
    final mapProvider = context.read<MapProvider?>();
    if (mapProvider == null) return;
    await mapProvider.setAutoTimerStartMode(mode);
    if (!mounted) return;
    SnackBarHelper.showSuccess(
      context,
      MapLocalizationKeys.timerSettingsSaved.tr(context),
    );
  }

  /// 保存计时器停止条件
  Future<void> _setStopMode(
    BuildContext context,
    MapAutoTimerStopMode mode,
  ) async {
    final mapProvider = context.read<MapProvider?>();
    if (mapProvider == null) return;
    await mapProvider.setAutoTimerStopMode(mode);
    if (!mounted) return;
    SnackBarHelper.showSuccess(
      context,
      MapLocalizationKeys.timerSettingsSaved.tr(context),
    );
  }

  // ── UI 构建 ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Consumer<MapProvider>(
      builder: (context, mapProvider, _) {
        final startMode = mapProvider.autoTimerStartMode;
        final stopMode = mapProvider.autoTimerStopMode;

        return SettingsSectionCard(
          icon: Icons.timer_outlined,
          title: MapLocalizationKeys.timerSectionTitle.tr(context),
          subtitle: MapLocalizationKeys.timerSectionDesc.tr(context),
          child: Column(
            children: [
              // 自动计时器总开关
              SwitchListTile(
                value: mapProvider.autoHudTimerEnabled,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  MapLocalizationKeys.timerAutoEnable.tr(context),
                ),
                onChanged: (value) {
                  unawaited(_setAutoTimerEnabled(context, value));
                },
              ),
              const SizedBox(height: 8),

              // ── 启动条件 ────────────────────────────────────────────────
              SettingsGroupTitle(
                title: MapLocalizationKeys.timerStartCondition.tr(context),
              ),
              const SizedBox(height: 8),

              // 跑道上开始移动时启动
              SelectionTile(
                selected: startMode == MapAutoTimerStartMode.runwayMovement,
                label: MapLocalizationKeys.timerStartRunwayMovement.tr(context),
                icon: Icons.flight_takeoff_rounded,
                onTap: () {
                  unawaited(
                    _setStartMode(context, MapAutoTimerStartMode.runwayMovement),
                  );
                },
              ),
              const SizedBox(height: 8),

              // 推出停机位时启动
              SelectionTile(
                selected: startMode == MapAutoTimerStartMode.pushback,
                label: MapLocalizationKeys.timerStartPushback.tr(context),
                icon: Icons.push_pin_outlined,
                onTap: () {
                  unawaited(
                    _setStartMode(context, MapAutoTimerStartMode.pushback),
                  );
                },
              ),
              const SizedBox(height: 8),

              // 任意移动时启动
              SelectionTile(
                selected: startMode == MapAutoTimerStartMode.anyMovement,
                label: MapLocalizationKeys.timerStartAnyMovement.tr(context),
                icon: Icons.directions_run_rounded,
                onTap: () {
                  unawaited(
                    _setStartMode(context, MapAutoTimerStartMode.anyMovement),
                  );
                },
              ),
              const SizedBox(height: 12),

              // ── 停止条件 ────────────────────────────────────────────────
              SettingsGroupTitle(
                title: MapLocalizationKeys.timerStopCondition.tr(context),
              ),
              const SizedBox(height: 8),

              // 稳定落地时停止
              SelectionTile(
                selected: stopMode == MapAutoTimerStopMode.stableLanding,
                label: MapLocalizationKeys.timerStopStableLanding.tr(context),
                icon: Icons.flight_land_rounded,
                onTap: () {
                  unawaited(
                    _setStopMode(context, MapAutoTimerStopMode.stableLanding),
                  );
                },
              ),
              const SizedBox(height: 8),

              // 落地后脱离跑道时停止
              SelectionTile(
                selected: stopMode == MapAutoTimerStopMode.runwayExitAfterLanding,
                label: MapLocalizationKeys.timerStopRunwayExit.tr(context),
                icon: Icons.turn_right_rounded,
                onTap: () {
                  unawaited(
                    _setStopMode(
                      context,
                      MapAutoTimerStopMode.runwayExitAfterLanding,
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),

              // 进入停机位时停止
              SelectionTile(
                selected: stopMode == MapAutoTimerStopMode.parkingArrival,
                label: MapLocalizationKeys.timerStopParkingArrival.tr(context),
                icon: Icons.local_parking_rounded,
                onTap: () {
                  unawaited(
                    _setStopMode(
                      context,
                      MapAutoTimerStopMode.parkingArrival,
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
