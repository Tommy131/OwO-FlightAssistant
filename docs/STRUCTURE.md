# 文档结构说明

本文档提供 OWO Flight Assistant 文档目录的完整结构视图。

## 📁 目录树

```
docs/
├── README.md                           # 📖 文档中心主页
├── STRUCTURE.md                        # 📋 本文档（结构说明）
│
├── guides/                             # 📚 用户指南
│   ├── README.md                       # 目录说明
│   ├── QUICK_START.md                  # 快速入门指南
│   ├── SIMULATOR_CONNECTION_GUIDE.md   # 模拟器连接指南
│   └── USAGE_EXAMPLES.md               # 使用示例
│
├── features/                           # ✨ 功能文档
│   ├── README.md                       # 目录说明
│   ├── HOME_PAGE_MAJOR_UPDATE.md       # 首页重大更新
│   ├── HOME_SIMULATOR_STATUS.md        # 首页模拟器状态
│   ├── SIDEBAR_AIRPORT_INFO.md         # 侧边栏机场信息
│   └── SIMULATOR_BUTTON_RELOCATION.md  # 模拟器按钮重定位
│
├── technical/                          # 🛠️ 技术文档
│   ├── README.md                       # 目录说明
│   ├── xplane_data_flow.md             # X-Plane 数据流
│   └── XPLANE_DEBUG_GUIDE.md           # X-Plane 调试指南
│
├── changelog/                          # 📝 变更记录
│   ├── README.md                       # 目录说明
│   ├── AIRCRAFT_ID_FIX.md              # 机型识别修复
│   ├── REFACTORING_SUMMARY.md          # 重构总结
│   ├── SIMULATOR_INTEGRATION_SUMMARY.md # 模拟器集成总结
│   └── XPLANE_CONNECTION_FIX.md        # X-Plane 连接修复
│
└── fmcu/                               # ✈️ FMCU 仿真模块
    ├── README.md                       # 模块文档主页
    ├── FMCU_SIMULATION.md              # 完整功能文档
    ├── FMCU_QUICK_START.md             # 快速入门指南
    ├── FMCU_UI_GUIDE.md                # 界面设计指南
    ├── FMCU_IMPLEMENTATION_SUMMARY.md  # 实现总结
    └── FMCU_CHECKLIST.md               # 功能验证清单
```

## 📊 统计信息

### 文档数量
- **总文档数**: 26 个
- **README 文档**: 6 个
- **功能文档**: 20 个

### 按目录分类
| 目录 | 文档数 | 说明 |
|------|--------|------|
| guides/ | 4 | 用户使用指南 |
| features/ | 5 | 功能说明文档 |
| technical/ | 3 | 技术实现文档 |
| changelog/ | 5 | 版本变更记录 |
| fmcu/ | 6 | FMCU 模块文档 |
| 根目录 | 3 | 索引和说明 |

### 按类型分类
| 类型 | 数量 | 示例 |
|------|------|------|
| 用户指南 | 7 | QUICK_START.md |
| 功能说明 | 4 | HOME_PAGE_MAJOR_UPDATE.md |
| 技术文档 | 2 | xplane_data_flow.md |
| 变更记录 | 4 | AIRCRAFT_ID_FIX.md |
| 模块文档 | 5 | FMCU_SIMULATION.md |
| 索引文档 | 6 | README.md |

## 🎯 文档分类逻辑

### guides/ - 用户指南
**分类标准**: 面向用户的操作指南和教程
- 快速入门
- 使用教程
- 操作指南
- 最佳实践

**目标读者**: 所有用户（新手到高级）

---

### features/ - 功能文档
**分类标准**: 具体功能模块的说明文档
- 功能介绍
- 使用方法
- 界面说明
- 功能更新

**目标读者**: 用户、产品经理

---

### technical/ - 技术文档
**分类标准**: 技术实现和架构文档
- 架构设计
- 技术实现
- 调试指南
- 性能优化

**目标读者**: 开发者、技术人员

---

### changelog/ - 变更记录
**分类标准**: 版本更新和变更历史
- Bug 修复
- 功能更新
- 重构记录
- 性能优化

**目标读者**: 所有用户、开发者

---

### fmcu/ - FMCU 模块
**分类标准**: 独立功能模块的完整文档
- 模块说明
- 使用指南
- 技术实现
- 开发文档

**目标读者**: 所有用户、开发者

## 🔍 查找文档

### 按角色查找

#### 👤 普通用户
```
docs/
├── README.md                    ← 从这里开始
├── guides/
│   ├── QUICK_START.md          ← 快速入门
│   └── SIMULATOR_CONNECTION_GUIDE.md
├── features/                    ← 了解功能
└── fmcu/
    └── FMCU_QUICK_START.md     ← FMCU 使用
```

#### 👨‍💻 开发者
```
docs/
├── README.md                    ← 从这里开始
├── technical/                   ← 技术实现
│   ├── xplane_data_flow.md
│   └── XPLANE_DEBUG_GUIDE.md
├── changelog/                   ← 变更历史
└── fmcu/
    └── FMCU_IMPLEMENTATION_SUMMARY.md ← 实现细节
```

#### 🎨 设计师
```
docs/
├── README.md                    ← 从这里开始
├── features/                    ← 功能理解
└── fmcu/
    └── FMCU_UI_GUIDE.md        ← 界面设计
```

### 按需求查找

#### 🚀 快速上手
1. [docs/README.md](README.md)
2. [guides/QUICK_START.md](guides/QUICK_START.md)
3. [guides/SIMULATOR_CONNECTION_GUIDE.md](guides/SIMULATOR_CONNECTION_GUIDE.md)

#### 📚 深入学习
1. [features/](features/) - 了解所有功能
2. [fmcu/FMCU_SIMULATION.md](fmcu/FMCU_SIMULATION.md) - FMCU 详解
3. [guides/USAGE_EXAMPLES.md](guides/USAGE_EXAMPLES.md) - 实践案例

#### 🔧 技术研究
1. [technical/](technical/) - 技术文档
2. [changelog/](changelog/) - 变更历史
3. [fmcu/FMCU_IMPLEMENTATION_SUMMARY.md](fmcu/FMCU_IMPLEMENTATION_SUMMARY.md) - 实现细节

#### 🐛 问题排查
1. [technical/XPLANE_DEBUG_GUIDE.md](technical/XPLANE_DEBUG_GUIDE.md) - 调试指南
2. [changelog/](changelog/) - 已知问题
3. [guides/SIMULATOR_CONNECTION_GUIDE.md](guides/SIMULATOR_CONNECTION_GUIDE.md) - 连接问题

## 📖 阅读顺序建议

### 新用户推荐路径
```
1. docs/README.md
   ↓
2. guides/QUICK_START.md
   ↓
3. guides/SIMULATOR_CONNECTION_GUIDE.md
   ↓
4. features/ (浏览感兴趣的功能)
   ↓
5. fmcu/FMCU_QUICK_START.md (如需使用 FMCU)
```

### 开发者推荐路径
```
1. docs/README.md
   ↓
2. technical/ (了解技术架构)
   ↓
3. changelog/ (了解变更历史)
   ↓
4. fmcu/FMCU_IMPLEMENTATION_SUMMARY.md (模块实现)
   ↓
5. 代码库 (开始开发)
```

## 🔗 文档间关联

### 交叉引用
文档之间通过相对路径相互引用：

```markdown
# 在 guides/QUICK_START.md 中
参考 [FMCU 快速入门](../fmcu/FMCU_QUICK_START.md)

# 在 fmcu/README.md 中
返回 [文档中心](../README.md)
```

### 导航链接
每个子目录的 README.md 都包含：
- 返回文档中心的链接
- 相关文档的链接
- 快速导航菜单

## 📝 文档维护

### 添加新文档
1. 确定文档类型和目标目录
2. 创建文档文件
3. 更新对应目录的 README.md
4. 更新 docs/README.md（如需要）
5. 更新本文档（STRUCTURE.md）

### 移动文档
1. 移动文件到新位置
2. 更新所有引用该文档的链接
3. 更新相关 README.md
4. 更新本文档

### 删除文档
1. 确认文档不再需要
2. 检查是否有其他文档引用
3. 删除文件
4. 更新相关 README.md
5. 更新本文档

## 🎨 文档命名规范

### 文件命名
- 使用大写字母和下划线：`QUICK_START.md`
- 使用描述性名称：`SIMULATOR_CONNECTION_GUIDE.md`
- 特殊情况：`xplane_data_flow.md`（技术文档可用小写）

### 目录命名
- 使用小写字母：`guides/`, `features/`
- 使用复数形式：`guides/` 而不是 `guide/`
- 简短且描述性：`fmcu/` 而不是 `fmcu_simulation/`

## 📊 文档质量指标

### 完整性
- ✅ 所有目录都有 README.md
- ✅ 所有文档都有清晰的标题
- ✅ 所有文档都有目标读者说明
- ✅ 所有文档都有更新日期

### 可访问性
- ✅ 清晰的目录结构
- ✅ 完善的导航链接
- ✅ 多种查找方式
- ✅ 详细的索引

### 可维护性
- ✅ 统一的命名规范
- ✅ 清晰的分类逻辑
- ✅ 完善的维护指南
- ✅ 版本信息记录

## 🔄 版本历史

### v2.0 (2026-02-09)
- ✨ 重新组织文档结构
- 📁 创建分类目录
- 📖 添加各目录 README
- 📋 创建结构说明文档

### v1.0 (之前)
- 📝 所有文档在根目录
- 📁 仅 fmcu/ 子目录

## 📞 反馈建议

如果你对文档结构有任何建议：
- 文档难以查找
- 分类不够清晰
- 缺少某类文档
- 其他改进建议

欢迎提出反馈！

---

**最后更新**: 2026-02-09  
**文档版本**: v2.0  
**维护者**: 开发团队

[← 返回文档中心](README.md)
