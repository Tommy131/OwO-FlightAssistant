import 'dart:math' as math;
import '../models/flight_briefing.dart';
import '../models/airport_detail_data.dart';
import 'weather_service.dart';
import 'airport_detail_service.dart';
import '../../core/utils/logger.dart';

/// 飞行简报生成服务
class BriefingService {
  static final BriefingService _instance = BriefingService._internal();
  factory BriefingService() => _instance;
  BriefingService._internal();

  final WeatherService _weatherService = WeatherService();
  final AirportDetailService _airportService = AirportDetailService();

  /// 生成飞行简报
  Future<FlightBriefing?> generateBriefing({
    required String departureIcao,
    required String arrivalIcao,
    String? alternateIcao,
    String? flightNumber,
    String? route,
    int? cruiseAltitude,
    String? departureRunway,
    String? arrivalRunway,
    // 模拟器重量数据
    int? simulatorTotalWeight,
    int? simulatorEmptyWeight,
    int? simulatorPayloadWeight,
    double? simulatorFuelWeight,
  }) async {
    try {
      AppLogger.info('Generating briefing: $departureIcao -> $arrivalIcao');

      // 1. 获取机场信息
      final departure = await _airportService.fetchAirportDetail(departureIcao);
      if (departure == null) {
        AppLogger.error('Failed to get departure airport: $departureIcao');
        return null;
      }

      final arrival = await _airportService.fetchAirportDetail(arrivalIcao);
      if (arrival == null) {
        AppLogger.error('Failed to get arrival airport: $arrivalIcao');
        return null;
      }

      AirportDetailData? alternate;
      if (alternateIcao != null && alternateIcao.isNotEmpty) {
        alternate = await _airportService.fetchAirportDetail(alternateIcao);
      }

      // 2. 获取天气信息
      final depMetar = await _weatherService.fetchMetar(departureIcao);
      final arrMetar = await _weatherService.fetchMetar(arrivalIcao);
      MetarData? altMetar;
      if (alternateIcao != null && alternateIcao.isNotEmpty) {
        altMetar = await _weatherService.fetchMetar(alternateIcao);
      }

      // 3. 计算航路数据
      final distance = FlightBriefing.calculateDistance(
        departure.latitude,
        departure.longitude,
        arrival.latitude,
        arrival.longitude,
      );

      // 4. 估算飞行时间 (基于距离和平均速度)
      final avgSpeed = 450.0; // 平均速度 450节
      final estimatedTime = (distance / avgSpeed * 60).round();

      // 5. 计算燃油需求 (简化计算)
      final fuelData = _calculateFuelRequirements(
        distance: distance,
        cruiseAltitude: cruiseAltitude ?? 35000,
        hasAlternate: alternate != null,
      );

      // 6. 选择跑道（优先使用用户指定的跑道）
      final depRunway =
          departureRunway ?? _selectBestRunway(departure, depMetar);
      final arrRunway = arrivalRunway ?? _selectBestRunway(arrival, arrMetar);

      // 7. 生成航班号
      final generatedFlightNumber = flightNumber ?? _generateFlightNumber();

      // 8. 计算重量数据（优先使用模拟器数据）
      int? takeoffWeight;
      int? landingWeight;
      int? zeroFuelWeight;

      if (simulatorTotalWeight != null && simulatorEmptyWeight != null) {
        // 使用模拟器数据
        takeoffWeight = simulatorTotalWeight;

        // 计算零燃油重量：空机重量 + 载荷重量
        if (simulatorPayloadWeight != null) {
          zeroFuelWeight = simulatorEmptyWeight + simulatorPayloadWeight;
        } else {
          // 如果没有载荷数据，用总重量减去燃油重量
          final currentFuel = simulatorFuelWeight ?? 0;
          zeroFuelWeight = (simulatorTotalWeight - currentFuel).round();
        }

        // 计算落地重量：起飞重量 - 航程燃油
        final tripFuel = fuelData['trip']!;
        landingWeight = (takeoffWeight - tripFuel).round();

        AppLogger.info(
          '使用模拟器重量数据: TOW=$takeoffWeight, ZFW=$zeroFuelWeight, LW=$landingWeight',
        );
      } else {
        // 使用默认计算
        zeroFuelWeight = 42000;
        takeoffWeight = _calculateWeight(fuelData['total']!, 'takeoff');
        landingWeight = _calculateWeight(fuelData['total']!, 'landing');

        AppLogger.info(
          '使用默认重量数据: TOW=$takeoffWeight, ZFW=$zeroFuelWeight, LW=$landingWeight',
        );
      }

      return FlightBriefing(
        flightNumber: generatedFlightNumber,
        generatedAt: DateTime.now(),
        departureAirport: departure,
        arrivalAirport: arrival,
        alternateAirport: alternate,
        departureMetar: depMetar,
        arrivalMetar: arrMetar,
        alternateMetar: altMetar,
        route: route,
        cruiseAltitude: cruiseAltitude ?? 35000,
        estimatedFlightTime: estimatedTime,
        distance: distance,
        tripFuel: fuelData['trip'],
        alternateFuel: fuelData['alternate'],
        reserveFuel: fuelData['reserve'],
        taxiFuel: fuelData['taxi'],
        totalFuel: fuelData['total'],
        takeoffWeight: takeoffWeight,
        landingWeight: landingWeight,
        zeroFuelWeight: zeroFuelWeight,
        departureRunway: depRunway,
        arrivalRunway: arrRunway,
      );
    } catch (e, stackTrace) {
      AppLogger.error('Error generating briefing', e, stackTrace);
      return null;
    }
  }

  /// 计算燃油需求
  Map<String, double> _calculateFuelRequirements({
    required double distance,
    required int cruiseAltitude,
    required bool hasAlternate,
  }) {
    // 简化的燃油计算模型 (基于A320/B737)
    // 实际应用中应该使用更精确的性能数据

    // 航程燃油: 约 2.5 kg/nm
    final tripFuel = distance * 2.5;

    // 备降燃油: 如果有备降机场，按200nm计算
    final alternateFuel = hasAlternate ? 200 * 2.5 : 0.0;

    // 储备燃油: 30分钟续航 (约1500kg)
    final reserveFuel = 1500.0;

    // 滑行燃油: 固定200kg
    final taxiFuel = 200.0;

    // 额外燃油: 5%的航程燃油
    final extraFuel = tripFuel * 0.05;

    final totalFuel =
        tripFuel + alternateFuel + reserveFuel + taxiFuel + extraFuel;

    return {
      'trip': tripFuel,
      'alternate': alternateFuel,
      'reserve': reserveFuel,
      'taxi': taxiFuel,
      'extra': extraFuel,
      'total': totalFuel,
    };
  }

  /// 计算重量
  int _calculateWeight(double fuelKg, String type) {
    const zeroFuelWeight = 42000; // 零燃油重量 (kg)

    if (type == 'takeoff') {
      return (zeroFuelWeight + fuelKg).round();
    } else if (type == 'landing') {
      // 假设消耗80%的航程燃油
      return (zeroFuelWeight + fuelKg * 0.2).round();
    }

    return zeroFuelWeight;
  }

  /// 选择最佳跑道 (基于风向)
  String? _selectBestRunway(AirportDetailData airport, MetarData? metar) {
    if (airport.runways.isEmpty) return null;

    // 如果没有天气数据，返回第一条跑道
    if (metar == null || metar.wind == null) {
      return airport.runways.first.ident;
    }

    // 解析风向
    final windStr = metar.wind!;
    int? windDirection;

    if (windStr.length >= 5) {
      final dirStr = windStr.substring(0, 3);
      windDirection = int.tryParse(dirStr);
    }

    if (windDirection == null) {
      return airport.runways.first.ident;
    }

    // 找到最接近风向的跑道
    String? bestRunway;
    int minDiff = 180;

    for (final runway in airport.runways) {
      // 解析跑道号 (例如 "17L/35R" -> [17, 35])
      final parts = runway.ident.split('/');
      for (final part in parts) {
        final rwNum = int.tryParse(part.replaceAll(RegExp(r'[LRC]'), ''));
        if (rwNum != null) {
          final rwHeading = rwNum * 10;
          final diff = (windDirection - rwHeading).abs();
          final normalizedDiff = diff > 180 ? 360 - diff : diff;

          if (normalizedDiff < minDiff) {
            minDiff = normalizedDiff;
            bestRunway = part;
          }
        }
      }
    }

    return bestRunway ?? airport.runways.first.ident;
  }

  /// 生成随机航班号
  String _generateFlightNumber() {
    final random = math.Random();
    final number = 1000 + random.nextInt(8999);
    return 'CA$number';
  }
}
