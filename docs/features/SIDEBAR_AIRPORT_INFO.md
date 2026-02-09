# 侧边栏机场信息显示 - 更新说明

## ✅ **更新完成**

已将侧边栏左下角的 **User 显示区域** 改为 **机场信息显示区域**。

---

## 🎯 **主要变更**

### **1. 显示逻辑**

#### **未连接模拟器**
- ❌ 不显示任何内容
- 底部区域完全隐藏

#### **已连接但无机场数据**
- ❌ 不显示任何内容
- 等待机场数据获取

#### **已连接且有机场数据**
- ✅ 显示机场信息
- 图标：飞机起飞图标 ✈️
- 内容：机场代码、跑道、ATIS频率

---

## 📊 **UI 对比**

### **修改前 - User 信息**

**展开状态**:
```
┌─────────────────┐
│ 👤  User        │
│     user@mail   │
└─────────────────┘
```

**折叠状态**:
```
┌────┐
│ 👤 │
└────┘
```

### **修改后 - 机场信息**

**展开状态（已连接且有数据）**:
```
┌─────────────────┐
│ ✈️  ZBAA        │
│     跑道: --    │
│     ATIS: ---   │
└─────────────────┘
```

**折叠状态（已连接且有数据）**:
```
┌────┐
│ ✈️ │
└────┘
```

**未连接或无数据**:
```
（不显示任何内容）
```

---

## 🔧 **技术实现**

### **文件修改**: `lib/core/widgets/desktop/sidebar.dart`

#### **1. 添加导入**
```dart
import '../../providers/simulator_provider.dart';
```

#### **2. 更新 _buildAvatar 方法**

**修改前**:
```dart
Widget _buildAvatar(ThemeData theme) {
  return CircleAvatar(
    child: Icon(Icons.person),  // 固定显示人物图标
  );
}
```

**修改后**:
```dart
Widget _buildAvatar(ThemeData theme) {
  return Consumer<SimulatorProvider>(
    builder: (context, simProvider, _) {
      final isConnected = simProvider.isConnected;
      final hasAirportData = simProvider.simulatorData.departureAirport != null ||
                             simProvider.simulatorData.arrivalAirport != null;

      // 如果未连接或没有机场数据，不显示
      if (!isConnected || !hasAirportData) {
        return const SizedBox.shrink();
      }

      return CircleAvatar(
        child: Icon(Icons.flight_takeoff),  // 显示飞机图标
      );
    },
  );
}
```

#### **3. 更新 _buildUserInfo 方法**

**修改前**:
```dart
Widget _buildUserInfo(ThemeData theme) {
  return Expanded(
    child: Column(
      children: [
        Text('User'),
        Text('user@mail.com'),
      ],
    ),
  );
}
```

**修改后**:
```dart
Widget _buildUserInfo(ThemeData theme) {
  return Consumer<SimulatorProvider>(
    builder: (context, simProvider, _) {
      // 如果未连接，不显示
      if (!simProvider.isConnected) {
        return const SizedBox.shrink();
      }

      final data = simProvider.simulatorData;

      // 如果没有机场数据，不显示
      if (data.departureAirport == null && data.arrivalAirport == null) {
        return const SizedBox.shrink();
      }

      // 显示机场信息
      final airport = data.departureAirport ?? data.arrivalAirport ?? '';

      return Expanded(
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.flight_takeoff, size: 12),
                SizedBox(width: 4),
                Text(airport, fontWeight: FontWeight.w600),
              ],
            ),
            SizedBox(height: 2),
            Text('跑道: --  ATIS: ---', fontSize: 11),
          ],
        ),
      );
    },
  );
}
```

---

## 📋 **显示内容**

### **当前显示**

| 字段 | 数据源 | 示例 |
|------|--------|------|
| 机场代码 | `departureAirport` 或 `arrivalAirport` | ZBAA |
| 跑道 | 待实现 | -- |
| ATIS频率 | 待实现 | --- |

### **数据优先级**

```dart
final airport = data.departureAirport ?? data.arrivalAirport ?? '';
```

- 优先显示起飞机场（`departureAirport`）
- 如果没有，显示目的机场（`arrivalAirport`）
- 如果都没有，不显示整个区域

---

## 🔄 **动态行为**

### **场景 1: 应用启动**
```
状态: 未连接
显示: （无）
```

### **场景 2: 连接模拟器**
```
状态: 已连接，等待数据
显示: （无）
```

### **场景 3: 接收到机场数据**
```
状态: 已连接，有机场数据
显示: ✈️ ZBAA
      跑道: --  ATIS: ---
```

### **场景 4: 断开连接**
```
状态: 未连接
显示: （无）
```

---

## 🚀 **下一步扩展**

### **1. 添加跑道信息**

需要在 `SimulatorData` 中添加跑道字段：

```dart
class SimulatorData {
  final String? activeRunway;  // 当前使用的跑道
  // ...
}
```

然后在 XPlaneService 中订阅相关 DataRef：

```dart
await _subscribeDataRef(110, 'sim/airport/runway_in_use');
```

### **2. 添加 ATIS 频率**

```dart
class SimulatorData {
  final double? atisFrequency;  // ATIS 频率
  // ...
}
```

订阅 DataRef：

```dart
await _subscribeDataRef(111, 'sim/cockpit2/radios/actuators/com1_frequency_hz');
```

### **3. 更新显示逻辑**

```dart
Text(
  '跑道: ${data.activeRunway ?? "--"}  ATIS: ${data.atisFrequency?.toStringAsFixed(2) ?? "---"}',
  style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
)
```

---

## 💡 **设计考虑**

### **为什么不显示而不是显示占位符？**

**选择**: 完全隐藏区域（`SizedBox.shrink()`）

**原因**:
1. **更简洁** - 避免显示无用信息
2. **更专业** - 只在有数据时显示
3. **更灵活** - 侧边栏可以完全用于导航

**替代方案**:
```dart
// 方案1: 显示"未连接"占位符
if (!isConnected) {
  return Text('未连接模拟器');
}

// 方案2: 显示默认图标
if (!isConnected) {
  return Icon(Icons.flight_land);
}
```

---

## 🎨 **视觉效果**

### **图标选择**

- ✈️ `Icons.flight_takeoff` - 起飞图标
- 表示机场信息
- 与航空主题一致

### **颜色方案**

- 图标颜色：主题色（`theme.colorScheme.primary`）
- 背景：主题色 20% 透明度
- 文字：主题文字颜色

### **字体大小**

- 机场代码：13px，粗体
- 跑道/ATIS：11px，常规

---

## ✅ **测试清单**

- [ ] 未连接时不显示底部区域
- [ ] 连接后无机场数据时不显示
- [ ] 有机场数据时正确显示
- [ ] 展开/折叠状态正常切换
- [ ] 断开连接后区域消失
- [ ] 重新连接后区域重新出现
- [ ] 机场代码正确显示
- [ ] 图标颜色正确

---

## 📝 **已知限制**

### **当前限制**

1. **跑道信息**: 显示为 `--`（待实现）
2. **ATIS频率**: 显示为 `---`（待实现）
3. **机场详情**: 只显示代码，无详细信息

### **未来改进**

1. **添加跑道数据订阅**
2. **添加 ATIS 频率订阅**
3. **显示机场全名**（如果可用）
4. **添加点击查看详情功能**

---

**更新时间**: 2026-02-03
**状态**: ✅ 已完成
**影响文件**: `lib/core/widgets/desktop/sidebar.dart`
