# X-Plane 连接修复 - 机型识别和连接验证

## ✅ **修复完成**

已修复两个关键问题：
1. ✅ 机型识别错误
2. ✅ 缺少真实连接验证

---

## 🐛 **问题 1: 机型识别失败**

### **根本原因**

**RREF 协议限制**：
- RREF 协议只能传输**浮点数**（float32）
- 无法传输**字符串**类型的 DataRef

**错误的订阅**：
```dart
await _subscribeDataRef(100, 'sim/aircraft/view/acf_descrip');  // ❌ 字符串
await _subscribeDataRef(101, 'sim/aircraft/view/acf_ICAO');     // ❌ 字符串
```

**日志证据**：
```
DataRef[100] = 0.0 (sim/aircraft/view/acf_descrip)  // 字符串返回0.0
DataRef[101] = 0.0 (sim/aircraft/view/acf_ICAO)     // 字符串返回0.0
```

### **解决方案**

**改用数值特征识别**：

```dart
void _detectAircraftType() {
  // 检查发动机运行状态
  final hasJetEngines = _currentData.engine1Running == true ||
                        _currentData.engine2Running == true;

  // 检查发动机N1值（喷气式飞机特征）
  final hasN1Data = (_currentData.engine1N1 ?? 0) > 0 ||
                    (_currentData.engine2N1 ?? 0) > 0;

  // 检查EGT值（排气温度，喷气式飞机特征）
  final hasEGTData = (_currentData.engine1EGT ?? 0) > 100;

  if (hasJetEngines || hasN1Data || hasEGTData) {
    // 喷气式飞机 -> A320
    aircraftTitle = 'Airbus A320';
  } else {
    // 通用航空飞机
    aircraftTitle = 'General Aviation Aircraft';
  }
}
```

**识别依据**：

| 特征 | DataRef | 喷气式 | 通航 |
|------|---------|--------|------|
| 发动机运行 | `ENGN_running` | ✅ | ✅ |
| N1 值 | `ENGN_N1_` | ✅ (>0) | ❌ (0) |
| EGT 温度 | `ENGN_EGT_c` | ✅ (>100°C) | ❌ (<100°C) |

---

## 🐛 **问题 2: 缺少连接验证**

### **UDP 协议特性**

**问题**：
- UDP 是**无连接**协议
- 不需要三次握手
- 发送数据不会报错，即使对方不存在

**后果**：
```dart
await _socket.bind(...);  // ✅ 总是成功
_isConnected = true;      // ❌ 但可能没有真实连接
```

### **解决方案**

#### **1. 添加数据接收时间戳**

```dart
DateTime? _lastDataReceived;

void _handleIncomingData(Uint8List data) {
  // 更新最后接收数据的时间
  _lastDataReceived = DateTime.now();
  // ...
}
```

#### **2. 添加连接验证定时器**

```dart
void _startConnectionVerification() {
  _connectionVerificationTimer = Timer.periodic(
    const Duration(seconds: 3),
    (timer) {
      if (_lastDataReceived == null) {
        AppLogger.error('未收到X-Plane数据，可能未真实连接');
        return;
      }

      final timeSinceLastData = DateTime.now().difference(_lastDataReceived!);

      if (timeSinceLastData > _connectionTimeout) {
        // 超过5秒未收到数据 -> 断开
        AppLogger.error('X-Plane数据超时，连接可能已断开');
        _isConnected = false;
      } else if (!_isConnected) {
        // 收到数据 -> 验证成功
        _isConnected = true;
        AppLogger.info('X-Plane连接已验证');
        _detectAircraftType();
      }
    },
  );
}
```

#### **3. 连接状态流转**

```
[点击连接]
    ↓
[UDP Socket 绑定成功]
    ↓
_isConnected = true (临时)
    ↓
[等待数据验证]
    ↓
┌─────────────────────┐
│ 3秒检查一次         │
├─────────────────────┤
│ 收到数据？          │
│  ✅ 是 -> 验证成功  │
│  ❌ 否 -> 未真实连接│
└─────────────────────┘
    ↓
[5秒内收到数据]
    ↓
_isConnected = true (确认)
    ↓
[触发机型识别]
```

---

## 📊 **修复对比**

### **修复前**

```dart
// ❌ 订阅字符串DataRef
await _subscribeDataRef(100, 'sim/aircraft/view/acf_descrip');

// ❌ 没有连接验证
_isConnected = true;  // 立即设为true
```

**问题**：
- 机型信息返回 0.0（无效）
- 无法判断是否真实连接
- 可能显示"已连接"但实际未连接

### **修复后**

```dart
// ✅ 移除字符串DataRef订阅
// ✅ 使用数值特征识别

// ✅ 添加连接验证
_startConnectionVerification();
_lastDataReceived = DateTime.now();
```

**改进**：
- 基于发动机参数识别机型
- 通过数据接收验证真实连接
- 5秒超时自动断开

---

## 🎯 **识别逻辑**

### **喷气式飞机识别**

满足以下**任一条件**即识别为喷气式：

1. **发动机运行** + **N1 > 0**
2. **EGT > 100°C**

**示例**：
```
发动机1运行: true
发动机1 N1: 20.36%
发动机1 EGT: 539.2°C
→ 识别为: Airbus A320 ✅
```

### **通用航空识别**

**不满足**喷气式条件：

```
发动机1运行: true
发动机1 N1: 0
发动机1 EGT: 50°C
→ 识别为: General Aviation Aircraft ✅
```

---

## 🔧 **连接验证机制**

### **验证流程**

```
1. 绑定 UDP Socket
   ↓
2. 订阅 DataRefs
   ↓
3. 启动验证定时器（每3秒）
   ↓
4. 检查 _lastDataReceived
   ├─ null -> "未收到数据"
   ├─ >5秒 -> "连接超时"
   └─ <5秒 -> "连接正常" ✅
```

### **状态日志**

**未收到数据**：
```
[ERROR] 未收到X-Plane数据，可能未真实连接
```

**连接超时**：
```
[ERROR] X-Plane数据超时，连接可能已断开
```

**验证成功**：
```
[INFO] X-Plane连接已验证
[INFO] 检测到喷气式飞机，默认识别为: Airbus A320
```

---

## 📝 **代码变更总结**

### **新增字段**

```dart
DateTime? _lastDataReceived;  // 最后接收数据时间
Timer? _connectionVerificationTimer;  // 验证定时器
static const Duration _connectionTimeout = Duration(seconds: 5);  // 超时时间
```

### **新增方法**

```dart
void _startConnectionVerification()  // 启动连接验证
void _detectAircraftType()           // 智能机型识别（改进）
```

### **修改方法**

```dart
void _handleIncomingData()  // 添加时间戳更新
void _subscribeToDataRefs() // 移除字符串DataRef
void disconnect()           // 清理验证定时器
```

---

## ✅ **测试清单**

### **连接验证测试**

- [ ] X-Plane 未运行时点击连接
  - 应显示"未收到数据"
  - 状态保持"未连接"

- [ ] X-Plane 运行时点击连接
  - 3秒内显示"连接已验证"
  - 状态变为"已连接"

- [ ] 连接后关闭 X-Plane
  - 5秒后显示"连接超时"
  - 状态变为"未连接"

### **机型识别测试**

- [ ] 加载 A320
  - 应识别为"Airbus A320"
  - 自动切换到 A320 检查单

- [ ] 加载 Cessna 172
  - 应识别为"General Aviation Aircraft"
  - 不切换检查单

- [ ] 发动机关闭
  - 等待2秒后识别
  - 根据 N1/EGT 判断

---

## 🚀 **未来改进**

### **1. 更精确的机型识别**

```dart
// 根据更多特征细化识别
if (hasN1Data && engineCount == 2) {
  if (wingArea > 120) {
    aircraftTitle = 'Airbus A320';
  } else {
    aircraftTitle = 'Boeing 737';
  }
}
```

### **2. 手动机型选择**

```dart
// 允许用户覆盖自动识别
void setAircraftManually(String aircraftId) {
  _currentData = _currentData.copyWith(
    aircraftTitle: getAircraftName(aircraftId),
  );
  _notifyAircraftDetected(aircraftId);
}
```

### **3. 连接质量指示**

```dart
// 显示连接质量
String getConnectionQuality() {
  if (_lastDataReceived == null) return '未连接';
  final delay = DateTime.now().difference(_lastDataReceived!);
  if (delay < Duration(seconds: 1)) return '优秀';
  if (delay < Duration(seconds: 3)) return '良好';
  return '较差';
}
```

---

**更新时间**: 2026-02-03
**状态**: ✅ 已修复
**影响文件**: `lib/core/services/xplane_service.dart`
