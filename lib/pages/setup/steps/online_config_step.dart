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
import 'package:url_launcher/url_launcher.dart';
import '../../../apps/services/app_core/database_path_service.dart';
import '../widgets/wizard_step_view.dart';

class OnlineConfigStep extends StatefulWidget {
  final VoidCallback onNext;

  const OnlineConfigStep({super.key, required this.onNext});

  @override
  State<OnlineConfigStep> createState() => _OnlineConfigStepState();
}

class _OnlineConfigStepState extends State<OnlineConfigStep> {
  final TextEditingController _tokenController = TextEditingController();
  final DatabasePathService _databaseService = DatabasePathService();
  bool _isValidating = false;
  String? _errorText;

  Future<void> _validateAndNext() async {
    final token = _tokenController.text.trim();
    if (token.isEmpty) {
      widget.onNext();
      return;
    }

    setState(() {
      _isValidating = true;
      _errorText = null;
    });

    final isValid = await _databaseService.validateToken(token);

    if (mounted) {
      setState(() => _isValidating = false);
      if (isValid) {
        await _databaseService.saveToken(token);
        widget.onNext();
      } else {
        setState(() => _errorText = '无效的 API Token，请检查后重试');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WizardStepView(
      title: '在线数据库配置',
      subtitle: '配置 API Token 后，应用可以从云端获取更详细的机场天气和详细信息。',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'AirportDB.io API Token',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _tokenController,
            decoration: InputDecoration(
              hintText: '输入您的 API Token (可选)',
              errorText: _errorText,
              prefixIcon: const Icon(Icons.vpn_key_rounded),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Theme.of(context).cardColor,
            ),
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: () => launchUrl(Uri.parse('https://airportdb.io/')),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.open_in_new_rounded,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  '点击前往 AirportDB.io 注册并获取免费 Token',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        ElevatedButton(
          onPressed: _isValidating ? null : _validateAndNext,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: _isValidating
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('下一步'),
        ),
      ],
    );
  }
}
