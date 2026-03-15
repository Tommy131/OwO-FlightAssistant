import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/localization/localization_keys.dart';
import '../../../../core/services/localization_service.dart';
import '../../../../core/theme/app_theme_data.dart';
import '../../../../core/widgets/common/snack_bar.dart';
import '../../../../core/widgets/common/dialog.dart';
import '../../localization/briefing_localization_keys.dart';
import '../../providers/briefing_provider.dart';

class BriefingHistoryPage extends StatefulWidget {
  final VoidCallback onBack;

  const BriefingHistoryPage({super.key, required this.onBack});

  @override
  State<BriefingHistoryPage> createState() => _BriefingHistoryPageState();
}

class _BriefingHistoryPageState extends State<BriefingHistoryPage> {
  final Set<String> _expandedRecordIds = <String>{};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(BriefingLocalizationKeys.historyTitle.tr(context)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: widget.onBack,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: BriefingLocalizationKeys.refresh.tr(context),
            onPressed: () async {
              final provider = context.read<BriefingProvider>();
              try {
                final count = await provider.reloadFromDirectory();
                if (count > 0) {
                  final message = BriefingLocalizationKeys.refreshSuccess
                      .tr(context)
                      .replaceAll('{}', count.toString());
                  SnackBarHelper.showSuccess(context, message);
                } else {
                  SnackBarHelper.showWarning(
                    context,
                    BriefingLocalizationKeys.refreshEmpty.tr(context),
                  );
                }
              } catch (_) {
                SnackBarHelper.showError(
                  context,
                  BriefingLocalizationKeys.refreshFailed.tr(context),
                );
              }
            },
          ),
          const SizedBox(width: AppThemeData.spacingMedium),
        ],
      ),
      body: Consumer<BriefingProvider>(
        builder: (context, provider, child) {
          if (provider.history.isEmpty) {
            return Center(
              child: Text(
                BriefingLocalizationKeys.historyEmpty.tr(context),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.hintColor,
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(AppThemeData.spacingMedium),
            itemCount: provider.history.length,
            itemBuilder: (context, index) {
              final record = provider.history[index];
              final recordId =
                  '${record.createdAt.millisecondsSinceEpoch}-${record.title}';
              final isExpanded = _expandedRecordIds.contains(recordId);
              final summary = _buildSummary(record);
              return Card(
                margin: const EdgeInsets.only(
                  bottom: AppThemeData.spacingSmall,
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    setState(() {
                      if (isExpanded) {
                        _expandedRecordIds.remove(recordId);
                      } else {
                        _expandedRecordIds.add(recordId);
                      }
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(AppThemeData.spacingMedium),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                record.title,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Icon(
                              isExpanded
                                  ? Icons.keyboard_arrow_up_rounded
                                  : Icons.keyboard_arrow_down_rounded,
                            ),
                            IconButton(
                              tooltip: BriefingLocalizationKeys.deleteAction.tr(
                                context,
                              ),
                              onPressed: () async {
                                final confirmed =
                                    await showAdvancedConfirmDialog(
                                      context: context,
                                      title: BriefingLocalizationKeys
                                          .deleteConfirmTitle
                                          .tr(context),
                                      content: BriefingLocalizationKeys
                                          .deleteConfirmContent
                                          .tr(context),
                                      icon: Icons.delete_outline,
                                      confirmColor: Colors.redAccent,
                                      confirmText: LocalizationKeys.confirm.tr(
                                        context,
                                      ),
                                      cancelText: LocalizationKeys.cancel.tr(
                                        context,
                                      ),
                                    );
                                if (confirmed != true || !context.mounted) {
                                  return;
                                }
                                final ok = await context
                                    .read<BriefingProvider>()
                                    .deleteBriefing(record);
                                if (!context.mounted) return;
                                if (ok) {
                                  _expandedRecordIds.remove(recordId);
                                  SnackBarHelper.showSuccess(
                                    context,
                                    BriefingLocalizationKeys.deleteSuccess.tr(
                                      context,
                                    ),
                                  );
                                } else {
                                  SnackBarHelper.showError(
                                    context,
                                    BriefingLocalizationKeys.deleteFailed.tr(
                                      context,
                                    ),
                                  );
                                }
                              },
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.redAccent,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          summary,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.hintColor,
                          ),
                        ),
                        if (isExpanded) ...[
                          const SizedBox(height: 8),
                          Text(
                            record.content,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontFamily: 'Monospace',
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _buildSummary(BriefingRecord record) {
    final lines = record.content.split('\n');
    String flightNumber = '--';
    String generatedAt = record.createdAt.toLocal().toString();
    for (final line in lines) {
      final separator = line.indexOf(':');
      if (separator <= 0) continue;
      final key = line.substring(0, separator).trim();
      final value = line.substring(separator + 1).trim();
      if (key == 'FLT' && value.isNotEmpty) {
        flightNumber = value;
      } else if (key == 'GEN' && value.isNotEmpty) {
        generatedAt = value;
      }
    }
    return '✈ $flightNumber  ·  🕒 $generatedAt';
  }
}
