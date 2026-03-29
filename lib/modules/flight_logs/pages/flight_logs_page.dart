import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/services/back_handler_service.dart';
import '../../../core/services/localization_service.dart';
import '../../../core/theme/app_theme_data.dart';
import '../../../core/widgets/common/dialog.dart';
import '../../common/providers/common_provider.dart';
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
    BackHandlerService().register(_onBack);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<FlightLogsProvider>().refreshLogs();
    });
  }

  @override
  void dispose() {
    BackHandlerService().unregister(_onBack);
    super.dispose();
  }

  bool _onBack() {
    if (!mounted) return false;
    final provider = context.read<FlightLogsProvider>();
    if (provider.selectedLog != null) {
      provider.clearSelection();
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<FlightLogsProvider, HomeProvider>(
      builder: (context, provider, commonProvider, child) {
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
              : _buildMainList(context, provider, commonProvider),
        );
      },
    );
  }

  Widget _buildMainList(
    BuildContext context,
    FlightLogsProvider provider,
    HomeProvider commonProvider,
  ) {
    final theme = Theme.of(context);
    return Scaffold(
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : provider.logs.isEmpty
          ? _buildEmptyState(context)
          : _buildLogList(context, provider),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (commonProvider.isConnected)
            FloatingActionButton.extended(
              heroTag: 'flight_log_record_fab',
              onPressed: () =>
                  _handleToggleRecording(context, provider, commonProvider),
              backgroundColor: provider.isRecording ? Colors.red : null,
              icon: Icon(
                provider.isRecording
                    ? Icons.stop_circle_outlined
                    : Icons.fiber_manual_record,
              ),
              label: Text(
                provider.isRecording
                    ? provider.isRecordingPaused
                          ? '${FlightLogsLocalizationKeys.stopRecord.tr(context)} (PAUSED)'
                          : FlightLogsLocalizationKeys.stopRecord.tr(context)
                    : FlightLogsLocalizationKeys.startRecord.tr(context),
              ),
            ),
          if (commonProvider.isConnected)
            const SizedBox(height: AppThemeData.spacingSmall),
          FloatingActionButton.extended(
            heroTag: 'flight_log_import_fab',
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
        ],
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

  Future<void> _handleToggleRecording(
    BuildContext context,
    FlightLogsProvider provider,
    HomeProvider commonProvider,
  ) async {
    if (provider.isRecording) {
      final saved = await provider.stopRecording(commonProvider.snapshot);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            saved
                ? FlightLogsLocalizationKeys.stopRecordSaved.tr(context)
                : FlightLogsLocalizationKeys.stopRecordDiscarded.tr(context),
          ),
        ),
      );
      return;
    }
    final started = provider.startRecording(
      snapshot: commonProvider.snapshot,
      flightNumber: commonProvider.flightNumber,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          started
              ? FlightLogsLocalizationKeys.startRecordStarted.tr(context)
              : FlightLogsLocalizationKeys.notConnected.tr(context),
        ),
      ),
    );
  }
}
