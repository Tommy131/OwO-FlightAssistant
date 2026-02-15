import 'package:flutter/material.dart';

/// 引导步骤的抽象基类
abstract class WizardStep {
  /// 步骤唯一标识符
  String get id;

  /// 步骤标题
  String get title;

  /// 步骤优先级（数字越小越靠前，默认100）
  int get priority => 100;

  /// 是否可以进入下一步
  bool canGoNext();

  /// 构建步骤UI
  Widget build(BuildContext context);

  /// 步骤完成时的回调（可选）
  Future<void> onComplete() async {}

  /// 步骤初始化时的回调（可选）
  void onInit() {}

  /// 获取步骤配置摘要（可选）
  /// 返回 Map，key 为配置项名称，value 为配置值
  Map<String, String>? getSummary() => null;
}
