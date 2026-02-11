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
import '../../../core/utils/logger.dart';
import '../widgets/wizard_step_view.dart';

class LoggingStep extends StatefulWidget {
  final VoidCallback onNext;

  const LoggingStep({super.key, required this.onNext});

  @override
  State<LoggingStep> createState() => _LoggingStepState();
}

class _LoggingStepState extends State<LoggingStep> with AutomaticKeepAliveClientMixin {
  bool _loggingEnabled = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadLoggingStatus();
  }

  Future<void> _loadLoggingStatus() async {
    final enabled = await AppLogger.isFileLoggingEnabled();
    if (mounted) {
      setState(() => _loggingEnabled = enabled);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    return WizardStepView(
      title: '日志记录',
      subtitle: '启用日志记录可以帮助我们在您遇到问题时更快地进行诊断。',
      content: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.bug_report_rounded,
              size: 40,
              color: Colors.orange,
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '开启文件日志',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '日志文件将保存在程序的 logs 目录下。',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                  ),
                ],
              ),
            ),
            Switch(
              value: _loggingEnabled,
              onChanged: (value) => setState(() => _loggingEnabled = value),
            ),
          ],
        ),
      ),
      actions: [
        ElevatedButton(
          onPressed: () async {
            await AppLogger.setFileLoggingEnabled(_loggingEnabled);
            widget.onNext();
          },
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text('下一步'),
        ),
      ],
    );
  }
}
