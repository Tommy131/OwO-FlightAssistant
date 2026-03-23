import 'package:flutter/material.dart';
import '../../../../core/services/localization_service.dart';
import '../../../../core/theme/app_theme_data.dart';
import '../../localization/monitor_localization_keys.dart';
import '../../models/monitor_data.dart';
import 'systems_status_row.dart';

/// 飞行系统状态卡片组件
///
/// 以卡片形式展示各飞机系统的当前状态，包括：
/// - 停机刹车（Parking Brake）
/// - 应答机（Transponder）
/// - 襟翼（Flaps）
/// - 减速板（Speed Brake）
/// - 火警警告（Fire Warning，仅在任一火警激活时显示）
///
/// 每一行状态由 [SystemsStatusRow] 渲染，告警项以高亮颜色区分。
class SystemsStatusCard extends StatelessWidget {
  /// 当前飞行数据快照
  final MonitorData data;

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
          // 卡片标题
          Text(
            MonitorLocalizationKeys.systemsTitle.tr(context),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 16),

          // 停机刹车状态：刹车启用时橙色高亮
          SystemsStatusRow(
            label: MonitorLocalizationKeys.parkingBrakeLabel.tr(context),
            value: data.parkingBrake == true
                ? MonitorLocalizationKeys.parkingBrakeSet.tr(context)
                : MonitorLocalizationKeys.parkingBrakeReleased.tr(context),
            isHighlight: data.parkingBrake == true,
            highlightColor: Colors.orangeAccent,
          ),
          const Divider(height: 20),

          // 应答机状态：特殊编码（7500/7600/7700）时高亮
          SystemsStatusRow(
            label: MonitorLocalizationKeys.transponderLabel.tr(context),
            value: _buildTransponderValue(context),
            isHighlight: _isTransponderHighlighted(),
            highlightColor: _getTransponderColor(data.transponderCode),
          ),
          const Divider(height: 20),

          // 襟翼状态：襟翼展开超过 5% 时蓝色高亮
          SystemsStatusRow(
            label: MonitorLocalizationKeys.flapsLabel.tr(context),
            value:
                data.flapsLabel ?? MonitorLocalizationKeys.flapsUp.tr(context),
            isHighlight: (data.flapsDeployRatio ?? 0) > 0.05,
            highlightColor: Colors.blueAccent,
          ),
          const Divider(height: 20),

          // 减速板状态：展开时橙色高亮
          SystemsStatusRow(
            label: MonitorLocalizationKeys.speedBrakeLabel.tr(context),
            value: data.speedBrakeLabel ??
                MonitorLocalizationKeys.speedBrakeUnknown.tr(context),
            isHighlight: data.speedBrake == true,
            highlightColor: Colors.orangeAccent,
          ),

          // 火警警告：仅在任一火警激活时显示，红色高亮
          if (data.fireWarningEngine1 == true ||
              data.fireWarningEngine2 == true ||
              data.fireWarningAPU == true) ...[
            const Divider(height: 20),
            SystemsStatusRow(
              label: MonitorLocalizationKeys.fireLabel.tr(context),
              value: _buildFireWarningValue(context),
              isHighlight: true,
              highlightColor: Colors.redAccent,
            ),
          ],
        ],
      ),
    );
  }

  // ── 应答机数值与高亮逻辑 ─────────────────────────────────────────────────

  /// 构建应答机显示值
  ///
  /// 优先显示编码，其次显示状态文字，否则显示 N/A
  String _buildTransponderValue(BuildContext context) {
    final code = data.transponderCode;
    final state = data.transponderState;
    if (code != null && code.isNotEmpty) return code;
    if (state != null && state.isNotEmpty) return state;
    return MonitorLocalizationKeys.transponderEmpty.tr(context);
  }

  /// 判断应答机是否需要高亮显示
  ///
  /// 特殊紧急编码（7500/7600/7700）或存在状态文字时高亮
  bool _isTransponderHighlighted() {
    final code = data.transponderCode;
    final state = data.transponderState;
    return _isSpecialTransponder(code) || (state != null && state.isNotEmpty);
  }

  /// 判断应答机编码是否为紧急编码
  bool _isSpecialTransponder(String? code) {
    if (code == null) return false;
    return code == '7700' || code == '7600' || code == '7500';
  }

  /// 根据应答机编码返回对应的告警颜色
  ///
  /// - 7700（通用紧急）：红色
  /// - 7600（无线电失效）：橙色
  /// - 7500（劫持）：紫色
  /// - 其他：蓝色（正常信息色）
  Color _getTransponderColor(String? code) {
    if (code == null) return Colors.blueAccent;
    switch (code) {
      case '7700':
        return Colors.redAccent;
      case '7600':
        return Colors.orangeAccent;
      case '7500':
        return Colors.purpleAccent;
      default:
        return Colors.blueAccent;
    }
  }

  // ── 火警数值构建 ────────────────────────────────────────────────────────

  /// 构建火警位置列表文字（如 "ENG1 ENG2 FIRE"）
  String _buildFireWarningValue(BuildContext context) {
    final labels = <String>[];
    if (data.fireWarningEngine1 == true) {
      labels.add(MonitorLocalizationKeys.fireEngine1.tr(context));
    }
    if (data.fireWarningEngine2 == true) {
      labels.add(MonitorLocalizationKeys.fireEngine2.tr(context));
    }
    if (data.fireWarningAPU == true) {
      labels.add(MonitorLocalizationKeys.fireApu.tr(context));
    }
    final suffix = MonitorLocalizationKeys.fireSuffix.tr(context);
    return '${labels.join(' ')} $suffix';
  }
}
