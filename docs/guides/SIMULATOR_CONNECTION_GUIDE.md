# 模拟器连接指南

## 📡 支持的模拟器

- **Microsoft Flight Simulator 2020/2024** (通过 WebSocket)
- **X-Plane 11/12** (通过 UDP)

---

## 🎮 X-Plane 连接设置

### 1. 配置 X-Plane

X-Plane 原生支持 UDP 数据输出，无需额外插件。

#### 步骤：

1. 启动 X-Plane
2. 进入 **Settings** → **Data Output**
3. 确保 **Network via UDP** 已启用
4. 设置输出地址：
   - IP: `127.0.0.1` (本地)
   - Port: `49001`

### 2. 在应用中连接

1. 打开 **OwO! FlightAssistant**
2. 进入 **飞行检查单** 页面
3. 点击顶部的连接状态按钮
4. 选择 **"连接 X-Plane"**
5. 等待连接成功（状态变为绿色）

### 支持的 DataRefs

应用会自动订阅以下 DataRefs：

**飞行数据：**
- `sim/flightmodel/position/indicated_airspeed` - 指示空速
- `sim/flightmodel/position/elevation` - 高度
- `sim/flightmodel/position/mag_psi` - 磁航向
- `sim/flightmodel/position/vh_ind` - 垂直速度

**系统状态：**
- `sim/cockpit2/controls/parking_brake_ratio` - 停机刹车
- `sim/cockpit/electrical/beacon_lights_on` - 信标灯
- `sim/cockpit/electrical/landing_lights_on` - 着陆灯
- `sim/cockpit/electrical/taxi_light_on` - 滑行灯
- `sim/cockpit/electrical/nav_lights_on` - 导航灯
- `sim/cockpit/electrical/strobe_lights_on` - 频闪灯
- `sim/flightmodel/controls/flaprqst` - 襟翼位置
- `sim/aircraft/parts/acf_gear_deploy` - 起落架

**发动机：**
- `sim/cockpit/engine/APU_running` - APU
- `sim/flightmodel/engine/ENGN_running[0]` - 发动机1
- `sim/flightmodel/engine/ENGN_running[1]` - 发动机2

**自动驾驶：**
- `sim/cockpit/autopilot/autopilot_mode` - 自动驾驶
- `sim/cockpit/autopilot/autothrottle_on` - 自动油门

---

## ✈️ MSFS 连接设置

### 1. 安装 WebSocket 服务器

MSFS 需要一个中间层来桥接 SimConnect 和 WebSocket。

#### 推荐方案：使用 Node.js WebSocket 服务器

**下载并安装：**
```bash
# 克隆仓库
git clone https://github.com/odwdinc/MSFS-WebSocket-Server.git
cd MSFS-WebSocket-Server

# 安装依赖
npm install

# 启动服务器
npm start
```

服务器默认运行在 `ws://localhost:8080`

#### 替代方案：Python SimConnect 桥接

```bash
# 安装 Python-SimConnect
pip install Python-SimConnect

# 运行桥接脚本（需要自行编写）
python msfs_websocket_bridge.py
```

### 2. 在应用中连接

1. **确保 MSFS 正在运行**
2. **启动 WebSocket 服务器**
3. 打开 **OwO! FlightAssistant**
4. 进入 **飞行检查单** 页面
5. 点击顶部的连接状态按钮
6. 选择 **"连接 MSFS"**
7. 等待连接成功（状态变为绿色）

### 支持的 SimVars

应用会自动订阅以下 SimConnect 变量：

**飞行数据：**
- `AIRSPEED_INDICATED` - 指示空速
- `INDICATED_ALTITUDE` - 指示高度
- `PLANE_HEADING_DEGREES_MAGNETIC` - 磁航向
- `VERTICAL_SPEED` - 垂直速度

**系统状态：**
- `BRAKE_PARKING_POSITION` - 停机刹车
- `LIGHT_BEACON` - 信标灯
- `LIGHT_LANDING` - 着陆灯
- `LIGHT_TAXI` - 滑行灯
- `LIGHT_NAV` - 导航灯
- `LIGHT_STROBE` - 频闪灯
- `FLAPS_HANDLE_INDEX` - 襟翼位置
- `GEAR_HANDLE_POSITION` - 起落架

**发动机：**
- `APU_SWITCH` - APU
- `GENERAL_ENG_COMBUSTION:1` - 发动机1
- `GENERAL_ENG_COMBUSTION:2` - 发动机2

**自动驾驶：**
- `AUTOPILOT_MASTER` - 自动驾驶
- `AUTOPILOT_THROTTLE_ARM` - 自动油门

---

## 🔧 故障排除

### X-Plane 无法连接

1. **检查防火墙**：确保允许应用访问 UDP 端口 49001
2. **检查 X-Plane 设置**：确认 Data Output 已正确配置
3. **检查 IP 地址**：确保使用 `127.0.0.1`
4. **重启 X-Plane**：有时需要重启模拟器才能生效

### MSFS 无法连接

1. **检查 WebSocket 服务器**：确保服务器正在运行
2. **检查端口**：默认端口是 8080，确保没有被占用
3. **检查 MSFS**：确保 MSFS 正在运行且已加载飞机
4. **查看服务器日志**：检查 WebSocket 服务器的控制台输出
5. **防火墙**：确保允许 WebSocket 连接

### 连接成功但无数据

1. **X-Plane**：检查是否已启用要输出的数据项
2. **MSFS**：确保 SimConnect 已正确初始化
3. **重新连接**：断开并重新连接
4. **检查日志**：查看应用日志获取详细错误信息

---

## 📊 数据更新频率

- **X-Plane**: 5 Hz (每秒5次)
- **MSFS**: 取决于 WebSocket 服务器配置，通常为 5-10 Hz

---

## 🎯 智能检查功能（未来）

连接模拟器后，应用将能够：

- ✅ **自动验证检查项**：根据模拟器状态自动标记完成
- ✅ **实时提示**：当检查项与实际状态不符时提醒
- ✅ **语音提示**：完成检查项时语音确认
- ✅ **飞行记录**：自动记录每次飞行的检查完成情况

---

## ⚠️ 注意事项

1. **性能影响**：连接模拟器会占用少量系统资源
2. **网络安全**：仅在本地网络使用，不要暴露到公网
3. **数据准确性**：某些数据可能因模拟器版本或插件而异
4. **兼容性**：建议使用最新版本的模拟器

---

## 🔗 相关资源

- [X-Plane DataRefs 文档](https://developer.x-plane.com/datarefs/)
- [MSFS SimConnect SDK](https://docs.flightsimulator.com/html/Programming_Tools/SimConnect/SimConnect_SDK.htm)
- [DataRefTool (X-Plane)](https://datareftool.com/)

---

**祝您飞行愉快！** ✈️
