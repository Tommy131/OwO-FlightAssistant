/// 自动计时器触发模式枚举
///
/// 用于 HUD 飞行计时器的「自动启停」功能配置，由用户在设置页选择。
library;

/// 自动计时器**启动**条件
enum MapAutoTimerStartMode {
  /// 跑道滑行触发：飞机在跑道/端头附近、地速 ≥ 8kt、停机刹车已释放
  runwayMovement,

  /// 推机/松刹车触发：停机刹车从 ON 变 OFF 且地速 ≥ 2kt
  pushback,

  /// 任意移动触发：只要飞机开始移动即启动
  anyMovement,
}

/// 自动计时器**停止**条件
enum MapAutoTimerStopMode {
  /// 稳定落地：落地后地速 ≤ 35kt 且垂直速度 ≤ 220 fpm，持续 6 秒
  stableLanding,

  /// 脱离跑道后：落地后地速 ≤ 22kt 且垂直速度 ≤ 300 fpm，持续 5 秒
  runwayExitAfterLanding,

  /// 抵达停机位：地面停机刹车从 OFF 变 ON 且地速 ≤ 0.1kt
  parkingArrival,
}
