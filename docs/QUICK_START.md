# 🚀 快速开始指南

## 📋 模拟器对接已完成！

您的飞行检查单应用现在已经完全支持与 **Microsoft Flight Simulator** 和 **X-Plane** 的实时连接！

---

## ⚡ 快速测试步骤

### 1. 安装依赖

```bash
cd d:\Workspace\flutter_projects\owo_flight_check_list
flutter pub get
```

### 2. 运行应用

```bash
flutter run -d windows
```

### 3. 测试 X-Plane 连接（最简单）

**X-Plane 配置：**
1. 启动 X-Plane
2. 进入 **Settings** → **Data Output**
3. 启用 **Network via UDP**
4. 设置输出到 `127.0.0.1:49001`

**应用操作：**
1. 打开应用，进入"飞行检查单"页面
2. 点击顶部的"未连接模拟器"按钮
3. 选择"连接 X-Plane"
4. 看到状态变为绿色"已连接 X-Plane"即成功！

### 4. 测试 MSFS 连接（需要额外步骤）

**安装 WebSocket 服务器：**
```bash
# 方法1：使用 Node.js（推荐）
git clone https://github.com/odwdinc/MSFS-WebSocket-Server.git
cd MSFS-WebSocket-Server
npm install
npm start
```

**应用操作：**
1. 确保 MSFS 正在运行
2. 确保 WebSocket 服务器正在运行
3. 打开应用，进入"飞行检查单"页面
4. 点击连接按钮，选择"连接 MSFS"
5. 看到状态变为绿色即成功！

---

## 📁 项目结构

```
lib/
├── core/
│   ├── models/
│   │   ├── flight_checklist.dart      # 检查单数据模型
│   │   └── simulator_data.dart        # 模拟器数据模型 ✨新增
│   ├── providers/
│   │   ├── checklist_provider.dart    # 检查单状态管理
│   │   └── simulator_provider.dart    # 模拟器连接管理 ✨新增
│   └── services/
│       ├── checklist_service.dart     # 检查单数据服务
│       ├── msfs_service.dart          # MSFS连接服务 ✨新增
│       └── xplane_service.dart        # X-Plane连接服务 ✨新增
├── pages/
│   ├── checklist/
│   │   └── checklist_page.dart        # 检查单页面（已更新）
│   └── home/
│       └── home_page.dart             # 首页
└── app.dart                           # 应用入口（已更新）
```

---

## 🎯 核心功能

### ✅ 已实现

1. **完整的检查清单**
   - A320 系列：93 个检查项
   - B737 系列：84 个检查项
   - 9 个飞行阶段全覆盖

2. **X-Plane 实时连接**
   - UDP 直连，无需插件
   - 20+ DataRefs 实时监控
   - 5 Hz 更新频率

3. **MSFS 实时连接**
   - WebSocket 桥接
   - 17+ SimVars 实时监控
   - 自动重连机制

4. **智能UI**
   - 动态连接状态显示
   - 一键切换模拟器
   - 实时数据可视化（预留）

### 🔮 未来功能

- [ ] 自动验证检查项
- [ ] 语音提示
- [ ] 飞行记录
- [ ] 更多机型

---

## 🐛 常见问题

### Q: X-Plane 连接失败？
**A:** 检查以下几点：
1. X-Plane 的 Data Output 是否正确配置
2. 防火墙是否允许 UDP 49001
3. 尝试重启 X-Plane

### Q: MSFS 连接失败？
**A:** 检查以下几点：
1. WebSocket 服务器是否正在运行
2. MSFS 是否已启动并加载飞机
3. 端口 8080 是否被占用
4. 查看服务器控制台日志

### Q: 连接成功但没有数据？
**A:**
1. X-Plane：确保在 Data Output 中启用了相应的数据项
2. MSFS：确保 SimConnect 已正确初始化
3. 尝试断开并重新连接

---

## 📚 详细文档

- **`CHECKLIST_README.md`** - 检查单功能详解
- **`SIMULATOR_CONNECTION_GUIDE.md`** - 模拟器连接详细指南
- **`SIMULATOR_INTEGRATION_SUMMARY.md`** - 技术实现总结

---

## 🎓 代码示例

### 获取模拟器数据

```dart
// 在任何 Widget 中
Consumer<SimulatorProvider>(
  builder: (context, simProvider, _) {
    if (!simProvider.isConnected) {
      return Text('未连接');
    }

    final data = simProvider.simulatorData;
    return Column(
      children: [
        Text('空速: ${data.airspeed?.toStringAsFixed(0) ?? "N/A"} kt'),
        Text('高度: ${data.altitude?.toStringAsFixed(0) ?? "N/A"} ft'),
        Text('航向: ${data.heading?.toStringAsFixed(0) ?? "N/A"}°'),
      ],
    );
  },
)
```

### 手动连接

```dart
final simProvider = Provider.of<SimulatorProvider>(context, listen: false);

// 连接 X-Plane
await simProvider.connectToXPlane();

// 连接 MSFS
await simProvider.connectToMSFS();

// 断开
await simProvider.disconnect();
```

---

## 🎉 开始使用

现在您可以：

1. ✅ 运行应用
2. ✅ 连接您的模拟器
3. ✅ 使用专业的飞行检查单
4. ✅ 实时监控飞行数据

**祝您飞行愉快！** ✈️🎮

---

## 💡 提示

- 建议先测试 X-Plane 连接（更简单）
- MSFS 需要额外的 WebSocket 服务器
- 所有连接都是本地的，无需互联网
- 数据更新是实时的，延迟极低

---

**有问题？查看详细文档或提交 Issue！**
