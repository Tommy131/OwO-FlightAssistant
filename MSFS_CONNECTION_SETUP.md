# MSFS 连接设置指南

## 🎯 目标

让你的 Flutter 应用能够实时连接 Microsoft Flight Simulator (MSFS) 并获取飞行数据。

## ⚡ 快速开始（3步）

### 步骤 1：编译服务器（首次使用）

**前置要求：**
- Go 1.21 或更高版本（https://golang.org/）

**编译：**
```bash
cd msfs_bridge
go build -o msfs-bridge.exe
```

或双击 `build.bat`

### 步骤 2：启动服务器

```bash
msfs-bridge.exe
```

或双击 `start.bat`

成功标志：
```
MSFS WebSocket Bridge started on port 8080
Attempting to connect to MSFS...
Connected to MSFS SimConnect
```

### 步骤 3：连接应用

1. 启动 Flutter 应用
2. 进入"飞行检查单"页面
3. 点击连接按钮
4. 选择"连接 MSFS"
5. 等待按钮变绿

## 📁 项目结构

```
msfs_bridge/
├── main.go                      # 入口文件
├── go.mod                       # Go 模块定义
├── internal/
│   ├── bridge/                  # 桥接逻辑（组件化）
│   ├── config/                  # 配置管理（可复用）
│   ├── simconnect/              # SimConnect 客户端（独立模块）
│   └── websocket/               # WebSocket 服务器（独立模块）
├── build.bat                    # Windows 构建脚本
├── start.bat                    # Windows 启动脚本
└── README.md                    # 详细文档

lib/apps/services/
└── msfs_service.dart            # Flutter MSFS 客户端
```

## 🔧 工作原理

```
┌─────────────────────────────────────────────────────┐
│                  Flutter 应用                        │
│  ┌──────────────────────────────────────────────┐  │
│  │         MSFSService (Dart)                   │  │
│  │  - WebSocket 客户端                          │  │
│  │  - 数据解析和处理                            │  │
│  └──────────────┬───────────────────────────────┘  │
└─────────────────┼──────────────────────────────────┘
                  │ WebSocket (ws://localhost:8080)
                  │ JSON 数据格式
┌─────────────────▼──────────────────────────────────┐
│           Go Bridge Server                          │
│  ┌──────────────────────────────────────────────┐  │
│  │  - WebSocket 服务器 (gorilla/websocket)     │  │
│  │  - SimConnect 客户端 (lian/msfs2020-go)    │  │
│  │  - 数据格式化和转发                          │  │
│  │  - 自动重连和心跳                            │  │
│  └──────────────┬───────────────────────────────┘  │
└─────────────────┼──────────────────────────────────┘
                  │ SimConnect Protocol
                  │ 二进制数据格式
┌─────────────────▼──────────────────────────────────┐
│         Microsoft Flight Simulator                  │
│  - SimConnect SDK                                   │
│  - 55+ SimVars 数据源                              │
│  - 5Hz 更新频率                                    │
└─────────────────────────────────────────────────────┘
```

## 📊 支持的数据

### 飞行数据
- 空速、马赫数、高度、航向、垂直速度
- 俯仰角、横滚角、经纬度

### 系统状态
- 停机刹车、灯光系统、襟翼、起落架
- 减速板、扰流板、自动刹车

### 发动机
- APU、发动机状态、N1、发动机数量

### 自动驾驶
- 自动驾驶、自动油门

### 警告系统
- 失速、超速、坠毁、火警、主警告/告警

### 环境数据
- 温度、风速/风向、能见度、气压

### 其他
- 机型信息、地面状态、暂停状态、应答机、COM频率

**总计：55+ 数据点**

## ❓ 常见问题

### Q: 服务器无法连接到 MSFS

**A:** 确保：
1. MSFS 已启动并加载飞机（不能停留在主菜单）
2. 已进入驾驶舱视角
3. 模拟器未暂停

### Q: 端口 8080 被占用

**A:** 使用自定义端口：
```bash
msfs-bridge.exe -port 9000
```

### Q: Flutter 应用无法连接

**A:** 确保：
1. 服务器正在运行
2. 服务器显示"Connected to MSFS SimConnect"
3. 应用配置为 `localhost:8080`

### Q: 如何查看详细日志

**A:** 使用 verbose 模式：
```bash
msfs-bridge.exe -verbose
```

## 🎯 优势

相比 Node.js 版本：

- ✅ **单一可执行文件** - 无需安装 Node.js
- ✅ **更低内存占用** - <20MB vs ~50MB
- ✅ **更快启动速度** - 即时启动
- ✅ **更好的性能** - Go 原生并发
- ✅ **更小的体积** - ~5MB vs ~50MB
- ✅ **跨平台编译** - 一次编译，到处运行

## 📚 详细文档

- **服务器文档**: `msfs_bridge/README.md`
- **快速开始**: `docs/guides/MSFS_QUICK_START_CN.md`
- **故障排除**: `docs/guides/MSFS_TROUBLESHOOTING.md`
- **完整指南**: `docs/guides/SIMULATOR_CONNECTION_GUIDE.md`

## 🎉 完成！

现在你可以：
- ✅ 实时查看飞行数据
- ✅ 使用智能检查单功能
- ✅ 监控飞机系统状态
- ✅ 记录飞行日志

**祝你飞行愉快！** ✈️

---

## 💡 提示

- 服务器需要在使用期间持续运行
- 支持多个应用同时连接
- 对系统性能影响极小（<1% CPU）
- 自动重连，无需手动干预

## 🔗 相关链接

- [Go 官网](https://golang.org/)
- [lian/msfs2020-go](https://github.com/lian/msfs2020-go)
- [MSFS SimConnect SDK](https://docs.flightsimulator.com/html/Programming_Tools/SimConnect/SimConnect_SDK.htm)
