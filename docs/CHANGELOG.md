# 变更记录

本文件遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/) 的组织方式，
版本号遵循 [SemVer 2.0.0](https://semver.org/lang/zh-CN/)。

> **发布硬约束**：每次发布前 MUST 在本文件顶部新增 `## v<版本> — <YYYY-MM-DD>` 段落，
> 按「新增 / 调整 / 删除 / 修复」写清本次改动，无对应项写「无」。
> CI 打 tag 时从对应段落自动生成 Release notes —— 这里写清楚，发行说明才清楚。

---

## 未发布

### 新增

- **SimBrief 飞行计划导入**：简报页填 SimBrief 用户名或 Pilot ID 即可导入最新 OFP，
  自动回填起降/备降、航班号、航路串与巡航高度；身份记在本地，下次自动带出。
  **读取已有 OFP 不需要 API key**（那个 key 是给「生成航路」用的）。
- **地图显示计划航路**：右侧控制栏「飞行」组新增开关。SID/STAR 段与巡航段分色
  （紫 / 青），悬停给出该点的计划高度、所经航路与阶段。与「航迹」区分开 ——
  那是飞过的实线，这是要飞的虚线。
- **计划航路解析单测**（12 例）+ **落盘防抖单测**（5 例）。

### 调整

- **`isValidCoordinate` 从两处收敛到 core**：`map-response-parsers` 与
  `map-airport-parser` 各有一份逐字符相同的实现，且 `common/` 的新解析器需要它 ——
  留在 map 里就得反过来 import。已移入 `core/utils/coordinates.ts`。
- **计划航路的数据落在 `common/` 而非 `map/`**：地图与简报两个模块都要用它。
  全库约定功能模块之间零互引，跨模块共享的状态一律落在 `common/`
  （`flight-data-store` 是先例）—— 否则删掉 map 模块，简报就编不过了。
  地图只保留「是否显示」这个开关。

### 删除

- 无。

### 修复

- **落盘防抖会永久挂死所有等待落盘的调用方**（core，影响面远超本次功能）：
  `scheduleSave` 里 `clearTimeout` 取消了旧定时器，但 `pendingSave ??= new Promise(...)`
  见 Promise 非空就不再进入回调 —— **新的定时器压根没排**。于是 `resolve` 永不调用、
  `pendingSave` 永不复位，此后每一次 `await PersistenceService.setModuleData(...)`
  都拿到同一个死 Promise。300ms 内写两次即可触发，`map-store` 里多处 await 同样中招。
  表现是「点了保存，界面就此不动，也不报错」—— 我正是在 SimBrief 导入时撞上它：
  表单不填、提示不弹、控制台干净。已把 Promise 的创建与定时器的排定解耦，
  `resetApp` 取消待落盘时也补上放行。
- 简报页保存 SimBrief 身份改为**不阻塞**：偏好写入只是附带效果，不该挡住填表与提示。

---

## v1.0.4-beta — 2026-08-06

### 新增

- **航迹回放**：飞行日志详情的「飞行轨迹」区新增时间轴 —— 拖动/播放时橙色光标
  沿航迹移动，同步显示该时刻的时间、高度、地速、垂速与航向，支持 1/2/4/8 倍速。
  数据全部来自已入库的 `FlightLogPoint`，无需新增采集。
- **落地评分卡补齐两项**：`remainingRunwayFt`（剩余跑道，<1500ft 标警告色）与
  `touchdownGForces`（接地序列，多次接地时逐次列出 G 值）。
  两者早就在数据模型里、i18n 键也备好了，只是一直没接到界面上。
- **遥测解析单测**（23 例）：字段名（带 `_ft`/`_kt` 单位后缀）、多个历史键名的
  兜底顺序、起落架比例推断、襟翼角度优先于比例、燃油计划配方。
  13 处变异全部被捕获。
- **滑行道路线编辑单测**（23 例）：分段重建、节点增删改、分段中插点后的下标位移、
  撤销栈封顶。9 处变异全部被捕获。
- **三个规则引擎的单测**（42 例）：飞行告警（阈值边界、危险优先于警告、各条独立开关）、
  HUD 计时器自动启停（3 种启动 × 3 种停止模式）、遥测派生（航迹裁剪、机场去重）。
  14 处变异全部被捕获。
- **ESLint 门禁**（工程手册 §4.1 警告即错误）：`npm run lint`，`--max-warnings=0`，
  已接入 `npm run check` 与 CI。只收能抓真实缺陷的规则（浮动 Promise、误用 any、
  `no-base-to-string`），风格交给 `.editorconfig`。首次全量扫描报出 57 处，已全部清零。
- **`toText()` 解析工具 + 单测**（12 例）：统一替代散落各处的 `String(x ?? '')`。
- **后端响应解析器单测**（24 例）：覆盖字段大小写混用、脏坐标剔除、`SFC` 语义、
  `hasDme` 严格布尔判定。已用变异测试确认 5 处关键行为被改坏后测试确实会红。
- **气象报文解码单测**（15 例）：能见度的米制/英里制/分数写法、云幕只认
  BKN/OVC/VV、飞行规则的分档边界值。

### 调整

- **航迹不再有点数上限**：原先 `MAX_ROUTE_POINTS = 4000`，配合 300ms 轮询、
  巡航时每点间隔约 69m，**只够约 20 分钟**，长航线必然丢掉前半程。
  抑制刷点靠的是 30m 最小间距过滤，不该靠砍历史。
- **`middleware-flight-data-adapter.ts` 抽出遥测解析层**（1047 → 800 行）：
  `services/flight-data-parser.ts` 收下 11 个纯函数（数据集 → `FlightData`、
  AI 机、告警、机场、起落架/襟翼推断、燃油计划）。原先它们和 WebSocket、轮询、
  健康监控挤在一个文件里，没法脱离那套 IO 单独调用。
  适配器类本身（连接生命周期与 IO 编排）未动 —— 它是运行时命脉，
  在有针对性的测试之前不拆。
- **`map-page.tsx` 按面板拆开**（1026 → 143 行）：新增 `pages/panels/`，顶部搜索栏、
  HUD、告警浮层、右侧控制栏、图层选择器、滑行道工具条、机场底卡各自成文件，
  页面本身只剩组装。搬运逐字符，组件体一行未改。
- **`map-store.ts` 抽出滑行道路线编辑器**（`services/taxiway-route-editor.ts`）：
  这是一套基于下标的节点/分段手术 —— 在分段中插一个节点，它后面所有分段的
  `fromIndex`/`toIndex` 都要整体后移。错一位不抛异常，只是某条分段连到了隔壁
  节点上，画出来仍是一条线。原先还依赖模块级的 `ctx.undoStack`，没法脱离
  Zustand 调用。现改为值进值出，撤销栈也变成不可变操作。
- **`map-canvas.tsx` 按图层职责拆开**（1467 → 709 行）：新增 `pages/layers/`，
  地面结构、视野内机场、机场详情三组渲染各自成文件，共享的配色与 z 序常量
  收进 `layers/layer-style.ts`；纯 HTML 构造抽到 `services/map-marker-html.ts`
  （不依赖 Leaflet，可单测）。组件自身只保留「什么时候画」。
  搬运是逐字符的，函数体一行未改。
- **`clamp` 从三处收敛到一处**：`core/theme/color-utils.ts`、`map-canvas.tsx`、
  `map/services/holding-geometry.ts` 各写了一份实现等价的版本，
  统一到 `core/utils/math-utils.ts`。
- **`map-store.ts` 再抽出三个规则引擎**：`services/flight-alerts.ts`（告警判定）、
  `services/hud-timer-rules.ts`（计时器启停判定）、`services/map-telemetry.ts`
  （航迹累积与机场标记）。三者此前都读整个 `MapState`、且航迹依赖模块级可变量
  `ctx.lastRoutePoint`，没法脱离 Zustand 调用 —— 也就一直没有测试。
  现在入参收窄、状态改为传入，`map-store.ts` 1524 → 1364 行。
  计时器的判定与副作用也就此分开：纯函数只回答「该做什么」，store 负责做。
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

- **界面显示的版本号永远是写死的回退值**：`app-constants.ts` 写的是
  `import.meta.env.VITE_APP_VERSION ?? '1.0.3-beta'`，而这个环境变量
  **从来没有人注入过** —— vite.config、CI、npm scripts 里都没有。于是侧边栏
  显示的一直是那个回退值，1.0.4 都要发了还挂着 1.0.3。
  现由 vite.config 从 package.json 构建期注入，并把该回退值纳入
  `check-version-sync` 的校验范围（此前它只看 package.json/CHANGELOG/README）。
- **航迹每帧整条重建**（违反 `DESIGN.md` NFR-3「增量更新，不整层重建」）：
  去掉点数上限后这个问题会直接把 UI 拖死，因此一并改为**分段渲染**。
  注意「只 `addLatLng` 新点」并不够 —— Leaflet 的 `addLatLng` 内部会
  `redraw()` 把整条线重新投影，实测 6000 点时单帧开销仍从 0.08ms 涨到 0.93ms。
  改为每 500 点冻结一段、只有末段在长之后，单帧开销与航迹总长基本无关：
  6000 点 0.93ms → 0.042ms；50000 点（≈4 小时航程）也只有 0.114ms。
- **一个抛异常的 store 订阅者会让它后面的订阅者全部收不到通知**：选中机场时
  `map.flyTo(..., Math.max(map.getZoom(), 15))` —— 上一次飞行动画还没结束就再次
  选中，`getZoom()` 返回 NaN，`Math.max(NaN, 15)` 仍是 NaN，Leaflet 抛
  "Invalid LatLng object"。而这是 Zustand 的订阅回调，异常会中断 `Set.forEach`，
  排在后面的订阅者（各面板的 React 订阅）全部收不到通知 —— 表现为「地图动了，
  但机场底卡不出来」，控制台只有一条看起来无关的 Leaflet 报错。已给缩放级别兜底。
- **地图图层有 6 处外部文本未转义就进了 innerHTML**（NFR-6）：Leaflet 的
  `divIcon` 与 `bindTooltip` 传字符串时内部都是 `node.innerHTML = content`，
  所以这两处都是 XSS 落点。文本来源并不都可信 —— 滑行道要素的 `ref`/`name`
  来自 **OpenStreetMap**（任何人可编辑），自绘滑行道的 `segment.name` 可由用户
  **从 JSON 文件导入**（别人分享的文件同样能带脚本）。同一个 `airport.code`
  在一个渲染器里转义、另一个里没转义，正是这类不一致的典型。
  6 处已全部走 `escapeHtml`，该函数移到 `core/utils/escape-html.ts` 并补 6 例单测
  （含「`&` 必须最先替换」这条容易改错的顺序约束），另补上了单引号转义。
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
