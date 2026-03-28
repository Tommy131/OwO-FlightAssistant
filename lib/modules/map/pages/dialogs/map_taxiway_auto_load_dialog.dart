import 'package:flutter/material.dart';

import '../../../../core/services/localization_service.dart';
import '../../localization/map_localization_keys.dart';
import '../../providers/map_provider.dart';
import '../../providers/map_taxiway_models.dart';

// ─────────────────────────────────────────────────────────────────
// 滑行路线自动加载对话框
//
// 职责：当检测到当前机场存在已保存的滑行路线文件时，
//       自动弹出提示询问用户是否加载。
//
// 对话框内部通过 [MapTaxiwayFileSummary] 展示文件列表，
// 用户确认后由 [MapProvider] 完成文件导入。
// ─────────────────────────────────────────────────────────────────

/// 显示滑行路线自动加载提示对话框。
///
/// [resolvedIcao] — 已解析的机场 ICAO 代码
/// [files]        — 可供加载的文件摘要列表（至少包含 1 条）
/// [provider]     — 地图状态管理器，负责执行文件导入
///
/// 加载成功后会通过 [onLoadResult] 回调通知外部显示结果。
Future<void> showTaxiwayAutoLoadDialog({
  required BuildContext context,
  required String resolvedIcao,
  required List<MapTaxiwayFileSummary> files,
  required MapProvider provider,
  required ValueChanged<String> onLoadResult,
}) async {
  // 默认选中最新的文件（列表已按修改时间降序排列）
  String selectedPath = files.first.filePath;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            // 标题：自动加载提示 + 机场 ICAO
            title: Text(
              '${MapLocalizationKeys.taxiwayAutoLoadTitle.tr(context)} ($resolvedIcao)',
            ),
            content: SizedBox(
              width: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 提示说明文本
                  Text(MapLocalizationKeys.taxiwayAutoLoadPrompt.tr(context)),
                  const SizedBox(height: 10),

                  // 文件列表
                  SizedBox(
                    height: 320,
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: files.length,
                      itemBuilder: (context, index) {
                        final item = files[index];
                        final selected = selectedPath == item.filePath;
                        final modifiedText = _formatDateTime(item.lastModified);
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 0,
                          ),
                          onTap: () {
                            setModalState(() {
                              selectedPath = item.filePath;
                            });
                          },
                          // 单选按钮图标
                          leading: Icon(
                            selected
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            size: 20,
                          ),
                          title: Text(item.fileName),
                          subtitle: Text(
                            '${MapLocalizationKeys.labelLastEdited.tr(context)}: $modifiedText'
                            '  ·  '
                            '${MapLocalizationKeys.labelNodeCount.tr(context)}: ${item.nodeCount}',
                          ),
                          selected: selected,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              // 跳过，不加载
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(
                  MapLocalizationKeys.taxiwayAutoLoadSkip.tr(context),
                ),
              ),
              // 确认加载选中文件
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(
                  MapLocalizationKeys.taxiwayAutoLoadLoad.tr(context),
                ),
              ),
            ],
          );
        },
      );
    },
  );

  if (confirmed != true) return;

  // 执行文件导入并通知外部结果
  final loadedCount = await provider.importTaxiwayRouteFromPath(selectedPath);
  if (context.mounted) {
    final message = loadedCount > 0
        ? '${MapLocalizationKeys.taxiwayAutoLoadLoaded.tr(context)}: $loadedCount'
        : MapLocalizationKeys.taxiwayAutoLoadInvalid.tr(context);
    onLoadResult(message);
  }
}

// ── 私有工具 ──────────────────────────────────────────────────────

/// 将 [DateTime] 格式化为 `yyyy-MM-dd HH:mm` 字符串。
String _formatDateTime(DateTime value) {
  final year = value.year.toString().padLeft(4, '0');
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$year-$month-$day $hour:$minute';
}
