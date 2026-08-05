# 项目专属约定

> 权威设计见 **[`docs/DESIGN.md`](docs/DESIGN.md)**；通用工程规范见工程手册。
> 本文件只写**本项目的差异点与避坑清单**。

---

## 目录即命名空间

```
src/
├─ core/          框架层：注册表 / 主题 / i18n / 持久化 / 布局 / 通用组件
│                 ⚠️ MUST NOT import 任何 modules/ —— 框架对业务模块一无所知
└─ modules/<名>/  业务模块，自带 pages / providers / services / models / localization
                  每个模块在 <名>-module.tsx 里声明式注册
```

新增功能 = 加一个 `modules/<名>/` 目录 + 在 `modules-register-entry.ts` 加一行。
**不改框架核心**。删掉任一模块目录 + 去掉注册行，应用仍应能编译运行。

---

## 关键约定

### 注册表工厂**可以**调用 React hooks

`core/module-registry/` 里注册的工厂函数在 render 期间求值，等价于 Flutter 的
`context.watch`。这是**有意设计**，不要「优化」成 `getState()` —— 那样会丢掉响应性。
`initializeAll()` 之后禁止再注册，所以 hooks 调用顺序是稳定的。

### 纯计算 service 不许碰框架

`services/` 下的几何与解析模块（`approach-beam` / `holding-geometry` /
`papi-guidance` / `airport-outline` / `map-airport-parser`）**MUST NOT** import
React、Leaflet、Zustand 或任何 IO。它们要能被单独调用和测试。

### 后端字段是 PascalCase

中间件返回 `Runways` / `LeLat` / `HeIdent` 这类 PascalCase 键，解析一律走
`pickString` / `pickDouble` 的多候选键写法，别写死单一大小写。

### 后端路由：一个路径只能绑一个 HTTP 方法

中间件的 mux 按 `route.Method` 校验，同路径重复注册会 panic。
所以接口一律用 `/资源/动作` 命名（`/flight-logs/list`、`/settings/bulk-set`），
不能用 RESTful 的同路径多方法。

---

## 避坑清单（都是真踩过的）

| 坑 | 说明 |
|---|---|
| **上游用 200 返回错误** | RainViewer 超缩放返回画着 "Zoom Level Not Supported" 的 PNG；Esri 返回 "Map data not yet available" 占位图（恒 2521 字节）；Overpass 超时返回 `elements: []` + `remark`。**只看状态码一律发现不了**，必须校验内容。 |
| **Overpass 区域镜像** | 只能收录**全球**实例。区域镜像（如 overpass.osm.ch 只有瑞士数据）对范围外查询返回 200 + 空 `elements` + 无 remark，看起来像「查询成功、该机场没有滑行道」。 |
| **航向台字段是打包值** | `earth_nav.dat` 的 LOC 字段 = `磁航道 × 360 + 真方位`。**画图用真方位、显示用磁航道**，混用会整体偏一个磁差角。 |
| **Leaflet LayerGroup 不隔离 z 序** | 所有矢量共用一个 `<svg>`，谁后 `addTo` 谁在上。需要稳定叠放顺序就用 `createPane` + 固定 z-index。 |
| **自建 pane 的 SVG 会被裁成 0 宽** | leaflet.css 只给 `.leaflet-overlay-pane svg` 解了 `max-width`。自建 pane 必须在 CSS 里补 `max-width/max-height: none`，否则矢量在 DOM 里、尺寸也对，就是一个像素都画不出来。 |
| **overflow 会裁掉弹出面板** | CSS 规定 `overflow-x/y` 只要有一个非 `visible`，另一个的 `visible` 就当 `auto`。带 `overflow` 的容器里放绝对定位的浮层会被整个裁掉。 |
| **栅格子项的百分比按自身 grid area 解析** | 在 `auto` 宽度的列里写 `max-width: 42%` 等于永远裁掉 58%，和可用空间无关。 |
| **Leaflet 标记按纬度排 z-index** | 同 pane 内不给 `zIndexOffset` 的话，压盖顺序由地理位置决定。重要标签要显式分层。 |
| **divIcon 给了 iconSize 就写死宽高** | 需要按内容自适应时传 `undefined`，用零尺寸外壳 + 内层 `translate(-50%,-50%)` 自己居中。**别在标记本体上写 transform** —— Leaflet 用它定位。 |

---

## 变更影响矩阵（改 A 必须连带查 B）

| 改动 | 必须连带检查 |
|---|---|
| 中间件新增/改接口 | `modules/http/services/middleware-http-service.ts` → 对应 store → 页面；`docs/DESIGN.md` 的 FR 表 |
| 改 `map-legends.ts` 的数值区间或配色 | 中间件 `map_overlay.go` 的 `colorForLayer()` —— **两边必须逐条对齐**，改一边就要改另一边 |
| 新增 i18n 文案 | zh/en/de 三份同步；缺键会回退成 key 本身暴露在界面上 |
| 改版本号 | `package.json` 是唯一来源；README 版本行由 `scripts/check-version-sync.mjs` 校验 |
| 新增地图图层 | 图例（`map-legends.ts`）+ 控制栏分组（`map-page.tsx`）+ 订阅里的重绘条件 |
| 在中间件仓库执行 `git add -A` | 先确认 `.gitignore` 里的 `web/` 仍在 —— 否则闭源后端会把公开前端一起收进去 |

---

## 提交与分支

- 提交信息用 [Conventional Commits](https://www.conventionalcommits.org/)：`type(scope): subject`，英文祈使句。
  type：`feat / fix / refactor / docs / chore / ci / test / perf`。
- **提交信息不加 AI 署名。**
- 不直接提交主干，走 `feat/<topic>` / `fix/<topic>` 分支；合并门禁：`npm run typecheck` +
  `npm run build` 全过。
- 发布前 MUST 更新 `docs/CHANGELOG.md` 顶部段落 —— CI 从那里生成 Release notes。
