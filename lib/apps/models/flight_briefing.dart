import 'dart:math' as math;
import 'airport_detail_data.dart';
import '../services/weather_service.dart';

/// 飞行简报数据模型
class FlightBriefing {
  final String flightNumber; // 航班号
  final DateTime generatedAt; // 生成时间

  // 航路信息
  final AirportDetailData departureAirport;
  final AirportDetailData arrivalAirport;
  final AirportDetailData? alternateAirport;

  // 天气信息
  final MetarData? departureMetar;
  final MetarData? arrivalMetar;
  final MetarData? alternateMetar;

  // 飞行计划
  final String? route; // 航路
  final int? cruiseAltitude; // 巡航高度 (feet)
  final int? estimatedFlightTime; // 预计飞行时间 (分钟)
  final double? distance; // 距离 (海里)

  // 燃油计划
  final double? tripFuel; // 航程燃油 (kg)
  final double? alternateFuel; // 备降燃油 (kg)
  final double? reserveFuel; // 储备燃油 (kg)
  final double? taxiFuel; // 滑行燃油 (kg)
  final double? totalFuel; // 总燃油 (kg)

  // 性能数据
  final int? takeoffWeight; // 起飞重量 (kg)
  final int? landingWeight; // 落地重量 (kg)
  final int? zeroFuelWeight; // 零燃油重量 (kg)

  // 跑道信息
  final String? departureRunway;
  final String? arrivalRunway;

  FlightBriefing({
    required this.flightNumber,
    required this.generatedAt,
    required this.departureAirport,
    required this.arrivalAirport,
    this.alternateAirport,
    this.departureMetar,
    this.arrivalMetar,
    this.alternateMetar,
    this.route,
    this.cruiseAltitude,
    this.estimatedFlightTime,
    this.distance,
    this.tripFuel,
    this.alternateFuel,
    this.reserveFuel,
    this.taxiFuel,
    this.totalFuel,
    this.takeoffWeight,
    this.landingWeight,
    this.zeroFuelWeight,
    this.departureRunway,
    this.arrivalRunway,
  });

  /// 获取格式化的航班号
  String get formattedFlightNumber {
    if (flightNumber.isEmpty) return 'N/A';
    // 如果已经包含航司代码，直接返回
    if (RegExp(r'^[A-Z]{2}\d+$').hasMatch(flightNumber)) {
      return flightNumber;
    }
    // 否则添加默认航司代码
    return 'CA$flightNumber';
  }

  /// 获取格式化的生成时间
  String get formattedGeneratedTime {
    final now = DateTime.now();
    final diff = now.difference(generatedAt);

    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    return '${diff.inDays}天前';
  }

  /// 计算大圆距离 (海里)
  static double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadiusNm = 3440.065; // 地球半径（海里）

    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadiusNm * c;
  }

  static double _toRadians(double degrees) => degrees * math.pi / 180;

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'flightNumber': flightNumber,
      'generatedAt': generatedAt.toIso8601String(),
      'departureAirport': {
        'icao': departureAirport.icaoCode,
        'name': departureAirport.name,
        'latitude': departureAirport.latitude,
        'longitude': departureAirport.longitude,
      },
      'arrivalAirport': {
        'icao': arrivalAirport.icaoCode,
        'name': arrivalAirport.name,
        'latitude': arrivalAirport.latitude,
        'longitude': arrivalAirport.longitude,
      },
      'alternateAirport': alternateAirport != null
          ? {
              'icao': alternateAirport!.icaoCode,
              'name': alternateAirport!.name,
              'latitude': alternateAirport!.latitude,
              'longitude': alternateAirport!.longitude,
            }
          : null,
      'departureMetar': departureMetar?.toJson(),
      'arrivalMetar': arrivalMetar?.toJson(),
      'alternateMetar': alternateMetar?.toJson(),
      'route': route,
      'cruiseAltitude': cruiseAltitude,
      'estimatedFlightTime': estimatedFlightTime,
      'distance': distance,
      'tripFuel': tripFuel,
      'alternateFuel': alternateFuel,
      'reserveFuel': reserveFuel,
      'taxiFuel': taxiFuel,
      'totalFuel': totalFuel,
      'takeoffWeight': takeoffWeight,
      'landingWeight': landingWeight,
      'zeroFuelWeight': zeroFuelWeight,
      'departureRunway': departureRunway,
      'arrivalRunway': arrivalRunway,
    };
  }

  /// 从JSON创建
  factory FlightBriefing.fromJson(Map<String, dynamic> json) {
    return FlightBriefing(
      flightNumber: json['flightNumber'] as String,
      generatedAt: DateTime.parse(json['generatedAt'] as String),
      departureAirport: AirportDetailData(
        icaoCode: json['departureAirport']['icao'] as String,
        name: json['departureAirport']['name'] as String,
        latitude: json['departureAirport']['latitude'] as double,
        longitude: json['departureAirport']['longitude'] as double,
        runways: [],
        frequencies: AirportFrequencies(all: []),
        fetchedAt: DateTime.now(),
      ),
      arrivalAirport: AirportDetailData(
        icaoCode: json['arrivalAirport']['icao'] as String,
        name: json['arrivalAirport']['name'] as String,
        latitude: json['arrivalAirport']['latitude'] as double,
        longitude: json['arrivalAirport']['longitude'] as double,
        runways: [],
        frequencies: AirportFrequencies(all: []),
        fetchedAt: DateTime.now(),
      ),
      alternateAirport: json['alternateAirport'] != null
          ? AirportDetailData(
              icaoCode: json['alternateAirport']['icao'] as String,
              name: json['alternateAirport']['name'] as String,
              latitude: json['alternateAirport']['latitude'] as double,
              longitude: json['alternateAirport']['longitude'] as double,
              runways: [],
              frequencies: AirportFrequencies(all: []),
              fetchedAt: DateTime.now(),
            )
          : null,
      departureMetar: json['departureMetar'] != null
          ? MetarData.fromJson(json['departureMetar'] as Map<String, dynamic>)
          : null,
      arrivalMetar: json['arrivalMetar'] != null
          ? MetarData.fromJson(json['arrivalMetar'] as Map<String, dynamic>)
          : null,
      alternateMetar: json['alternateMetar'] != null
          ? MetarData.fromJson(json['alternateMetar'] as Map<String, dynamic>)
          : null,
      route: json['route'] as String?,
      cruiseAltitude: json['cruiseAltitude'] as int?,
      estimatedFlightTime: json['estimatedFlightTime'] as int?,
      distance: json['distance'] as double?,
      tripFuel: json['tripFuel'] as double?,
      alternateFuel: json['alternateFuel'] as double?,
      reserveFuel: json['reserveFuel'] as double?,
      taxiFuel: json['taxiFuel'] as double?,
      totalFuel: json['totalFuel'] as double?,
      takeoffWeight: json['takeoffWeight'] as int?,
      landingWeight: json['landingWeight'] as int?,
      zeroFuelWeight: json['zeroFuelWeight'] as int?,
      departureRunway: json['departureRunway'] as String?,
      arrivalRunway: json['arrivalRunway'] as String?,
    );
  }
}
