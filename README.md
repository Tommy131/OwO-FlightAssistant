# Flutter App Framework

一个现代化的跨平台应用框架，支持桌面端（Windows）和移动设备端（Android、iOS）。

## 特性

### 🎨 现代化UI设计
- **响应式布局**：自动适配桌面端和移动端
- **流畅动画**：侧边栏展开/折叠、页面切换等动画效果
- **亮色/暗色主题**：支持主题切换
- **精美组件**：卡片、按钮、导航栏等现代化组件

### 📱 移动端布局
- **顶部AppBar**：显示Logo、标题和操作按钮
- **主内容区**：展示当前页面内容
- **底部导航栏**：参考Instagram、WeChat、Telegram的设计
- **徽章支持**：显示未读消息数量等

### 💻 桌面端布局
- **可折叠侧边栏**：支持展开/折叠，带有流畅动画
- **顶部AppBar**：显示当前页面标题和操作按钮
- **主内容区**：宽敞的内容展示区域

### 🏗️ 模块化架构
```
lib/
├── core/                    # 核心模块
│   ├── app_theme.dart      # 主题配置
│   └── responsive.dart     # 响应式布局辅助
├── models/                  # 数据模型
│   └── navigation_item.dart # 导航项模型
├── widgets/                 # 可复用组件
│   ├── desktop/
│   │   └── sidebar.dart    # 桌面端侧边栏
│   └── mobile/
│       └── bottom_navbar.dart # 移动端底部导航栏
├── layouts/                 # 布局组件
│   ├── desktop_layout.dart # 桌面端布局
│   └── mobile_layout.dart  # 移动端布局
├── pages/                   # 页面
│   ├── home/               # 首页
│   ├── explore/            # 探索页
│   ├── messages/           # 消息页
│   ├── notifications/      # 通知页
│   └── profile/            # 个人资料页
└── main.dart               # 应用入口
```

## 技术栈

- **Flutter**: 跨平台UI框架
- **Material Design 3**: 现代化设计语言
- **响应式设计**: 自适应不同屏幕尺寸

## 运行项目

### 桌面端（Windows）
```bash
flutter run -d windows
```

### 移动端（Android）
```bash
flutter run -d android
```

### 移动端（iOS）
```bash
flutter run -d ios
```

## 主要功能

### 1. 首页
- 欢迎卡片
- 统计数据展示
- 最近活动列表

### 2. 探索页
- 分类标签筛选
- 内容网格展示
- 点赞和评论统计

### 3. 消息页
- 消息列表
- 未读消息标记
- 搜索功能

### 4. 通知页
- 不同类型的通知（点赞、评论、关注、分享）
- 未读通知标记
- 时间显示

### 5. 个人资料页
- 用户信息展示
- 统计数据（帖子、关注、粉丝）
- 设置选项列表

## 自定义配置

### 修改主题颜色
编辑 `lib/core/app_theme.dart` 文件中的颜色常量：

```dart
static const Color primaryColor = Color(0xFF6C5CE7);
static const Color secondaryColor = Color(0xFFA29BFE);
static const Color accentColor = Color(0xFF00B894);
```

### 添加新页面
1. 在 `lib/pages/` 目录下创建新页面
2. 在 `lib/main.dart` 中的 `_navigationItems` 列表中添加新的导航项

### 调整响应式断点
编辑 `lib/core/responsive.dart` 文件中的断点值：

```dart
static bool isMobile(BuildContext context) =>
    MediaQuery.of(context).size.width < 650;

static bool isDesktop(BuildContext context) =>
    MediaQuery.of(context).size.width >= 1100;
```

## 开发建议

1. **保持模块化**：每个功能模块独立开发，便于维护
2. **复用组件**：使用 `widgets/` 目录下的可复用组件
3. **统一主题**：使用 `AppTheme` 中定义的颜色和样式
4. **响应式优先**：确保所有页面在不同屏幕尺寸下都能正常显示

## 许可证

MIT License
