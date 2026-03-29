# OWO Flight Assistant: EFB 深度分析与未来功能规划报告

## 1. 项目现状深度评估 (Current Status Assessment)

### 1.1 核心架构

当前项目采用了 **Flutter App + Go Middleware** 的双端架构。这种设计非常合理：

- **中间件 (Middleware)**: 承担了繁重的 NavData 解析 (AIRAC, LNM, MSFS/XP)
  和模拟器实时通信 (SimConnect/UDP) 任务，保证了数据的准确性与高效采集。
- **移动端 (Flutter)**: 提供了现代化的跨平台 UI 体验，利用 Provider
  进行状态管理，支持多语言国际化，具备良好的响应式设计。

### 1.2 已有功能模块

- **仪表板 (Home/Dashboard)**: 实现了发动机、燃料、环境、导航
  及主飞行数据的实时监控。
- **移动地图 (Moving Map)**: 支持飞机位置跟踪、机场标记、滑行道绘制
  及基本的飞行告警。
- **检查单 (Checklist)**: 内置了 A320、B737 及通用机型的标准化检查单，
  支持阶段跳转。
- **飞行简报 (Briefing)**: 提供基于机场和 METAR 的自动化简报生成，
  具备基本的燃油测算和跑道建议。
- **工具箱 (Toolbox)**: 包含单位转换、术语翻译、天气解码以及基础的
  重量平衡与性能计算器。
- **飞行日志 (Flight Logs)**: 实现了飞行过程记录、航迹回放及参数分析图表。

---

## 2. 差距分析 (Gap Analysis vs Professional EFB)

对比真实飞行中使用的专业 EFB（如 ForeFlight, Jeppesen FliteDeck,
Navigraph, FlyByWire EFB），当前项目在以下方面仍有提升空间：

### 2.1 飞行计划深度 (Flight Planning)

- **现状**: 简报生成主要依赖手动输入或简单的本地计算。
- **差距**: 缺乏与 **SimBrief** 的原生集成。专业飞行员通常从 SimBrief
  获取详细的 OFP (Operational Flight Plan)，包括精确的油耗、载荷、
  航路点和垂直剖面。

### 2.2 航图系统 (Charts & Plates)

- **现状**: 地图功能偏向 VFR 或基础导航，只有机场坐标和滑行道。
- **差距**: 缺失 **Navigraph / Jeppesen** 航图集成。无法直接在 App 内
  查看 SID/STAR 和进近图，且地图不支持 Georeferenced
  （航图叠加在地图上显示飞机位置）。

### 2.3 气象与情报 (Weather & NOTAMs)

- **现状**: 仅支持 METAR 查询和简单的天气解码。
- **差距**: 缺失 **TAF (预报)**、**NOTAM (航行通告)**、
  **Radar (降水雷达图)** 和 **Sigmet/Airmet**。
  这些信息对于决策是否出发或备降至关重要。

### 2.4 专业性能计算 (Performance Calculation)

- **现状**: 性能计算器使用通用简化模型。
- **差距**: 缺乏针对具体机型 (如 Toliss A320, PMDG 737) 的精确性能数据。
  真实 EFB 需要根据当前的重量、气压、温度、跑道长度、道面状况计算
  V-speeds 和 FLEX/ASSUMED 温度。

### 2.5 文档管理 (Document Management)

- **现状**: 无文档查看功能。
- **差距**: 缺乏 **PDF/QRH/SOP 浏览器**。在模拟飞行中，快速查阅
  QRH (快速检查单) 或公司 SOP 手册是核心需求。

---

## 3. 未来功能路线图 (Future Roadmap)

### 3.1 短期规划 (P1 - 提升效率与基础完整性)

1. **SimBrief API 集成**:
    - 通过 SimBrief 用户 ID 一键获取最新计划。
    - 自动填充简报中的航路、油耗、配载和高度数据。
2. **气象增强**:
    - 增加 TAF 预报显示。
    - 集成 NOTAM 查询功能，并按关键字（如“RWY”, “ILS”, “CLOSED”）
      进行着色标记。
3. **性能工具优化**:
    - 增加针对 A320/B737 的简易 V-speeds 快速查表工具。

### 3.2 中期规划 (P2 - 增强态势感知)

1. **PDF 浏览器**:
    - 支持用户上传 PDF 文档（QRH, SOP, POH）。
    - 支持书签和快速搜索。
2. **联网流量监控 (Vatsim/IVAO)**:
    - 在地图上显示 Vatsim/IVAO 联网飞机的实时位置、高度和呼号。
    - 显示当前在线的 ATC 区域。
3. **电子手写板 (Scratchpad)**:
    - 提供手写 or 快速文本输入功能，用于记录 ATC 许可 (Clearance)
      和 ATIS 信息。

### 3.3 长期规划 (P3 - 专业化生态建设)

1. **Navigraph Charts 集成**:
    - 如果具备 API 权限，集成 Navigraph 航图显示。
2. **高级飞行分析 (FOQA-light)**:
    - 自动检测飞行违规（如：超速、进近不稳定、硬着陆等）。
    - 生成详细的飞行质量评分报告。
3. **自定义检查单引擎**:
    - 允许用户通过 JSON 或 UI 自定义检查单内容，满足不同插件机型或公司规范。

---

## 4. 优化方向 (Optimization Suggestions)

### 4.1 UI/UX 体验

- **EFB 化交互**: 采用更符合平板电脑操作的侧边栏或底部标签栏切换，减少层级。
- **自定义仪表板**: 允许用户长按卡片进行位置拖拽或隐藏，定制属于自己的监控面板。
- **多窗口支持**: 针对 iPad/安卓平板提供分屏或画中画功能。

### 4.2 技术底层

- **数据存储**: 目前日志和简报使用 JSON 文件存储，随着数据量增加，
  建议迁移至 **SQLite** 以提升查询效率。
- **连接稳定性**: 在 Home 页面增加更详细的连接诊断（如：Middleware 延迟、
  SimConnect 状态、UDP 丢包率）。
- **数据频率管理**: 允许用户在设置中调节数据采集频率（例如：低功耗模式
  vs 高频率记录模式）。

---

## 5. 总结

`OWO Flight Assistant` 目前已经是一个非常实用且架构稳健的飞行辅助工具。
通过加强 **SimBrief 集成**、**专业气象情报 (TAF/NOTAM)**
和 **文档管理** 功能，它将能从一个“数据监控器”蜕变为一个
真正的“电子飞行包 (EFB)”。

报告生成于: 2026-03-26
分析人: OWO Assistant (Powered by Gemini-3-Flash)
