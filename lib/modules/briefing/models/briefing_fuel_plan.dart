/// 飞行燃油计划方案模型
/// 包含行程、备降、储备、航站楼滑行等各阶段燃油需求（单位建议为 KG）
class BriefingFuelPlan {
  /// 航程燃油 (Trip Fuel)
  final double trip;

  /// 备降燃油 (Alternate Fuel)
  final double alternate;

  /// 最终储备金燃油 (Final Reserve)
  final double reserve;

  /// 地面滑行燃油 (Taxi Fuel)
  final double taxi;

  /// 5% 意外余粮 (Extra/Contingency)
  final double extra;

  /// 总燃油需求 (Total Fuel)
  final double total;

  /// 平均油耗 (Average Flow, KG/H)
  final double avgFlow;

  /// 到达目的地的预估余油量 (Estimated Arrival Fuel)
  final double estimatedArrivalFuel;

  const BriefingFuelPlan({
    required this.trip,
    required this.alternate,
    required this.reserve,
    required this.taxi,
    required this.extra,
    required this.total,
    required this.avgFlow,
    required this.estimatedArrivalFuel,
  });
}
