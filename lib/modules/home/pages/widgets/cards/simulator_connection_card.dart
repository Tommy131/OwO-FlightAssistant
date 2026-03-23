import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../core/services/localization_service.dart';
import '../../../../../core/theme/app_theme_data.dart';
import '../../../../../core/widgets/common/dialog.dart';
import '../../../../common/models/common_models.dart';
import '../../../../common/providers/common_provider.dart';
import '../../../localization/home_localization_keys.dart';

/// 模拟器连接状态卡片
///
/// 当已连接时显示模拟器名称及断开按钮；未连接时显示一个弹出菜单，
/// 可选择连接 X-Plane 或 MSFS，并在连接过程中显示进度对话框
class SimulatorConnectionCard extends StatelessWidget {
  const SimulatorConnectionCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<HomeProvider>();
    final isConnected = provider.isConnected;
    final simulatorType = provider.simulatorType;

    return Container(
      padding: const EdgeInsets.all(AppThemeData.spacingLarge),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppThemeData.borderRadiusMedium),
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
          // 标题行：连接状态图标 + 标签
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
                  HomeLocalizationKeys.simTitle.tr(context),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 连接状态文本
          Text(
            isConnected
                ? HomeLocalizationKeys.simConnected
                      .tr(context)
                      .replaceAll('{sim}', _getSimulatorName(simulatorType))
                : HomeLocalizationKeys.simDisconnected.tr(context),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isConnected ? Colors.green : Colors.grey,
            ),
          ),
          const Spacer(),
          const SizedBox(height: 12),
          // 操作按钮：断开 or 连接菜单
          if (isConnected)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => provider.disconnect(),
                icon: const Icon(Icons.link_off, size: 16),
                label: Text(HomeLocalizationKeys.simDisconnect.tr(context)),
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
                onSelected: (value) {
                  final type = switch (value) {
                    'xplane' => HomeSimulatorType.xplane,
                    'msfs' => HomeSimulatorType.msfs,
                    _ => HomeSimulatorType.msfs,
                  };
                  _handleConnect(context, provider, type);
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'xplane',
                    child: Row(
                      children: [
                        const Icon(Icons.airplanemode_active, size: 18),
                        const SizedBox(width: 8),
                        Text(HomeLocalizationKeys.simConnectXplane.tr(context)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'msfs',
                    child: Row(
                      children: [
                        const Icon(Icons.flight, size: 18),
                        const SizedBox(width: 8),
                        Text(HomeLocalizationKeys.simConnectMsfs.tr(context)),
                      ],
                    ),
                  ),
                ],
                child: ElevatedButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.link, size: 16),
                  label: Text(HomeLocalizationKeys.simConnect.tr(context)),
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
  }

  /// 获取模拟器显示名称
  String _getSimulatorName(HomeSimulatorType type) {
    return switch (type) {
      HomeSimulatorType.xplane => 'X-Plane 11/12',
      HomeSimulatorType.msfs => 'MSFS 2020/2024',
      HomeSimulatorType.none => 'N/A',
    };
  }

  /// 处理连接流程：弹出进度对话框、调用 provider.connect()、处理失败情况
  Future<void> _handleConnect(
    BuildContext context,
    HomeProvider provider,
    HomeSimulatorType type,
  ) async {
    final theme = Theme.of(context);
    final name = _getSimulatorName(type);

    // 显示连接进度对话框（不可关闭）
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
                  HomeLocalizationKeys.simConnectingTitle
                      .tr(context)
                      .replaceAll('{sim}', name),
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  HomeLocalizationKeys.simConnectingSubtitle.tr(context),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final success = await provider.connect(type);

    // 关闭进度对话框
    if (context.mounted) {
      Navigator.of(context).pop();
    }

    // 连接失败时弹出错误提示
    if (!success && context.mounted) {
      showAdvancedConfirmDialog(
        context: context,
        style: ConfirmDialogStyle.material,
        title: HomeLocalizationKeys.simConnectFailedTitle.tr(context),
        content:
            provider.errorMessage ??
            HomeLocalizationKeys.simConnectFailedContent.tr(context),
        icon: Icons.error_outline,
        confirmColor: Colors.red,
        confirmText: HomeLocalizationKeys.flightNumberDialogConfirm.tr(context),
        cancelText: '',
      );
    }
  }
}
