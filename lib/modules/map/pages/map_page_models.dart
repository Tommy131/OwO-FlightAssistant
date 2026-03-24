import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────
// 地图固定机场标记辅助数据模型
//
// 本文件集中存放 MapPage 内部用于构建固定机场大头针（PinnedMarker）
// 所需的辅助数据结构：
//   - [PinnedAirportBundle]：同一位置机场的多角色合并数据包
//   - [RolePinData]        ：单一角色大头针的渲染参数
//   - [CombinedPinData]    ：多角色合并大头针的渲染参数
//   - [PlannedRouteLeg]    ：计划航路的单个航段信息
//
// 这些模型仅在 MapPage 的标记构建方法中使用，不依赖 Provider 或 UI 框架。
// ─────────────────────────────────────────────────────────────────

/// 同一地理位置上可能同时承担多个角色（主场/起飞/降落/备降）的机场数据包。
///
/// 用于在构建地图标记时对同位置机场进行去重和角色合并。
class PinnedAirportBundle {
  /// 机场去重键（优先使用 ICAO，否则使用坐标字符串）。
  final String dedupeKey;

  /// 机场 ICAO 代码（已大写规范化）。
  final String code;

  /// 机场纬度。
  final double latitude;

  /// 机场经度。
  final double longitude;

  /// 是否为本场机场（HOME）。
  bool isHome = false;

  /// 是否为计划起飞机场。
  bool isDeparture = false;

  /// 是否为计划目的地机场。
  bool isDestination = false;

  /// 是否为计划备降机场。
  bool isAlternate = false;

  PinnedAirportBundle({
    required this.dedupeKey,
    required this.code,
    required this.latitude,
    required this.longitude,
  });
}

/// 单一角色大头针的渲染参数。
class RolePinData {
  /// 大头针标签文本（如"起飞机场"）。
  final String title;

  /// 大头针图标。
  final IconData icon;

  /// 大头针主色。
  final Color color;

  const RolePinData({
    required this.title,
    required this.icon,
    required this.color,
  });
}

/// 多角色合并大头针的渲染参数（仅保留图标和主色）。
class CombinedPinData {
  /// 大头针图标。
  final IconData icon;

  /// 大头针主色。
  final Color color;

  const CombinedPinData({required this.icon, required this.color});
}

/// 计划航路的单个航段信息。
///
/// 包含起止机场 ICAO、坐标及距离（NM），用于折线和距离标签的渲染。
class PlannedRouteLeg {
  /// 出发机场 ICAO 代码。
  final String fromCode;

  /// 目的地机场 ICAO 代码。
  final String toCode;

  /// 出发点坐标。
  final PlannedRouteLegPoint from;

  /// 目的地坐标。
  final PlannedRouteLegPoint to;

  /// 航段距离（海里）。
  final double distanceNm;

  const PlannedRouteLeg({
    required this.fromCode,
    required this.toCode,
    required this.from,
    required this.to,
    required this.distanceNm,
  });
}

/// 航段端点坐标（经纬度）。
class PlannedRouteLegPoint {
  final double latitude;
  final double longitude;

  const PlannedRouteLegPoint({
    required this.latitude,
    required this.longitude,
  });
}
