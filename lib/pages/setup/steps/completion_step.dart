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

import 'package:flutter/material.dart';
import '../../../core/services/persistence/app_storage_paths.dart';
import '../widgets/wizard_step_view.dart';

class CompletionStep extends StatelessWidget {
  final VoidCallback onFinish;

  const CompletionStep({super.key, required this.onFinish});

  @override
  Widget build(BuildContext context) {
    return WizardStepView(
      title: '配置完成！',
      subtitle: '感谢您的配合，现在您可以开始您的飞行之旅了。',
      content: Column(
        children: [
          const Icon(
            Icons.check_circle_rounded,
            size: 100,
            color: Colors.green,
          ),
          const SizedBox(height: 32),
          const Text(
            '所有设置已就绪',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          FutureBuilder(
            future: AppStoragePaths.getBaseDirectory(),
            builder: (context, snapshot) {
              final path = snapshot.data?.path ?? '正在获取...';
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
                ),
                child: Column(
                  children: [
                    const Text(
                      '数据存储路径 (便携模式)：',
                      style: TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      path,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: Colors.blueAccent,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      actions: [
        ElevatedButtonGradient.withGradient(
          onPressed: onFinish,
          gradient: const LinearGradient(
            colors: [Color(0xFF00F5FF), Color(0xFF7B2FFF)],
          ),
          child: const Text(
            '进入应用',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

class ElevatedButtonGradient {
  static Widget withGradient({
    required VoidCallback onPressed,
    required Gradient gradient,
    required Widget child,
    ButtonStyle? style,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: gradient.colors.first.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: (style ?? ElevatedButton.styleFrom()).copyWith(
          backgroundColor: WidgetStateProperty.all(Colors.transparent),
          shadowColor: WidgetStateProperty.all(Colors.transparent),
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        child: child,
      ),
    );
  }
}
