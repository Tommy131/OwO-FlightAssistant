import 'package:flutter/material.dart';

class SetupGuideAutoDetectButton extends StatelessWidget {
  final bool isDetecting;
  final VoidCallback onAutoDetect;

  const SetupGuideAutoDetectButton({
    super.key,
    required this.isDetecting,
    required this.onAutoDetect,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: isDetecting ? null : onAutoDetect,
      icon: isDetecting
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.search_rounded),
      label: Text(isDetecting ? '正在自动识别中...' : '自动识别本地已安装的数据库'),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}

class SetupGuideActionBar extends StatelessWidget {
  final bool isValidating;
  final VoidCallback onComplete;

  const SetupGuideActionBar({
    super.key,
    required this.isValidating,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        if (isValidating)
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: CircularProgressIndicator(),
          ),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: onComplete,
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              '完成配置并进入应用',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }
}
