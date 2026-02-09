# X-Plane 连接和数据获取 - 调试指南

## 🔍 当前状态

已完成 XPlaneService 的扩展，新增了以下功能：
- ✅ 订阅 20+ 新的 DataRefs
- ✅ 添加机型自动识别逻辑
- ✅ 扩展数据处理方法

---

## 📊 **已订阅的 DataRefs**

### **飞行数据** (索引 0-7)
| 索引 | DataRef | 说明 |
|------|---------|------|
| 0 | sim/flightmodel/position/indicated_airspeed | 指示空速 |
| 1 | sim/flightmodel/position/elevation | 高度 |
| 2 | sim/flightmodel/position/mag_psi | 航向 |
| 3 | sim/flightmodel/position/vh_ind | 垂直速度 |
| 4 | sim/flightmodel/position/latitude | 纬度 |
| 5 | sim/flightmodel/position/longitude | 经度 |
| 6 | sim/flightmodel/position/groundspeed | 地速 |
| 7 | sim/flightmodel/position/true_airspeed | 真空速 |

### **系统状态** (索引 10-17)
| 索引 | DataRef | 说明 |
|------|---------|------|
| 10 | sim/cockpit2/controls/parking_brake_ratio | 停机刹车 |
| 11 | sim/cockpit/electrical/beacon_lights_on | 信标灯 |
| 12 | sim/cockpit/electrical/landing_lights_on | 着陆灯 |
| 13 | sim/cockpit/electrical/taxi_light_on | 滑行灯 |
| 14 | sim/cockpit/electrical/nav_lights_on | 导航灯 |
| 15 | sim/cockpit/electrical/strobe_lights_on | 频闪灯 |
| 16 | sim/flightmodel/controls/flaprqst | 襟翼位置 |
| 17 | sim/aircraft/parts/acf_gear_deploy | 起落架 |

### **发动机** (索引 20-22, 60-63)
| 索引 | DataRef | 说明 |
|------|---------|------|
| 20 | sim/cockpit/engine/APU_running | APU |
| 21 | sim/flightmodel/engine/ENGN_running[0] | 发动机1运行 |
| 22 | sim/flightmodel/engine/ENGN_running[1] | 发动机2运行 |
| 60 | sim/flightmodel/engine/ENGN_N1_[0] | 发动机1 N1 |
| 61 | sim/flightmodel/engine/ENGN_N1_[1] | 发动机2 N1 |
| 62 | sim/flightmodel/engine/ENGN_EGT_c[0] | 发动机1 EGT |
| 63 | sim/flightmodel/engine/ENGN_EGT_c[1] | 发动机2 EGT |

### **自动驾驶** (索引 30-31)
| 索引 | DataRef | 说明 |
|------|---------|------|
| 30 | sim/cockpit/autopilot/autopilot_mode | 自动驾驶 |
| 31 | sim/cockpit/autopilot/autothrottle_on | 自动油门 |

### **环境数据** (索引 40-43)
| 索引 | DataRef | 说明 |
|------|---------|------|
| 40 | sim/weather/temperature_ambient_c | 外部温度 |
| 41 | sim/weather/temperature_le_c | 总温度 |
| 42 | sim/weather/wind_speed_kt | 风速 |
| 43 | sim/weather/wind_direction_degt | 风向 |

### **燃油** (索引 50-51)
| 索引 | DataRef | 说明 |
|------|---------|------|
| 50 | sim/flightmodel/weight/m_fuel_total | 总燃油量 |
| 51 | sim/cockpit2/engine/indicators/fuel_flow_kg_sec[0] | 燃油流量 |

### **机型信息** (索引 100-103)
| 索引 | DataRef | 说明 |
|------|---------|------|
| 100 | sim/aircraft/view/acf_ICAO | ICAO代码 (字符串) |
| 101 | sim/aircraft/view/acf_descrip | 机型描述 (字符串) |
| 102 | sim/aircraft/engine/acf_num_engines | 发动机数量 |
| 103 | sim/aircraft/geometry/wing_area | 机翼面积 |

---

## ⚠️ **已知问题**

### **1. X-Plane UDP Data Output 与 RREF 的区别**

**重要**: X-Plane 的 "Data Output" 设置和我们使用的 RREF 协议是**两个完全不同的系统**！

- **Data Output (Settings → Data Output)**:
  - 发送预定义的数据包
  - 使用固定的数据格式
  - 不需要订阅，直接发送

- **RREF 协议** (我们使用的):
  - 需要主动订阅 DataRefs
  - 自定义数据点
  - 更灵活，但需要正确的订阅

**结论**: 即使您在 X-Plane 中启用了 Data Output，我们的应用也不会接收这些数据，因为我们使用的是 RREF 订阅机制。

---

## 🔧 **调试步骤**

### **步骤 1: 检查 X-Plane 设置**

1. 启动 X-Plane
2. 加载任意飞机（建议 A320 或 B737）
3. **不需要**在 Settings → Data Output 中设置任何东西
4. 确保 X-Plane 正在运行

### **步骤 2: 检查网络连接**

1. 确认 X-Plane 监听端口 **49000**
2. 确认应用监听端口 **49001**
3. 检查防火墙是否允许 UDP 通信

### **步骤 3: 连接并查看日志**

1. 在应用中点击"连接 X-Plane"
2. 查看控制台日志，应该看到：
   ```
   [INFO] 正在连接到 X-Plane...
   [INFO] 已连接到 X-Plane
   [INFO] 检测到机型: Airbus A320
   ```

### **步骤 4: 检查数据接收**

如果连接成功但没有数据：

1. **检查 RREF 订阅是否成功**
   - 查看日志中是否有错误
   - 确认 X-Plane 版本支持 RREF (11/12 都支持)

2. **检查 DataRef 名称**
   - 某些 DataRef 可能在不同版本的 X-Plane 中有所不同
   - 使用 DataRefTool 插件验证 DataRef 名称

3. **检查数据更新频率**
   - 当前设置为 5 Hz (每秒5次)
   - 可以在代码中调整

---

## 🐛 **常见问题**

### **Q1: 连接成功但所有数据显示 N/A**

**可能原因**:
1. RREF 订阅未成功
2. DataRef 名称不正确
3. X-Plane 未发送数据

**解决方法**:
1. 检查 X-Plane 控制台是否有错误
2. 使用 DataRefTool 验证 DataRef
3. 尝试重启 X-Plane 和应用

### **Q2: 无法识别机型**

**当前实现**:
- 连接后 2 秒尝试识别
- 基于发动机状态判断
- 默认识别为 A320

**改进方案**:
1. 使用更多 DataRef 组合判断
2. 允许用户手动选择机型
3. 保存机型偏好设置

### **Q3: 部分数据正常，部分显示 N/A**

**可能原因**:
1. 某些 DataRef 在当前飞机上不可用
2. DataRef 名称在您的 X-Plane 版本中不同
3. 数据尚未初始化

**解决方法**:
1. 等待几秒让数据初始化
2. 检查特定 DataRef 是否存在
3. 使用 DataRefTool 查看实际值

---

## 🔍 **调试工具**

### **推荐使用 DataRefTool**

DataRefTool 是一个 X-Plane 插件，可以：
- 查看所有可用的 DataRefs
- 实时监控 DataRef 值
- 验证 DataRef 名称是否正确

**下载**: https://github.com/leecbaker/datareftool

**使用方法**:
1. 安装 DataRefTool 到 X-Plane
2. 在 X-Plane 中打开 Plugins → DataRefTool
3. 搜索我们订阅的 DataRef
4. 确认它们存在且有值

---

## 📝 **下一步优化**

### **1. 改进机型识别**

当前方法比较简单，可以改进为：

```dart
void _detectAircraftType() {
  // 方案1: 基于多个DataRef组合判断
  final numEngines = _engineCount;
  final wingArea = _wingArea;
  final maxWeight = _maxWeight;

  // 方案2: 使用机型数据库匹配
  // 方案3: 允许用户手动选择并保存偏好
}
```

### **2. 添加数据验证**

```dart
void _updateDataByIndex(int index, double value) {
  // 添加数据范围验证
  if (index == 0 && value < 0) {
    AppLogger.warn('空速数据异常: $value');
    return;
  }

  // 添加数据变化检测
  if (_hasSignificantChange(index, value)) {
    // 更新数据
  }
}
```

### **3. 添加重连机制**

```dart
void _startHeartbeat() {
  _heartbeatTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
    if (_isConnected && _socket != null) {
      // 检查是否收到数据
      if (_lastDataTime.difference(DateTime.now()).inSeconds > 5) {
        AppLogger.warn('未收到数据，尝试重连...');
        _reconnect();
      }
    }
  });
}
```

---

## 💡 **临时解决方案**

如果机型识别仍然有问题，可以使用以下临时方案：

### **方案 1: 手动触发机型识别**

在主页添加一个按钮，允许用户手动选择机型：

```dart
ElevatedButton(
  onPressed: () {
    simProvider.setAircraftTitle('Airbus A320');
  },
  child: Text('设置为 A320'),
)
```

### **方案 2: 使用配置文件**

创建一个配置文件，保存用户的机型偏好：

```json
{
  "preferred_aircraft": "A320",
  "auto_detect": true
}
```

### **方案 3: 基于飞行计划**

如果用户输入了飞行计划，可以从中推断机型。

---

## 🎯 **测试清单**

- [ ] X-Plane 已启动
- [ ] 加载了 A320 或 B737
- [ ] 应用成功连接
- [ ] 主页显示"已连接到 X-Plane"
- [ ] 空速、高度、航向、垂直速度有数据
- [ ] 地速、经纬度有数据
- [ ] 温度、风速有数据
- [ ] 发动机参数有数据
- [ ] 系统状态徽章显示
- [ ] 机型自动识别成功

---

**更新时间**: 2026-02-03
**状态**: 🔧 调试中
**下一步**: 验证数据接收并优化机型识别
