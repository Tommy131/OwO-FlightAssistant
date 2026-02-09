# 飞行简报验证与重量数据集成

## 概述

本文档描述了飞行简报功能的两个重要优化：
1. **ICAO机场代码实时验证**：确保用户输入有效的机场代码
2. **模拟器重量数据集成**：当模拟器连接时，使用实时重量数据

## 功能详情

### 1. ICAO机场代码实时验证

#### 验证时机
- **回车键触发**：用户在输入框中按下回车键时
- **失焦触发**：用户点击其他区域，输入框失去焦点时

#### 验证逻辑
1. 检查输入是否为4位字符
2. 验证字符格式（仅允许A-Z和0-9）
3. 在机场数据库中查询ICAO代码
4. 显示验证结果：
   - ✅ 有效：显示机场中文名称
   - ❌ 无效：显示错误提示"未找到机场: XXXX"

#### 生成简报限制
只有满足以下条件才能生成简报：
- ✅ 起飞机场ICAO代码有效
- ✅ 到达机场ICAO代码有效
- ✅ 备降机场（如果填写）ICAO代码有效或为空

如果任一必填机场代码无效，生成按钮将被禁用，并显示相应提示信息。

#### 实现文件
- `lib/core/widgets/common/airport_search_field.dart`
  - 添加了 `_validationError` 状态
  - 增强了 `_onFocusChanged()` 方法
  - 增强了 `onFieldSubmitted` 回调
  - 改进了 `_validateAndNotify()` 方法

- `lib/pages/briefing/widgets/briefing_input_card.dart`
  - 添加了验证状态标志：`_isDepartureValid`, `_isArrivalValid`, `_isAlternateValid`
  - 新增 `_canGenerateBriefing()` 方法检查是否可以生成
  - 新增 `_getValidationMessage()` 方法提供验证提示
  - 更新了 `onAirportSelected` 回调以跟踪验证状态

### 2. 模拟器重量数据集成

#### 数据来源
当模拟器连接成功时，从 `SimulatorProvider` 获取以下数据：
- **总重量** (`totalWeight`): 飞机当前总重量
- **空机重量** (`emptyWeight`): 飞机空载重量
- **载荷重量** (`payloadWeight`): 乘客、货物等载荷重量
- **燃油重量** (`fuelQuantity`): 当前机载燃油重量

#### 重量计算逻辑

##### 使用模拟器数据时（模拟器已连接）
```dart
起飞重量 (TOW) = 模拟器总重量
零燃油重量 (ZFW) = 空机重量 + 载荷重量
落地重量 (LW) = 起飞重量 - 航程燃油
```

##### 使用默认数据时（模拟器未连接）
```dart
零燃油重量 (ZFW) = 42000 kg (固定值)
起飞重量 (TOW) = ZFW + 总燃油
落地重量 (LW) = ZFW + 剩余燃油 (约20%总燃油)
```

#### 数据流程
1. **输入阶段** (`briefing_input_card.dart`)
   - 检查模拟器连接状态
   - 如果已连接，提取重量数据
   - 将数据传递给 `BriefingProvider`

2. **处理阶段** (`briefing_provider.dart`)
   - 接收模拟器重量参数
   - 转发给 `BriefingService`

3. **生成阶段** (`briefing_service.dart`)
   - 优先使用模拟器数据
   - 如果模拟器数据不可用，使用默认计算
   - 记录日志以便调试

4. **显示阶段** (`briefing_display_card.dart`)
   - 在"重量信息"卡片中显示计算结果
   - 无需修改，自动显示新数据

#### 实现文件
- `lib/pages/briefing/widgets/briefing_input_card.dart`
  - 在 `_generateBriefing()` 中获取模拟器数据
  - 传递重量参数到 provider

- `lib/apps/providers/briefing_provider.dart`
  - 添加模拟器重量参数到 `generateBriefing()` 方法
  - 转发参数到 service

- `lib/apps/services/briefing_service.dart`
  - 添加模拟器重量参数到 `generateBriefing()` 方法
  - 实现智能重量计算逻辑
  - 添加日志记录

## 用户体验改进

### ICAO验证
- ✅ 即时反馈：用户输入后立即知道是否有效
- ✅ 防止错误：无效代码无法生成简报
- ✅ 清晰提示：明确告知用户哪个字段有问题

### 重量数据集成
- ✅ 自动化：模拟器连接时自动使用实时数据
- ✅ 准确性：使用真实飞机数据而非估算值
- ✅ 透明性：日志记录数据来源，便于调试

## 技术细节

### 验证状态管理
```dart
// 三个布尔标志跟踪验证状态
bool _isDepartureValid = false;
bool _isArrivalValid = false;
bool _isAlternateValid = true; // 备降机场可选，默认有效

// 检查是否可以生成简报
bool _canGenerateBriefing() {
  return _isDepartureValid && 
         _isArrivalValid && 
         _isAlternateValid;
}
```

### 模拟器数据提取
```dart
// 仅在模拟器连接时提取数据
if (simProvider.isConnected) {
  simulatorTotalWeight = simProvider.simulatorData.totalWeight?.round();
  simulatorEmptyWeight = simProvider.simulatorData.emptyWeight?.round();
  simulatorPayloadWeight = simProvider.simulatorData.payloadWeight?.round();
  simulatorFuelWeight = simProvider.simulatorData.fuelQuantity;
}
```

### 智能重量计算
```dart
if (simulatorTotalWeight != null && simulatorEmptyWeight != null) {
  // 使用模拟器数据
  takeoffWeight = simulatorTotalWeight;
  zeroFuelWeight = simulatorEmptyWeight + (simulatorPayloadWeight ?? 0);
  landingWeight = (takeoffWeight - tripFuel).round();
} else {
  // 使用默认计算
  zeroFuelWeight = 42000;
  takeoffWeight = _calculateWeight(totalFuel, 'takeoff');
  landingWeight = _calculateWeight(totalFuel, 'landing');
}
```

## 测试建议

### ICAO验证测试
1. 输入有效的ICAO代码（如 VHHH, ZBAA）
2. 输入无效的ICAO代码（如 XXXX, 1234）
3. 输入不完整的代码（如 VH, ZBA）
4. 测试回车键触发验证
5. 测试失焦触发验证
6. 验证备降机场的可选性

### 重量数据集成测试
1. **模拟器未连接**
   - 生成简报
   - 验证使用默认重量数据

2. **模拟器已连接**
   - 连接X-Plane或其他模拟器
   - 生成简报
   - 验证使用模拟器实时数据
   - 检查日志确认数据来源

3. **边界情况**
   - 模拟器连接但数据不完整
   - 模拟器在生成过程中断开连接

## 未来改进

### ICAO验证
- [ ] 添加模糊搜索建议
- [ ] 支持IATA代码自动转换
- [ ] 缓存验证结果以提高性能

### 重量数据
- [ ] 支持更多模拟器平台
- [ ] 添加重量数据的手动覆盖选项
- [ ] 显示数据来源标识（模拟器 vs 默认）
- [ ] 重量数据异常检测和警告

## 相关文档
- [飞行简报功能](./FLIGHT_BRIEFING.md)
- [简报自动填充](./BRIEFING_AUTO_FILL.md)
- [模拟器集成](../technical/xplane_data_flow.md)

## 更新日期
2026-02-09

## 更新历史

### 2026-02-09 - 历史简报页面颜色优化
**问题**：选中简报时，航班号和机场代码的颜色对比度不足，难以阅读。

**解决方案**：
- 将选中状态的文本颜色从 `primary` 改为 `onPrimaryContainer`
- 确保文本颜色与背景色 `primaryContainer` 有足够的对比度
- 同时优化了时间和距离图标的颜色，保持视觉一致性

**修改文件**：
- `lib/pages/briefing/widgets/briefing_history_page.dart`

**颜色方案**：
```dart
// 未选中状态
背景: theme.colorScheme.surface
文本: theme.colorScheme.onSurface

// 选中状态
背景: theme.colorScheme.primaryContainer
文本: theme.colorScheme.onPrimaryContainer (确保对比度)
次要文本: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.7)
```
