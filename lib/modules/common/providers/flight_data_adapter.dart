import '../models/common_models.dart';

/// 飞行数据适配器抽象接口
///
/// 定义获取模拟器飞行数据所需的所有操作契约。
/// 具体实现（如 [MiddlewareFlightDataAdapter]）负责与后端通信细节。
abstract class FlightDataAdapter {
  /// 飞行数据实时流，每次数据更新时推送新的 [FlightDataSnapshot]
  Stream<FlightDataSnapshot> get stream;

  /// 连接指定类型的模拟器
  Future<bool> connect(SimulatorType type);

  /// 断开模拟器连接
  Future<void> disconnect();

  /// 刷新后端服务健康状态
  Future<bool> refreshBackendHealth();

  /// 获取当前飞行数据轮询间隔（毫秒）
  Future<int> getFlightDataIntervalMs();

  /// 设置飞行数据轮询间隔（毫秒）
  Future<void> setFlightDataIntervalMs(int milliseconds);

  /// 设置当前飞行航班号
  Future<void> setFlightNumber(String? value);

  /// 设置出发机场
  Future<void> setDeparture(AirportInfo? airport);

  /// 设置目的地机场
  Future<void> setDestination(AirportInfo? airport);

  /// 设置备降机场
  Future<void> setAlternate(AirportInfo? airport);

  /// 按关键词搜索机场
  Future<List<AirportInfo>> searchAirports(String keyword);

  /// 刷新指定机场的 METAR 气象数据
  Future<void> refreshMetar(AirportInfo airport);
}
