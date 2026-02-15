import 'wizard_step.dart';

/// 向导步骤注册表
class WizardStepRegistry {
  static final WizardStepRegistry _instance = WizardStepRegistry._internal();
  factory WizardStepRegistry() => _instance;
  WizardStepRegistry._internal();

  final Map<String, WizardStep Function()> _stepFactories = {};

  /// 注册向导步骤
  void register(String id, WizardStep Function() factory, {int? priority}) {
    _stepFactories[id] = factory;
  }

  /// 获取所有已注册的步骤（按优先级排序）
  List<WizardStep> getAllSteps() {
    final steps = _stepFactories.values.map((factory) => factory()).toList();
    steps.sort((a, b) => a.priority.compareTo(b.priority));
    return steps;
  }

  /// 根据ID获取步骤
  WizardStep? getStep(String id) {
    final factory = _stepFactories[id];
    return factory?.call();
  }

  /// 清空所有注册
  void clear() {
    _stepFactories.clear();
  }
}
