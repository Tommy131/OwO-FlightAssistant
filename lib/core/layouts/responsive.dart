import 'package:flutter/material.dart';

// import '../utils/logger.dart';

/// 响应式布局辅助类
/// 用于判断当前设备类型并提供响应式布局支持
class Responsive extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget desktop;

  const Responsive({
    super.key,
    required this.mobile,
    this.tablet,
    required this.desktop,
  });

  /// 判断是否为移动设备
  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < 650;

  /// 判断是否为平板设备
  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= 650 &&
      MediaQuery.of(context).size.width < 1242;

  /// 判断是否为桌面设备
  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= 1242;

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;

    // 调试输出：当前窗口宽度
    /* AppLogger.debug(
      'Window Width: ${size.width.toStringAsFixed(2)} | Type: ${size.width >= 1242 ? "Desktop" : (size.width >= 650 ? "Tablet" : "Mobile")}',
    ); */

    // 桌面端
    if (size.width >= 1242) {
      return desktop;
    }
    // 平板端（如果提供了tablet布局则使用，否则使用mobile）
    else if (size.width >= 650) {
      return tablet ?? mobile;
    }
    // 移动端
    else {
      return mobile;
    }
  }
}
