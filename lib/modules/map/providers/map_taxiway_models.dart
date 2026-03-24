import '../models/map_taxiway_node.dart';
import '../models/map_taxiway_segment.dart';

// ─────────────────────────────────────────────────────────────────
// 滑行路线相关内部数据模型
//
// 本文件集中存放 MapProvider 内部使用的滑行路线专属模型：
//   - [MapTaxiwayFileSummary]          ：文件摘要（供 UI 展示文件列表）
//   - [MapTaxiwayFileData]             ：从 JSON 文件解析出的完整数据
//   - [MapTaxiwayOperationSnapshot]    ：操作前/后的节点+线段快照
//   - [MapTaxiwayOperationRecord]      ：单次撤销/重做记录
//   - [MapTaxiwaySegmentMatchResult]   ：飞机与路线的最近匹配结果
// ─────────────────────────────────────────────────────────────────

// ── 公开模型 ──────────────────────────────────────────────────────

/// 滑行路线文件摘要。
///
/// 仅用于 UI 展示文件选择列表，不包含完整节点数据。
class MapTaxiwayFileSummary {
  /// 文件的绝对路径。
  final String filePath;

  /// 文件名（不含目录前缀）。
  final String fileName;

  /// 文件最后修改时间。
  final DateTime lastModified;

  /// 路线节点总数。
  final int nodeCount;

  const MapTaxiwayFileSummary({
    required this.filePath,
    required this.fileName,
    required this.lastModified,
    required this.nodeCount,
  });
}

// ── 内部模型（仅 Provider 层使用）─────────────────────────────────

/// 从 JSON 文件解析出的完整滑行路线数据，仅供内部使用。
class MapTaxiwayFileData {
  /// 路线节点列表。
  final List<MapTaxiwayNode> nodes;

  /// 路线线段列表（与节点一一对应，长度 = 节点数 − 1）。
  final List<MapTaxiwaySegment> segments;

  /// 文件中记录的机场 ICAO 代码（可能为 null）。
  final String? airportIcao;

  /// 路线首次创建时间（可能为 null）。
  final DateTime? createdAt;

  const MapTaxiwayFileData({
    required this.nodes,
    required this.segments,
    this.airportIcao,
    this.createdAt,
  });
}

/// 单个滑行路线操作的状态快照，用于撤销 / 重做。
class MapTaxiwayOperationSnapshot {
  /// 快照时刻的节点列表（不可变副本）。
  final List<MapTaxiwayNode> nodes;

  /// 快照时刻的线段列表（不可变副本）。
  final List<MapTaxiwaySegment> segments;

  const MapTaxiwayOperationSnapshot({
    required this.nodes,
    required this.segments,
  });
}

/// 一条撤销 / 重做历史记录，保존操作前后的完整快照。
class MapTaxiwayOperationRecord {
  /// 操作执行之前的状态快照。
  final MapTaxiwayOperationSnapshot before;

  /// 操作执行之后的状态快照。
  final MapTaxiwayOperationSnapshot after;

  const MapTaxiwayOperationRecord({
    required this.before,
    required this.after,
  });
}

/// 飞机位置与滑行路线线段的最近匹配结果。
///
/// 供自动完成状态计算使用，记录最近线段索引、沿线进度和垂直距离。
class MapTaxiwaySegmentMatchResult {
  /// 最近匹配的线段索引（从 0 开始）。
  final int segmentIndex;

  /// 全局连续进度（= segmentIndex + 线段内归一化进度，范围 [0, 节点数-1]）。
  final double progress;

  /// 飞机到最近点的距离（米）。
  final double distanceMeters;

  const MapTaxiwaySegmentMatchResult({
    required this.segmentIndex,
    required this.progress,
    required this.distanceMeters,
  });
}
