# 日志输出修复 (LOG_FIX)

## 问题描述
在生产环境下（使用 `flutter build windows --release` 打包后），日志无法正常输出到本地文件，且无法在外部查看诊断信息。

## 根本原因
1.  **静默失败**：原有的诊断输出使用 `print`，但在 Release 模式下会被屏蔽，导致开发者无法得知日志系统是否配置成功。
2.  **默认过滤器拦截**：`logger` 插件默认使用 `DevelopmentFilter`。在 Release 模式下，由于断言被移除，该过滤器会默认返回 `false`，从而拦截所有日志记录请求。
3.  **目录/文件创建逻辑不完善**：在写入前未进行充分的目录存在性校验，且缺乏同步刷盘机制。

## 修复方案

### 1. 强制启用生产环境过滤器
显式指定 `ProductionFilter`，确保在 Release 模式下日志记录请求不会被默认拦截。
```dart
return Logger(
  filter: ProductionFilter(), // 明确指定在生产环境下也进行日志记录
  // ...
);
```

### 2. 重定向诊断输出到 stderr
改进诊断函数，在生产模式下将关键状态信息写入 `stderr`。这样可以通过命令行重定向（如 `2> error.log`）捕获初始化阶段的诊断信息。
```dart
void _print(String message) {
  if (kDebugMode) {
    print(message);
  } else {
    // 在 release 模式下输出到 stderr，方便通过重定向捕获
    stderr.writeln('[AppLogger] $message');
  }
}
```

### 3. 增强初始化与写入的可观察性
- 在初始化时记录运行模式（DEBUG/RELEASE）、日志目录和轮转阈值。
- 在每次尝试写入文件时输出诊断信息。
- 使用 `flush: true` 确保数据立即写入物理磁盘，防止程序崩溃导致日志丢失。

### 4. 完善目录校验机制
在 `_FileLogOutput` 构造函数和 `output` 方法中实施双重校验，确保日志目录和父目录在写入操作发生前已正确创建。

## 验证与测试建议

### 1. 开发环境测试
- 运行应用并启用文件日志。
- 检查控制台输出，应包含初始化诊断信息：
  ```
  [AppLogger] Initializing file logger in DEBUG mode
  [AppLogger] Log directory: <路径>
  [AppLogger] Rotation threshold: 2MB
  [AppLogger] Log directory verified successfully
  ```
- 验证 `logs/app.log` 成功生成并记录业务日志。

### 2. 生产环境测试
- 使用 `flutter build windows --release` 打包应用。
- 运行打包后的应用并启用文件日志。
- 验证日志文件位置（优先级）：
    1. 自定义目录：`<自定义路径>/logs/`
    2. 便携模式：`<exe目录>/data/logs/`
    3. 默认模式：`<exe目录>/logs/`

### 3. 调试生产环境问题
如果生产环境下日志仍无法写入，请使用以下命令运行应用以捕获诊断信息：

**Windows (PowerShell):**
```powershell
.\owo_flight_assistant.exe 2> error.log
```

**Windows (CMD):**
```cmd
owo_flight_assistant.exe 2> error.log
```

查看 `error.log`，正常情况下应看到：
```
[AppLogger] Initializing file logger in RELEASE mode
[AppLogger] Log directory: D:\path\to\logs
[AppLogger] Rotation threshold: 2MB
[AppLogger] Log directory verified successfully
```

## 注意事项
1. **文件权限**：确保应用程序对日志目录有写入权限。
2. **日志轮转**：日志文件达到设定大小（默认 2MB）时会自动轮转，旧日志以时间戳命名，如 `app_2026-02-11_02-45-30.log`。
3. **性能**：在 Release 模式下，启用文件日志后会禁用控制台输出以优化性能。

## 验证结果
经过测试，通过重定向 `stderr` 成功解决了生产环境下日志系统“黑盒”运行的问题，能够清晰诊断初始化失败的原因，并确保了日志的持久化存储。
