/*
 *        _____   _          __  _____   _____   _       _____   _____
 *      /  _  \ | |        / / /  _  \ |  _  \ | |     /  _  \ /  ___|
 *      | | | | | |  __   / /  | | | | | |_| | | |     | | | | | |
 *      | | | | | | /  | / /   | | | | |  _  { | |     | | | | | |   _
 *      | |_| | | |/   |/ /    | |_| | | |_| | | |___  | |_| | | |_| |
 *      \_____/ |___/|___/     \_____/ |_____/ |_____| \_____/ \_____/
 *
 *  Copyright (c) 2023 by OwOTeam-DGMT (OwOBlog).
 * @Date         : 2025-12-18
 * @Author       : HanskiJay
 * @LastEditors  : HanskiJay
 * @LastEditTime : 2025-12-18
 * @E-Mail       : support@owoblog.com
 * @GitHub       : https://github.com/Tommy131
 */

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'persistence_service.dart';
import 'dart:convert';

import '../constants/app_constants.dart';
import '../utils/logger.dart';

// ==================== 数据模型 ====================

/// 通知优先级枚举
enum NotificationPriority {
  low, // 低优先级：静默通知
  normal, // 普通优先级：默认行为
  high, // 高优先级：会弹出提示
  urgent, // 紧急优先级：全屏显示、持续提醒
}

/// 通知状态数据类
class NotificationState {
  final int id;
  final String title;
  final String body;
  final DateTime createdAt;
  final DateTime? readAt;
  final DateTime? clickedAt;
  final String? payload;

  NotificationState({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    this.readAt,
    this.clickedAt,
    this.payload,
  });

  bool get isRead => readAt != null;
  bool get isClicked => clickedAt != null;

  NotificationState copyWith({DateTime? readAt, DateTime? clickedAt}) {
    return NotificationState(
      id: id,
      title: title,
      body: body,
      createdAt: createdAt,
      readAt: readAt ?? this.readAt,
      clickedAt: clickedAt ?? this.clickedAt,
      payload: payload,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'createdAt': createdAt.toIso8601String(),
    'readAt': readAt?.toIso8601String(),
    'clickedAt': clickedAt?.toIso8601String(),
    'payload': payload,
  };

  factory NotificationState.fromJson(Map<String, dynamic> json) {
    return NotificationState(
      id: json['id'] as int,
      title: json['title'] as String,
      body: json['body'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      readAt: json['readAt'] != null
          ? DateTime.parse(json['readAt'] as String)
          : null,
      clickedAt: json['clickedAt'] != null
          ? DateTime.parse(json['clickedAt'] as String)
          : null,
      payload: json['payload'] as String?,
    );
  }
}

/// 批量通知数据类
class NotificationData {
  final int id;
  final String title;
  final String body;
  final String? payload;
  final NotificationPriority priority;
  final String? groupKey;

  NotificationData({
    required this.id,
    required this.title,
    required this.body,
    this.payload,
    this.priority = NotificationPriority.normal,
    this.groupKey,
  });
}

/// 通知统计数据类
class NotificationStats {
  final int totalSent;
  final int totalClicked;
  final int totalRead;
  final DateTime lastSentAt;

  NotificationStats({
    required this.totalSent,
    required this.totalClicked,
    required this.totalRead,
    required this.lastSentAt,
  });

  double get clickRate => totalSent > 0 ? totalClicked / totalSent : 0.0;
  double get readRate => totalSent > 0 ? totalRead / totalSent : 0.0;
}

// ==================== 主服务类 ====================

/// 通知服务类
///
/// 提供跨平台(Android、iOS、Windows)的本地通知功能
/// 支持多种通知类型：简单通知、进度通知、定时通知、周期通知等
///
/// 使用示例:
/// ```dart
/// final notificationService = NotificationService();
/// await notificationService.initialize();
/// await notificationService.showNotification(
///   id: 1,
///   title: '标题',
///   body: '内容',
/// );
/// ```
class NotificationService {
  // ==================== 单例模式 ====================

  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  // ==================== 常量定义 ====================

  /// 通知渠道 ID 常量
  static const String _defaultChannelId = 'default_channel';
  static const String _progressChannelId = 'progress_channel';
  static const String _bigTextChannelId = 'big_text_channel';
  static const String _bigPictureChannelId = 'big_picture_channel';
  static const String _scheduledChannelId = 'scheduled_channel';
  static const String _periodicChannelId = 'periodic_channel';
  static const String _actionChannelId = 'action_channel';
  static const String _soundChannelId = 'sound_channel';
  static const String _badgeChannelId = 'badge_channel';
  static const String _groupChannelId = 'group_channel';
  static const String _inlineReplyChannelId = 'inline_reply_channel';

  /// 通知渠道名称常量
  static const String _defaultChannelName = '默认通知';
  static const String _progressChannelName = '进度通知';
  static const String _bigTextChannelName = '大文本通知';
  static const String _bigPictureChannelName = '图片通知';
  static const String _scheduledChannelName = '定时通知';
  static const String _periodicChannelName = '周期通知';
  static const String _actionChannelName = '操作通知';
  static const String _soundChannelName = '声音通知';
  static const String _badgeChannelName = '徽章通知';
  static const String _groupChannelName = '分组通知';
  static const String _inlineReplyChannelName = '快速回复通知';

  /// iOS 操作分类 ID
  static const String _iosActionCategoryId = 'actionCategory';
  static const String _iosReplyCategoryId = 'replyCategory';

  /// Windows 应用配置
  static const String _windowsAppName = AppConstants.appName;
  static const String _windowsAppUserModelId = AppConstants.appPackageName;
  static const String _windowsGuid = 'b8206b54-a31f-48cc-bede-3f1bf3102865';
  static const String _androidNotificationIcon = 'ic_notification';
  static const String _androidFallbackNotificationIcon = 'launch_background';

  // 图标路径 (从常量引用)
  static const String _iconPath = AppConstants.assetIconPath;

  /// 本地存储键
  static const String _notificationHistoryKey = 'notification_history';
  // static const String _notificationStatsKey = 'notification_stats';

  /// 限流配置
  static const Duration _rateLimitDuration = Duration(milliseconds: 500);
  static const int _maxNotificationsPerMinute = 30;

  // ==================== 私有成员 ====================

  /// 通知插件实例
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  /// 初始化状态标志
  bool _initialized = false;
  bool _timeZoneInitialized = false;
  String _resolvedAndroidNotificationIcon = _androidNotificationIcon;

  /// 回调函数
  Function(NotificationResponse)? onNotificationTapped;
  final Map<String, Function(NotificationResponse)> _actionCallbacks = {};

  /// 状态管理
  final Map<int, NotificationState> _notificationStates = {};
  final Set<int> _activeNotificationIds = {};

  /// 限流控制
  final Map<int, DateTime> _lastNotificationTime = {};
  final List<DateTime> _recentNotificationTimes = [];

  /// 本地存储

  // ==================== 初始化方法 ====================

  /// 初始化通知服务
  ///
  /// 必须在使用任何通知功能前调用
  /// 建议在应用启动时调用，如 main() 函数中
  ///
  /// 返回 [Future<bool>] 初始化是否成功
  ///
  /// 功能:
  /// - 初始化时区数据（用于定时通知）
  /// - 配置 Android、iOS、Windows 平台的通知设置
  /// - 请求必要的系统权限
  /// - 设置通知点击回调
  /// - 加载历史数据
  Future<bool> initialize() async {
    // 防止重复初始化
    if (_initialized) return true;

    try {
      AppLogger.info('🔄 Initializing notification service...');

      // 1. 初始化持久化服务已经由主应用完成，这里只需确保 PersistenceService 已就绪
      if (!PersistenceService().isInitialized) {
        await PersistenceService().init();
      }

      // 2. 初始化时区数据（定时通知必需）
      if (!_timeZoneInitialized) {
        tz.initializeTimeZones();
        _timeZoneInitialized = true;
      }

      // 准备 Windows 图标（Windows 通知需要物理文件路径）
      String? windowsIconPath;
      if (defaultTargetPlatform == TargetPlatform.windows) {
        windowsIconPath = await _prepareWindowsIcon();
      }

      final result = await _initializePluginWithFallback(windowsIconPath);

      if (result != true) {
        AppLogger.warning('Notification plugin initialization returned false');
      }

      // 5. 请求各平台权限
      await _requestPermissions();

      // 6. 加载历史数据
      await _loadHistory();

      _initialized = true;
      AppLogger.info('Notification service initialized successfully');
      return true;
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to initialize notification service: $e',
        e,
        stackTrace,
      );
      AppLogger.error('Stack trace: $stackTrace');
      return false;
    }
  }

  /// 创建 Android 初始化设置
  AndroidInitializationSettings _createAndroidInitSettings(String iconName) {
    return AndroidInitializationSettings(iconName);
  }

  Future<bool?> _initializePluginWithFallback(String? windowsIconPath) async {
    try {
      _resolvedAndroidNotificationIcon = _androidNotificationIcon;
      final primarySettings = InitializationSettings(
        android: _createAndroidInitSettings(_resolvedAndroidNotificationIcon),
        iOS: _createIOSInitSettings(),
        macOS: _createIOSInitSettings(),
        windows: _createWindowsInitSettings(windowsIconPath),
        linux: LinuxInitializationSettings(
          defaultActionName: 'Open notification',
          defaultIcon: AssetsLinuxIcon(_iconPath),
        ),
      );
      return await _notifications.initialize(
        primarySettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );
    } on PlatformException catch (e) {
      final shouldFallback =
          defaultTargetPlatform == TargetPlatform.android &&
          e.code == 'invalid_icon';
      if (!shouldFallback) rethrow;
      _resolvedAndroidNotificationIcon = _androidFallbackNotificationIcon;
      AppLogger.warning(
        'Notification icon $_androidNotificationIcon is invalid, falling back to $_androidFallbackNotificationIcon',
      );
      final fallbackSettings = InitializationSettings(
        android: _createAndroidInitSettings(_resolvedAndroidNotificationIcon),
        iOS: _createIOSInitSettings(),
        macOS: _createIOSInitSettings(),
        windows: _createWindowsInitSettings(windowsIconPath),
        linux: LinuxInitializationSettings(
          defaultActionName: 'Open notification',
          defaultIcon: AssetsLinuxIcon(_iconPath),
        ),
      );
      return await _notifications.initialize(
        fallbackSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );
    }
  }

  /// 创建 iOS 初始化设置
  DarwinInitializationSettings _createIOSInitSettings() {
    return DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      // 配置通知操作分类（用于带按钮的通知）
      notificationCategories: [
        DarwinNotificationCategory(
          _iosActionCategoryId,
          actions: [
            DarwinNotificationAction.plain('confirm', '确认'),
            DarwinNotificationAction.plain('cancel', '取消'),
          ],
        ),
        DarwinNotificationCategory(
          _iosReplyCategoryId,
          actions: [
            DarwinNotificationAction.text('reply', '回复', buttonTitle: '发送'),
          ],
        ),
      ],
    );
  }

  /// 创建 Windows 初始化设置
  WindowsInitializationSettings _createWindowsInitSettings(
    String? customIconPath,
  ) {
    return WindowsInitializationSettings(
      appName: _windowsAppName,
      appUserModelId: _windowsAppUserModelId,
      guid: _windowsGuid,
      // Windows 必须使用绝对路径，如果 customIconPath 为空则不设置路径，让插件使用默认逻辑
      iconPath: (customIconPath != null && File(customIconPath).existsSync())
          ? customIconPath
          : null,
    );
  }

  /// 准备 Windows 通知图标（将 Asset 导出为物理文件）
  Future<String?> _prepareWindowsIcon() async {
    return await _safeExecute(
      () async {
        final byteData = await rootBundle.load(_iconPath);
        final directory =
            await getApplicationCacheDirectory(); // 尝试使用临时目录，确保权限和路径兼容性
        final iconPath =
            '${directory.path}${Platform.pathSeparator}app_icon.png';
        final file = File(iconPath);

        await file.writeAsBytes(
          byteData.buffer.asUint8List(
            byteData.offsetInBytes,
            byteData.lengthInBytes,
          ),
          flush: true,
        );

        if (await file.exists()) {
          AppLogger.info(
            'Windows notification icon prepared (absolute path): ${file.absolute.path}',
          );
          return file.absolute.path;
        } else {
          AppLogger.error('Failed to write Windows notification icon');
          return null;
        }
      },
      '准备 Windows 图标',
      null,
    );
  }

  // ==================== 权限管理 ====================

  /// 请求各平台通知权限
  Future<void> _requestPermissions() async {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        await _requestAndroidPermissions();
        break;
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        await _requestIOSPermissions();
        break;
      default:
        // Windows、Linux 系统不需要额外请求权限
        break;
    }
  }

  /// 请求 Android 通知权限
  ///
  /// 包括:
  /// - 通知权限 (Android 13+)
  /// - 精确闹钟权限 (用于定时通知)
  Future<bool> _requestAndroidPermissions() async {
    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (androidPlugin == null) return false;

    try {
      // Android 13+ 需要请求通知权限
      final notificationGranted = await androidPlugin
          .requestNotificationsPermission();
      // 请求精确闹钟权限（定时通知需要）
      final alarmGranted = await androidPlugin.requestExactAlarmsPermission();

      AppLogger.info(
        'Android permission request completed - Notification: $notificationGranted, Alarm: $alarmGranted',
      );
      return notificationGranted == true;
    } catch (e) {
      AppLogger.warning('Failed to request Android permissions: $e');
      return false;
    }
  }

  /// 请求 iOS 通知权限
  ///
  /// 包括:
  /// - 横幅提醒权限
  /// - 徽章权限
  /// - 声音权限
  ///
  /// 返回 [bool?] 是否授予权限，null 表示请求失败
  Future<bool?> _requestIOSPermissions() async {
    final iosPlugin = _notifications
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();

    if (iosPlugin == null) return null;

    try {
      final granted = await iosPlugin.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      AppLogger.info(
        'iOS permission request completed: ${granted == true ? "Authorized" : "Denied"}',
      );
      return granted;
    } catch (e) {
      AppLogger.warning('Failed to request iOS permissions: $e');
      return null;
    }
  }

  /// 检查通知权限状态
  ///
  /// 返回 [bool] 是否已授予权限
  Future<bool> checkPermissions() async {
    if (!_initialized) {
      AppLogger.warning('Service not initialized, cannot check permissions');
      return false;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return await _checkIOSPermissions();
      case TargetPlatform.android:
        // Android 权限在请求时已确定，这里返回 true
        return true;
      default:
        return true;
    }
  }

  /// 检查 iOS 通知权限状态
  Future<bool> _checkIOSPermissions() async {
    final iosPlugin = _notifications
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();

    if (iosPlugin == null) return false;

    try {
      final granted = await iosPlugin.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    } catch (e) {
      AppLogger.warning('Failed to check iOS permissions: $e');
      return false;
    }
  }

  // ==================== 回调处理 ====================

  /// 注册特定 action 的回调
  ///
  /// 用于处理通知操作按钮的点击事件
  ///
  /// 示例:
  /// ```dart
  /// service.registerActionCallback('confirm', (response) {
  ///   AppLogger.info('User clicked the confirm button');
  /// });
  /// ```
  void registerActionCallback(
    String actionId,
    Function(NotificationResponse) callback,
  ) {
    _actionCallbacks[actionId] = callback;
    AppLogger.info('Registered Action callback: $actionId');
  }

  /// 移除特定 action 的回调
  void unregisterActionCallback(String actionId) {
    _actionCallbacks.remove(actionId);
    AppLogger.info('Removed Action callback: $actionId');
  }

  /// 清除所有 action 回调
  void clearActionCallbacks() {
    _actionCallbacks.clear();
    AppLogger.info('Cleared all Action callbacks');
  }

  /// 通知点击回调
  ///
  /// 当用户点击通知或通知操作按钮时触发
  /// 可以在这里处理导航逻辑
  void _onNotificationTapped(NotificationResponse response) {
    try {
      // 提取和清理数据
      final String? actionId = response.actionId?.isEmpty == true
          ? null
          : response.actionId;
      final String? payload = response.payload?.isEmpty == true
          ? null
          : response.payload;

      // 在 Windows 等平台上，response.id 可能为 null
      // 尝试从 payload 中恢复 ID (如果我们之前在发送时注入了 ID)
      int? notificationId = response.id;
      if (notificationId == null && payload != null) {
        try {
          final data = jsonDecode(payload);
          if (data is Map && data.containsKey('_n_id')) {
            notificationId = data['_n_id'];
          }
        } catch (_) {
          // 不是 JSON 格式或解析失败，忽略
        }
      }

      AppLogger.info('''
📱 Notification interaction:
   - ID: ${notificationId ?? 'null'}
   - Action: ${actionId ?? 'Tap notification'}
   - Payload: ${payload ?? 'None'}
   - Input: ${response.input?.isEmpty == true ? 'None' : response.input ?? 'None'}
''');

      // 更新通知状态为已点击
      if (notificationId != null) {
        _markNotificationAsClicked(notificationId);
      }

      // 处理特定 action 回调
      if (actionId != null && _actionCallbacks.containsKey(actionId)) {
        _actionCallbacks[actionId]!(response);
      } else {
        // 调用通用回调
        onNotificationTapped?.call(response);
      }
    } catch (e, stackTrace) {
      AppLogger.error('Failed to handle notification tap: $e', e, stackTrace);
      AppLogger.error('Stack trace: $stackTrace');
    }
  }

  /// 内部辅助：构建 Payload (注入 ID 以便在 Windows 等平台恢复)
  String? _wrapPayload(int id, String? payload) {
    if (payload == null) {
      return jsonEncode({'_n_id': id});
    }
    try {
      // 如果已经是 JSON，尝试合并
      final data = jsonDecode(payload);
      if (data is Map) {
        data['_n_id'] = id;
        return jsonEncode(data);
      }
    } catch (_) {
      // 不是 JSON，作为普通字符串和 ID 封装
    }
    return jsonEncode({'_n_id': id, 'data': payload});
  }

  // ==================== 通知详情构建器 ====================

  /// 构建通知详情
  ///
  /// 根据不同平台创建对应的通知配置
  NotificationDetails _buildNotificationDetails({
    required String channelId,
    required String channelName,
    String? channelDescription,
    Importance importance = Importance.high,
    Priority priority = Priority.high,
    AndroidNotificationDetails? customAndroid,
    DarwinNotificationDetails? customIOS,
  }) {
    final darwinDetails =
        customIOS ??
        const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          interruptionLevel: InterruptionLevel.active,
        );

    return NotificationDetails(
      android:
          customAndroid ??
          AndroidNotificationDetails(
            channelId,
            channelName,
            channelDescription: channelDescription ?? '$channelName渠道',
            icon: _resolvedAndroidNotificationIcon,
            largeIcon: DrawableResourceAndroidBitmap(
              _resolvedAndroidNotificationIcon,
            ),
            importance: importance,
            priority: priority,
            showWhen: true,
          ),
      iOS: darwinDetails,
      macOS: darwinDetails,
      windows: const WindowsNotificationDetails(),
      linux: const LinuxNotificationDetails(),
    );
  }

  // ==================== 统一执行器 ====================

  /// 统一的通知显示执行器
  ///
  /// 封装了初始化检查、限流、去重、Payload 封装、状态记录和错误处理
  Future<bool> _executeShow({
    required int id,
    required String title,
    required String body,
    String? payload,
    required NotificationDetails details,
    String? logMessage,
    String operationName = '显示通知',
  }) async {
    return await _safeExecute(
      () async {
        await _ensureInitialized();

        // 限流检查
        if (_shouldRateLimit(id)) return false;

        // 去重处理
        await _handleDuplicateNotification(id);

        // 封装 Payload (注入 ID 以便在 Windows 等平台恢复)
        final finalPayload = _wrapPayload(id, payload);

        // 调用原生通知
        await _notifications.show(
          id,
          title,
          body,
          details,
          payload: finalPayload,
        );

        // 记录状态
        _recordNotificationTime(id);
        _createNotificationState(id, title, body, payload);

        if (logMessage != null) AppLogger.info(logMessage);
        return true;
      },
      operationName,
      false,
    );
  }

  // ==================== 限流和去重 ====================

  /// 检查是否应该限流
  bool _shouldRateLimit(int id) {
    final now = DateTime.now();

    // 检查单个通知的限流（500ms 内不能重复）
    final lastTime = _lastNotificationTime[id];
    if (lastTime != null && now.difference(lastTime) < _rateLimitDuration) {
      AppLogger.warning(
        'Notification $id rate limited (${now.difference(lastTime).inMilliseconds}ms since last send)',
      );
      return true;
    }

    // 检查整体限流（每分钟不超过 30 条）
    _recentNotificationTimes.removeWhere(
      (time) => now.difference(time) > const Duration(minutes: 1),
    );

    if (_recentNotificationTimes.length >= _maxNotificationsPerMinute) {
      AppLogger.warning(
        'Reached per-minute notification limit ($_maxNotificationsPerMinute)',
      );
      return true;
    }

    return false;
  }

  /// 记录通知发送时间
  void _recordNotificationTime(int id) {
    _lastNotificationTime[id] = DateTime.now();
    _recentNotificationTimes.add(DateTime.now());
  }

  /// 检查并处理重复通知
  Future<void> _handleDuplicateNotification(int id) async {
    if (_activeNotificationIds.contains(id)) {
      await cancelNotification(id);
    }
    _activeNotificationIds.add(id);
  }

  // ==================== 状态管理 ====================

  /// 创建通知状态记录
  void _createNotificationState(
    int id,
    String title,
    String body,
    String? payload,
  ) {
    final state = NotificationState(
      id: id,
      title: title,
      body: body,
      createdAt: DateTime.now(),
      payload: payload,
    );
    _notificationStates[id] = state;
    _saveHistory();
  }

  /// 标记通知为已读
  void markNotificationAsRead(int id) {
    final state = _notificationStates[id];
    if (state != null && !state.isRead) {
      _notificationStates[id] = state.copyWith(readAt: DateTime.now());
      _saveHistory();
      AppLogger.info('Notification $id marked as read');
    }
  }

  /// 标记通知为已点击
  void _markNotificationAsClicked(int id) {
    final state = _notificationStates[id];
    if (state != null && !state.isClicked) {
      _notificationStates[id] = state.copyWith(
        clickedAt: DateTime.now(),
        readAt: state.readAt ?? DateTime.now(),
      );
      _saveHistory();
      AppLogger.info('Notification $id marked as clicked');
    }
  }

  /// 获取通知状态
  NotificationState? getNotificationState(int id) {
    return _notificationStates[id];
  }

  /// 获取所有通知状态
  List<NotificationState> getAllNotificationStates() {
    return _notificationStates.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// 获取未读通知数量
  int getUnreadCount() {
    return _notificationStates.values.where((state) => !state.isRead).length;
  }

  // ==================== 历史数据管理 ====================

  /// 保存通知历史
  Future<void> _saveHistory() async {
    try {
      final historyJson = _notificationStates.values
          .map((state) => state.toJson())
          .toList();
      await PersistenceService().set(
        _notificationHistoryKey,
        jsonEncode(historyJson),
      );
    } catch (e) {
      AppLogger.warning('Failed to save notification history: $e');
    }
  }

  /// 加载通知历史
  Future<void> _loadHistory() async {
    try {
      final historyString = PersistenceService().getString(
        _notificationHistoryKey,
      );
      if (historyString != null) {
        final List<dynamic> historyJson = jsonDecode(historyString);
        for (var json in historyJson) {
          final state = NotificationState.fromJson(json);
          _notificationStates[state.id] = state;
        }
        AppLogger.info(
          'Loaded notification history: ${_notificationStates.length} items',
        );
      }
    } catch (e) {
      AppLogger.warning('Failed to load notification history: $e');
    }
  }

  /// 清除通知历史
  Future<void> clearHistory() async {
    _notificationStates.clear();
    await PersistenceService().remove(_notificationHistoryKey);
    AppLogger.info('Cleared notification history');
  }

  /// 清除过期历史（保留最近 30 天）
  Future<void> clearExpiredHistory({int days = 30}) async {
    final cutoffDate = DateTime.now().subtract(Duration(days: days));
    _notificationStates.removeWhere(
      (id, state) => state.createdAt.isBefore(cutoffDate),
    );
    await _saveHistory();
    AppLogger.info('Cleared notification history from $days days ago');
  }

  // ==================== 统计功能 ====================

  /// 获取通知统计信息
  NotificationStats getStats() {
    final states = _notificationStates.values.toList();
    final totalSent = states.length;
    final totalClicked = states.where((s) => s.isClicked).length;
    final totalRead = states.where((s) => s.isRead).length;
    final lastSentAt = states.isEmpty
        ? DateTime.now()
        : states
              .reduce((a, b) => a.createdAt.isAfter(b.createdAt) ? a : b)
              .createdAt;

    return NotificationStats(
      totalSent: totalSent,
      totalClicked: totalClicked,
      totalRead: totalRead,
      lastSentAt: lastSentAt,
    );
  }

  // ==================== 公共通知方法 ====================

  /// 显示简单通知
  ///
  /// 最基础的通知类型，包含标题和正文
  ///
  /// 参数:
  /// - [id] 通知唯一标识符，相同 ID 会覆盖旧通知
  /// - [title] 通知标题
  /// - [body] 通知正文
  /// - [payload] 自定义数据，点击通知时可获取
  /// - [priority] 通知优先级
  Future<bool> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    NotificationPriority priority = NotificationPriority.normal,
  }) async {
    final (importance, androidPriority) = _mapPriority(priority);
    final details = _buildNotificationDetails(
      channelId: _defaultChannelId,
      channelName: _defaultChannelName,
      importance: importance,
      priority: androidPriority,
    );

    return await _executeShow(
      id: id,
      title: title,
      body: body,
      payload: payload,
      details: details,
      logMessage: '📨 发送简单通知: $title',
    );
  }

  /// 显示进度通知
  ///
  /// 用于显示下载、上传等进度
  ///
  /// 参数:
  /// - [id] 通知 ID（使用相同 ID 可更新进度）
  /// - [title] 通知标题
  /// - [progress] 当前进度值
  /// - [maxProgress] 最大进度值
  /// - [indeterminate] 是否为不确定进度（无限循环）
  ///
  /// 注意: iOS 不支持进度条，会显示百分比文本
  Future<bool> showProgressNotification({
    required int id,
    required String title,
    required int progress,
    required int maxProgress,
    bool indeterminate = false,
    String? payload,
  }) async {
    // Android: 显示进度条
    final androidDetails = AndroidNotificationDetails(
      _progressChannelId,
      _progressChannelName,
      channelDescription: '显示进度的通知',
      icon: 'ic_launcher',
      largeIcon: const DrawableResourceAndroidBitmap('ic_launcher'),
      importance: Importance.low,
      priority: Priority.low,
      showProgress: true,
      maxProgress: maxProgress,
      progress: progress,
      indeterminate: indeterminate,
      onlyAlertOnce: true, // 只在首次显示时提醒
      ongoing: progress < maxProgress, // 进行中时显示为持续通知
    );

    // iOS/macOS: 显示进度百分比
    final percentage = maxProgress > 0
        ? (progress / maxProgress * 100).toStringAsFixed(0)
        : '0';
    final darwinDetails = DarwinNotificationDetails(
      subtitle: indeterminate ? '处理中...' : '进度: $percentage%',
    );

    final details = _buildNotificationDetails(
      channelId: _progressChannelId,
      channelName: _progressChannelName,
      customAndroid: androidDetails,
      customIOS: darwinDetails,
    );

    final body = indeterminate ? '处理中...' : '$progress/$maxProgress';

    return await _executeShow(
      id: id,
      title: title,
      body: body,
      payload: payload,
      details: details,
      logMessage: '📊 更新进度通知: $title - $progress/$maxProgress',
      operationName: '显示进度通知',
    );
  }

  /// 显示大文本通知
  ///
  /// 用于显示长文本内容，支持展开查看
  ///
  /// 参数:
  /// - [id] 通知 ID
  /// - [title] 通知标题
  /// - [body] 简短摘要（未展开时显示）
  /// - [bigText] 完整文本内容（展开后显示）
  Future<bool> showBigTextNotification({
    required int id,
    required String title,
    required String body,
    required String bigText,
    String? payload,
  }) async {
    // Android: 使用 BigTextStyle
    final androidDetails = AndroidNotificationDetails(
      _bigTextChannelId,
      _bigTextChannelName,
      channelDescription: '显示大量文本的通知',
      icon: 'ic_launcher',
      largeIcon: const DrawableResourceAndroidBitmap('ic_launcher'),
      importance: Importance.high,
      priority: Priority.high,
      styleInformation: BigTextStyleInformation(
        bigText,
        contentTitle: title,
        summaryText: body,
      ),
    );

    // iOS/macOS: 使用 subtitle 显示摘要
    final darwinDetails = DarwinNotificationDetails(subtitle: body);

    final details = _buildNotificationDetails(
      channelId: _bigTextChannelId,
      channelName: _bigTextChannelName,
      customAndroid: androidDetails,
      customIOS: darwinDetails,
    );

    return await _executeShow(
      id: id,
      title: title,
      body: bigText,
      payload: payload,
      details: details,
      logMessage: '📄 发送大文本通知: $title',
      operationName: '显示大文本通知',
    );
  }

  /// 显示带图片的通知
  ///
  /// 在通知中显示图片
  ///
  /// 参数:
  /// - [id] 通知 ID
  /// - [title] 通知标题
  /// - [body] 通知正文
  /// - [imageUrl] 图片路径（本地文件路径）
  ///
  /// 注意:
  /// - Android 使用 BigPictureStyle
  /// - iOS 使用 Attachment 附件
  Future<bool> showBigPictureNotification({
    required int id,
    required String title,
    required String body,
    required String imageUrl,
    String? payload,
  }) async {
    // Android: 使用 BigPictureStyle
    final androidDetails = AndroidNotificationDetails(
      _bigPictureChannelId,
      _bigPictureChannelName,
      channelDescription: '显示图片的通知',
      icon: 'ic_launcher',
      largeIcon: const DrawableResourceAndroidBitmap('ic_launcher'),
      importance: Importance.high,
      priority: Priority.high,
      styleInformation: BigPictureStyleInformation(
        FilePathAndroidBitmap(imageUrl),
        contentTitle: title,
        summaryText: body,
      ),
    );

    // iOS/macOS: 使用附件
    final darwinDetails = DarwinNotificationDetails(
      attachments: [DarwinNotificationAttachment(imageUrl)],
    );

    final details = _buildNotificationDetails(
      channelId: _bigPictureChannelId,
      channelName: _bigPictureChannelName,
      customAndroid: androidDetails,
      customIOS: darwinDetails,
    );

    return await _executeShow(
      id: id,
      title: title,
      body: body,
      payload: payload,
      details: details,
      logMessage: '🖼️ 发送图片通知: $title',
      operationName: '显示图片通知',
    );
  }

  /// 显示带网络图片的通知
  ///
  /// 自动下载网络图片并显示
  ///
  /// 参数:
  /// - [id] 通知 ID
  /// - [title] 通知标题
  /// - [body] 通知正文
  /// - [imageUrl] 网络图片 URL
  Future<bool> showNotificationWithNetworkImage({
    required int id,
    required String title,
    required String body,
    required String imageUrl,
    String? payload,
  }) async {
    return await _safeExecute(
      () async {
        await _ensureInitialized();

        try {
          // 下载图片到临时目录
          AppLogger.info('📥 Downloading notification image: $imageUrl');
          final response = await http
              .get(Uri.parse(imageUrl))
              .timeout(const Duration(seconds: 10));

          if (response.statusCode != 200) {
            throw Exception('Image download failed: ${response.statusCode}');
          }

          final tempDir = await getTemporaryDirectory();
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final filePath =
              '${tempDir.path}/notification_image_${id}_$timestamp.jpg';
          final file = File(filePath);
          await file.writeAsBytes(response.bodyBytes);

          AppLogger.info('Image downloaded successfully: $filePath');

          // 使用本地文件路径显示
          return await showBigPictureNotification(
            id: id,
            title: title,
            body: body,
            imageUrl: filePath,
            payload: payload,
          );
        } catch (e) {
          AppLogger.warning(
            'Failed to download notification image: $e, falling back to standard notification',
          );
          // 降级为普通通知
          return await showNotification(
            id: id,
            title: title,
            body: body,
            payload: payload,
          );
        }
      },
      '显示网络图片通知',
      false,
    );
  }

  /// 定时通知
  ///
  /// 在指定时间显示通知
  ///
  /// 参数:
  /// - [id] 通知 ID
  /// - [title] 通知标题
  /// - [body] 通知正文
  /// - [scheduledTime] 计划显示时间
  /// - [payload] 自定义数据
  ///
  /// 注意: 需要精确闹钟权限（Android）
  Future<bool> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? payload,
  }) async {
    return await _safeExecute(
      () async {
        await _ensureInitialized();

        if (scheduledTime.isBefore(DateTime.now())) {
          AppLogger.warning('Scheduled time cannot be in the past');
          return false;
        }

        final details = _buildNotificationDetails(
          channelId: _scheduledChannelId,
          channelName: _scheduledChannelName,
          channelDescription: 'Scheduled notifications',
        );

        await _notifications.zonedSchedule(
          id,
          title,
          body,
          tz.TZDateTime.from(scheduledTime, tz.local),
          details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.dateAndTime,
          payload: payload,
        );

        _createNotificationState(id, title, body, payload);

        AppLogger.info('⏰ Scheduled notification: $title at $scheduledTime');
        return true;
      },
      'Set scheduled notification',
      false,
    );
  }

  /// 周期性通知
  ///
  /// 按固定间隔重复显示通知
  ///
  /// 参数:
  /// - [id] 通知 ID
  /// - [title] 通知标题
  /// - [body] 通知正文
  /// - [interval] 重复间隔（每分钟、每小时、每天、每周）
  ///
  /// 可用间隔:
  /// - RepeatInterval.everyMinute (每分钟)
  /// - RepeatInterval.hourly (每小时)
  /// - RepeatInterval.daily (每天)
  /// - RepeatInterval.weekly (每周)
  Future<bool> showPeriodicNotification({
    required int id,
    required String title,
    required String body,
    required RepeatInterval interval,
    String? payload,
  }) async {
    return await _safeExecute(
      () async {
        await _ensureInitialized();

        final details = _buildNotificationDetails(
          channelId: _periodicChannelId,
          channelName: _periodicChannelName,
          channelDescription: 'Periodic notifications',
        );

        final finalPayload = _wrapPayload(id, payload);
        await _notifications.periodicallyShow(
          id,
          title,
          body,
          interval,
          details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          payload: finalPayload,
        );

        _createNotificationState(id, title, body, payload);

        AppLogger.info(
          '🔄 Set periodic notification: $title, interval: $interval',
        );
        return true;
      },
      'Set periodic notification',
      false,
    );
  }

  /// 自定义周期通知
  ///
  /// 支持任意时间间隔的周期通知
  ///
  /// 参数:
  /// - [id] 通知 ID
  /// - [title] 通知标题
  /// - [body] 通知正文
  /// - [interval] 自定义间隔时间
  /// - [startTime] 首次显示时间（可选，默认为当前时间+间隔）
  Future<bool> scheduleCustomPeriodicNotification({
    required int id,
    required String title,
    required String body,
    required Duration interval,
    DateTime? startTime,
    String? payload,
  }) async {
    return await _safeExecute(
      () async {
        await _ensureInitialized();

        final start = startTime ?? DateTime.now().add(interval);
        final details = _buildNotificationDetails(
          channelId: _periodicChannelId,
          channelName: _periodicChannelName,
        );

        final finalPayload = _wrapPayload(id, payload);
        // 使用定时通知模拟自定义周期
        await _notifications.zonedSchedule(
          id,
          title,
          body,
          tz.TZDateTime.from(start, tz.local),
          details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time,
          payload: finalPayload,
        );

        _createNotificationState(id, title, body, payload);

        AppLogger.info(
          '🔄 Set custom periodic notification: $title, interval: $interval',
        );
        return true;
      },
      'Set custom periodic notification',
      false,
    );
  }

  /// 显示带操作按钮的通知
  ///
  /// 通知中包含可点击的操作按钮
  ///
  /// 参数:
  /// - [id] 通知 ID
  /// - [title] 通知标题
  /// - [body] 通知正文
  ///
  /// 按钮操作:
  /// - 确认 (action: 'confirm')
  /// - 取消 (action: 'cancel')
  ///
  /// 可在 [registerActionCallback] 中处理按钮点击
  Future<bool> showNotificationWithActions({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    // Android: 使用 AndroidNotificationAction
    const androidDetails = AndroidNotificationDetails(
      _actionChannelId,
      _actionChannelName,
      channelDescription: 'Notifications with action buttons',
      icon: 'ic_launcher',
      largeIcon: DrawableResourceAndroidBitmap('ic_launcher'),
      importance: Importance.high,
      priority: Priority.high,
      actions: [
        AndroidNotificationAction('confirm', 'Confirm'),
        AndroidNotificationAction('cancel', 'Cancel'),
      ],
    );

    // iOS/macOS: 使用 categoryIdentifier 关联操作分类
    const darwinDetails = DarwinNotificationDetails(
      categoryIdentifier: _iosActionCategoryId,
    );

    final details = _buildNotificationDetails(
      channelId: _actionChannelId,
      channelName: _actionChannelName,
      customAndroid: androidDetails,
      customIOS: darwinDetails,
    );

    return await _executeShow(
      id: id,
      title: title,
      body: body,
      payload: payload,
      details: details,
      logMessage: '🔘 Sent action notification: $title',
      operationName: 'Show action notification',
    );
  }

  /// 显示内联回复通知（Android）
  ///
  /// 允许用户直接在通知中输入回复
  ///
  /// 参数:
  /// - [id] 通知 ID
  /// - [title] 通知标题
  /// - [body] 通知正文
  ///
  /// 使用示例:
  /// ```dart
  /// service.registerActionCallback('reply', (response) {
  ///   final replyText = response.input;
  ///   AppLogger.info('User reply: $replyText');
  /// });
  /// ```
  Future<bool> showNotificationWithInlineReply({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    // Android: 支持内联回复
    const androidDetails = AndroidNotificationDetails(
      _inlineReplyChannelId,
      _inlineReplyChannelName,
      channelDescription: 'Notifications with quick replies',
      icon: 'ic_launcher',
      largeIcon: DrawableResourceAndroidBitmap('ic_launcher'),
      importance: Importance.high,
      priority: Priority.high,
      actions: [
        AndroidNotificationAction(
          'reply',
          'Reply',
          inputs: [AndroidNotificationActionInput(label: 'Enter reply...')],
        ),
      ],
    );

    // iOS/macOS: 使用文本输入操作
    const darwinDetails = DarwinNotificationDetails(
      categoryIdentifier: _iosReplyCategoryId,
    );

    final details = _buildNotificationDetails(
      channelId: _inlineReplyChannelId,
      channelName: _inlineReplyChannelName,
      customAndroid: androidDetails,
      customIOS: darwinDetails,
    );

    return await _executeShow(
      id: id,
      title: title,
      body: body,
      payload: payload,
      details: details,
      logMessage: '💬 Sent reply notification: $title',
      operationName: 'Show reply notification',
    );
  }

  /// 显示分组通知
  ///
  /// 将多个通知归为一组，可折叠显示
  ///
  /// 参数:
  /// - [id] 通知 ID
  /// - [title] 通知标题
  /// - [body] 通知正文
  /// - [groupKey] 分组键（相同键的通知会被分组）
  /// - [groupSummary] 分组摘要文本（可选）
  ///
  /// 使用示例:
  /// ```dart
  /// // 发送多条消息通知，会自动分组
  /// await service.showGroupedNotification(
  ///   id: 1, title: '张三', body: '你好', groupKey: 'messages',
  /// );
  /// await service.showGroupedNotification(
  ///   id: 2, title: '李四', body: '在吗', groupKey: 'messages',
  /// );
  /// ```
  Future<bool> showGroupedNotification({
    required int id,
    required String title,
    required String body,
    required String groupKey,
    String? groupSummary,
    String? payload,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      _groupChannelId,
      _groupChannelName,
      channelDescription: 'Grouped notifications',
      icon: 'ic_launcher',
      largeIcon: const DrawableResourceAndroidBitmap('ic_launcher'),
      importance: Importance.high,
      priority: Priority.high,
      groupKey: groupKey,
      setAsGroupSummary: groupSummary != null,
    );

    final iosDetails = DarwinNotificationDetails(
      threadIdentifier: groupKey, // iOS 使用 threadIdentifier 分组
    );

    final details = _buildNotificationDetails(
      channelId: _groupChannelId,
      channelName: _groupChannelName,
      customAndroid: androidDetails,
      customIOS: iosDetails,
    );

    final displayBody = groupSummary ?? body;

    return await _executeShow(
      id: id,
      title: title,
      body: displayBody,
      payload: payload,
      details: details,
      logMessage: '📂 Sent grouped notification: $title (group: $groupKey)',
      operationName: 'Show grouped notification',
    );
  }

  /// 显示带自定义声音的通知
  ///
  /// 使用自定义音频文件作为通知提示音
  ///
  /// 参数:
  /// - [id] 通知 ID
  /// - [title] 通知标题
  /// - [body] 通知正文
  /// - [soundFile] 音频文件名（不含路径和扩展名）
  ///
  /// 注意:
  /// - Android: 将音频文件放在 android/app/src/main/res/raw/
  /// - iOS: 将音频文件放在 Runner/Resources/
  /// - 支持格式: .wav, .mp3
  Future<bool> showNotificationWithSound({
    required int id,
    required String title,
    required String body,
    String? soundFile,
    String? payload,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      _soundChannelId,
      _soundChannelName,
      channelDescription: 'Notifications with custom sounds',
      icon: 'ic_launcher',
      largeIcon: const DrawableResourceAndroidBitmap('ic_launcher'),
      importance: Importance.high,
      priority: Priority.high,
      sound: soundFile != null
          ? RawResourceAndroidNotificationSound(soundFile)
          : null,
    );

    final darwinDetails = DarwinNotificationDetails(
      sound: soundFile,
      presentSound: true,
    );

    final details = _buildNotificationDetails(
      channelId: _soundChannelId,
      channelName: _soundChannelName,
      customAndroid: androidDetails,
      customIOS: darwinDetails,
    );

    return await _executeShow(
      id: id,
      title: title,
      body: body,
      payload: payload,
      details: details,
      logMessage: '🔊 Sent sound notification: $title',
      operationName: 'Show sound notification',
    );
  }

  /// 显示带徽章数字的通知 (主要用于 iOS)
  ///
  /// 在应用图标上显示数字徽章
  ///
  /// 参数:
  /// - [id] 通知 ID
  /// - [title] 通知标题
  /// - [body] 通知正文
  /// - [badgeNumber] 徽章数字（iOS 应用图标角标）
  ///
  /// 注意: Android 徽章由系统自动 management
  Future<bool> showNotificationWithBadge({
    required int id,
    required String title,
    required String body,
    int? badgeNumber,
    String? payload,
  }) async {
    final darwinDetails = DarwinNotificationDetails(
      badgeNumber: badgeNumber,
      presentBadge: true,
    );

    final details = _buildNotificationDetails(
      channelId: _badgeChannelId,
      channelName: _badgeChannelName,
      customIOS: darwinDetails,
    );

    return await _executeShow(
      id: id,
      title: title,
      body: body,
      payload: payload,
      details: details,
      logMessage: '🔢 Sent badge notification: $title, number: $badgeNumber',
      operationName: 'Show badge notification',
    );
  }

  /// 显示优先级通知
  ///
  /// 根据优先级显示不同级别的通知
  ///
  /// 参数:
  /// - [id] 通知 ID
  /// - [title] 通知标题
  /// - [body] 通知正文
  /// - [priority] 通知优先级
  /// - [payload] 自定义数据
  Future<bool> showPriorityNotification({
    required int id,
    required String title,
    required String body,
    required NotificationPriority priority,
    String? payload,
  }) async {
    final (importance, androidPriority) = _mapPriority(priority);

    final androidDetails = AndroidNotificationDetails(
      _defaultChannelId,
      _defaultChannelName,
      icon: 'ic_launcher',
      largeIcon: const DrawableResourceAndroidBitmap('ic_launcher'),
      importance: importance,
      priority: androidPriority,
    );

    final darwinDetails = DarwinNotificationDetails(
      interruptionLevel: _mapIOSInterruptionLevel(priority),
    );

    final details = _buildNotificationDetails(
      channelId: _defaultChannelId,
      channelName: _defaultChannelName,
      customAndroid: androidDetails,
      customIOS: darwinDetails,
    );

    return await _executeShow(
      id: id,
      title: title,
      body: body,
      payload: payload,
      details: details,
      logMessage: '⚡ Sent priority notification: $title (priority: $priority)',
      operationName: 'Show priority notification',
    );
  }

  // ==================== 批量操作 ====================

  /// 批量显示通知
  ///
  /// 一次性显示多条通知，自动处理限流
  ///
  /// 参数:
  /// - [notifications] 通知数据列表
  /// - [delay] 每条通知之间的延迟（防止系统限流）
  Future<List<bool>> showMultipleNotifications(
    List<NotificationData> notifications, {
    Duration delay = const Duration(milliseconds: 100),
  }) async {
    final results = <bool>[];

    for (final notification in notifications) {
      final result = await showNotification(
        id: notification.id,
        title: notification.title,
        body: notification.body,
        payload: notification.payload,
        priority: notification.priority,
      );
      results.add(result);

      // 添加延迟避免系统限流
      if (notification != notifications.last) {
        await Future.delayed(delay);
      }
    }

    AppLogger.info(
      '📮 Sent ${notifications.length} bulk notifications, ${results.where((r) => r).length} successful',
    );
    return results;
  }

  // ==================== 通知管理 ====================

  /// 取消指定 ID 的通知
  ///
  /// 移除已显示的通知或取消待显示的通知
  Future<bool> cancelNotification(int id) async {
    return await _safeExecute(
      () async {
        await _notifications.cancel(id);
        _activeNotificationIds.remove(id);
        AppLogger.warning('Canceled notification: ID=$id');
        return true;
      },
      'Cancel notification',
      false,
    );
  }

  /// 取消所有通知
  ///
  /// 清除所有已显示和待显示的通知
  Future<bool> cancelAllNotifications() async {
    return await _safeExecute(
      () async {
        await _notifications.cancelAll();
        _activeNotificationIds.clear();
        AppLogger.warning('Canceled all notifications');
        return true;
      },
      'Cancel all notifications',
      false,
    );
  }

  /// 获取待处理的通知列表
  ///
  /// 返回所有计划中但尚未显示的通知
  /// 包括定时通知和周期通知
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _safeExecute(
      () async {
        final pending = await _notifications.pendingNotificationRequests();
        AppLogger.info('📋 Pending notifications count: ${pending.length}');
        return pending;
      },
      'Get pending notifications',
      <PendingNotificationRequest>[],
    );
  }

  /// 获取当前活动的通知列表
  ///
  /// 返回当前显示在通知栏的通知
  ///
  /// 支持平台: Android, iOS
  /// Windows 不支持此功能
  Future<List<ActiveNotification>> getActiveNotifications() async {
    return await _safeExecute(
      () async {
        switch (defaultTargetPlatform) {
          case TargetPlatform.android:
            return await _getAndroidActiveNotifications();
          case TargetPlatform.iOS:
          case TargetPlatform.macOS:
            return await _getIOSActiveNotifications();
          default:
            return <ActiveNotification>[];
        }
      },
      'Get active notifications',
      <ActiveNotification>[],
    );
  }

  /// 获取 Android 活动通知
  Future<List<ActiveNotification>> _getAndroidActiveNotifications() async {
    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (androidPlugin != null) {
      final notifications = await androidPlugin.getActiveNotifications();
      AppLogger.info(
        '📱 Android active notifications: ${notifications.length}',
      );
      return notifications;
    }
    return [];
  }

  /// 获取 iOS 活动通知
  Future<List<ActiveNotification>> _getIOSActiveNotifications() async {
    final iosPlugin = _notifications
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();

    if (iosPlugin != null) {
      final notifications = await iosPlugin.getActiveNotifications();
      AppLogger.info('📱 iOS active notifications: ${notifications.length}');

      // 转换为统一的 ActiveNotification 格式
      return notifications
          .map(
            (n) => ActiveNotification(
              id: n.id ?? 0,
              channelId: '',
              title: n.title,
              body: n.body,
            ),
          )
          .toList();
    }
    return [];
  }

  // ==================== 工具方法 ====================

  /// 确保服务已初始化
  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await initialize();
    }
  }

  /// 安全执行操作
  ///
  /// 统一的错误处理包装器
  Future<T> _safeExecute<T>(
    Future<T> Function() operation,
    String operationName,
    T defaultValue,
  ) async {
    try {
      return await operation();
    } catch (e, stackTrace) {
      AppLogger.error('$operationName failed: $e', e, stackTrace);
      AppLogger.error('Stack trace: $stackTrace');
      return defaultValue;
    }
  }

  /// 映射优先级到平台特定值
  (Importance, Priority) _mapPriority(NotificationPriority priority) {
    switch (priority) {
      case NotificationPriority.low:
        return (Importance.low, Priority.low);
      case NotificationPriority.normal:
        return (Importance.defaultImportance, Priority.defaultPriority);
      case NotificationPriority.high:
        return (Importance.high, Priority.high);
      case NotificationPriority.urgent:
        return (Importance.max, Priority.max);
    }
  }

  /// 映射优先级到 iOS 中断级别
  InterruptionLevel _mapIOSInterruptionLevel(NotificationPriority priority) {
    switch (priority) {
      case NotificationPriority.low:
        return InterruptionLevel.passive;
      case NotificationPriority.normal:
        return InterruptionLevel.active;
      case NotificationPriority.high:
        return InterruptionLevel.timeSensitive;
      case NotificationPriority.urgent:
        return InterruptionLevel.critical;
    }
  }

  /// 检查是否已初始化
  bool get isInitialized => _initialized;

  /// 获取当前平台名称
  String get platformName => defaultTargetPlatform.name;

  /// 获取活动通知 ID 集合
  Set<int> get activeNotificationIds =>
      Set.unmodifiable(_activeNotificationIds);

  // ==================== 清理资源 ====================

  /// 清理服务资源
  ///
  /// 在应用退出时调用
  Future<void> dispose() async {
    await _saveHistory();
    _actionCallbacks.clear();
    _notificationStates.clear();
    _activeNotificationIds.clear();
    _lastNotificationTime.clear();
    _recentNotificationTimes.clear();
    AppLogger.info('Notification service resources cleaned up');
  }
}
