# OwO! FlightAssistant

[English](README.md)

![Flutter](https://img.shields.io/badge/Flutter-v3.9.2+-02569B?logo=flutter)
![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20Android%20%7C%20iOS%20%7C%20Web-blue)
![License](https://img.shields.io/badge/License-CC%20BY--NC--SA%204.0-lightgrey)

OwO! FlightAssistant 是一个面向模拟飞行场景的模块化前端应用。
当前版本集成了飞行监控、检查单执行、地图可视化、机场与 METAR 查询、飞行日志分析，以及 MSFS / X-Plane 中间件连通诊断能力。

---

## 1. 🚀 功能介绍

### 1.1 首页总览与模拟器会话

| 基础信息 | 飞机信息 | 机场信息 |
| --- | --- | --- |
| ![Home General](assets/images/home_page-general-info.png) | ![Home Aircraft](assets/images/home_page-aircraft-info.png) | ![Home Airport](assets/images/home_page-airport-info.png) |

- **实时同步**：在首页实现模拟器（MSFS/X-Plane）会话的无缝连接与断开。
- **统一状态面板**：聚合关键飞行参数、发动机数据、地面状态及应答机状态。
- **智能上下文**：自动抓取当前起降机场的 METAR 报文并提供智能翻译。

### 1.2 机场搜索与飞行简报

| 机场搜索 | 简报生成 | 简报详情 |
| --- | --- | --- |
| ![Airport Search](assets/images/airport_search_page.png) | ![Briefing Generator](assets/images/briefing_page-generator.png) | ![Briefing Details](assets/images/briefing_page-details.png) |

- **全球机场数据库**：基于 ICAO 的机场搜索，支持联想建议与收藏管理。
- **深度数据检索**：获取详细的跑道配置、无线电频率、停机位坐标及实时天气。
- **飞行简报系统**：生成包含燃油计划在内的完整运行简报，并支持历史记录回溯。

### 1.3 检查单、监控与工具箱

| 检查单 | 监控图表 | 起落架监控 | 工具箱 |
| --- | --- | --- | --- |
| ![Checklist](assets/images/checklist_page.png) | ![Monitor Charts](assets/images/monitor_page-charts.png) | ![Monitor Landing Gear](assets/images/monitor_page-landing-gear.png) | ![Toolbox](assets/images/tool_box_page.png) |

- **SOP 检查单**：支持 **A320**、**B737** 及通用机型的多阶段标准作业程序。
- **阶段自动化**：基于飞行状态智能推导当前阶段，自动高亮相关检查单项目。
- **实时监控面板**：高度/速度实时趋势图、航向罗盘及交互式起落架状态显示。
- **飞行工具箱**：快速访问飞行辅助工具与飞行员参考资料。

### 1.4 地图模块（图层、天气、机场）

| 图层面板 | 机场类型 | 机场信息 | 天气雷达 |
| --- | --- | --- | --- |
| ![Map Layers](assets/images/map_page-layers.png) | ![Map Airport Types](assets/images/map_page-airport-types.png) | ![Map Airport Info](assets/images/map_page-airport-info.png) | ![Map Radar](assets/images/map_page-weather-radar.png) |

- **多源交互图层**：支持 OSM、Esri 世界影像/地形、Carto 等多种底图切换。
- **滑行道绘制**：支持手动或自动滑行路径绘制，助力地面引导。
- **天气雷达叠加**：集成 RainViewer 实时雷达图层，支持时间轴回放与透明度调节。
- **动态机场渲染**：按类别动态渲染机场图标，支持点击查看详情卡片。

### 1.5 飞行日志与复盘分析

| 日志列表 | 航迹视图 | 飞行质量报告 | 风险测试 |
| --- | --- | --- | --- |
| ![Flight Logs](assets/images/flight_logs_page.png) | ![Flight Track](assets/images/flight_logs_page-flight-track.png) | ![Flight Quality](assets/images/flight_logs_page-flight-quality-report.png) | ![Danger Test](assets/images/flight_logs_page-danger-test-flight.png) |

- **黑匣子数据回放**：记录高频事件数据与系统状态，支持精细化的飞后复盘。
- **飞行质量评分**：基于飞行稳定性与安全参数的自动化评估系统。
- **可视化轨迹分析**：在交互式地图上回放飞行轨迹，关联高度与速度曲线。
- **安全审计报告**：提供专门的“风险测试”报告，识别关键飞行安全违规项。

### 1.6 设置与中间件诊断

| 中间件设置 | 地图模块设置 | 全局设置 |
| --- | --- | --- |
| ![Middleware Settings](assets/images/middleware_settings_page.png) | ![Map Module Settings](assets/images/map_module_settings_page.png) | ![Settings](assets/images/settings_page.png) |

- **中间件编排**：配置 HTTP/WebSocket 地址，内置实时连通性健康检查。
- **完善的国际化**：全界面支持 **简体中文** 与 **English** 自由切换。
- **个性化定制**：自定义地图行为、主题偏好及本地化日志存储设置。

---

## 2. 📱 适用设备与模拟器

### 2.1 响应式布局区间

- **手机布局**：宽度 `< 650`
- **平板布局**：宽度 `650 - 1241`
- **桌面布局**：宽度 `>= 1242`

### 2.2 仓库目标平台

- **Windows 桌面端**：推荐主力运行环境
- **Android / iOS**：移动端伴飞场景可用
- **Web**：具备基础 Web 目标工程

### 2.3 模拟器支持

- **Microsoft Flight Simulator（2020 / 2024）**
- **X-Plane（11 / 12）**

---

## 3. 🏗️ 前端架构概览

```text
lib/
├── core/                    # 应用壳层、国际化、主题、模块注册
├── modules/
│   ├── home/                # 首页与模拟器连接控制
│   ├── checklist/           # SOP 检查单
│   ├── map/                 # 交互地图、图层、天气
│   ├── airport_search/      # ICAO 搜索、机场详情、METAR
│   ├── monitor/             # 实时监控与图表
│   ├── briefing/            # 飞行简报生成与历史
│   ├── flight_logs/         # 飞行日志与分析
│   ├── toolbox/             # 工具箱
│   └── http/                # 中间件配置与诊断
└── main.dart
```

模块统一注册入口：`lib/modules/modules_register_entry.dart`。

---

## 4. 🛠️ 安装与使用方法

### 4.1 下载 Release 版本 (推荐)

对于非开发人员，最简单的方法是下载预编译的压缩包：

1. 访问 [GitHub Releases](https://github.com/Tommy131/OwO-FlightAssistant/releases) 页面。
2. 下载适用于您平台的最新压缩包（例如 Windows 的 `.zip` 文件）。
3. 解压压缩包并运行可执行文件。
4. 关于详细的配置和安装说明，请务必**查看我们的 [Wiki](https://github.com/Tommy131/OwO-FlightAssistant/wiki)**。

### 4.2 通过源码构建

#### 环境要求

- Flutter SDK `^3.9.2`
- 可运行的中间件后端实例（默认：`http://127.0.0.1:18080`）
- 可选模拟器运行环境：MSFS 2020/2024 或 X-Plane 11/12

#### 安装步骤

```bash
git clone https://github.com/Tommy131/OwO-FlightAssistant.git
cd OwO-FlightAssistant
flutter pub get
```

#### 启动方式（推荐 Windows）

```bash
flutter run -d windows
```

#### 其他目标

```bash
flutter run -d android
flutter run -d ios
flutter run -d chrome
```

### 4.3 基本使用流程

1. 进入 **Settings → Middleware Settings**，确认后端地址。
2. 回到 **Home** 页面，建立模拟器连接。
3. 飞行中使用 **Checklist / Map / Monitor / Airport Search** 模块。
4. 飞行后在 **Flight Logs** 页面进行复盘分析。

---

## 5. 📚 使用到的开源仓库 / 库

- **核心框架与状态管理**：[Flutter](https://flutter.dev/), [provider](https://pub.dev/packages/provider)
- **网络通信与模拟器通道**：[http](https://pub.dev/packages/http), [web_socket_channel](https://pub.dev/packages/web_socket_channel)
- **地图与地理能力**：[flutter_map](https://pub.dev/packages/flutter_map), [latlong2](https://pub.dev/packages/latlong2)
- **存储、文件与桌面能力**：[shared_preferences](https://pub.dev/packages/shared_preferences), [sqlite3](https://pub.dev/packages/sqlite3), [sqlite3_flutter_libs](https://pub.dev/packages/sqlite3_flutter_libs), [file_picker](https://pub.dev/packages/file_picker), [window_manager](https://pub.dev/packages/window_manager)
- **UI 与工具能力**：[fl_chart](https://pub.dev/packages/fl_chart), [flex_color_picker](https://pub.dev/packages/flex_color_picker), [google_fonts](https://pub.dev/packages/google_fonts), [flutter_local_notifications](https://pub.dev/packages/flutter_local_notifications), [share_plus](https://pub.dev/packages/share_plus), [url_launcher](https://pub.dev/packages/url_launcher), [logger](https://pub.dev/packages/logger), [intl](https://pub.dev/packages/intl), [confetti](https://pub.dev/packages/confetti)

---

## 6. 📡 API 接口清单（前端调用）

默认中间件地址：

- HTTP Base URL：`http://127.0.0.1:18080`
- WebSocket Base URL：`ws://127.0.0.1:18081/api/v1/simulator/ws`

主要接口：

- `GET /health`
- `GET /api/v1/airport/{icao}`, `GET /api/v1/airport-layout/{icao}`, `GET /api/v1/metar/{icao}`
- `GET /api/v1/airport-list`, `GET /api/v1/airport-suggest?q={query}`, `GET /api/v1/airports?min_lat=&...`
- `POST /api/v1/simulator/state`, `POST /api/v1/simulator/connect`, `POST /api/v1/simulator/data`, `POST /api/v1/simulator/disconnect`
- `GET /api/v1/simulator/ws`

---

## 7. 📄 开源许可

本项目采用以下许可证：

- **Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International**
- 完整条款见 [LICENSE](LICENSE)。

---

## 8. 👨‍💻 开发者信息

- 团队：**OwOTeam-DGMT (OwOBlog)**
- 主要开发者：**HanskiJay**
- 联系邮箱：**<support@owoblog.com>**
- GitHub： [Tommy131](https://github.com/Tommy131)
- 仓库： [OwO-FlightAssistant](https://github.com/Tommy131/OwO-FlightAssistant)
- Telegram： [@HanskiJay](https://t.me/HanskiJay)

---

## 9. ⚠️ 免责声明

本项目仅用于模拟飞行训练、学习与研究。
请勿用于真实飞行操作。
