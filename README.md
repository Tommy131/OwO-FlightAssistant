# OwO! FlightAssistant — Web GUI

![React](https://img.shields.io/badge/React-19-61DAFB?logo=react)
![TypeScript](https://img.shields.io/badge/TypeScript-5.7-3178C6?logo=typescript)
![Vite](https://img.shields.io/badge/Vite-6-646CFF?logo=vite)
![License](https://img.shields.io/badge/License-CC%20BY--NC--SA%204.0-lightgrey)

**版本：1.0.5-beta** · 权威设计见 [`docs/DESIGN.md`](docs/DESIGN.md) · 变更记录见 [`docs/CHANGELOG.md`](docs/CHANGELOG.md)

[OwO! FlightAssistant](https://github.com/Tommy131/OwO-FlightAssistant)（Flutter 桌面版）的 Web GUI 移植。
保留原版的**模块化微内核架构**、**设计语言**与**后端 API 契约**，在浏览器中运行。

> 本分支（`dev-web-v1`）是当前的活跃开发线。Flutter 桌面版保留在
> `dev-master-archived` / `dev-architecture-v1` 分支，作为只读存档。

---

## 0. 直接使用：下载一个文件，双击即用

到 [Releases](https://github.com/Tommy131/OwO-FlightAssistant/releases) 下载
`OwO! FlightAssistant Middleware.exe` 并运行，**就这一步**。

- 前端已**编译进可执行文件**，不必另外下载产物、不必摆目录、不必装 Node；
- 启动后**自动打开浏览器**到 <http://127.0.0.1:18080>，前端同源托管，无跨域问题；
- 前端每次资源请求都会记进 `resources/cache/logs/http.log`，排障时能看到完整加载过程。

不想自动弹浏览器就设环境变量 `OWO_NO_BROWSER=1`。

> Release 里的 `owo-flight-assistant-web-dist.zip` 仅供需要单独部署前端
> （例如放到自己的 Web 服务器）的用户，普通用户不需要下载。
>
> 中间件为闭源组件，仅以编译产物分发；本仓库只含前端源码。

---

## 1. 从源码开发

```bash
npm install
```

```bash
npm run dev
```

浏览器打开 <http://localhost:5273>。

首次启动会进入配置向导（语言 → 日志 → 确认），完成后进入主界面。
未启动中间件时首页显示「后端离线」毛玻璃遮罩，这是预期行为。

其他命令：

```bash
npm run build
```

```bash
npm run typecheck
```

### 没有中间件时怎么开发

仓库自带一个最小 mock 中间件（`tools/mock-middleware.mjs`），提供 `/health`、机场详情、
METAR、联想建议与性能计算的假数据，够把需要后端连通的模块跑起来：

```bash
npm run mock
```

它监听 `127.0.0.1:18080`，与 Vite dev proxy 的默认目标一致，开着它再 `npm run dev` 即可。
**仅供开发调试，不要用于任何真实用途。**

---

## 2. 部署与 CORS ⚠️

浏览器**无法**直接跨源访问中间件（`http://127.0.0.1:18080`）。本项目默认走同源代理：

| 前端请求 | 代理目标 |
| --- | --- |
| `/mw-api/*` | `http://127.0.0.1:18080/*` |
| `/mw-ws` | `ws://127.0.0.1:18081/api/v1/simulator/ws` |
| `/rainviewer/*` | `https://api.rainviewer.com/*`（天气雷达索引） |

**开发期**：Vite dev server 自动代理，无需额外配置。
可用 `.env.local` 覆盖目标地址：

```env
VITE_MIDDLEWARE_HTTP=http://192.168.1.10:18080
VITE_MIDDLEWARE_WS=ws://192.168.1.10:18081
```

**生产部署**，二选一：

1. **同源部署（推荐）** — 把 `dist/` 挂到中间件的静态目录下，前端与 API 同源，无需 CORS。
2. **中间件下发 CORS 头** — 在中间件加 `Access-Control-Allow-Origin`，
   然后在「设置 → 中间件设置」里把地址改成绝对 URL（如 `http://127.0.0.1:18080`）。
   WebSocket 同样需要中间件允许跨源握手。

---

## 3. 架构

与 Flutter 版一一对应的微内核结构：`core/` 不认识任何业务模块，
全部能力由模块在 `register()` 中反向注入到 11 张注册表。

```text
src/
├── core/
│   ├── constants/          应用常量
│   ├── layouts/            响应式断点 + 桌面/移动布局
│   ├── localization/       Key 表 + zh_CN/en_US/de_DE 词条 + useTranslate
│   ├── module-registry/    ★ 11 张注册表（微内核）
│   ├── services/           持久化 / i18n / 初始化
│   ├── setup-wizard/       首启向导
│   ├── theme/              6 套主题 + 明暗 + 对比度调节 → CSS 变量
│   ├── utils/              日志 / 宽容解析 / 地理计算
│   └── widgets/            通用组件、侧边栏、底部导航、AppBar、浮层
├── modules/
│   ├── modules-register-entry.ts   ★ 唯一注册入口
│   ├── common/             全局飞行数据总线 + 侧边栏卡片 + 导航分组
│   ├── home/               首页仪表盘
│   ├── flight_logs/        黑匣子数据模型与记录逻辑
│   └── http/               中间件 HTTP 客户端
└── styles/global.css       设计令牌消费方 + 排版基线
```

### 11 张注册表

| 注册表 | 作用 |
| --- | --- |
| `NavigationRegistry` | 导航项（`priority` 排序 + `groupId` 分组） |
| `NavigationAvailabilityRegistry` | 导航可用性（后端不通则置灰） |
| `SettingsPageRegistry` | 模块自注册设置页 |
| `AboutPageRegistry` | 关于页区块 |
| `AppBarActionRegistry` | AppBar 动作 + 侧边二级菜单 |
| `SidebarFooterRegistry` | 侧边栏页脚 |
| `SidebarMiniCardRegistry` | 侧边栏迷你卡片 |
| `SidebarTitleRegistry` / `SidebarTitleBadgeRegistry` | 侧边栏标题与状态徽章 |
| `WizardStepRegistry` | 首启向导步骤 |
| `ProviderRegistry` | 模块 store 之间的订阅绑定 |

> **重要约束**：注册表的工厂函数与解析器**在组件 render 期间被调用**，因此允许在其中使用 hooks
> （等价于 Flutter 的 `context.watch`）。这是安全的 —— `ModuleRegistry.initializeAll()` 之后
> 禁止再注册，工厂数组长度恒定，hooks 调用顺序稳定。

### 响应式断点（与桌面版一致）

| 布局 | 宽度 |
| --- | --- |
| Mobile | `< 650` |
| Tablet | `650 – 1241`（回退 mobile） |
| Desktop | `>= 1242`（内容区最小 1000px，不足则横向滚动） |

### 技术栈映射

| Flutter | Web |
| --- | --- |
| `provider` (ChangeNotifier) | Zustand |
| `ChangeNotifierProxyProvider` | `ProviderRegistry` 的 store 订阅绑定 |
| `ThemeData` + `AppThemeData` | CSS 自定义属性（运行时注入 `:root`） |
| `Icons.*` (Material Icons) | Material Symbols 变量字体（FILL 轴对应描边/实心） |
| `flutter_map` + `latlong2` | Leaflet |
| `fl_chart` | ECharts |
| `showDialog` / `SnackBar` | 全局 overlay store + `<OverlayHost />` |
| `PersistenceService`（磁盘 JSON） | IndexedDB（`idb-keyval`） |

---

## 4. 相对桌面版的差异

### 合理降级（浏览器无对应能力）

| 桌面能力 | Web 处理 |
| --- | --- |
| `window_manager` 无边框标题栏 / 关闭拦截 | 移除 |
| 自选数据存储路径 + 迁移 | 固定 IndexedDB；向导「存储路径」步骤移除，设置页改为展示用量与清理 |
| 日志文件轮转（按 MB 分割） | 内存环形缓冲（按条数），支持导出 `.log` |
| `flutter_local_notifications` | 浏览器 Notification API |
| `file_picker` 导入导出 | `<input type=file>` + Blob 下载（JSON 格式与桌面版互通） |
| Android 物理返回键 | 移除 |
| `sqlite3` 本地库 | 不需要（数据由中间件提供） |

### 相对桌面版的几处修正

移植过程中发现的原版缺陷，已在 Web 版修正（都不改变既有功能，只是让它按设计生效）：

**1. i18n 回退链** — 桌面版 `translate()` 查不到 key 就直接返回 key 本身。由于业务模块只提供
zh_CN / en_US，选德语时模块文案会整片显示成 `map.nav_title` 这类原始 key。
Web 版补了 **当前语言 → en_US → key** 的回退链，德语界面退化为英文而非乱码。

**2. 首页检查单卡片恒为空** — 桌面版 `MiddlewareFlightDataAdapter` 声明了
`_checklistPhase` / `_checklistProgress` 两个字段却从未赋值，导致首页那张「当前检查阶段」
卡片永远显示「暂无检查阶段」。Web 版由 checklist 模块反向回填这两个值，卡片按设计生效。

**3. 监控图表配色对比度不足** — 桌面版三张趋势图分别用 `Colors.orangeAccent` (#FFAB40) 与
`Colors.cyanAccent` (#18FFFF)。这两个是 Material **Accent** 色，只为深色底设计；
在本应用的浅色主题下对比度仅 1.88:1 和 1.25:1（远低于 3:1 门槛），曲线几乎不可见。
Web 版换成同色系但经过校验的步进值（浅/深两套），并给每张图加了当前值徽章作为兜底读数。

**4. 分析图单轴叠加** — 桌面版飞行日志分析图把所有选中指标叠在**同一个 Y 轴**上
（`_resolveMinY/_resolveMaxY` 取全体极值）。同时选高度（0–40000 ft）和 G 值（0–3）时，
G 值被压成贴底的直线。Web 版改成**小倍数**：每指标一行、各自 Y 轴、共享时间轴，
多选能力不变，混合量纲的组合终于可读。

---

## 4.1 地图瓦片源的三个坑

都是实测出来的，改动瓦片相关代码前请先读这一节。

**RainViewer 雷达只到 z7** — 超过这一级，上游**不返回 HTTP 错误**，而是返回一张状态码 200 的
PNG，图里画着 "Zoom Level Not Supported" 字样。任何基于状态码或 Content-Type 的检查都发现不了，
用户会直接在地图上看到满屏错误文字（地图默认 zoom 就是 8，一开图层就中招）。
因此雷达层必须用 `maxNativeZoom: 7` 让 Leaflet 放大 z7 瓦片，**不能**用 `maxZoom`。

**`maxZoom` ≠ `maxNativeZoom`** — 在 Leaflet 里给瓦片层设 `maxZoom: N`，
表示「地图缩放超过 N 时整层隐藏」，而不是「瓦片最高请求到 N」。
四个天气叠加层原先写的是 `maxZoom: 12`，于是放大过 z12 后天气整片消失。
要的是 `maxNativeZoom`（到顶后放大已有瓦片继续显示）。

**滑行道底图必须带注记** — 该图层的意义就是看滑行道编号，
而原先用的 Carto `voyager_nolabels` 样式**本身不含任何注记**，几何画得出来编号永远看不到。
现在换成 OSM 标准瓦片，z15 起可读出 `Z2` / `M7` / `W5` / `18L-36R` 这类 aeroway ref。
⚠️ `tile.openstreetmap.org` 受 [OSM 瓦片使用政策](https://operations.osmfoundation.org/policies/tiles/)
约束（个人低频使用没问题，不得批量抓取）。若要商用或高频访问，
请在 `map-models.ts` 的 `mapTileUrl()` 里换成自建瓦片服务或商业源。

另外**降雨量层原先是死的**：`tiles.windy.com/tiles/v9.0/rain/...` 对任意位置、
任意缩放级别都只返回同一张 169 字节的全透明 PNG（多地区 z4~z14 逐一验证过），
从未画出任何东西。现已改走中间件既有的 Open-Meteo 渲染管线（字段 `precipitation`），
并让 alpha 随降水量变化 —— 没下雨的地方保持全透明，不会给整张图糊一层蓝。

图层颜色对应的数值区间见 `src/modules/map/models/map-legends.ts`，
**必须与中间件 `map_overlay.go` 的 `colorForLayer()` 保持一致**，改一边就要改另一边。

---

## 5. 后端 API 契约

```text
GET  /health                                  GET  /api/v1/version
GET  /api/v1/airport/{icao}                   GET  /api/v1/airport-layout/{icao}
GET  /api/v1/metar/{icao}                     GET  /api/v1/airport-list
GET  /api/v1/airport-suggest?q=&limit=
GET  /api/v1/airports?min_lat=&max_lat=&min_lon=&max_lon=&limit=
GET  /api/v1/airspace/restricted?...
GET  /api/v1/weather/wind/profile?lat=&lon=&altitude_ft=
POST /api/v1/map/report/{wind|airspace|terrain-warning}
POST /api/v1/simulator/{state|connect|data|disconnect}
GET  /api/v1/simulator/ws     → WS ws://127.0.0.1:18081/api/v1/simulator/ws?token=
GET  /api/v1/performance/aircraft-profiles
POST /api/v1/performance/calculate
```

实时数据优先走 WebSocket，握手失败自动回退到 HTTP 轮询（最快 1s/次）。
后端健康每 2s 探测一次，持续不可达超过 10s 宽限期则触发离线遮罩并跳回首页。

---

## 6. 服务端存储（飞行日志 / 简报）

前端保存后**自动落到中间件对应路径**，多个前端实例共享同一份数据：

```text
resources/persistent/flight_logs/flight_log_<id>.json
resources/persistent/briefings/briefing_<id>.json
```

这批接口是本次移植**新增到 Go 中间件**的（`internal/apps/common/http/handlers/v1/storage.go`）：

```text
GET  /api/v1/flight-logs/list      POST /api/v1/flight-logs/save     POST /api/v1/flight-logs/delete
GET  /api/v1/briefings/list        POST /api/v1/briefings/save       POST /api/v1/briefings/delete
```

写入策略：

- **本地先落盘再推后端** —— IndexedDB 作缓存，后端不可达时照常可用
- **恢复连通后自动补传** —— `refreshLogs()` / `init()` 比对两侧 id，把离线期间新增的记录补推上去
- **合并以后端为准** —— 两侧同 id 时用后端版本，本地独有的保留
- 原子写（临时文件 + rename）、ID 白名单校验（杜绝 `../` 穿越）、删除幂等

导入导出：

| 方向 | 飞行日志 | 简报 |
| --- | --- | --- |
| 导出 | `.json`（与桌面版格式互通） | `.txt`（与桌面版落盘内容一致）+ `.json` |
| 导入 | `.json`，单条对象或数组皆可 | `.json` 或 `.txt`（纯文本自动推断标题） |

导入的记录同样会推到后端，「本地文件 → 前端 → 后端」链路完整。

---

## 7. 只初始化一次（设置存后端数据库）

语言、日志开关与缓冲条数、主题、首启完成标记等**全部存在中间件的 SQLite** 里：

```text
resources/persistent/database.db → app_settings 表（key / value / updated_at）
```

对应接口（本次新增，`internal/apps/common/http/handlers/v1/settings.go`）：

```text
GET  /api/v1/settings/all       POST /api/v1/settings/set      POST /api/v1/settings/bulk-set
POST /api/v1/settings/delete    POST /api/v1/settings/reset
```

因此：

- **换浏览器 / 无痕窗口 / 清站点数据 → 不再重跑初始化向导**，后端仍持有完成标记
- **桌面端与 Web 端共享同一份配置**
- 只有「设置 → 危险操作 → 重置应用」会显式清空后端设置，才重新走向导

IndexedDB 退化为本地缓存：

| 场景 | 行为 |
| --- | --- |
| 启动 | 先读 IndexedDB（同步、可离线），再拉后端覆盖同名键并回写缓存 |
| 写入 | 本地先落盘，再推后端 |
| 后端不可达 | 写入入队，恢复连通后由 `flushPendingSettings()` 自动补传 |
| 首启向导完成 | 用 `bulk-set` 一次性提交，避免半套配置落库 |

---

## 8. 移植进度

| 模块 | 状态 |
| --- | --- |
| 核心框架（注册中心 / 主题 / i18n / 持久化 / 布局 / 通用组件 / 浮层） | ✅ 完成 |
| 数据层（HTTP 客户端 / WS 适配器 / 96 字段飞行数据模型） | ✅ 完成 |
| `common`（飞行数据总线 / 侧边栏卡片 / 导航分组） | ✅ 完成 |
| `home`（欢迎卡 / 航班号 / 连接卡 / 检查单阶段 / 5 面板仪表盘 / METAR / 离线遮罩） | ✅ 完成 |
| `checklist`（A320 93 条 / B737 84 条 / 通用 16 条，9 阶段 + 机型识别 + 阶段推导 + 导入导出） | ✅ 完成 |
| `toolbox`（6 个 tab：单位换算 / 76 条术语库 / 3 个计算器 / 气象解码 / 性能 / 运行工具） | ✅ 完成 |
| `airport_search`（ICAO 搜索 / 联想 / 收藏 / 跑道频率 METAR 详情卡） | ✅ 完成 |
| `flight_logs` 数据层（黑匣子模型 / 记录逻辑 / 起降检测 / 导入导出） | ✅ 完成 |
| `flight_logs` UI（列表 / 详情 / 小倍数分析图 / Leaflet 轨迹图 / 起降质量报告 / 分页黑匣子） | ✅ 完成 |
| `monitor`（3 张趋势图 / 航向罗盘 / 交互式起落架面板 / 系统状态 / 告警横幅 / 限流） | ✅ 完成 |
| `briefing`（简报生成 / 历史 / 燃油计划 / 按风向自动选跑道） | ✅ 完成 |
| `map`（Leaflet 4 种底图 / RainViewer 雷达 + 4 层天气叠加 / 滑行道绘制含撤销重做导入导出 / 本机 + AI 机 / 航迹 / HUD 计时器 / 告警浮层 / 设置页） | ✅ 完成 |
| `http`（地址配置 / 运行时参数 / 连通性诊断）· `log_viewer` · 设置页 · 关于页 | ✅ 完成 |

### 已知优化项

**图标字体体积**：`material-symbols` 的 Rounded 变量字体含全部 ~3600 个图标，
打包后 4.6 MB（woff2 已压缩，gzip 无进一步收益）。项目实际只用到约 90 个图标，
用 `pyftsubset` 按用到的字形子集化可降到 ~60 KB：

```bash
pyftsubset node_modules/material-symbols/material-symbols-rounded.woff2 --text-file=icons.txt --flavor=woff2 --layout-features=liga --output-file=public/fonts/ms-subset.woff2
```

需要 `pip install fonttools brotli`，并把 `global.css` 的 `@import` 换成指向子集文件的
`@font-face`。首次加载后字体会被浏览器缓存，因此这不是阻塞项，按需处理即可。

---

## 9. 许可与免责

- **CC BY-NC-SA 4.0** — 完整条款见 [LICENSE](LICENSE)
- 团队：**OwOTeam-DGMT (OwOBlog)** · 主要开发者：**HanskiJay** · <support@owoblog.com>
- 本项目仅用于模拟飞行训练、学习与研究，**请勿用于真实飞行操作**。
