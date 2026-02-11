# OWO Flight Assistant 文档中心

欢迎来到 OWO Flight Assistant 的文档中心！本目录包含了应用的所有文档，按照功能和用途进行分类。

## 📚 文档结构

### 📖 [guides/](guides/) - 用户指南
用户使用手册和操作指南，帮助你快速上手和使用应用。

- **[QUICK_START.md](guides/QUICK_START.md)** - 快速入门指南
- **[SIMULATOR_CONNECTION_GUIDE.md](guides/SIMULATOR_CONNECTION_GUIDE.md)** - 模拟器连接指南
- **[USAGE_EXAMPLES.md](guides/USAGE_EXAMPLES.md)** - 使用示例

### ✨ [features/](features/) - 功能文档
各个功能模块的详细说明和使用方法。

- **[HOME_PAGE_MAJOR_UPDATE.md](features/HOME_PAGE_MAJOR_UPDATE.md)** - 首页重大更新说明
- **[HOME_SIMULATOR_STATUS.md](features/HOME_SIMULATOR_STATUS.md)** - 首页模拟器状态功能
- **[SIDEBAR_AIRPORT_INFO.md](features/SIDEBAR_AIRPORT_INFO.md)** - 侧边栏机场信息功能
- **[SIMULATOR_BUTTON_RELOCATION.md](features/SIMULATOR_BUTTON_RELOCATION.md)** - 模拟器按钮重定位

### 🛠️ [technical/](technical/) - 技术文档
技术实现细节、架构说明和调试指南。

- **[xplane_data_flow.md](technical/xplane_data_flow.md)** - X-Plane 数据流说明
- **[XPLANE_DEBUG_GUIDE.md](technical/XPLANE_DEBUG_GUIDE.md)** - X-Plane 调试指南

### 📝 [changelog/](changelog/) - 变更记录
版本更新、Bug 修复和重构记录。

- **[AIRCRAFT_ID_FIX.md](changelog/AIRCRAFT_ID_FIX.md)** - 机型识别修复
- **[REFACTORING_SUMMARY.md](changelog/REFACTORING_SUMMARY.md)** - 重构总结
- **[SIMULATOR_INTEGRATION_SUMMARY.md](changelog/SIMULATOR_INTEGRATION_SUMMARY.md)** - 模拟器集成总结
- **[XPLANE_CONNECTION_FIX.md](changelog/XPLANE_CONNECTION_FIX.md)** - X-Plane 连接修复

### ✈️ [fmcu/](fmcu/) - FMCU 仿真模块
飞行管理计算机单元（FMCU）仿真功能的完整文档。

- **[FMCU_SIMULATION.md](fmcu/FMCU_SIMULATION.md)** - 完整功能文档
- **[FMCU_QUICK_START.md](fmcu/FMCU_QUICK_START.md)** - 快速入门指南
- **[FMCU_IMPLEMENTATION_SUMMARY.md](fmcu/FMCU_IMPLEMENTATION_SUMMARY.md)** - 实现总结
- **[FMCU_UI_GUIDE.md](fmcu/FMCU_UI_GUIDE.md)** - 界面设计指南
- **[FMCU_CHECKLIST.md](fmcu/FMCU_CHECKLIST.md)** - 功能验证清单

## 🚀 快速导航

### 新用户入门
1. 📖 [快速入门指南](guides/QUICK_START.md) - 了解基本使用方法
2. 🔌 [模拟器连接指南](guides/SIMULATOR_CONNECTION_GUIDE.md) - 连接 X-Plane 或 MSFS
3. 💡 [使用示例](guides/USAGE_EXAMPLES.md) - 查看实际使用案例

### 功能探索
- ✈️ [FMCU 仿真](fmcu/FMCU_QUICK_START.md) - 体验专业的飞行管理计算机
- 🏠 [首页功能](features/HOME_PAGE_MAJOR_UPDATE.md) - 了解首页的强大功能
- 🛫 [机场信息](features/SIDEBAR_AIRPORT_INFO.md) - 查看详细的机场数据

### 开发者资源
- 🔧 [技术文档](technical/) - 了解技术实现细节
- 📝 [变更记录](changelog/) - 查看版本更新历史
- 🛠️ [调试指南](technical/XPLANE_DEBUG_GUIDE.md) - 解决技术问题

## 📋 文档分类说明

### guides/ - 用户指南
**目标读者**: 所有用户
**内容类型**: 操作指南、使用教程、快速入门
**更新频率**: 随功能更新

### features/ - 功能文档
**目标读者**: 用户、产品经理
**内容类型**: 功能说明、使用方法、特性介绍
**更新频率**: 新功能发布时

### technical/ - 技术文档
**目标读者**: 开发者、技术人员
**内容类型**: 架构设计、技术实现、调试方法
**更新频率**: 技术变更时

### changelog/ - 变更记录
**目标读者**: 所有用户、开发者
**内容类型**: 版本更新、Bug 修复、重构记录
**更新频率**: 每次重要更新

### fmcu/ - FMCU 模块
**目标读者**: 所有用户、开发者
**内容类型**: 完整的模块文档（用户+开发者）
**更新频率**: 模块更新时

## 🔍 查找文档

### 按用途查找
- **我想快速上手** → [guides/QUICK_START.md](guides/QUICK_START.md)
- **我想连接模拟器** → [guides/SIMULATOR_CONNECTION_GUIDE.md](guides/SIMULATOR_CONNECTION_GUIDE.md)
- **我想使用 FMCU** → [fmcu/FMCU_QUICK_START.md](fmcu/FMCU_QUICK_START.md)
- **我遇到了问题** → [technical/XPLANE_DEBUG_GUIDE.md](technical/XPLANE_DEBUG_GUIDE.md)
- **我想了解更新** → [changelog/](changelog/)

### 按角色查找
- **普通用户** → [guides/](guides/) + [features/](features/)
- **高级用户** → [fmcu/](fmcu/) + [features/](features/)
- **开发者** → [technical/](technical/) + [changelog/](changelog/)
- **贡献者** → 所有文档

## 📖 文档规范

### 文件命名
- 使用大写字母和下划线（如 `QUICK_START.md`）
- 使用描述性名称
- 避免使用特殊字符

### 文档结构
- 使用 Markdown 格式
- 包含清晰的标题层级
- 添加目录（长文档）
- 使用代码块和示例

### 更新原则
- 保持文档与代码同步
- 及时更新过时信息
- 添加版本号和日期
- 记录重要变更

## 🤝 贡献文档

欢迎贡献文档！请遵循以下步骤：

1. **选择合适的目录**
   - 用户指南 → `guides/`
   - 功能说明 → `features/`
   - 技术文档 → `technical/`
   - 变更记录 → `changelog/`
   - 模块文档 → 创建新的子目录

2. **创建文档**
   - 使用 Markdown 格式
   - 遵循现有文档的风格
   - 添加清晰的标题和结构

3. **更新索引**
   - 在本 README 中添加链接
   - 更新相关目录的 README

4. **提交审查**
   - 检查拼写和语法
   - 确保链接有效
   - 验证代码示例

## 📞 获取帮助

如果你在文档中找不到需要的信息：

1. 查看 [快速入门指南](guides/QUICK_START.md)
2. 浏览 [使用示例](guides/USAGE_EXAMPLES.md)
3. 查阅 [调试指南](technical/XPLANE_DEBUG_GUIDE.md)
4. 查看 [变更记录](changelog/) 了解最新更新

## 📅 文档版本

- **最后更新**: 2026-02-09
- **文档版本**: v2.0
- **应用版本**: v0.1.0

## 📜 许可证

本文档遵循项目主许可证。

---

**提示**: 使用 Ctrl+F（Windows）或 Cmd+F（Mac）快速搜索关键词！
