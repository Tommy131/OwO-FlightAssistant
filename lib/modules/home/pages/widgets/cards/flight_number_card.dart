import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../core/services/localization_service.dart';
import '../../../../../core/theme/app_theme_data.dart';
import '../../../../../core/widgets/common/dialog.dart';
import '../../../../common/providers/common_provider.dart';
import '../../../localization/home_localization_keys.dart';

/// 航班号卡片，展示当前航班号并提供设置/编辑功能
///
/// 编辑时会先展示确认对话框（若已存在航班号），再通过输入框更新
class FlightNumberCard extends StatelessWidget {
  const FlightNumberCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<HomeProvider>();

    return Container(
      padding: const EdgeInsets.all(AppThemeData.spacingMedium),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppThemeData.borderRadiusMedium),
        border: Border.all(
          color: AppThemeData.getBorderColor(theme).withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // 航班号图标
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(
                AppThemeData.borderRadiusSmall,
              ),
            ),
            child: Icon(
              Icons.confirmation_number_outlined,
              color: theme.colorScheme.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: AppThemeData.spacingMedium),
          // 航班号标签与数值
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  HomeLocalizationKeys.flightNumberTitle.tr(context),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  provider.hasFlightNumber
                      ? provider.flightNumber!
                      : HomeLocalizationKeys.flightNumberEmpty.tr(context),
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
          // 编辑按钮
          ElevatedButton.icon(
            onPressed: () => _showEditDialog(context, provider),
            icon: const Icon(Icons.edit_note_rounded, size: 18),
            label: Text(
              provider.hasFlightNumber
                  ? HomeLocalizationKeys.flightNumberEdit.tr(context)
                  : HomeLocalizationKeys.flightNumberSet.tr(context),
            ),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 弹出航班号编辑对话框
  ///
  /// 若已有航班号则先显示确认对话框，确认后显示输入框；
  /// 输入内容经格式校验（ICAO 航班号格式）后写入 provider
  Future<void> _showEditDialog(
    BuildContext context,
    HomeProvider provider,
  ) async {
    final controller = TextEditingController(text: provider.flightNumber);

    // 已有航班号时需二次确认
    if (provider.hasFlightNumber) {
      final confirm = await showAdvancedConfirmDialog(
        context: context,
        title: HomeLocalizationKeys.flightNumberDialogEditTitle.tr(context),
        content: HomeLocalizationKeys.flightNumberDialogEditContent
            .tr(context)
            .replaceAll('{number}', provider.flightNumber ?? ''),
        icon: Icons.info_outline_rounded,
        confirmText: HomeLocalizationKeys.flightNumberDialogContinue.tr(
          context,
        ),
        cancelText: HomeLocalizationKeys.flightNumberDialogCancel.tr(context),
      );
      if (confirm != true) return;
    }

    if (!context.mounted) return;

    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        final formKey = GlobalKey<FormState>();
        return AlertDialog(
          title: Text(HomeLocalizationKeys.flightNumberDialogTitle.tr(context)),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(HomeLocalizationKeys.flightNumberDialogHint.tr(context)),
                Text(
                  HomeLocalizationKeys.flightNumberDialogFormat.tr(context),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: controller,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: HomeLocalizationKeys.flightNumberDialogInputHint
                        .tr(context),
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.flight_outlined),
                  ),
                  textCapitalization: TextCapitalization.characters,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return null;
                    if (!RegExp(
                      r'^[A-Z]{2,3}\d{1,4}[A-Z]?$',
                    ).hasMatch(value.trim().toUpperCase())) {
                      return HomeLocalizationKeys.flightNumberDialogInvalid.tr(
                        context,
                      );
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                HomeLocalizationKeys.flightNumberDialogCancel.tr(context),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(context, controller.text.trim());
                }
              },
              child: Text(
                HomeLocalizationKeys.flightNumberDialogConfirm.tr(context),
              ),
            ),
          ],
        );
      },
    );

    if (result != null) {
      await provider.setFlightNumber(result.isEmpty ? null : result);
    }
  }
}
