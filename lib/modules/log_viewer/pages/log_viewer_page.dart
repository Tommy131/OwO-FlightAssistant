import 'package:flutter/material.dart';
import '../../../core/theme/app_theme_data.dart';
import '../../../core/services/localization_service.dart';
import '../localization/log_viewer_localization_keys.dart';
import '../services/log_viewer_service.dart';
import '../../../core/widgets/common/snack_bar.dart';

class LogViewerPage extends StatefulWidget {
  const LogViewerPage({super.key});

  @override
  State<LogViewerPage> createState() => _LogViewerPageState();
}

class _LogViewerPageState extends State<LogViewerPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _scrollController1 = ScrollController();
  final ScrollController _scrollController2 = ScrollController();

  List<LogEntry> _appLogs = [];
  List<LogEntry> _errorLogs = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _refreshLogs();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController1.dispose();
    _scrollController2.dispose();
    super.dispose();
  }

  Future<void> _refreshLogs() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final appLogs = await LogViewerService.readLogs('app.log');
      final errorLogs = await LogViewerService.readLogs('error.log');

      if (mounted) {
        setState(() {
          _appLogs = appLogs;
          _errorLogs = errorLogs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        SnackBarHelper.showError(context, 'Failed to refresh logs: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(LogViewerLocalizationKeys.pageTitle.tr(context)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _refreshLogs,
            tooltip: LogViewerLocalizationKeys.refresh.tr(context),
          ),
          const SizedBox(width: 16),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: LogViewerLocalizationKeys.allLogs.tr(context)),
            Tab(text: LogViewerLocalizationKeys.errorLogs.tr(context)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildLogList(_appLogs, _scrollController1),
          _buildLogList(_errorLogs, _scrollController2),
        ],
      ),
    );
  }

  Widget _buildLogList(List<LogEntry> logs, ScrollController scrollController) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (logs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notes, size: 48, color: Theme.of(context).disabledColor),
            const SizedBox(height: 16),
            Text(
              LogViewerLocalizationKeys.emptyLogs.tr(context),
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).disabledColor,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: scrollController,
      itemCount: logs.length,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemBuilder: (context, index) {
        final entry = logs[index];
        return _buildLogItem(entry);
      },
    );
  }

  Widget _buildLogItem(LogEntry entry) {
    final theme = Theme.of(context);

    // Determine color based on log level
    Color levelColor;
    IconData icon;

    final level = entry.level.toUpperCase();
    if (level.contains('ERROR')) {
      levelColor = theme.colorScheme.error;
      icon = Icons.error_outline;
    } else if (level.contains('WARN')) {
      levelColor = Colors.orange;
      icon = Icons.warning_amber_outlined;
    } else if (level.contains('DEBUG')) {
      levelColor = Colors.blueGrey;
      icon = Icons.bug_report_outlined;
    } else {
      levelColor = theme.colorScheme.primary;
      icon = Icons.info_outline;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppThemeData.borderRadiusSmall),
        border: Border.all(
          color: levelColor.withValues(alpha: 0.2),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: levelColor.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppThemeData.borderRadiusSmall),
                topRight: Radius.circular(AppThemeData.borderRadiusSmall),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: levelColor, size: 14),
                const SizedBox(width: 6),
                Text(
                  level,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: levelColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (entry.timestamp.isNotEmpty) ...[
                  const Spacer(),
                  Text(
                    entry.timestamp,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.disabledColor,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: SelectableText(
              entry.message,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                fontSize: 12,
                color: theme.colorScheme.onSurface,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
