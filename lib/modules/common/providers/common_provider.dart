/// common_provider.dart — 向后兼容导出文件
///
/// 将拆分后的各子模块统一重导出，已有引用无需修改。
/// 推荐新代码直接按需引入对应文件：
///   - flight_data_adapter.dart
///   - flight_data_provider.dart
///   - middleware_flight_data_adapter.dart
library;

export 'flight_data_adapter.dart';
export 'flight_data_provider.dart';
export 'middleware_flight_data_adapter.dart';

/// [HomeProvider]、[HomeDataAdapter]、[MiddlewareHomeDataAdapter] 的类型别名
/// 供现有引用代码继续编译通过，后续统一迁移至新命名
import 'flight_data_provider.dart';
import 'flight_data_adapter.dart';
import 'middleware_flight_data_adapter.dart';

typedef HomeProvider = FlightDataProvider;
typedef HomeDataAdapter = FlightDataAdapter;
typedef MiddlewareHomeDataAdapter = MiddlewareFlightDataAdapter;
