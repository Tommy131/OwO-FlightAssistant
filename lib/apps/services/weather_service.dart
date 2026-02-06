import 'package:http/http.dart' as http;

class MetarData {
  final String icao;
  final String raw;
  final String? time;
  final String? wind;
  final String? visibility;
  final String? temperature;
  final String? altimeter;
  final String? clouds;
  final DateTime timestamp;

  MetarData({
    required this.icao,
    required this.raw,
    this.time,
    this.wind,
    this.visibility,
    this.temperature,
    this.altimeter,
    this.clouds,
    required this.timestamp,
  });

  factory MetarData.parse(String icao, String raw) {
    // 简单的 METAR 解析逻辑
    String? time, wind, visibility, temperature, altimeter, clouds;

    final parts = raw.split(' ');

    // 查找时间 (通常是第二或第三部分，以 Z 结尾)
    for (var i = 0; i < parts.length; i++) {
      if (parts[i].endsWith('Z') && parts[i].length == 7) {
        time = parts[i];
      }
      // 查找风向风速 (例如 25008KT)
      if (parts[i].endsWith('KT') || parts[i].endsWith('MPS')) {
        wind = parts[i];
      }
      // 查找可见度 (例如 10SM 或 9999)
      if (parts[i].endsWith('SM') ||
          (int.tryParse(parts[i]) != null && parts[i].length == 4)) {
        visibility = parts[i];
      }
      // 查找温度/露点 (例如 16/09)
      if (parts[i].contains('/') && parts[i].split('/').length == 2) {
        final tempParts = parts[i].split('/');
        if (int.tryParse(tempParts[0].replaceAll('M', '-')) != null) {
          temperature = parts[i];
        }
      }
      // 查找修正海压 (例如 A3002 或 Q1013)
      if (parts[i].startsWith('A') && parts[i].length == 5) {
        altimeter = parts[i];
      } else if (parts[i].startsWith('Q') && parts[i].length == 5) {
        altimeter = parts[i];
      }

      // 查找云况 (FEW, SCT, BKN, OVC, CLR, SKC)
      if ([
        'FEW',
        'SCT',
        'BKN',
        'OVC',
        'CLR',
        'SKC',
      ].any((element) => parts[i].startsWith(element))) {
        clouds = (clouds == null) ? parts[i] : '$clouds ${parts[i]}';
      }
    }

    return MetarData(
      icao: icao,
      raw: raw,
      time: time,
      wind: wind,
      visibility: visibility,
      temperature: temperature,
      altimeter: altimeter,
      clouds: clouds,
      timestamp: DateTime.now(),
    );
  }

  String get displayWind {
    if (wind == null) return "N/A";
    if (wind!.contains('KT')) {
      final dir = wind!.substring(0, 3);
      final speed = wind!.substring(3).replaceAll('KT', '');
      return '$dir° / $speed kt';
    }
    if (wind!.contains('MPS')) {
      final dir = wind!.substring(0, 3);
      final speed = wind!.substring(3).replaceAll('MPS', '');
      return '$dir° / $speed m/s';
    }
    return wind!;
  }

  String get displayVisibility {
    if (visibility == null) return "N/A";
    if (visibility!.endsWith('SM')) {
      return visibility!.replaceAll('SM', ' SM');
    }
    if (int.tryParse(visibility!) != null) {
      final meters = int.parse(visibility!);
      if (meters >= 9999) return ">10 km";
      return "${(meters / 1000).toStringAsFixed(1)} km";
    }
    return visibility!;
  }

  String get displayTemperature {
    if (temperature == null) return "N/A";
    final parts = temperature!.split('/');
    if (parts.length == 2) {
      final t = parts[0].replaceAll('M', '-');
      final d = parts[1].replaceAll('M', '-');
      return '$t°C / $d°C';
    }
    return temperature!;
  }

  String get displayAltimeter {
    if (altimeter == null) return "N/A";
    if (altimeter!.startsWith('A')) {
      final val = altimeter!.substring(1);
      if (val.length == 4) {
        return '${val.substring(0, 2)}.${val.substring(2)} inHg';
      }
    }
    if (altimeter!.startsWith('Q')) {
      return '${altimeter!.substring(1)} hPa';
    }
    return altimeter!;
  }
}

class WeatherService {
  static const String _baseUrl =
      'https://tgftp.nws.noaa.gov/data/observations/metar/stations/';

  Future<MetarData?> fetchMetar(String icao) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl${icao.toUpperCase()}.TXT'),
      );
      if (response.statusCode == 200) {
        // NOAA 返回的格式通常包含两行：第一行是时间戳，第二行是原始 METAR
        final lines = response.body.split('\n');
        if (lines.length >= 2) {
          final rawMetar = lines.sublist(1).join(' ').trim();
          if (rawMetar.isNotEmpty) {
            return MetarData.parse(icao, rawMetar);
          }
        }
      }
    } catch (e) {
      print('Error fetching METAR for $icao: $e');
    }
    return null;
  }
}
