import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../apps/providers/simulator/simulator_provider.dart';
import '../../../core/theme/app_theme_data.dart';
import '../../../core/widgets/common/dialog.dart';

class SimulatorConnectionCard extends StatelessWidget {
  const SimulatorConnectionCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
}
