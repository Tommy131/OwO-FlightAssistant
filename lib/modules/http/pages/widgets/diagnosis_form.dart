import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/localization_service.dart';
import '../../../../core/theme/app_theme_data.dart';
import '../../../common/models/common_models.dart';
import '../../../common/providers/common_provider.dart';
import '../../../http/http_module.dart';
import '../../localization/http_localization_keys.dart';

/// 连接诊断表单卡片
///
/// 一键运行四项诊断检查：
/// 1. 后端 HTTP /health 可达性
/// 2. WebSocket 端点可达性
/// 3. 模拟器连接 Token 有效性
/// 4. 模拟器状态接口响应
///
/// 结果以带 ✅/❌ 前缀的文本列表展示
class DiagnosisForm extends StatefulWidget {
  const DiagnosisForm({super.key});

  @override
  State<DiagnosisForm> createState() => _DiagnosisFormState();
}

class _DiagnosisFormState extends State<DiagnosisForm> {
  bool _isDiagnosing = false;

  /// 诊断结果消息列表，每项以 ✅ 或 ❌ 开头
  List<String> _diagnosisMessages = const [];

  /// 执行全套诊断流程并更新结果列表
  Future<void> _runDiagnosis(BuildContext context) async {
    setState(() {
      _isDiagnosing = true;
      _diagnosisMessages = const [];
    });

    final homeProvider = context.read<HomeProvider>();
    final checks = <String>[];

    try {
      // 诊断 1：后端 HTTP 连通性
      await HttpModule.client.init();
      try {
        await HttpModule.client.getHealth();
        checks.add('✅ ${HttpLocalizationKeys.diagnoseBackendOk.tr(context)}');
      } catch (e) {
        checks.add(
          '❌ ${HttpLocalizationKeys.diagnoseBackendFail.tr(context)}: $e',
        );
      }

      // 诊断 2：WebSocket 端点连通性
      try {
        await HttpModule.client.getSimulatorWebSocketInfo();
        checks.add('✅ ${HttpLocalizationKeys.diagnoseWsOk.tr(context)}');
      } catch (e) {
        checks.add('❌ ${HttpLocalizationKeys.diagnoseWsFail.tr(context)}: $e');
      }

      // 诊断 3：Token / 模拟器连接状态
      if (homeProvider.isConnected) {
        checks.add('✅ ${HttpLocalizationKeys.diagnoseTokenOk.tr(context)}');
      } else {
        checks.add('❌ ${HttpLocalizationKeys.diagnoseTokenFail.tr(context)}');
      }

      // 诊断 4：模拟器状态接口
      final simulatorType = _resolveSimulatorType(homeProvider);
      try {
        await HttpModule.client.getSimulatorState(type: simulatorType);
        checks.add(
          '✅ ${HttpLocalizationKeys.diagnoseSimulatorOk.tr(context)}',
        );
      } catch (e) {
        checks.add(
          '❌ ${HttpLocalizationKeys.diagnoseSimulatorFail.tr(context)}: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDiagnosing = false;
          _diagnosisMessages = checks;
        });
      }
    }
  }

  /// 将 HomeSimulatorType 枚举转换为 API 参数字符串
  String _resolveSimulatorType(HomeProvider provider) {
    return switch (provider.simulatorType) {
      HomeSimulatorType.msfs => 'msfs',
      HomeSimulatorType.xplane => 'xplane',
      HomeSimulatorType.none => 'xplane',
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppThemeData.spacingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 区块标题 + 描述
            Text(
              HttpLocalizationKeys.diagnoseSectionTitle.tr(context),
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              HttpLocalizationKeys.diagnoseSectionDescription.tr(context),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: AppThemeData.spacingMedium),

            // 一键诊断按钮
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isDiagnosing
                    ? null
                    : () => _runDiagnosis(context),
                icon: _isDiagnosing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.medical_information_outlined, size: 18),
                label: Text(
                  _isDiagnosing
                      ? HttpLocalizationKeys.testing.tr(context)
                      : HttpLocalizationKeys.runDiagnosis.tr(context),
                ),
              ),
            ),

            // 诊断结果列表
            if (_diagnosisMessages.isNotEmpty) ...[
              const SizedBox(height: AppThemeData.spacingMedium),
              ..._diagnosisMessages.map(
                (message) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(message, style: theme.textTheme.bodySmall),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
