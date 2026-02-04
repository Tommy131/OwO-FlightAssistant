import 'dart:typed_data';

/// 数据转换工具类
///
/// 提供各种单位转换和数据格式转换功能
class DataConverters {
  // ==================== 单位转换 ====================

  /// 米转英尺
  static double metersToFeet(double meters) => meters * 3.28084;

  /// 英尺转米
  static double feetToMeters(double feet) => feet / 3.28084;

  /// 米/秒转英尺/分钟
  static double mpsToFpm(double mps) => mps * 196.85;

  /// 英尺/分钟转米/秒
  static double fpmToMps(double fpm) => fpm / 196.85;

  /// 米/秒转节
  static double mpsToKnots(double mps) => mps * 1.94384;

  /// 节转米/秒
  static double knotsToMps(double knots) => knots / 1.94384;

  /// 千克/秒转千克/小时
  static double kgsToKgh(double kgs) => kgs * 3600;

  /// 千克/小时转千克/秒
  static double kghToKgs(double kgh) => kgh / 3600;

  /// 襟翼比例转角度（假设最大40度）
  static double flapRatioToDegrees(double ratio, {double maxDegrees = 40.0}) {
    return ratio * maxDegrees;
  }

  // ==================== 数据类型转换 ====================

  /// 将布尔值转换为数值（0或1）
  static double boolToDouble(bool value) => value ? 1.0 : 0.0;

  /// 将数值转换为布尔值（>0.5为true）
  static bool doubleToBool(double value, {double threshold = 0.5}) {
    return value > threshold;
  }

  // ==================== 字节序列转换 ====================

  /// 字节数组转Int32（小端序）
  static int bytesToInt32(Uint8List bytes) {
    return ByteData.sublistView(bytes).getInt32(0, Endian.little);
  }

  /// 字节数组转Float32（小端序）
  static double bytesToFloat32(Uint8List bytes) {
    return ByteData.sublistView(bytes).getFloat32(0, Endian.little);
  }

  /// Int32转字节数组（小端序）
  static List<int> int32ToBytes(int value) {
    final Uint8List bytes = Uint8List(4);
    ByteData.view(bytes.buffer).setInt32(0, value, Endian.little);
    return bytes.toList();
  }

  /// Float32转字节数组（小端序）
  static List<int> float32ToBytes(double value) {
    final Uint8List bytes = Uint8List(4);
    ByteData.view(bytes.buffer).setFloat32(0, value, Endian.little);
    return bytes.toList();
  }

  // ==================== 格式化显示 ====================

  /// 格式化速度显示（节）
  static String formatSpeed(double? knots, {int decimals = 0}) {
    if (knots == null) return '--';
    return knots.toStringAsFixed(decimals);
  }

  /// 格式化高度显示（英尺）
  static String formatAltitude(double? feet, {int decimals = 0}) {
    if (feet == null) return '--';
    return feet.toStringAsFixed(decimals);
  }

  /// 格式化航向显示（度）
  static String formatHeading(double? degrees, {int decimals = 0}) {
    if (degrees == null) return '--';
    return degrees.toStringAsFixed(decimals).padLeft(3, '0');
  }

  /// 格式化垂直速度显示（英尺/分钟）
  static String formatVerticalSpeed(double? fpm, {bool showSign = true}) {
    if (fpm == null) return '--';
    final sign = showSign && fpm > 0 ? '+' : '';
    return '$sign${fpm.toStringAsFixed(0)}';
  }

  /// 格式化温度显示（摄氏度）
  static String formatTemperature(double? celsius, {int decimals = 1}) {
    if (celsius == null) return '--';
    return celsius.toStringAsFixed(decimals);
  }

  /// 格式化频率显示（MHz）
  static String formatFrequency(double? mhz, {int decimals = 3}) {
    if (mhz == null) return '--';
    return mhz.toStringAsFixed(decimals);
  }
}
