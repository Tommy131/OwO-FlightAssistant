import 'map_aircraft_state.dart';
import 'map_airport.dart';
import 'map_coordinate.dart';

/// 地图数据快照
///
/// 封装某一时刻的完整地图数据，是适配器流推送给 [MapProvider] 的基本单元。
class MapDataSnapshot {
  /// 当前飞机状态（未连接时为 null）
  final MapAircraftState? aircraft;

  /// 历史飞行轨迹点列表
  final List<MapRoutePoint> route;

  /// 当前可见机场标记列表
  final List<MapAirportMarker> airports;

  /// 是否已连接到模拟器
  final bool isConnected;

  const MapDataSnapshot({
    this.aircraft,
    this.route = const [],
    this.airports = const [],
    this.isConnected = false,
  });
}

/// 地图数据适配器接口
///
/// 由各平台（FlightSimulator、MSFS、X-Plane 等）的具体适配器实现，
/// 通过 [stream] 向 [MapProvider] 推送实时数据快照。
abstract class MapDataAdapter {
  /// 实时数据快照流（每次飞行数据更新时发出新快照）
  Stream<MapDataSnapshot> get stream;
}
