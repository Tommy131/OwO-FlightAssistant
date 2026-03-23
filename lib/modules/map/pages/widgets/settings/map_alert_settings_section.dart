// 飞行警报配置区块
//
// 负责单一职责：管理所有飞行告警相关设置。
// 包含：
// - 全局告警开关（SwitchListTile）
// - 可配置告警类型的勾选标签列表（AlertToggleTag）
// - 爬升/下降速率警告/危险阈值的输入框（FPM）
// - 阈值保存按钮
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../../core/services/localization_service.dart';
import '../../../../../core/theme/app_theme_data.dart';
import '../../../../../core/widgets/common/snack_bar.dart';
import '../../../localization/map_localization_keys.dart';
import '../../../providers/map_provider.dart';
import 'map_settings_controls.dart';
import 'map_settings_section_card.dart';

/// 飞行警报配置区块
///
/// 自治 StatefulWidget，内部管理：
/// - 4 个阈值输入框的 [TextEditingController] 和 [FocusNode]
/// - 阈值保存的 loading 状态
/// - 避免 Provider 更新覆盖用户正在编辑的字段（通过签名比对）
class MapAlertSettingsSection extends StatefulWidget {
  const MapAlertSettingsSection({super.key});

  @override
  State<MapAlertSettingsSection> createState() =>
      _MapAlertSettingsSectionState();
}

class _MapAlertSettingsSectionState extends State<MapAlertSettingsSection> {
  // ── 爬升速率输入框 ─────────────────────────────────────────────────────────
  /// 爬升警告阈值输入框控制器（FPM）
  final TextEditingController _climbWarningCtrl = TextEditingController();

  /// 爬升危险阈值输入框控制器（FPM）
  final TextEditingController _climbDangerCtrl = TextEditingController();

  // ── 下降速率输入框 ─────────────────────────────────────────────────────────
  /// 下降警告阈值输入框控制器（FPM）
  final TextEditingController _descentWarningCtrl = TextEditingController();

  /// 下降危险阈值输入框控制器（FPM）
  final TextEditingController _descentDangerCtrl = TextEditingController();

  // ── 焦点节点 ───────────────────────────────────────────────────────────────
  final FocusNode _climbWarningFocus = FocusNode();
  final FocusNode _climbDangerFocus = FocusNode();
  final FocusNode _descentWarningFocus = FocusNode();
  final FocusNode _descentDangerFocus = FocusNode();

  /// 是否正在保存阈值
  bool _isSaving = false;

  /// 上次同步到输入框的阈值签名（用于跳过无变化的更新）
  String? _thresholdSignature;

  @override
  void dispose() {
    _climbWarningCtrl.dispose();
    _climbDangerCtrl.dispose();
    _descentWarningCtrl.dispose();
    _descentDangerCtrl.dispose();
    _climbWarningFocus.dispose();
    _climbDangerFocus.dispose();
    _descentWarningFocus.dispose();
    _descentDangerFocus.dispose();
    super.dispose();
  }

  // ── 内部逻辑 ──────────────────────────────────────────────────────────────

  /// 将 [MapProvider] 中的阈值同步到输入框
  ///
  /// 若任意输入框正在被编辑，或正在保存中，则跳过同步（避免打断用户输入）。
  /// 若数据与上次签名相同，也跳过（避免无谓重绘）。
  void _syncControllers(MapProvider mapProvider) {
    final hasFocus =
        _climbWarningFocus.hasFocus ||
        _climbDangerFocus.hasFocus ||
        _descentWarningFocus.hasFocus ||
        _descentDangerFocus.hasFocus;
    if (hasFocus || _isSaving) return;

    final sig =
        '${mapProvider.climbRateWarningFpm}|${mapProvider.climbRateDangerFpm}'
        '|${mapProvider.descentRateWarningFpm}|${mapProvider.descentRateDangerFpm}';
    if (sig == _thresholdSignature) return;

    _climbWarningCtrl.text = '${mapProvider.climbRateWarningFpm}';
    _climbDangerCtrl.text = '${mapProvider.climbRateDangerFpm}';
    _descentWarningCtrl.text = '${mapProvider.descentRateWarningFpm}';
    _descentDangerCtrl.text = '${mapProvider.descentRateDangerFpm}';
    _thresholdSignature = sig;
  }

  /// 验证并保存阈值设置到 [MapProvider]
  ///
  /// 规则：各值必须为正整数，且 danger > warning。
  Future<void> _save(BuildContext context, MapProvider mapProvider) async {
    final climbWarning = int.tryParse(_climbWarningCtrl.text.trim());
    final climbDanger = int.tryParse(_climbDangerCtrl.text.trim());
    final descentWarning = int.tryParse(_descentWarningCtrl.text.trim());
    final descentDanger = int.tryParse(_descentDangerCtrl.text.trim());

    final isValid =
        climbWarning != null &&
        climbDanger != null &&
        descentWarning != null &&
        descentDanger != null &&
        climbWarning > 0 &&
        climbDanger > climbWarning &&
        descentWarning > 0 &&
        descentDanger > descentWarning;

    if (!isValid) {
      SnackBarHelper.showError(
        context,
        MapLocalizationKeys.invalidAlertThreshold.tr(context),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await mapProvider.setVerticalRateThresholds(
        climbWarningFpm: climbWarning,
        climbDangerFpm: climbDanger,
        descentWarningFpm: descentWarning,
        descentDangerFpm: descentDanger,
      );
      if (!mounted) return;
      _syncControllers(mapProvider);
      SnackBarHelper.showSuccess(
        context,
        MapLocalizationKeys.alertSettingsSaved.tr(context),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── UI 构建 ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Consumer<MapProvider>(
      builder: (context, mapProvider, _) {
        _syncControllers(mapProvider);
        final theme = Theme.of(context);
        final alertsEnabled = mapProvider.alertsEnabled;
        final canEdit = alertsEnabled && !_isSaving;

        return SettingsSectionCard(
          icon: Icons.warning_amber_rounded,
          title: MapLocalizationKeys.alertSettingsSectionTitle.tr(context),
          subtitle: MapLocalizationKeys.alertSettingsSectionDesc.tr(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 全局告警开关
              SwitchListTile(
                value: alertsEnabled,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  MapLocalizationKeys.alertSettingsEnableAll.tr(context),
                ),
                onChanged: (value) {
                  unawaited(mapProvider.setAlertsEnabled(value));
                },
              ),
              const SizedBox(height: 4),
              // 告警类型标签组标题
              Text(
                MapLocalizationKeys.alertSettingsSelectAlerts.tr(context),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              // 可配置告警类型标签列表
              Wrap(
                spacing: AppThemeData.spacingSmall,
                runSpacing: AppThemeData.spacingSmall,
                children: mapProvider.configurableAlertIds.map((alertId) {
                  final labelKey =
                      mapProvider.alertMessageKeyForId(alertId) ?? alertId;
                  final selected = mapProvider.isAlertEnabled(alertId);
                  return AlertToggleTag(
                    label: labelKey.tr(context),
                    selected: selected,
                    enabled: alertsEnabled,
                    onTap: () {
                      unawaited(
                        mapProvider.setAlertEnabled(alertId, !selected),
                      );
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: AppThemeData.spacingSmall),
              // 阈值设置标题
              Text(
                MapLocalizationKeys.alertSettingsThresholdTitle.tr(context),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppThemeData.spacingSmall),
              // 爬升速率 - 警告阈值
              TextField(
                controller: _climbWarningCtrl,
                focusNode: _climbWarningFocus,
                enabled: canEdit,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: MapLocalizationKeys.alertThresholdClimbWarningLabel
                      .tr(context),
                  prefixIcon: const Icon(Icons.trending_up_rounded),
                ),
              ),
              const SizedBox(height: AppThemeData.spacingSmall),
              // 爬升速率 - 危险阈值
              TextField(
                controller: _climbDangerCtrl,
                focusNode: _climbDangerFocus,
                enabled: canEdit,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: MapLocalizationKeys.alertThresholdClimbDangerLabel
                      .tr(context),
                  prefixIcon: const Icon(Icons.trending_up_rounded),
                ),
              ),
              const SizedBox(height: AppThemeData.spacingSmall),
              // 下降速率 - 警告阈值
              TextField(
                controller: _descentWarningCtrl,
                focusNode: _descentWarningFocus,
                enabled: canEdit,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText:
                      MapLocalizationKeys.alertThresholdDescentWarningLabel.tr(
                        context,
                      ),
                  prefixIcon: const Icon(Icons.trending_down_rounded),
                ),
              ),
              const SizedBox(height: AppThemeData.spacingSmall),
              // 下降速率 - 危险阈值
              TextField(
                controller: _descentDangerCtrl,
                focusNode: _descentDangerFocus,
                enabled: canEdit,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText:
                      MapLocalizationKeys.alertThresholdDescentDangerLabel.tr(
                        context,
                      ),
                  prefixIcon: const Icon(Icons.trending_down_rounded),
                ),
              ),
              const SizedBox(height: AppThemeData.spacingSmall),
              // 阈值说明提示文字
              Text(
                MapLocalizationKeys.alertThresholdHint.tr(context),
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: AppThemeData.spacingMedium),
              // 保存按钮（全宽）
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: canEdit
                      ? () => _save(context, mapProvider)
                      : null,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined, size: 18),
                  label: Text(
                    _isSaving
                        ? MapLocalizationKeys.saving.tr(context)
                        : MapLocalizationKeys.saveButton.tr(context),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
