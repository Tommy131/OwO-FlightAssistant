/// 机场数据库模型
class AirportInfo {
  final String icaoCode;
  final String nameChinese;
  final double latitude;
  final double longitude;

  const AirportInfo({
    required this.icaoCode,
    required this.nameChinese,
    required this.latitude,
    required this.longitude,
  });

  /// 完整显示名称 (ICAO + 中文名)
  String get displayName => '$icaoCode $nameChinese';
}

/// 机场数据库管理器
class AirportsDatabase {
  /// 中国及周边主要机场数据库
  static const List<AirportInfo> _airports = [
    // 中国北方
    AirportInfo(
      icaoCode: 'ZBAA',
      nameChinese: '北京首都',
      latitude: 40.072,
      longitude: 116.597,
    ),
    AirportInfo(
      icaoCode: 'ZBSJ',
      nameChinese: '石家庄正定',
      latitude: 38.281,
      longitude: 114.697,
    ),
    AirportInfo(
      icaoCode: 'ZBTJ',
      nameChinese: '天津滨海',
      latitude: 39.124,
      longitude: 117.346,
    ),

    // 中国东部
    AirportInfo(
      icaoCode: 'ZSPD',
      nameChinese: '上海浦东',
      latitude: 31.144,
      longitude: 121.805,
    ),
    AirportInfo(
      icaoCode: 'ZSSS',
      nameChinese: '上海虹桥',
      latitude: 31.198,
      longitude: 121.336,
    ),

    // 中国南方
    AirportInfo(
      icaoCode: 'ZGGZ',
      nameChinese: '广州白云',
      latitude: 23.392,
      longitude: 113.299,
    ),
    AirportInfo(
      icaoCode: 'ZGSZ',
      nameChinese: '深圳宝安',
      latitude: 22.639,
      longitude: 113.811,
    ),
    AirportInfo(
      icaoCode: 'VHHH',
      nameChinese: '香港赤鱲角',
      latitude: 22.308,
      longitude: 113.914,
    ),

    // 中国西部
    AirportInfo(
      icaoCode: 'ZUUU',
      nameChinese: '成都双流',
      latitude: 30.578,
      longitude: 103.947,
    ),

    // 国际机场
    AirportInfo(
      icaoCode: 'RKSI',
      nameChinese: '首尔仁川',
      latitude: 37.469,
      longitude: 126.451,
    ),
    AirportInfo(
      icaoCode: 'RJTT',
      nameChinese: '东京羽田',
      latitude: 35.549,
      longitude: 139.779,
    ),
    AirportInfo(
      icaoCode: 'KJFK',
      nameChinese: '纽约肯尼迪',
      latitude: 40.641,
      longitude: -73.778,
    ),
    AirportInfo(
      icaoCode: 'EGLL',
      nameChinese: '伦敦希思罗',
      latitude: 51.470,
      longitude: -0.454,
    ),
  ];

  /// 获取所有机场列表
  static List<AirportInfo> get allAirports => _airports;

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

  /// 根据名称模糊搜索机场
  static List<AirportInfo> searchByName(String keyword) {
    final lowerKeyword = keyword.toLowerCase();
    return _airports.where((airport) {
      return airport.icaoCode.toLowerCase().contains(lowerKeyword) ||
          airport.nameChinese.contains(keyword);
    }).toList();
  }
}
