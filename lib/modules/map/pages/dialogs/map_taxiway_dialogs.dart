import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/localization/localization_keys.dart';
import '../../../../core/services/localization_service.dart';
import '../../localization/map_localization_keys.dart';
import '../../models/map_models.dart';
import '../../providers/map_provider.dart';

// ─────────────────────────────────────────────────────────────────
// 滑行路线对话框集合
//
// 本文件封装与滑行路线编辑相关的所有对话框逻辑，包含：
//   - [showTaxiwayNodeEditorDialog]    ：节点编辑对话框（名称/备注/颜色）
//   - [showTaxiwaySegmentEditorDialog] ：线段编辑对话框（名称/颜色/弯曲度）
//
// 对话框通过 [MapProvider] 提交修改，不持有任何自身状态。
// ─────────────────────────────────────────────────────────────────

/// 滑行路线颜色调色板（十六进制字符串列表）。
const List<String> kTaxiwayColorHexPalette = [
  '#00E5FF',
  '#4CAF50',
  '#FFC107',
  '#FF7043',
  '#EC407A',
  '#7E57C2',
  '#42A5F5',
  '#FFFFFF',
];

// ── 节点编辑对话框 ─────────────────────────────────────────────────

/// 显示滑行路线节点编辑对话框。
///
/// 允许用户修改节点的名称、备注和颜色标记；
/// 也支持删除该节点，删除后会通过 [onSelectedIndexChanged] 通知外部更新选中状态。
///
/// [provider]              — 地图状态管理器，用于提交修改
/// [index]                 — 要编辑的节点索引
/// [onSelectedIndexChanged] — 删除节点后用于更新外部选中状态的回调
Future<void> showTaxiwayNodeEditorDialog({
  required BuildContext context,
  required MapProvider provider,
  required int index,
  required ValueChanged<int?> onSelectedIndexChanged,
}) async {
  final nodes = provider.taxiwayNodes;
  if (index < 0 || index >= nodes.length) return;

  final target = nodes[index];
  // 计算节点朝向角度（度）供信息摘要显示
  final headingDeg = _computeNodeHeading(nodes, index);

  final nameController = TextEditingController(text: target.name ?? '');
  final noteController = TextEditingController(text: target.note ?? '');
  var selectedColorHex = target.colorHex ?? '#00E5FF';

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            // 标题：节点编号 + "设置"
            title: Text(
              '${MapLocalizationKeys.taxiwayNode.tr(context)} ${index + 1}'
              ' ${MapLocalizationKeys.taxiwayNodeSettings.tr(context)}',
            ),
            content: SizedBox(
              width: 360,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── 节点信息摘要卡 ──────────────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${MapLocalizationKeys.taxiwayNode.tr(context)} ${index + 1}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${MapLocalizationKeys.labelLatitudeLongitude.tr(context)}：'
                            '${target.latitude.toStringAsFixed(6)}, '
                            '${target.longitude.toStringAsFixed(6)}',
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${MapLocalizationKeys.labelHeading.tr(context)}：'
                            '${headingDeg == null ? '--' : '${headingDeg.toStringAsFixed(0)}°'}',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── 节点名称输入 ─────────────────────────────────
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: MapLocalizationKeys.taxiwayNodeName
                            .tr(context),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // ── 备注输入 ──────────────────────────────────────
                    TextField(
                      controller: noteController,
                      decoration: InputDecoration(
                        labelText: MapLocalizationKeys.taxiwayNodeNote
                            .tr(context),
                      ),
                      minLines: 2,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 14),

                    // ── 颜色选择器 ────────────────────────────────────
                    Text(
                      MapLocalizationKeys.taxiwayNodeColor.tr(context),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    TaxiwayColorPicker(
                      selectedHex: selectedColorHex,
                      onChanged: (hex) {
                        setModalState(() => selectedColorHex = hex);
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${MapLocalizationKeys.taxiwayNodeCurrentColor.tr(context)}：$selectedColorHex',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              // 取消，不保存
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(LocalizationKeys.cancel.tr(context)),
              ),
              // 删除该节点
              TextButton(
                onPressed: () {
                  provider.removeTaxiwayNodeAt(index);
                  final nextLength = provider.taxiwayNodes.length;
                  if (nextLength <= 0) {
                    onSelectedIndexChanged(null);
                  } else {
                    onSelectedIndexChanged(
                      index >= nextLength ? nextLength - 1 : index,
                    );
                  }
                  Navigator.of(dialogContext).pop();
                },
                style:
                    TextButton.styleFrom(foregroundColor: Colors.redAccent),
                child: Text(
                  MapLocalizationKeys.taxiwayDeleteNode.tr(context),
                ),
              ),
              // 保存修改
              FilledButton(
                onPressed: () {
                  provider.updateTaxiwayNodeInfo(
                    index,
                    name: nameController.text,
                    colorHex: selectedColorHex,
                    note: noteController.text,
                  );
                  Navigator.of(dialogContext).pop();
                },
                child: Text(LocalizationKeys.save.tr(context)),
              ),
            ],
          );
        },
      );
    },
  );
}

// ── 线段编辑对话框 ─────────────────────────────────────────────────

/// 显示滑行路线线段编辑对话框。
///
/// 允许用户修改线段的名称、备注、颜色、线型及弯曲度。
///
/// [provider]     — 地图状态管理器，用于提交修改
/// [segmentIndex] — 要编辑的线段索引
Future<void> showTaxiwaySegmentEditorDialog({
  required BuildContext context,
  required MapProvider provider,
  required int segmentIndex,
}) async {
  final nodes = provider.taxiwayNodes;
  if (segmentIndex < 0 || segmentIndex >= nodes.length - 1) return;

  final segments = provider.taxiwaySegments;
  // 若对应线段尚未存在，使用默认 segment
  final target = segmentIndex < segments.length
      ? segments[segmentIndex]
      : const MapTaxiwaySegment();

  final nameController = TextEditingController(text: target.name ?? '');
  final noteController = TextEditingController(text: target.note ?? '');
  var selectedColorHex = target.colorHex ?? '#FFD54F';
  var selectedLineType = target.lineType;
  var selectedCurvature = target.curvature;
  var selectedCurveDirection = target.curveDirection;

  final startNode = nodes[segmentIndex];
  final endNode = nodes[segmentIndex + 1];

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            // 标题：连接 N
            title: Text(
              '${MapLocalizationKeys.taxiwayConnection.tr(context)} ${segmentIndex + 1}',
            ),
            content: SizedBox(
              width: 360,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── 端点坐标摘要卡 ─────────────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${MapLocalizationKeys.taxiwayConnectionRange.tr(context)}：'
                        '${segmentIndex + 1} → ${segmentIndex + 2}\n'
                        '${MapLocalizationKeys.labelLatitudeLongitude.tr(context)}：'
                        '${startNode.latitude.toStringAsFixed(6)}, '
                        '${startNode.longitude.toStringAsFixed(6)} ↔ '
                        '${endNode.latitude.toStringAsFixed(6)}, '
                        '${endNode.longitude.toStringAsFixed(6)}',
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── 连接名称 ───────────────────────────────────
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: MapLocalizationKeys.taxiwayConnectionName
                            .tr(context),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // ── 备注 ──────────────────────────────────────
                    TextField(
                      controller: noteController,
                      decoration: InputDecoration(
                        labelText: MapLocalizationKeys.taxiwayConnectionNote
                            .tr(context),
                      ),
                      minLines: 2,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 14),

                    // ── 颜色选择器 ────────────────────────────────
                    Text(
                      MapLocalizationKeys.taxiwayConnectionColor.tr(context),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    TaxiwayColorPicker(
                      selectedHex: selectedColorHex,
                      onChanged: (hex) {
                        setModalState(() => selectedColorHex = hex);
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${MapLocalizationKeys.taxiwayNodeCurrentColor.tr(context)}：$selectedColorHex',
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 14),

                    // ── 线型选择 ──────────────────────────────────
                    Text(
                      MapLocalizationKeys.taxiwayConnectionLineType.tr(
                        context,
                      ),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<MapTaxiwaySegmentLineType>(
                      initialValue: selectedLineType,
                      decoration: const InputDecoration(),
                      items: [
                        DropdownMenuItem<MapTaxiwaySegmentLineType>(
                          value: MapTaxiwaySegmentLineType.straight,
                          child: Text(
                            MapLocalizationKeys
                                .taxiwayConnectionLineTypeStraight
                                .tr(context),
                          ),
                        ),
                        DropdownMenuItem<MapTaxiwaySegmentLineType>(
                          value: MapTaxiwaySegmentLineType.mapMatching,
                          child: Text(
                            MapLocalizationKeys
                                .taxiwayConnectionLineTypeMapMatching
                                .tr(context),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setModalState(() => selectedLineType = value);
                      },
                    ),
                    const SizedBox(height: 10),

                    // ── 弯曲度滑块 ────────────────────────────────
                    Text(
                      '${MapLocalizationKeys.taxiwayConnectionCurvature.tr(context)}：'
                      '${selectedCurvature.toStringAsFixed(2)}',
                    ),
                    Slider(
                      value: selectedCurvature.clamp(0.0, 1.0).toDouble(),
                      min: 0.0,
                      max: 1.0,
                      divisions: 20,
                      // 仅曲线模式下启用
                      onChanged: selectedLineType ==
                              MapTaxiwaySegmentLineType.mapMatching
                          ? (value) {
                              setModalState(() => selectedCurvature = value);
                            }
                          : null,
                    ),
                    const SizedBox(height: 10),

                    // ── 转弯方向下拉 ──────────────────────────────
                    Text(
                      MapLocalizationKeys.taxiwayConnectionCurveDirection.tr(
                        context,
                      ),
                    ),
                    DropdownButtonFormField<MapTaxiwaySegmentCurveDirection>(
                      initialValue: selectedCurveDirection,
                      decoration: const InputDecoration(),
                      items: [
                        DropdownMenuItem<MapTaxiwaySegmentCurveDirection>(
                          value: MapTaxiwaySegmentCurveDirection.left,
                          child: Text(
                            MapLocalizationKeys
                                .taxiwayConnectionCurveDirectionLeft
                                .tr(context),
                          ),
                        ),
                        DropdownMenuItem<MapTaxiwaySegmentCurveDirection>(
                          value: MapTaxiwaySegmentCurveDirection.right,
                          child: Text(
                            MapLocalizationKeys
                                .taxiwayConnectionCurveDirectionRight
                                .tr(context),
                          ),
                        ),
                      ],
                      // 仅曲线模式下启用
                      onChanged: selectedLineType ==
                              MapTaxiwaySegmentLineType.mapMatching
                          ? (value) {
                              if (value == null) return;
                              setModalState(
                                () => selectedCurveDirection = value,
                              );
                            }
                          : null,
                    ),
                    const SizedBox(height: 8),

                    // ── 拖动操作提示文本 ──────────────────────────
                    Text(
                      MapLocalizationKeys.taxiwayConnectionDragHint.tr(
                        context,
                      ),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(LocalizationKeys.cancel.tr(context)),
              ),
              FilledButton(
                onPressed: () {
                  provider.updateTaxiwaySegmentInfo(
                    segmentIndex,
                    name: nameController.text,
                    colorHex: selectedColorHex,
                    note: noteController.text,
                    lineType: selectedLineType,
                    curvature: selectedCurvature,
                    curveDirection: selectedCurveDirection,
                  );
                  Navigator.of(dialogContext).pop();
                },
                child: Text(LocalizationKeys.save.tr(context)),
              ),
            ],
          );
        },
      );
    },
  );
}

// ── 可复用组件 ────────────────────────────────────────────────────

/// 调色板颜色选择器，供节点和线段编辑对话框共用。
class TaxiwayColorPicker extends StatelessWidget {
  /// 当前选中的颜色（十六进制字符串，如 `#00E5FF`）。
  final String selectedHex;

  /// 颜色变更回调。
  final ValueChanged<String> onChanged;

  const TaxiwayColorPicker({
    super.key,
    required this.selectedHex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: kTaxiwayColorHexPalette
          .map(
            (hex) => GestureDetector(
              onTap: () => onChanged(hex),
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: colorFromHex(hex),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selectedHex == hex
                        ? Colors.white
                        : Colors.black.withValues(alpha: 0.45),
                    width: selectedHex == hex ? 2 : 1,
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  /// 将十六进制字符串转换为 Flutter [Color]。
  static Color colorFromHex(String hex) {
    final normalized = hex.trim().toUpperCase().replaceAll('#', '');
    if (RegExp(r'^[0-9A-F]{6}$').hasMatch(normalized)) {
      return Color(int.parse('FF$normalized', radix: 16));
    }
    if (RegExp(r'^[0-9A-F]{8}$').hasMatch(normalized)) {
      return Color(int.parse(normalized, radix: 16));
    }
    return Colors.cyanAccent;
  }
}

// ── 私有工具函数 ──────────────────────────────────────────────────

/// 计算节点朝向角度（度，正北 0° 顺时针）。
///
/// 若节点数不足或索引越界，返回 null。
double? _computeNodeHeading(List<MapTaxiwayNode> nodes, int index) {
  if (nodes.length < 2 || index < 0 || index >= nodes.length) return null;

  final MapTaxiwayNode from;
  final MapTaxiwayNode to;

  if (index < nodes.length - 1) {
    from = nodes[index];
    to = nodes[index + 1];
  } else {
    from = nodes[index - 1];
    to = nodes[index];
  }

  // 以经纬度差计算近似方位角，并转换为正北顺时针体系
  final dLat = to.latitude - from.latitude;
  final dLon = to.longitude - from.longitude;
  final rawDeg = math.atan2(dLon, dLat) * 180 / math.pi;
  return (rawDeg + 360) % 360;
}
