# 变更记录

本文件遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/) 的组织方式，
版本号遵循 [SemVer 2.0.0](https://semver.org/lang/zh-CN/)。

> **发布硬约束**：每次发布前 MUST 在本文件顶部新增 `## v<版本> — <YYYY-MM-DD>` 段落，
> 按「新增 / 调整 / 删除 / 修复」写清本次改动，无对应项写「无」。
> CI 打 tag 时从对应段落自动生成 Release notes —— 这里写清楚，发行说明才清楚。

---

## 未发布

### 新增

- **ESLint 门禁**（工程手册 §4.1 警告即错误）：`npm run lint`，`--max-warnings=0`，
  已接入 `npm run check` 与 CI。只收能抓真实缺陷的规则（浮动 Promise、误用 any、
  `no-base-to-string`），风格交给 `.editorconfig`。首次全量扫描报出 57 处，已全部清零。
- **`toText()` 解析工具 + 单测**（12 例）：统一替代散落各处的 `String(x ?? '')`。
- **后端响应解析器单测**（24 例）：覆盖字段大小写混用、脏坐标剔除、`SFC` 语义、
  `hasDme` 严格布尔判定。已用变异测试确认 5 处关键行为被改坏后测试确实会红。
- **气象报文解码单测**（15 例）：能见度的米制/英里制/分数写法、云幕只认
  BKN/OVC/VV、飞行规则的分档边界值。

### 调整

- **`map-store.ts` 抽出纯解析层**：9 个解析函数移入
  `modules/map/services/map-response-parsers.ts`，`map-store.ts` 由 1726 行降到 1524 行。
  解析器不再依赖 store，可被直接调用与测试，并纳入架构门禁的「纯计算」白名单。
- **气象报文解码工具归位**：`map/providers/map-weather-utils.ts` →
  `toolbox/services/metar-decode.ts`。原位置有两处不对：`providers/` 按分层约定放
  Zustand store，而这些是纯函数；且 map 模块自己一处都没用，唯一消费方是 toolbox，
  等于 toolbox 越界读 map 的内部实现，map 模块无法独立裁剪。
- **地图几何基元合并**：`bearingDeg` 在 `approach-beam` 与 `papi-guidance` 里各有一份
  逐字符相同的实现，`EARTH_RADIUS_NM` 也各写一遍，而 `holding-geometry` 为了拿
  `destination` 得去 import「进近波束」。统一收进 `map/services/geo.ts`。
- **Haversine 算式只留一份**：`geo.ts` 的 `distanceInNm` 与 `core/utils` 的
  `calculateDistanceNm` 是同一套公式的两种写法（asin / atan2，地球半径也各写一个），
  前者改为委托后者。两种签名（`MapCoordinate` / 四个标量）各有调用场景，保留；
  但算式本身留两份，早晚会改了一处漏另一处，让两边给出不同的距离。
  实测两种写法差 0.06 ppm（4200 海里差 0.00025 海里），远低于导航数据本身的精度。

### 删除

- **清理无人引用的导出**（14 处）：`calculateBearingDeg`（与 `bearingDeg` 重复实现）、
  `pickArray`、`contrastRatio`、`isGroupElement`、`LocalizationKey`、`PENDING_SYNC_KEY`、
  `airportDisplayName`、`termDisplayValue`、`MapDataSnapshot`、`MapRunwayApproach`、
  `ConfigurableAlertId`、`resolveApproachRule`、`normalizeApproachRule`、
  `APPROACH_RULE_COLOR`。
- **`flightDataSelectors` 及其 4 个便捷 hook**：移植期照搬桌面版 `FlightDataProvider`
  的 getter 代理，但全部 29 处订阅点都用的内联选择器，这套从未被采用。

### 修复

- **`String(x ?? '')` 会把类型不对的字段伪装成合法字符串**：后端字段是 `unknown`，
  真传来对象时 `String()` 得到 `"[object Object]"` —— 非空，于是调用方随后的
  `.trim().length === 0` 判空永远不成立，脏数据一路流进界面。全项目 45 处已改用
  `toText()`（非标量一律当作没有值）；`toStringOrUndefined` 同样的洞一并修掉。
- **两处本地重复实现的 `asText`** 收敛到公共实现（`flight-log-models` 与
  `middleware-flight-data-adapter` 各写了一份）。
- **日志丢栈信息**：`AppLogger.error` 的 `stackTrace` 走 `String()`，传对象时整条栈
  变成 `"[object Object]"`，等于什么都没记；改走已有的 `stringifyError`。
- **非 JSON 请求体被发成 `"[object Object]"`**：`serializeBody` 在 content-type
  不是 JSON 时对对象直接 `String()`；改为 `JSON.stringify`，至少可读可排查。
- **气象解码把时间戳当成能见度**（用户可见）：`extractWorstVisibility` 的正则少了
  两侧 `\b`，于是时间戳 `052300Z`、风组 `01004MPS`、跑道视程 `R36L/1200N`、
  修正海压 `Q1024` 里的四位数字全被当成能见度候选 —— 而该函数取的是**最小值**。
  结果是任何一份报文都会被风组数字判成 LIFR，连 `CAVOK`（能见度与云幕俱佳）
  都会显示成 LIFR。同文件的 `decodeMetar` 一直用的是带 `\b` 的正确写法，
  是这个 helper 抄漏了。
- **架构门禁漏判副作用导入**：`scripts/check-architecture.mjs` 原先只匹配
  `from 'x'`，`import 'leaflet';` 这类副作用导入完全看不见 —— 铁律形同虚设。
  改为统一用 `importPattern()` 生成正则，同时覆盖 `from` / 裸 `import` / `require`。

---

## v1.0.3-beta — 2026-08-04

首个 Web 版本。由 Flutter 桌面版（277 个 Dart 文件 / 61597 行）完整移植而来。

### 新增

- **框架层**：11 张模块注册表构成的微内核；主题系统（6 套预设 + CSS 变量注入）；
  i18n 运行时切换（zh/en/de，回退链 当前语言 → en_US → key）。
- **业务模块**：地图、检查单、简报、飞行日志、监控、工具箱、机场查询、日志查看、设置。
- **地图航空要素**：
  - 跑道进近设施 —— ILS 类别（CAT I/II/III）、航向台识别码/频率/磁航道、下滑角、DME，
    数据来自中间件解析的 `earth_nav.dat`；卡片与地图两处展示，下滑道可单独开关。
  - 进近波束 —— 点击跑道展开两端波束，ILS/GLS/RNAV 分色；进近类型来自 CIFP 程序库。
  - 等待航线 —— 来自 `earth_hold.dat` + `earth_fix.dat` 的已公布航线，还原为跑道形环圈。
  - PAPI 目视坡度指示 —— 连接模拟器且处于进近条件时按 ICAO Annex 14 灯位角显示。
  - 机场地面结构 —— 跑道/滑行道/停机坪矢量取自 OSM aeroway，带滑行道位置牌配色。
  - 七类图层图例色标，数值区间与后端渲染逐条对齐。
- **持久化**：飞行日志与简报落盘到中间件；前端设置存后端 SQLite，首启向导只跑一次。
- **工程规范**：本文件、`docs/DESIGN.md`、ADR、`.editorconfig`/`.gitattributes`、
  CI 质量门禁与 tag 触发发布。
- **单文件分发**：前端产物用 `go:embed` 编译进中间件可执行文件，用户下载一个 exe
  双击即用；启动后自动打开浏览器（`OWO_NO_BROWSER=1` 可关），前端的静态资源请求
  与 SPA 兜底一并记入后端 HTTP 日志。

### 调整

- **依赖方向修正**：`core/services/{backend-sync,settings-sync}` 原本反向 import
  `modules/http`，违反「core 不得依赖业务模块」的铁律。改为依赖倒置 ——
  core 声明 `BackendTransport` 端口，由 `modules/http` 在注册期注入实现。
- 新增可执行的门禁脚本：`check-architecture`（依赖方向）、`check-i18n`
  （键集一致 / 重复键 / 占位符对齐 / 覆盖率），并接入 CI；`npm run check` 一键全跑。
- 引入 Vitest 并为纯计算部分补齐 35 例单测：进近波束（含磁航道/真方位的回归用例）、
  等待航线几何、PAPI 五种判定与显示条件、机场轮廓凸包。已用变异测试确认这些用例
  在缺陷重现时确实会失败。
- 右侧控制栏由 18 个平铺开关重组为 6 个分组，悬停展开、点击常驻；图标去重（25 个全互异）。
- 地图底图改用带完整注记的样式，机场地面结构由 aeroway 矢量单独绘制。
- 跑道渲染从「蓝色发光条」改为深色沥青道面 + 白色虚线中线，并脱离滑行道开关独立控制。

### 删除

- 桌面专属能力：无边框标题栏、启动向导中的「选择存储路径」步骤（Web 无对应能力）。
- 清理死代码：`core/widgets/common/overflow-marquee-text`、
  `core/widgets/navigation/module-side-nav` 及其 CSS module —— 全部导出符号
  在代码库中零引用。

### 修复

- 进近波束方位：航向台字段是「磁航道 × 360 + 真方位」的打包值，此前误用磁航道作图，
  波束整体偏转一个磁差角（北京实测 7.9°）。现按真方位作图、磁航道显示。
- 天气图层缩放：雷达 z≥8 会拿到上游画着 "Zoom Level Not Supported" 的 200 图片；
  改用 `maxNativeZoom` 放大最后一级可用瓦片。
- 地形图层在部分地区 z≥15 拿到 Esri 的 "Map data not yet available" 占位图，改用 OpenTopoMap。
- 滑行道数据对多个机场（VHHH/ZSNJ/ZHHH 等）查不出：镜像列表混入了区域实例，
  范围外查询返回 200 + 空结果被当成「该机场没有滑行道」。已移除区域镜像并把内容校验放进镜像循环。
- 检查单响应值被截断：栅格子项的百分比 `max-width` 按自身 grid area 解析，永远裁掉大半。
- 跑道端点信息板被滑行道编号牌遮挡：同 pane 内标记按纬度排序，现按重要性显式分层。
