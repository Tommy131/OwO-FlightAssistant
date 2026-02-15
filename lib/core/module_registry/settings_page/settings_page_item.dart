import 'package:flutter/material.dart';

/// 设置页面项抽象类
abstract class SettingsPageItem {
  /// 页面唯一标识符
  String get id;

  /// 页面标题（支持国际化）
  String getTitle(BuildContext context);

  /// 页面图标
  IconData get icon;

  /// 页面优先级（数字越小越靠前，默认100）
  int get priority => 100;

  /// 页面描述（可选，支持国际化）
  String? getDescription(BuildContext context) => null;

  /// 构建页面内容
  Widget build(BuildContext context);
}
