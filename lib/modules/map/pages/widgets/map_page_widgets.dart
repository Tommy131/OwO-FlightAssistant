import 'package:flutter/material.dart';

import '../../../../core/services/localization_service.dart';
import '../../localization/map_localization_keys.dart';
import '../../models/map_taxiway_node.dart';
import '../../models/map_taxiway_segment.dart';

// ─────────────────────────────────────────────────────────────────
// 地图页面专属小型 UI 组件
//
// 本文件集中存放仅在 MapPage 内部使用、但业务上独立的展示型组件：
//   - [PlannedRouteLegLabel]  ：计划航路腿距离标签（显示在地图折线中点）
//   - [PlannedRouteTotalChip] ：计划总航程标签（显示在地图左下角）
//   - [TaxiwayNodeInfoCard]   ：滑行路线节点悬停信息卡
//
// 所有组件均为无状态 Widget，不依赖 Provider，仅接收展示所需的数据。
// ─────────────────────────────────────────────────────────────────

// ── 计划航路腿标签 ─────────────────────────────────────────────────

/// 显示在计划航路折线中点处的航段距离标签。
///
/// 以半透明黑色背景 + 白色文字展示 "DEP → ARR  xxx NM" 格式信息。
class PlannedRouteLegLabel extends StatelessWidget {
  /// UI 缩放比例系数（基于屏幕宽度计算）。
  final double scale;

  /// 要显示的文本（格式：`<出发> → <目的>  <距离> NM`）。
  final String text;

  const PlannedRouteLegLabel({
    super.key,
    required this.scale,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      padding: EdgeInsets.symmetric(
        horizontal: 10 * scale,
        vertical: 5 * scale,
      ),
      decoration: BoxDecoration(
        // 半透明黑色背景
        color: Colors.black.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(10 * scale),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Colors.white,
          fontSize: 12 * scale,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ── 计划总航程标签 ─────────────────────────────────────────────────

/// 显示在地图左下角的计划航路总里程标签。
///
/// 以半透明黑色背景展示总 NM 数。
class PlannedRouteTotalChip extends StatelessWidget {
  /// UI 缩放比例系数（基于屏幕宽度计算）。
  final double scale;

  /// 要显示的文本（格式：`计划总里程: xxx NM`）。
  final String text;

  const PlannedRouteTotalChip({
    super.key,
    required this.scale,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 10 * scale,
        vertical: 7 * scale,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(10 * scale),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white,
          fontSize: 12 * scale,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ── 滑行路线节点悬停信息卡 ────────────────────────────────────────────

/// 鼠标悬停在滑行路线节点时显示的浮动信息卡。
///
/// 展示节点编号、名称、经纬度和朝向角度。
class TaxiwayNodeInfoCard extends StatelessWidget {
  /// UI 缩放比例系数。
  final double scale;

  /// 节点在路线中的索引（从 0 开始，显示时 +1）。
  final int index;

  /// 悬停的节点数据。
  final MapTaxiwayNode node;

  /// 节点朝向角度（度），null 表示无法计算。
  final double? headingDeg;

  const TaxiwayNodeInfoCard({
    super.key,
    required this.scale,
    required this.index,
    required this.node,
    required this.headingDeg,
  });

  @override
  Widget build(BuildContext context) {
    // 格式化朝向文本
    final headingText =
        headingDeg == null ? '--' : '${headingDeg!.toStringAsFixed(0)}°';

    // 节点标题：若有名称则拼接，否则仅显示编号
    final titleText = (node.name ?? '').trim().isEmpty
        ? '${MapLocalizationKeys.taxiwayNode.tr(context)} ${index + 1}'
        : '${node.name} (${MapLocalizationKeys.taxiwayNode.tr(context)} ${index + 1})';

    return Container(
      width: 240 * scale,
      padding: EdgeInsets.symmetric(
        horizontal: 12 * scale,
        vertical: 10 * scale,
      ),
      decoration: BoxDecoration(
        // 半透明黑色卡片背景
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(10 * scale),
        border: Border.all(color: Colors.white24),
      ),
      child: DefaultTextStyle(
        style: TextStyle(color: Colors.white, fontSize: 12 * scale),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 节点标题行（加粗）
            Text(
              titleText,
              style: TextStyle(
                fontSize: 13 * scale,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 6 * scale),

            // 经纬度
            Text(
              '${MapLocalizationKeys.labelLatitudeLongitude.tr(context)}：'
              '${node.latitude.toStringAsFixed(6)}, '
              '${node.longitude.toStringAsFixed(6)}',
            ),
            SizedBox(height: 3 * scale),

            // 朝向角度
            Text(
              '${MapLocalizationKeys.labelHeading.tr(context)}：$headingText',
            ),
          ],
        ),
      ),
    );
  }
}

class TaxiwaySegmentInfoCard extends StatelessWidget {
  final double scale;
  final int segmentIndex;
  final MapTaxiwayNode startNode;
  final MapTaxiwayNode endNode;
  final MapTaxiwaySegment segment;
  final double distanceMeters;

  const TaxiwaySegmentInfoCard({
    super.key,
    required this.scale,
    required this.segmentIndex,
    required this.startNode,
    required this.endNode,
    required this.segment,
    required this.distanceMeters,
  });

  @override
  Widget build(BuildContext context) {
    final connectionTitle =
        '${MapLocalizationKeys.taxiwayConnection.tr(context)} ${segmentIndex + 1}';
    final lineTypeLabel = segment.lineType == MapTaxiwaySegmentLineType.straight
        ? MapLocalizationKeys.taxiwayConnectionLineTypeStraight.tr(context)
        : MapLocalizationKeys.taxiwayConnectionLineTypeMapMatching.tr(context);
    final connectionRangeText =
        '${MapLocalizationKeys.taxiwayConnectionRange.tr(context)}：'
        '${segmentIndex + 1} → ${segmentIndex + 2}';
    final coordinateText =
        '${MapLocalizationKeys.labelLatitudeLongitude.tr(context)}：'
        '${startNode.latitude.toStringAsFixed(6)}, ${startNode.longitude.toStringAsFixed(6)} ↔ '
        '${endNode.latitude.toStringAsFixed(6)}, ${endNode.longitude.toStringAsFixed(6)}';
    return Container(
      width: 300 * scale,
      padding: EdgeInsets.symmetric(
        horizontal: 12 * scale,
        vertical: 10 * scale,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(10 * scale),
        border: Border.all(color: Colors.white24),
      ),
      child: DefaultTextStyle(
        style: TextStyle(color: Colors.white, fontSize: 12 * scale),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              connectionTitle,
              style: TextStyle(
                fontSize: 13 * scale,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 6 * scale),
            Text(connectionRangeText),
            SizedBox(height: 3 * scale),
            Text(
              '${MapLocalizationKeys.distance.tr(context)}：'
              '${distanceMeters.toStringAsFixed(1)} m',
            ),
            SizedBox(height: 3 * scale),
            Text(
              '${MapLocalizationKeys.taxiwayConnectionLineType.tr(context)}：$lineTypeLabel',
            ),
            SizedBox(height: 3 * scale),
            Text(coordinateText),
          ],
        ),
      ),
    );
  }
}
