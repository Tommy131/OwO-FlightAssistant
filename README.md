# OwO! FlightAssistant - 你的全能模拟飞行助手

![Flutter](https://img.shields.io/badge/Flutter-v3.9+-02569B?logo=flutter)
![Platform](https://img.shields.io/badge/Platform-Windows%20|%20Mobile-blue)

**OwO! FlightAssistant** 是一款专为 **Microsoft Flight Simulator (MSFS) 2020/2024** 和 **X-Plane 11/12** 设计的高级飞行辅助工具。它不仅提供基于真实 SOP 的检查单，还集成了强大的机场数据库查询、实时气象监控和飞行仪表显示功能。

---

## 📸 功能预览

| 🏠 首页仪表盘 | 🛫 飞行检查单 |
| :---: | :---: |
| ![首页](assets/images/home_page-1.png) | ![检查单](assets/images/flight_checklist.png) |
| *实时监控飞行状态与目的地信息* | *覆盖 9 大阶段的专业 SOP* |

| 🗺️ 机场详情 | 🛠️ 数据源设置 |
| :---: | :---: |
| ![机场信息](assets/images/airport_info_page.png) | ![设置](assets/images/data_settings_page-1.png) |
| *跑道、频率、ILS 与 METAR 综合查询* | *多数据库版本管理与 AIRAC 检测* |

---

## ✨ 核心特性

### 🎨 现代化界面 (UI/UX)
- **多主题支持**：内置多种预设主题（默认紫、圣诞红、海洋蓝、自然绿等），支持 Material 3 设计规范。
- **动态深色模式**：自动适配系统主题，支持桌面端与移动端的最佳显示效果。
- **毛玻璃设计**：基于现代审美风格，提供流畅的交互动画与视觉反馈。

### 📊 实时飞行监控 (Monitor)
- **多维仪表盘**：集成磁航向罗盘、起落架状态监控及 Master Warning/Caution 智能告警。
- **趋势分析图表**：实时高度趋势、G-Force 重力曲线及大气压强监测。
- **状态同步**：自动识别模拟器暂停状态，确保飞行数据实时准确。

### 🌍 全球机场与气象 (Airport Info)
- **多源数据源**：支持 AirportDB.io 在线 API 及本地 X-Plane (`apt.dat`) / Little Navmap (`navdata.sqlite`) 数据库。
- **AIRAC 周期管理**：自动检测导航数据版本，提供 AIRAC 过期预警。
- **实时气象解析**：直连 NOAA 获取最新 METAR 报文，智能解析风向、能见度、温度及修正海压。

### 🔌 模拟器连接 ✨
- **MSFS (2020/2024)**：通过 WebSocket 桥接 SimConnect，实时同步飞行状态。
- **X-Plane (11/12)**：通过 UDP 协议直连 DataRef，无需安装额外插件。
- **完整 SOP 检查单**：覆盖 A320 系列与 B737 系列从冷舱到关车的 9 大飞行阶段。

---

## 🛠️ 技术栈

- **框架**：[Flutter](https://flutter.dev/) (Dart)
- **状态管理**：[Provider](https://pub.dev/packages/provider)
- **本地数据库**：[sqlite3](https://pub.dev/packages/sqlite3) (用于解析 LNM/XP 导航数据)
- **网络通信**：WebSocket (MSFS) / UDP (X-Plane) / HTTP (METAR API)
- **持久化**：Shared Preferences

## 📦 主要开源库

- `window_manager`：精细的桌面窗口控制。
- `fl_chart`：飞行参数实时图表显示。
- `flex_color_picker`：高度自定义的主题色选器。
- `sqlite3_flutter_libs`：跨平台 SQLite 运行时支持。
- `url_launcher`：快速访问航图与外部链接。

---

## 🔌 数据与 API 来源

- **导航数据**：支持 Little Navmap (LNM) 导出的 SQLite 数据库及 X-Plane `apt.dat` 格式。
- **气象 API**：[AviationAPI](https://www.aviationapi.com/) 提供实时 METAR 数据。
- **机型预设**：内置参考多家主流航空公司 (SOP) 的标准检查单。

---

## 🏗️ 代码架构

项目遵循清晰的分层架构，便于扩展与维护：

```text
lib/
├── apps/               # 业务逻辑层
│   ├── data/           # 数据库操作与持久化
│   ├── models/         # 数据模型 (Airport, Metar, Checklist)
│   ├── providers/      # 状态管理 (Simulator, Theme, Checklist)
│   └── services/       # 外部服务 (WeatherService, AirportDetailService)
├── core/               # 核心层
│   ├── theme/          # 主题与配色定义
│   ├── utils/          # 工具类 (Logger, Validators)
│   └── widgets/        # 通用 UI 组件
└── pages/              # UI 页面层
    ├── home/           # 仪表盘首页
    ├── airport_info/   # 机场详情与搜索
    ├── checklist/      # 交互式检查单
    └── settings/       # 系统与数据路径配置
```

---

## 📥 快速开始

1. 确保已安装 Flutter 环境。
2. 克隆项目：`git clone https://github.com/your-repo/owo_flight_assistant.git`
3. 安装依赖：`flutter pub get`
4. 运行应用：`flutter run` (建议在 Windows 桌面端运行以获得最佳体验)

---

## 📄 许可证 (License)

本项目采用 **[Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International (CC BY-NC-SA 4.0)](LICENSE)** 许可协议。

### 📌 协议要点说明：
- **署名 (Attribution)**：他人分发或修改代码时，必须标注原作者及源代码来源。
- **非商业性使用 (Non-Commercial)**：他人**不得**将本项目代码（及其衍生版本）用于任何形式的付费或商业用途。
- **相同方式共享 (ShareAlike)**：如果他人对代码进行了二次修改，其修改后的代码也**必须**以相同的开源协议（CC BY-NC-SA 4.0）公开，不得闭源。
- **允许二次开发**：欢迎 Fork 并根据个人需求进行修改和使用。

### ⚠️ 免责声明
本项目仅供学习和模拟飞行研究使用，严禁用于真实飞行。

---

**OwO! FlightAssistant** - 让每一次起降都充满仪式感。