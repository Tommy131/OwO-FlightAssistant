import 'package:flutter/material.dart';

class UpdateProgressDialog extends StatefulWidget {
  final Future<bool> Function(Function(double progress) onProgress) onDownload;

  const UpdateProgressDialog({super.key, required this.onDownload});

  @override
  State<UpdateProgressDialog> createState() => _UpdateProgressDialogState();
}

class _UpdateProgressDialogState extends State<UpdateProgressDialog> {
  double _progress = 0.0;
  String _status = '正在准备下载...';
  bool _isFinished = false;
  bool _success = false;

  @override
  void initState() {
    super.initState();
    _startDownload();
  }

  Future<void> _startDownload() async {
    final success = await widget.onDownload((progress) {
      if (mounted) {
        setState(() {
          _progress = progress;
          _status = '正在下载更新包: ${(_progress * 100).toStringAsFixed(1)}%';
        });
      }
    });

    if (mounted) {
      setState(() {
        _isFinished = true;
        _success = success;
        _status = success
            ? '下载完成！\n更新包已存至: update.zip\n请关闭程序后手动解压覆盖 root 目录以完成更新。'
            : '下载失败，请检查网络后重试。';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    _isFinished
                        ? (_success
                              ? Icons.check_circle_outline
                              : Icons.error_outline)
                        : Icons.downloading_rounded,
                    color: _isFinished
                        ? (_success ? Colors.green : Colors.red)
                        : theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '更新下载',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (!_isFinished)
                LinearProgressIndicator(
                  value: _progress,
                  backgroundColor: theme.dividerColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
              const SizedBox(height: 16),
              Text(
                _status,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              if (_isFinished) ...[
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(_success),
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('确定'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
