import 'package:flutter/material.dart';

/// 关于页面卡片模型
class AboutPageItem {
  final String id;
  final Widget Function(BuildContext) builder;
  final int priority;

  const AboutPageItem({
    required this.id,
    required this.builder,
    this.priority = 100,
  });
}
