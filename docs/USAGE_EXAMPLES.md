# 新工具类使用示例

本文档展示如何使用重构后新增的工具类。

## 1. 机场数据库 (AirportsDatabase)

### 基本使用

```dart
import 'package:owo_flight_assistant/apps/data/airports_database.dart';

// 通过 ICAO 代码查找机场
final airport = AirportsDatabase.findByIcao('ZBAA');
if (airport != null) {
  print('机场: ${airport.displayName}');  // 输出: ZBAA 北京首都
  print('坐标: (${airport.latitude}, ${airport.longitude})');
}

// 通过坐标查找最近的机场
final nearestAirport = AirportsDatabase.findNearestByCoords(40.0, 116.6);
if (nearestAirport != null) {
  print('最近的机场: ${nearestAirport.displayName}');
}

// 模糊搜索
final searchResults = AirportsDatabase.searchByName('上海');
for (final result in searchResults) {
  print(result.displayName);  // ZSPD 上海浦东, ZSSS 上海虹桥
}

// 获取所有机场
final allAirports = AirportsDatabase.allAirports;
print('机场总数: ${allAirports.length}');
```

### 扩展机场数据

```dart
// 在 airports_database.dart 中添加新机场
static const List<AirportInfo> _airports = [
  // 现有机场...

  // 新增机场
  AirportInfo(
    icaoCode: 'ZYHB',
    nameChinese: '哈尔滨太平',
    latitude: 45.623,
    longitude: 126.250,
  ),
];
```

## 2. 机型检测器 (AircraftDetector)

### 基本使用

```dart
import 'package:owo_flight_assistant/apps/utils/aircraft_detector.dart';
import 'package:owo_flight_assistant/apps/models/simulator_data.dart';

// 创建检测器实例
final detector = AircraftDetector();

// 持续检测机型
void onDataReceived(SimulatorData data) {
  final result = detector.detectAircraft(data);

  if (result != null) {
    print('检测到机型: ${result.aircraftType}');
    print('检测次数: ${result.detectionCount}');
    print('是否稳定: ${result.isStable}');

    if (result.isStable) {
      print('✓ 机型识别稳定: ${result.aircraftType}');
    }
  }
}

// 重置检测器
detector.reset();

// 获取检测进度 (0.0 ~ 1.0)
final progress = detector.detectionProgress;
print('检测进度: ${(progress * 100).toStringAsFixed(0)}%');
```

### 添加新机型识别规则

```dart
// 在 aircraft_detector.dart 的 _identifyAircraftType 方法中添加规则
String _identifyAircraftType(double n1_1, double n1_2, int flapDetents) {
  final isJet = n1_1 > 5 || n1_2 > 5 || flapDetents >= 5;

  if (isJet) {
    if (flapDetents >= 8) {
      return 'Boeing 737';
    } else if (flapDetents == 6) {
      return 'Boeing 777';  // 新增机型
    } else if (flapDetents > 0) {
      return 'Airbus A320';
    }
  }
  // ...
}
```

## 3. 数据转换器 (DataConverters)

### 单位转换

```dart
import 'package:owo_flight_assistant/apps/utils/data_converters.dart';

// 高度转换
final altitudeMeters = 1000.0;
final altitudeFeet = DataConverters.metersToFeet(altitudeMeters);
print('高度: ${altitudeFeet.toStringAsFixed(0)} 英尺');

// 速度转换
final speedMps = 100.0;
final speedKnots = DataConverters.mpsToKnots(speedMps);
print('速度: ${speedKnots.toStringAsFixed(0)} 节');

// 垂直速度转换
final vsMs = 5.0;
final vsFpm = DataConverters.mpsToFpm(vsMs);
print('垂直速度: +${vsFpm.toStringAsFixed(0)} fpm');

// 襟翼角度转换
final flapRatio = 0.5;
final flapAngle = DataConverters.flapRatioToDegrees(flapRatio);
print('襟翼角度: ${flapAngle.toStringAsFixed(0)}°');
```

### 数据格式化

```dart
// 格式化显示
final airspeed = 250.5;
final altitude = 35000.0;
final heading = 45.8;
final vs = 1500.0;

print('空速: ${DataConverters.formatSpeed(airspeed)} kt');
print('高度: ${DataConverters.formatAltitude(altitude)} ft');
print('航向: ${DataConverters.formatHeading(heading)}°');
print('垂直速度: ${DataConverters.formatVerticalSpeed(vs, showSign: true)} fpm');
```

### 字节转换

```dart
import 'dart:typed_data';

// Int32 转换
final value = 12345;
final bytes = DataConverters.int32ToBytes(value);
final decoded = DataConverters.bytesToInt32(Uint8List.fromList(bytes));
print('原值: $value, 解码: $decoded');

// Float32 转换
final floatValue = 123.45;
final floatBytes = DataConverters.float32ToBytes(floatValue);
final decodedFloat = DataConverters.bytesToFloat32(Uint8List.fromList(floatBytes));
print('原值: $floatValue, 解码: $decodedFloat');
```

## 4. X-Plane DataRefs 配置

### 基本使用

```dart
import 'package:owo_flight_assistant/apps/services/config/xplane_datarefs.dart';

// 获取单个 DataRef
final airspeedRef = XPlaneDataRefs.airspeed;
print('索引: ${airspeedRef.index}');
print('路径: ${airspeedRef.path}');
print('描述: ${airspeedRef.description}');

// 批量获取所有 DataRefs
final allRefs = XPlaneDataRefs.getAllDataRefs();
print('总计订阅: ${allRefs.length} 个 DataRef');

// 在服务中使用
for (final dataRef in allRefs) {
  await subscribeDataRef(dataRef.index, dataRef.path);
}
```

### 添加新 DataRef

```dart
// 在 xplane_datarefs.dart 中添加新的 DataRef
static const XPlaneDataRef cabinPressure = XPlaneDataRef(
  index: 80,  // 使用未使用的索引
  path: 'sim/cockpit2/pressurization/indicators/cabin_altitude_ft',
  description: '客舱高度',
);

// 在 getAllDataRefs() 中添加
static List<XPlaneDataRef> getAllDataRefs() {
  return [
    // 现有 DataRefs...
    cabinPressure,  // 新增
  ];
}
```

## 5. MSFS SimVars 配置

### 基本使用

```dart
import 'package:owo_flight_assistant/apps/services/config/msfs_simvars.dart';

// 获取单个 SimVar
final airspeed = MSFSSimVars.airspeed;
print('变量名: ${airspeed.name}');
print('单位: ${airspeed.unit}');
print('描述: ${airspeed.description}');

// 生成订阅消息
final subscriptionMsg = MSFSSimVars.generateSubscriptionMessage();
sendToWebSocket(subscriptionMsg);

// 转换为订阅格式
final subMap = airspeed.toSubscriptionMap();
// 输出: {'name': 'AIRSPEED_INDICATED', 'unit': 'knots'}
```

### 添加新 SimVar

```dart
// 在 msfs_simvars.dart 中添加新的 SimVar
static const MSFSSimVar cabinAltitude = MSFSSimVar(
  name: 'PRESSURIZATION_CABIN_ALTITUDE',
  unit: 'feet',
  description: '客舱高度',
);

// 在 getAllSimVars() 中添加
static List<MSFSSimVar> getAllSimVars() {
  return [
    // 现有 SimVars...
    cabinAltitude,  // 新增
  ];
}
```

## 完整示例：在服务中使用工具类

```dart
import 'package:owo_flight_assistant/apps/data/airports_database.dart';
import 'package:owo_flight_assistant/apps/utils/aircraft_detector.dart';
import 'package:owo_flight_assistant/apps/utils/data_converters.dart';
import 'package:owo_flight_assistant/apps/models/simulator_data.dart';

class MySimulatorService {
  final AircraftDetector _detector = AircraftDetector();

  void onDataUpdate(double lat, double lon, double altMeters, SimulatorData data) {
    // 1. 查找机场
    final airport = AirportsDatabase.findNearestByCoords(lat, lon);
    if (airport != null) {
      print('当前位置: ${airport.displayName}');
    }

    // 2. 检测机型
    final detection = _detector.detectAircraft(data);
    if (detection?.isStable ?? false) {
      print('识别到机型: ${detection!.aircraftType}');
    }

    // 3. 转换高度
    final altitudeFeet = DataConverters.metersToFeet(altMeters);
    print('高度: ${DataConverters.formatAltitude(altitudeFeet)} ft');
  }
}
```

---

通过使用这些工具类，您可以：
- ✅ 减少重复代码
- ✅ 提高代码可读性
- ✅ 简化维护工作
- ✅ 便于扩展新功能
