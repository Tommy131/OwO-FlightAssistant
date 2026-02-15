# Checklist 模块

## 功能特性

- 支持内置与自定义检查单数据并存
- 支持导入与导出 JSON 格式检查单
- 支持从应用数据目录热加载检查单
- 支持手动机型切换
- 仅内存勾选，不回写配置文件

## 使用方式

### 页面入口

- 模块注册后在导航中进入 Checklist 页面

### 导入与导出

- 导入：在页面底部点击「导入」，选择 JSON 文件后加载到应用
- 导出：在页面底部点击「导出」，导出当前加载的检查单到 JSON 文件

### 热加载

- 将 JSON 文件放到应用数据目录的 `checklist` 子目录中
- 点击页面底部「刷新配置」按钮即会从该目录重新加载

### 机型切换

- 页面头部下拉框切换当前机型

## 自定义数据格式

### 结构说明

支持三种等价格式：

1. 单机型对象
2. 机型对象数组
3. 包装对象（推荐）

### 推荐格式（包装对象）

```json
{
  "version": 1,
  "aircraft": [
    {
      "id": "a320_series",
      "name": "A320-200 / A321 / A319",
      "family": "a320",
      "sections": [
        {
          "phase": "coldAndDark",
          "items": [
            {
              "id": "a1_1",
              "task": "电池 (BAT 1+2)",
              "response": "开启 (ON)",
              "detail": "可选，补充说明"
            }
          ]
        }
      ]
    }
  ]
}
```

### 单机型对象

```json
{
  "id": "b737_series",
  "name": "B737-800 / Max",
  "family": "b737",
  "sections": [
    {
      "phase": "beforeTakeoff",
      "items": [
        { "id": "b3_1", "task": "飞行控制", "response": "检查 (CHECKED)" }
      ]
    }
  ]
}
```

### 机型数组

```json
[
  {
    "id": "a320_series",
    "name": "A320-200 / A321 / A319",
    "family": "a320",
    "sections": []
  }
]
```

### 字段约束

- `id`：机型唯一标识（必填）
- `name`：机型展示名称（必填）
- `family`：机型家族，支持 `a320` / `b737`
- `sections`：阶段数组（必填）
- `phase`：阶段枚举名，需匹配 `ChecklistPhase` 名称
- `items`：该阶段条目数组
- `task` / `response`：检查单内容与应答（必填）
- `detail`：可选补充说明

### phase 可选值

- `coldAndDark`
- `beforePushback`
- `beforeTaxi`
- `beforeTakeoff`
- `cruise`
- `beforeDescent`
- `beforeApproach`
- `afterLanding`
- `parking`

## 目录结构

```text
checklist/
├── checklist_module.dart
├── data/
│   └── checklists/
│       ├── a320_checklist.dart
│       └── b737_checklist.dart
├── localization/
│   ├── checklist_localization_keys.dart
│   └── checklist_translations.dart
├── models/
│   └── flight_checklist.dart
├── pages/
│   ├── checklist_page.dart
│   └── widgets/
│       ├── checklist_footer.dart
│       ├── checklist_header.dart
│       ├── checklist_item_tile.dart
│       ├── checklist_items_list.dart
│       └── checklist_sidebar.dart
├── providers/
│   ├── checklist_provider.dart
├── services/
│   └── checklist_service.dart
└── widgets/
```

## 核心类说明

- `ChecklistService`：加载/解析/导出检查单
- `ChecklistProvider`：状态管理与手动机型切换、热加载入口
- `ChecklistPage`：页面布局与展示
- `flight_checklist.dart`：模型与阶段枚举
