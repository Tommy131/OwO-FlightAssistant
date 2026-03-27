import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../module_registry/update/update_config.dart';
import '../services/update_service.dart';
import '../services/localization_service.dart';
import '../widgets/common/snack_bar.dart';
import '../widgets/common/dialog.dart';
import '../localization/localization_keys.dart';
import '../utils/logger.dart';

enum _UpdateDialogAction { cancel, openReleasePage, download }

/// 更新检测UI辅助类
class UpdateChecker {
  /// 执行更新检测并显示UI反馈
  ///
  /// [context] - BuildContext用于显示对话框和SnackBar
  /// [showLoadingSnackBar] - 是否显示"正在检查更新"的SnackBar
  /// [showNoUpdateSnackBar] - 当没有更新时是否显示SnackBar
  static Future<void> checkAndShowUpdate(
    BuildContext context, {
    bool showLoadingSnackBar = true,
    bool showNoUpdateSnackBar = true,
  }) async {
    if (!context.mounted) return;

    // 检查是否已配置更新服务
    if (!UpdateConfig.isConfigured) {
      // 未配置更新服务
      if (kDebugMode) {
        // Debug模式：显示提示对话框
        _showConfigurationWarning(context);
      } else {
        // Release模式：静默，什么也不做
        AppLogger.info('Update service not configured, skipping update check');
      }
      return;
    }

    // 显示检查中提示
    if (showLoadingSnackBar) {
      try {
        SnackBarHelper.showInfo(
          context,
          LocalizationKeys.checkingForUpdates.tr(context),
        );
      } catch (e) {
        AppLogger.warning('Failed to show SnackBar: $e');
      }
    }

    try {
      // 执行更新检测
      final result = await UpdateService().checkForUpdates();

      if (!context.mounted) return;

      // 处理检测结果
      if (result.isError) {
        // 静默处理错误，只记录日志，不显示给用户（自动检测时）
        if (showLoadingSnackBar) {
          // 只有手动检测时才显示错误
          _handleError(context, result.error!);
        } else {
          AppLogger.info(
            'Automatic update check failed (silent): ${result.error}',
          );
        }
      } else if (result.hasUpdate && result.versionInfo != null) {
        _showUpdateDialog(context, result);
      } else {
        if (showNoUpdateSnackBar) {
          try {
            SnackBarHelper.showSuccess(
              context,
              LocalizationKeys.alreadyLatestVersion.tr(context),
            );
          } catch (e) {
            AppLogger.warning('Failed to show SnackBar: $e');
          }
        }
      }
    } catch (e, stackTrace) {
      AppLogger.error('Update check exception', e, stackTrace);
      if (context.mounted && showLoadingSnackBar) {
        // 只有手动检测时才显示错误
        try {
          SnackBarHelper.showError(
            context,
            '${LocalizationKeys.updateCheckFailed.tr(context)}: $e',
          );
        } catch (snackBarError) {
          AppLogger.warning('Failed to show error SnackBar: $snackBarError');
        }
      }
    }
  }

  /// 显示配置警告对话框（仅Debug模式）
  static Future<void> _showConfigurationWarning(BuildContext context) async {
    await showAdvancedConfirmDialog(
      context: context,
      title: '更新服务未配置',
      content:
          '检测到更新服务尚未配置。\n\n'
          '请在 modules_register_entry.dart 中调用 UpdateConfig.setCustomConfig() 配置更新检测API地址。\n\n'
          '参考示例：lib/modules/example_module/update_config_example.dart\n\n'
          '注意：此提示仅在Debug模式下显示。',
      icon: Icons.warning_amber_rounded,
      confirmColor: Colors.orange,
      confirmText: '我知道了',
      cancelText: '',
    );
  }

  /// 处理错误情况
  static void _handleError(BuildContext context, String error) {
    if (error == 'timeout') {
      SnackBarHelper.showWarning(
        context,
        LocalizationKeys.updateCheckTimeout.tr(context),
      );
    } else {
      SnackBarHelper.showError(
        context,
        '${LocalizationKeys.updateCheckFailed.tr(context)}: $error',
      );
    }
  }

  /// 显示更新对话框
  static Future<void> _showUpdateDialog(
    BuildContext context,
    UpdateCheckResult result,
  ) async {
    final versionInfo = result.versionInfo!;
    final action = await showDialog<_UpdateDialogAction>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final hasDownload = versionInfo.downloadUrl.isNotEmpty;
        final hasReleasePage = versionInfo.releasePageUrl.isNotEmpty;

        return AlertDialog(
          icon: Icon(
            Icons.system_update_outlined,
            color: theme.colorScheme.primary,
          ),
          title: Text(LocalizationKeys.updateAvailable.tr(dialogContext)),
          content: SingleChildScrollView(
            child: Text(_buildUpdateContent(dialogContext, result)),
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(_UpdateDialogAction.cancel),
              child: Text(LocalizationKeys.cancel.tr(dialogContext)),
            ),
            if (hasReleasePage)
              TextButton(
                onPressed: () => Navigator.of(
                  dialogContext,
                ).pop(_UpdateDialogAction.openReleasePage),
                child: Text(LocalizationKeys.viewReleasePage.tr(dialogContext)),
              ),
            if (hasDownload)
              FilledButton(
                onPressed: () => Navigator.of(
                  dialogContext,
                ).pop(_UpdateDialogAction.download),
                child: Text(LocalizationKeys.downloadUpdate.tr(dialogContext)),
              ),
          ],
        );
      },
    );

    if (!context.mounted) {
      return;
    }

    if (action == _UpdateDialogAction.download &&
        versionInfo.downloadUrl.isNotEmpty) {
      await _openExternalUrl(
        context,
        versionInfo.downloadUrl,
        failureMessage: '无法打开下载链接',
      );
    } else if (action == _UpdateDialogAction.openReleasePage &&
        versionInfo.releasePageUrl.isNotEmpty) {
      await _openExternalUrl(
        context,
        versionInfo.releasePageUrl,
        failureMessage: '无法打开发布页面',
      );
    }
  }

  /// 构建更新内容文本
  static String _buildUpdateContent(
    BuildContext context,
    UpdateCheckResult result,
  ) {
    final buffer = StringBuffer();

    buffer.writeln(
      '${LocalizationKeys.currentVersionLabel.tr(context)}: ${result.currentVersion}',
    );
    buffer.writeln(
      '${LocalizationKeys.latestVersionLabel.tr(context)}: ${result.versionInfo!.version}',
    );

    if (result.versionInfo!.description.isNotEmpty) {
      buffer.writeln();
      buffer.writeln(LocalizationKeys.updateContent.tr(context));
      buffer.write(result.versionInfo!.description);
    }

    return buffer.toString();
  }

  static Future<void> _openExternalUrl(
    BuildContext context,
    String url, {
    required String failureMessage,
  }) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          SnackBarHelper.showError(context, failureMessage);
        }
      }
    } catch (e) {
      AppLogger.error('Failed to open external link', e);
      if (context.mounted) {
        SnackBarHelper.showError(context, '$failureMessage: $e');
      }
    }
  }
}
