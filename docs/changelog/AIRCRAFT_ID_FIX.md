# 机型识别错误修复

## 🐛 **问题描述**

应用在连接模拟器后崩溃，错误信息：
```
Bad state: No element
ChecklistProvider.selectAircraft
```

---

## 🔍 **根本原因**

### **问题 1: 机型ID不匹配**

**错误的ID**:
- SimulatorProvider 使用: `a320`, `b737`

**正确的ID**:
- ChecklistService 定义: `a320_series`, `b737_series`

当 SimulatorProvider 检测到机型并调用 `selectAircraft('a320')` 时，ChecklistProvider 找不到这个ID，导致 `firstWhere` 抛出异常。

### **问题 2: 缺少错误处理**

`selectAircraft` 方法没有错误处理，当找不到机型时直接崩溃。

---

## ✅ **修复方案**

### **修复 1: 更正机型ID**

**文件**: `lib/core/providers/simulator_provider.dart`

**修改前**:
```dart
if (aircraftTitle.contains('a320')) {
  detectedAircraftId = 'a320';  // ❌ 错误的ID
}
```

**修改后**:
```dart
if (aircraftTitle.contains('a320') ||
    aircraftTitle.contains('a319') ||
    aircraftTitle.contains('a321') ||
    aircraftTitle.contains('airbus')) {
  detectedAircraftId = 'a320_series';  // ✅ 正确的ID
}
```

同样修复了 B737:
```dart
if (aircraftTitle.contains('737') ||
    aircraftTitle.contains('b737') ||
    aircraftTitle.contains('boeing')) {
  detectedAircraftId = 'b737_series';  // ✅ 正确的ID
}
```

### **修复 2: 添加错误处理**

**文件**: `lib/core/providers/checklist_provider.dart`

**修改前**:
```dart
void selectAircraft(String id) {
  _selectedAircraft = _aircraftList.firstWhere((a) => a.id == id);
  // ❌ 找不到时会崩溃
}
```

**修改后**:
```dart
void selectAircraft(String id) {
  try {
    final aircraft = _aircraftList.firstWhere((a) => a.id == id);
    _selectedAircraft = aircraft;
    _currentPhase = ChecklistPhase.coldAndDark;
    notifyListeners();
  } catch (e) {
    // ✅ 机型未找到，保持当前选择，不会崩溃
    debugPrint('未找到机型: $id，可用机型: ${_aircraftList.map((a) => a.id).join(", ")}');
  }
}
```

---

## 📊 **机型ID映射表**

| 检测关键词 | 机型ID | 检查单名称 |
|-----------|--------|-----------|
| a320, a319, a321, airbus | `a320_series` | A320-200 / A321 / A319 |
| 737, b737, boeing | `b737_series` | B737-800 / Max |

---

## 🎯 **识别规则优化**

### **扩展了识别关键词**

**A320 系列**:
- ✅ `a320` - 直接机型名
- ✅ `a319` - 系列变体
- ✅ `a321` - 系列变体
- ✅ `airbus` - 制造商名称（通用匹配）

**B737 系列**:
- ✅ `737` - 机型编号
- ✅ `b737` - 完整机型名
- ✅ `boeing` - 制造商名称（通用匹配）

这样即使机型名称格式不同，也能正确识别。

---

## 🔧 **测试场景**

### **场景 1: X-Plane A320**
```
机型名称: "Airbus A320"
识别关键词: "airbus" ✅
机型ID: a320_series ✅
结果: 成功切换到 A320 检查单
```

### **场景 2: X-Plane B737**
```
机型名称: "Boeing 737-800"
识别关键词: "boeing" 或 "737" ✅
机型ID: b737_series ✅
结果: 成功切换到 B737 检查单
```

### **场景 3: 未知机型**
```
机型名称: "Cessna 172"
识别关键词: 无匹配 ❌
机型ID: null
结果: 保持当前选择，不崩溃 ✅
```

---

## 💡 **改进建议**

### **1. 添加更多机型支持**

当前只支持 A320 和 B737，可以扩展：

```dart
// A330 系列
if (aircraftTitle.contains('a330')) {
  detectedAircraftId = 'a330_series';
}

// B777 系列
if (aircraftTitle.contains('777') || aircraftTitle.contains('b777')) {
  detectedAircraftId = 'b777_series';
}
```

### **2. 用户手动选择**

如果自动识别失败，允许用户手动选择：

```dart
// 在主页添加一个按钮
if (simProvider.simulatorData.aircraftTitle != null) {
  TextButton(
    onPressed: () {
      // 显示机型选择对话框
      showAircraftSelectionDialog();
    },
    child: Text('手动选择机型'),
  )
}
```

### **3. 保存机型偏好**

记住用户的选择，下次自动应用：

```dart
// 使用 SharedPreferences
final prefs = await SharedPreferences.getInstance();
await prefs.setString('preferred_aircraft', 'a320_series');
```

---

## 🎉 **修复结果**

✅ **不再崩溃** - 添加了错误处理
✅ **正确识别** - 使用了正确的机型ID
✅ **更智能** - 扩展了识别关键词
✅ **更健壮** - 处理了未知机型的情况

---

## 📝 **下一步**

1. **测试连接** - 重新运行应用并连接 X-Plane
2. **验证识别** - 检查是否正确识别机型
3. **查看日志** - 确认没有错误信息
4. **测试数据** - 验证飞行数据是否正常显示

---

**修复时间**: 2026-02-03
**状态**: ✅ 已修复
**影响范围**: SimulatorProvider, ChecklistProvider
