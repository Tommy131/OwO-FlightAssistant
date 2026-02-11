/*
 *        _____   _          __  _____   _____   _       _____   _____
 *      /  _  \ | |        / / /  _  \ |  _  \ | |     /  _  \ /  ___|
 *      | | | | | |  __   / /  | | | | | |_| | | |     | | | | | |
 *      | | | | | | /  | / /   | | | | |  _  { | |     | | | | | |   _
 *      | |_| | | |/   |/ /    | |_| | | |_| | | |___  | |_| | | |_| |
 *      \_____/ |___/|___/     \_____/ |_____/ |_____| \_____/ \_____/
 *
 *  Copyright (c) 2023 by OwOTeam-DGMT (OwOBlog).
 * @Date         : 2025-10-22
 * @Author       : HanskiJay
 * @LastEditors  : HanskiJay
 * @LastEditTime : 2025-10-22
 * @E-Mail       : support@owoblog.com
 * @Telegram     : https://t.me/HanskiJay
 * @GitHub       : https://github.com/Tommy131
 */
import 'dart:io';
import 'package:flutter/material.dart';

import '../../../../../core/services/persistence/persistence_service.dart';
import '../../../../../core/widgets/common/dialog.dart';
import '../common/card_header.dart';

class TroubleshootingCard extends StatelessWidget {
  const TroubleshootingCard({super.key});

  Future<void> _handleReset(BuildContext context) async {
    final firstConfirm = await showAdvancedConfirmDialog(
      context: context,
      title: '重置应用',
      content: '确定要重置应用吗？这将删除所有配置并重新开始引导流程。',
      icon: Icons.warning_amber_rounded,
      confirmText: '确定',
      cancelText: '取消',
      confirmColor: Colors.red,
    );

    if (firstConfirm != true) return;

    if (!context.mounted) return;

    final secondConfirm = await showAdvancedConfirmDialog(
      context: context,
      title: '最后确认',
      content: '此操作不可撤销！点击“确认重置”后，应用将清除所有数据并退出。',
      icon: Icons.dangerous_rounded,
      confirmText: '确认重置',
      cancelText: '点错了',
      confirmColor: Colors.red.shade900,
    );

    if (secondConfirm != true) return;

    // 执行重置逻辑
    await PersistenceService().resetApp();

    // 退出应用以重新加载
    exit(0);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CardHeader(icon: Icons.build_rounded, title: '故障排除'),
            const Divider(height: 24),
            Text(
              '如果您遇到了无法解决的问题，可以尝试重置应用。这会删除所有本地设置和路径配置。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _handleReset(context),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('重置应用并重新引导'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: BorderSide(color: Colors.red.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
