import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/services/localization_service.dart';
import '../../../core/theme/app_theme_data.dart';
import '../../../core/widgets/common/dialog.dart';
import '../localization/flight_logs_localization_keys.dart';
import '../providers/flight_logs_provider.dart';
import 'flight_log_detail_page.dart';
import 'widgets/flight_log_list_item.dart';

class FlightLogsPage extends StatefulWidget {
  const FlightLogsPage({super.key});

  @override
  State<FlightLogsPage> createState() => _FlightLogsPageState();
}

class _FlightLogsPageState extends State<FlightLogsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<FlightLogsProvider>().refreshLogs();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FlightLogsProvider>(
      builder: (context, provider, child) {
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
          child: provider.selectedLog != null
              ? FlightLogDetailPage(
                  log: provider.selectedLog!,
                  onBack: provider.clearSelection,
                )
              : _buildMainList(context, provider),
        );
      },
    );
  }

  Widget _buildMainList(BuildContext context, FlightLogsProvider provider) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(FlightLogsLocalizationKeys.pageTitle.tr(context)),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : provider.logs.isEmpty
          ? _buildEmptyState(context)
          : _buildLogList(context, provider),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          showLoadingDialog(
            context: context,
            title: FlightLogsLocalizationKeys.importLog.tr(context),
          );
          try {
            final ok = await provider.importLog();
            if (!context.mounted) return;
            _closeDialog(context);
            if (ok) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    FlightLogsLocalizationKeys.importSuccess.tr(context),
                  ),
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    FlightLogsLocalizationKeys.notConnected.tr(context),
                  ),
                ),
              );
            }
          } catch (e) {
            if (context.mounted) {
              _closeDialog(context);
              showAdvancedConfirmDialog(
                context: context,
                title: FlightLogsLocalizationKeys.importLog.tr(context),
                content: e.toString(),
                icon: Icons.warning_amber_rounded,
                confirmColor: Colors.orange,
                confirmText: FlightLogsLocalizationKeys.cancel.tr(context),
                cancelText: '',
              );
            }
          }
        },
        icon: const Icon(Icons.file_download_outlined),
        label: Text(FlightLogsLocalizationKeys.importLog.tr(context)),
      ),
      backgroundColor: theme.scaffoldBackgroundColor,
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history_edu_outlined,
            size: 80,
            color: theme.disabledColor.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            FlightLogsLocalizationKeys.emptyTitle.tr(context),
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.disabledColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            FlightLogsLocalizationKeys.emptySubtitle.tr(context),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.disabledColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogList(BuildContext context, FlightLogsProvider provider) {
    return ListView.builder(
      padding: const EdgeInsets.all(AppThemeData.spacingMedium),
      itemCount: provider.logs.length,
      itemBuilder: (context, index) {
        final log = provider.logs[index];
        return FlightLogListItem(
          log: log,
          onTap: () async {
            showLoadingDialog(
              context: context,
              title: FlightLogsLocalizationKeys.detailTitle.tr(context),
            );
            await Future.delayed(const Duration(milliseconds: 150));
            if (!context.mounted) return;
            provider.selectLog(log);
            _closeDialog(context);
          },
          onDelete: () async {
            final confirm = await showAdvancedConfirmDialog(
              context: context,
              title: FlightLogsLocalizationKeys.deleteConfirmTitle.tr(context),
              content: FlightLogsLocalizationKeys.deleteConfirmContent.tr(
                context,
              ),
              confirmText: FlightLogsLocalizationKeys.deleteConfirm.tr(context),
              confirmColor: Colors.redAccent,
            );
            if (confirm == true) {
              await provider.deleteLog(log.id);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    FlightLogsLocalizationKeys.deleteSuccess.tr(context),
                  ),
                ),
              );
            }
          },
          onExport: () async {
            showLoadingDialog(
              context: context,
              title: FlightLogsLocalizationKeys.exportLog.tr(context),
            );
            try {
              await provider.exportLog(log);
              if (context.mounted) {
                _closeDialog(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      FlightLogsLocalizationKeys.exportSuccess.tr(context),
                    ),
                  ),
                );
              }
            } catch (e) {
              if (context.mounted) {
                _closeDialog(context);
                showAdvancedConfirmDialog(
                  context: context,
                  title: FlightLogsLocalizationKeys.exportLog.tr(context),
                  content: e.toString(),
                  icon: Icons.error_outline_rounded,
                  confirmColor: Colors.redAccent,
                  confirmText: FlightLogsLocalizationKeys.cancel.tr(context),
                  cancelText: '',
                );
              }
            }
          },
        );
      },
    );
  }

  void _closeDialog(BuildContext context) {
    final navigator = Navigator.of(context, rootNavigator: true);
    if (navigator.canPop()) {
      navigator.pop();
    }
  }
}
