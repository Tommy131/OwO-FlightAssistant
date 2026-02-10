import 'package:flutter/material.dart';
import '../../apps/models/flight_log.dart';
import '../../apps/services/flight_log_service.dart';
import 'flight_log_detail_page.dart';
import 'widgets/flight_log_list_item.dart';
import '../../core/theme/app_theme_data.dart';
import '../../core/widgets/common/dialog.dart';

class FlightLogsPage extends StatefulWidget {
  const FlightLogsPage({super.key});

  @override
  State<FlightLogsPage> createState() => _FlightLogsPageState();
}

class _FlightLogsPageState extends State<FlightLogsPage> {
  final FlightLogService _logService = FlightLogService();
  List<FlightLog>? _logs;
  bool _isLoading = true;
  FlightLog? _selectedLog;

  @override
  void initState() {
    super.initState();
    _loadLogs();
    _logService.addListener(_loadLogs);
  }

  @override
  void dispose() {
    _logService.removeListener(_loadLogs);
    super.dispose();
  }

  Future<void> _loadLogs() async {
    final logs = await _logService.getLogs();
    if (mounted) {
      setState(() {
        _logs = logs;
        _isLoading = false;
        // 如果当前选中的日志被删除了，重置状态
        if (_selectedLog != null) {
          final exists = logs.any((l) => l.id == _selectedLog!.id);
          if (!exists) {
            _selectedLog = null;
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.05, 0),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: _selectedLog != null
          ? FlightLogDetailPage(
              log: _selectedLog!,
              onBack: () => setState(() => _selectedLog = null),
            )
          : _buildMainList(),
    );
  }

  Widget _buildMainList() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('飞行日志'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _logs == null || _logs!.isEmpty
          ? _buildEmptyState()
          : _buildLogList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          showLoadingDialog(context: context, message: '正在导入飞行日志...');
          try {
            final success = await _logService.importLog();
            if (mounted) hideLoadingDialog(context);

            if (success) {
              if (mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('导入飞行日志成功')));
              }
            } else {
              if (mounted) {
                showAdvancedConfirmDialog(
                  context: context,
                  title: '导入失败',
                  content: '未能识别或导入该飞行日志文件，请检查文件格式。',
                  icon: Icons.error_outline_rounded,
                  confirmColor: Colors.redAccent,
                  confirmText: '好的',
                  cancelText: '',
                );
              }
            }
          } catch (e) {
            if (mounted) {
              hideLoadingDialog(context);
              showAdvancedConfirmDialog(
                context: context,
                title: '导入异常',
                content: '导入过程中发生错误：$e',
                icon: Icons.warning_amber_rounded,
                confirmColor: Colors.orange,
                confirmText: '确定',
                cancelText: '',
              );
            }
          }
        },
        icon: const Icon(Icons.file_download_outlined),
        label: const Text('导入日志'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history_edu_outlined,
            size: 80,
            color: Theme.of(context).disabledColor.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            '尚未记录任何飞行日志',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Theme.of(context).disabledColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '连接模拟器并开始录制，即可在这里看到您的飞行记录',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).disabledColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogList() {
    return ListView.builder(
      padding: const EdgeInsets.all(AppThemeData.spacingMedium),
      itemCount: _logs!.length,
      itemBuilder: (context, index) {
        final log = _logs![index];
        return FlightLogListItem(
          log: log,
          onTap: () async {
            // 显示加载弹窗，给予用户反馈
            showLoadingDialog(context: context, message: '正在读取飞行数据...');

            // 给 UI 线程一点时间渲染弹窗
            await Future.delayed(const Duration(milliseconds: 150));

            if (mounted) {
              setState(() {
                _selectedLog = log;
              });
              // 在状态更新（昂贵的构建任务开始前）后尝试关闭此时还没被阻塞的任务，
              // 或者在构建完成后（Navigator.pop 是异步排队的）关闭。
              hideLoadingDialog(context);
            }
          },
          onDelete: () async {
            final confirm = await showAdvancedConfirmDialog(
              context: context,
              title: '删除飞行日志',
              content: '确定要删除这条飞行记录吗？此操作不可撤销。',
              confirmText: '删除',
              confirmColor: Colors.redAccent,
            );
            if (confirm == true) {
              await _logService.deleteLog(log.id);
            }
          },
          onExport: () async {
            showLoadingDialog(context: context, message: '正在准备导出...');
            try {
              await _logService.exportLog(log);
              if (mounted) hideLoadingDialog(context);
            } catch (e) {
              if (mounted) {
                hideLoadingDialog(context);
                showAdvancedConfirmDialog(
                  context: context,
                  title: '导出失败',
                  content: '导出飞行日志时发生错误：$e',
                  icon: Icons.error_outline_rounded,
                  confirmColor: Colors.redAccent,
                  confirmText: '确定',
                  cancelText: '',
                );
              }
            }
          },
        );
      },
    );
  }
}
