import '../models/airport_info.dart';
export '../models/airport_info.dart';

/// 机场数据库管理器
class AirportsDatabase {
  /// 动态机场列表
  static List<AirportInfo> _airports = [];

  /// 更新机场列表
  static void updateAirports(List<AirportInfo> airports) {
    _airports = airports;
  }

  /// 获取所有机场列表
  static List<AirportInfo> get allAirports => _airports;

  /// 检查数据库是否为空
  static bool get isEmpty => _airports.isEmpty;

  /// 根据ICAO代码查询机场
  static AirportInfo? findByIcao(String icaoCode) {
    try {
      return _airports.firstWhere(
        (airport) => airport.icaoCode.toUpperCase() == icaoCode.toUpperCase(),
      );
    } catch (_) {
      return null;
    }
  }

  /// 根据坐标查找最近的机场
  ///
  /// [latitude] 纬度
  /// [longitude] 经度
  /// [threshold] 距离阈值（度），默认0.05（约5.5km）
  ///
  /// 返回最近的机场信息，如果没有在阈值范围内的机场则返回null
  static AirportInfo? findNearestByCoords(
    double latitude,
    double longitude, {
    double threshold = 0.05,
  }) {
    // 过滤无效坐标
    if (latitude == 0 && longitude == 0) return null;

    AirportInfo? nearestAirport;
    double minDistance = threshold;

    for (final airport in _airports) {
      // 简化距离计算（适用于小范围）
      final dLat = (latitude - airport.latitude).abs();
      final dLon = (longitude - airport.longitude).abs();
      final distance = dLat + dLon; // 曼哈顿距离

      if (distance < minDistance) {
        minDistance = distance;
        nearestAirport = airport;
      }
    }

    return nearestAirport;
  }

  /// 综合搜索机场：名称、ICAO、IATA、经纬度
  static List<AirportInfo> search(String keyword) {
    if (keyword.isEmpty) return [];
    final lowerKeyword = keyword.toLowerCase();

    // 检查是否可能是经纬度搜索 (例如 "31.2, 121.4")
    final coordParts = lowerKeyword
        .split(RegExp(r'[,\s]+'))
        .where((p) => p.isNotEmpty)
        .toList();
    double? searchLat;
    double? searchLon;
    if (coordParts.length == 2) {
      searchLat = double.tryParse(coordParts[0]);
      searchLon = double.tryParse(coordParts[1]);
    }

    return _airports.where((airport) {
      final icao = airport.icaoCode.toLowerCase();
      final iata = airport.iataCode.toLowerCase();
      final name = airport.nameChinese.toLowerCase();

      // 基础文本匹配
      if (icao.contains(lowerKeyword) ||
          iata.contains(lowerKeyword) ||
          name.contains(lowerKeyword)) {
        return true;
      }

      // 坐标数值匹配 (模糊匹配距离较近的)
      if (searchLat != null && searchLon != null) {
        final dLat = (airport.latitude - searchLat).abs();
        final dLon = (airport.longitude - searchLon).abs();
        if (dLat < 0.1 && dLon < 0.1) return true; // 约 11km 范围内
      }

      // 坐标字符串匹配 (搜索数字)
      final latStr = airport.latitude.toString();
      final lonStr = airport.longitude.toString();
      if (latStr.contains(lowerKeyword) || lonStr.contains(lowerKeyword)) {
        return true;
      }

      return false;
    }).toList();
  }
}
