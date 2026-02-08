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
 * @LastEditors  : Claude AI
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
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../constants/app_constants.dart';

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
  static const String _windowsGuid = 'b8206b54-a31f-48cc-bede-3f1bf3102859';
  static const String _windowsIconPath = '../../assets/icons/app_icon.png';

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
  SharedPreferences? _prefs;

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
      debugPrint('🔄 开始初始化通知服务...');

      // 1. 初始化本地存储
      _prefs = await SharedPreferences.getInstance();

      // 2. 初始化时区数据（定时通知必需）
      if (!_timeZoneInitialized) {
        tz.initializeTimeZones();
        _timeZoneInitialized = true;
      }

      // 3. 创建初始化配置
      final initSettings = InitializationSettings(
        android: _createAndroidInitSettings(),
        iOS: _createIOSInitSettings(),
        windows: _createWindowsInitSettings(),
      );

      // 4. 初始化插件
      final result = await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      if (result != true) {
        debugPrint('⚠️ 通知插件初始化返回 false');
      }

      // 5. 请求各平台权限
      await _requestPermissions();

      // 6. 加载历史数据
      await _loadHistory();

      _initialized = true;
      debugPrint('✅ 通知服务初始化成功');
      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ 通知服务初始化失败: $e');
      debugPrint('堆栈: $stackTrace');
      return false;
    }
  }

  /// 创建 Android 初始化设置
  AndroidInitializationSettings _createAndroidInitSettings() {
    return const AndroidInitializationSettings('@drawable/app_icon');
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
  WindowsInitializationSettings _createWindowsInitSettings() {
    return const WindowsInitializationSettings(
      appName: _windowsAppName,
      appUserModelId: _windowsAppUserModelId,
      guid: _windowsGuid,
      iconPath: _windowsIconPath,
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
        await _requestIOSPermissions();
        break;
      default:
        // Windows 和其他平台不需要额外请求权限
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

      debugPrint(
        '✅ Android 权限请求完成 - 通知: $notificationGranted, 闹钟: $alarmGranted',
      );
      return notificationGranted == true;
    } catch (e) {
      debugPrint('⚠️ Android 权限请求失败: $e');
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
      debugPrint('✅ iOS 权限请求完成: ${granted == true ? "已授权" : "已拒绝"}');
      return granted;
    } catch (e) {
      debugPrint('⚠️ iOS 权限请求失败: $e');
      return null;
    }
  }

  /// 检查通知权限状态
  ///
  /// 返回 [bool] 是否已授予权限
  Future<bool> checkPermissions() async {
    if (!_initialized) {
      debugPrint('⚠️ 服务未初始化，无法检查权限');
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
      debugPrint('⚠️ 检查 iOS 权限失败: $e');
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
  ///   print('用户点击了确认按钮');
  /// });
  /// ```
  void registerActionCallback(
    String actionId,
    Function(NotificationResponse) callback,
  ) {
    _actionCallbacks[actionId] = callback;
    debugPrint('✅ 注册 Action 回调: $actionId');
  }

  /// 移除特定 action 的回调
  void unregisterActionCallback(String actionId) {
    _actionCallbacks.remove(actionId);
    debugPrint('✅ 移除 Action 回调: $actionId');
  }

  /// 清除所有 action 回调
  void clearActionCallbacks() {
    _actionCallbacks.clear();
    debugPrint('✅ 清除所有 Action 回调');
  }

  /// 通知点击回调
  ///
  /// 当用户点击通知或通知操作按钮时触发
  /// 可以在这里处理导航逻辑
  void _onNotificationTapped(NotificationResponse response) {
    try {
      debugPrint('''
📱 通知交互:
   - ID: ${response.id}
   - Action: ${response.actionId ?? '点击通知'}
   - Payload: ${response.payload ?? '无'}
   - Input: ${response.input ?? '无'}
''');

      // 更新通知状态为已点击
      if (response.id != null) {
        _markNotificationAsClicked(response.id!);
      }

      // 处理特定 action 回调
      final actionId = response.actionId;
      if (actionId != null && _actionCallbacks.containsKey(actionId)) {
        _actionCallbacks[actionId]!(response);
      } else {
        // 调用通用回调
        onNotificationTapped?.call(response);
      }
    } catch (e, stackTrace) {
      debugPrint('❌ 处理通知点击失败: $e');
      debugPrint('堆栈: $stackTrace');
    }
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
    return NotificationDetails(
      android:
          customAndroid ??
          AndroidNotificationDetails(
            channelId,
            channelName,
            channelDescription: channelDescription ?? '$channelName渠道',
            icon: 'notification_icon',
            importance: importance,
            priority: priority,
            showWhen: true,
          ),
      iOS:
          customIOS ??
          const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
      windows: const WindowsNotificationDetails(),
    );
  }

  // ==================== 限流和去重 ====================

  /// 检查是否应该限流
  bool _shouldRateLimit(int id) {
    final now = DateTime.now();

    // 检查单个通知的限流（500ms 内不能重复）
    final lastTime = _lastNotificationTime[id];
    if (lastTime != null && now.difference(lastTime) < _rateLimitDuration) {
      debugPrint(
        '⚠️ 通知 $id 被限流（距上次发送 ${now.difference(lastTime).inMilliseconds}ms）',
      );
      return true;
    }

    // 检查整体限流（每分钟不超过 30 条）
    _recentNotificationTimes.removeWhere(
      (time) => now.difference(time) > const Duration(minutes: 1),
    );

    if (_recentNotificationTimes.length >= _maxNotificationsPerMinute) {
      debugPrint('⚠️ 达到每分钟通知上限（$_maxNotificationsPerMinute 条）');
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
      debugPrint('✅ 通知 $id 标记为已读');
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
      debugPrint('✅ 通知 $id 标记为已点击');
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
      await _prefs?.setString(_notificationHistoryKey, jsonEncode(historyJson));
    } catch (e) {
      debugPrint('⚠️ 保存通知历史失败: $e');
    }
  }

  /// 加载通知历史
  Future<void> _loadHistory() async {
    try {
      final historyString = _prefs?.getString(_notificationHistoryKey);
      if (historyString != null) {
        final List<dynamic> historyJson = jsonDecode(historyString);
        for (var json in historyJson) {
          final state = NotificationState.fromJson(json);
          _notificationStates[state.id] = state;
        }
        debugPrint('✅ 加载通知历史: ${_notificationStates.length} 条');
      }
    } catch (e) {
      debugPrint('⚠️ 加载通知历史失败: $e');
    }
  }

  /// 清除通知历史
  Future<void> clearHistory() async {
    _notificationStates.clear();
    await _prefs?.remove(_notificationHistoryKey);
    debugPrint('✅ 清除通知历史');
  }

  /// 清除过期历史（保留最近 30 天）
  Future<void> clearExpiredHistory({int days = 30}) async {
    final cutoffDate = DateTime.now().subtract(Duration(days: days));
    _notificationStates.removeWhere(
      (id, state) => state.createdAt.isBefore(cutoffDate),
    );
    await _saveHistory();
    debugPrint('✅ 清除 $days 天前的通知历史');
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
    return await _safeExecute(
      () async {
        await _ensureInitialized();

        // 限流检查
        if (_shouldRateLimit(id)) return false;

        // 去重处理
        await _handleDuplicateNotification(id);

        final (importance, androidPriority) = _mapPriority(priority);
        final details = _buildNotificationDetails(
          channelId: _defaultChannelId,
          channelName: _defaultChannelName,
          importance: importance,
          priority: androidPriority,
        );

        await _notifications.show(id, title, body, details, payload: payload);

        // 记录状态
        _recordNotificationTime(id);
        _createNotificationState(id, title, body, payload);

        debugPrint('📨 发送简单通知: $title');
        return true;
      },
      '显示通知',
      false,
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
  }) async {
    return await _safeExecute(
      () async {
        await _ensureInitialized();

        // Android: 显示进度条
        final androidDetails = AndroidNotificationDetails(
          _progressChannelId,
          _progressChannelName,
          channelDescription: '显示进度的通知',
          icon: 'notification_icon',
          importance: Importance.low,
          priority: Priority.low,
          showProgress: true,
          maxProgress: maxProgress,
          progress: progress,
          indeterminate: indeterminate,
          onlyAlertOnce: true, // 只在首次显示时提醒
          ongoing: progress < maxProgress, // 进行中时显示为持续通知
        );

        // iOS: 显示进度百分比
        final percentage = maxProgress > 0
            ? (progress / maxProgress * 100).toStringAsFixed(0)
            : '0';
        final iosDetails = DarwinNotificationDetails(
          subtitle: indeterminate ? '处理中...' : '进度: $percentage%',
        );

        final details = NotificationDetails(
          android: androidDetails,
          iOS: iosDetails,
          windows: const WindowsNotificationDetails(),
        );

        final body = indeterminate ? '处理中...' : '$progress/$maxProgress';
        await _notifications.show(id, title, body, details);

        debugPrint('📊 更新进度通知: $title - $progress/$maxProgress');
        return true;
      },
      '显示进度通知',
      false,
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
  }) async {
    return await _safeExecute(
      () async {
        await _ensureInitialized();

        if (_shouldRateLimit(id)) return false;
        await _handleDuplicateNotification(id);

        // Android: 使用 BigTextStyle
        final androidDetails = AndroidNotificationDetails(
          _bigTextChannelId,
          _bigTextChannelName,
          channelDescription: '显示大量文本的通知',
          icon: 'notification_icon',
          importance: Importance.high,
          priority: Priority.high,
          styleInformation: BigTextStyleInformation(
            bigText,
            contentTitle: title,
            summaryText: body,
          ),
        );

        // iOS: 使用 subtitle 显示摘要
        final iosDetails = DarwinNotificationDetails(subtitle: body);

        final details = NotificationDetails(
          android: androidDetails,
          iOS: iosDetails,
          windows: const WindowsNotificationDetails(),
        );

        await _notifications.show(id, title, bigText, details);

        _recordNotificationTime(id);
        _createNotificationState(id, title, body, null);

        debugPrint('📄 发送大文本通知: $title');
        return true;
      },
      '显示大文本通知',
      false,
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
  }) async {
    return await _safeExecute(
      () async {
        await _ensureInitialized();

        if (_shouldRateLimit(id)) return false;
        await _handleDuplicateNotification(id);

        // Android: 使用 BigPictureStyle
        final androidDetails = AndroidNotificationDetails(
          _bigPictureChannelId,
          _bigPictureChannelName,
          channelDescription: '显示图片的通知',
          icon: 'notification_icon',
          importance: Importance.high,
          priority: Priority.high,
          styleInformation: BigPictureStyleInformation(
            FilePathAndroidBitmap(imageUrl),
            contentTitle: title,
            summaryText: body,
          ),
        );

        // iOS: 使用附件
        final iosDetails = DarwinNotificationDetails(
          attachments: [DarwinNotificationAttachment(imageUrl)],
        );

        final details = NotificationDetails(
          android: androidDetails,
          iOS: iosDetails,
          windows: const WindowsNotificationDetails(),
        );

        await _notifications.show(id, title, body, details);

        _recordNotificationTime(id);
        _createNotificationState(id, title, body, null);

        debugPrint('🖼️ 发送图片通知: $title');
        return true;
      },
      '显示图片通知',
      false,
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
  }) async {
    return await _safeExecute(
      () async {
        await _ensureInitialized();

        try {
          // 下载图片到临时目录
          debugPrint('📥 开始下载通知图片: $imageUrl');
          final response = await http
              .get(Uri.parse(imageUrl))
              .timeout(const Duration(seconds: 10));

          if (response.statusCode != 200) {
            throw Exception('图片下载失败: ${response.statusCode}');
          }

          final tempDir = await getTemporaryDirectory();
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final filePath =
              '${tempDir.path}/notification_image_${id}_$timestamp.jpg';
          final file = File(filePath);
          await file.writeAsBytes(response.bodyBytes);

          debugPrint('✅ 图片下载成功: $filePath');

          // 使用本地文件路径显示
          return await showBigPictureNotification(
            id: id,
            title: title,
            body: body,
            imageUrl: filePath,
          );
        } catch (e) {
          debugPrint('⚠️ 下载通知图片失败: $e，降级为普通通知');
          // 降级为普通通知
          return await showNotification(id: id, title: title, body: body);
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
          debugPrint('⚠️ 计划时间不能早于当前时间');
          return false;
        }

        final details = _buildNotificationDetails(
          channelId: _scheduledChannelId,
          channelName: _scheduledChannelName,
          channelDescription: '定时推送的通知',
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

        debugPrint('⏰ 设置定时通知: $title，时间: $scheduledTime');
        return true;
      },
      '设置定时通知',
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
  }) async {
    return await _safeExecute(
      () async {
        await _ensureInitialized();

        final details = _buildNotificationDetails(
          channelId: _periodicChannelId,
          channelName: _periodicChannelName,
          channelDescription: '周期性推送的通知',
        );

        await _notifications.periodicallyShow(
          id,
          title,
          body,
          interval,
          details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        );

        _createNotificationState(id, title, body, null);

        debugPrint('🔄 设置周期通知: $title，间隔: $interval');
        return true;
      },
      '设置周期通知',
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
  }) async {
    return await _safeExecute(
      () async {
        await _ensureInitialized();

        final start = startTime ?? DateTime.now().add(interval);
        final details = _buildNotificationDetails(
          channelId: _periodicChannelId,
          channelName: _periodicChannelName,
        );

        // 使用定时通知模拟自定义周期
        await _notifications.zonedSchedule(
          id,
          title,
          body,
          tz.TZDateTime.from(start, tz.local),
          details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time,
        );

        _createNotificationState(id, title, body, null);

        debugPrint('🔄 设置自定义周期通知: $title，间隔: $interval');
        return true;
      },
      '设置自定义周期通知',
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
  }) async {
    return await _safeExecute(
      () async {
        await _ensureInitialized();

        if (_shouldRateLimit(id)) return false;
        await _handleDuplicateNotification(id);

        // Android: 使用 AndroidNotificationAction
        const androidDetails = AndroidNotificationDetails(
          _actionChannelId,
          _actionChannelName,
          channelDescription: '带操作按钮的通知',
          icon: 'notification_icon',
          importance: Importance.high,
          priority: Priority.high,
          actions: [
            AndroidNotificationAction('confirm', '确认'),
            AndroidNotificationAction('cancel', '取消'),
          ],
        );

        // iOS: 使用 categoryIdentifier 关联操作分类
        const iosDetails = DarwinNotificationDetails(
          categoryIdentifier: _iosActionCategoryId,
        );

        const details = NotificationDetails(
          android: androidDetails,
          iOS: iosDetails,
          windows: WindowsNotificationDetails(),
        );

        await _notifications.show(id, title, body, details);

        _recordNotificationTime(id);
        _createNotificationState(id, title, body, null);

        debugPrint('🔘 发送操作通知: $title');
        return true;
      },
      '显示操作通知',
      false,
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
  ///   print('用户回复: $replyText');
  /// });
  /// ```
  Future<bool> showNotificationWithInlineReply({
    required int id,
    required String title,
    required String body,
  }) async {
    return await _safeExecute(
      () async {
        await _ensureInitialized();

        if (_shouldRateLimit(id)) return false;
        await _handleDuplicateNotification(id);

        // Android: 支持内联回复
        const androidDetails = AndroidNotificationDetails(
          _inlineReplyChannelId,
          _inlineReplyChannelName,
          channelDescription: '支持快速回复的通知',
          icon: 'notification_icon',
          importance: Importance.high,
          priority: Priority.high,
          actions: [
            AndroidNotificationAction(
              'reply',
              '回复',
              inputs: [AndroidNotificationActionInput(label: '输入回复内容...')],
            ),
          ],
        );

        // iOS: 使用文本输入操作
        const iosDetails = DarwinNotificationDetails(
          categoryIdentifier: _iosReplyCategoryId,
        );

        const details = NotificationDetails(
          android: androidDetails,
          iOS: iosDetails,
        );

        await _notifications.show(id, title, body, details);

        _recordNotificationTime(id);
        _createNotificationState(id, title, body, null);

        debugPrint('💬 发送回复通知: $title');
        return true;
      },
      '显示回复通知',
      false,
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
    return await _safeExecute(
      () async {
        await _ensureInitialized();

        if (_shouldRateLimit(id)) return false;
        await _handleDuplicateNotification(id);

        final androidDetails = AndroidNotificationDetails(
          _groupChannelId,
          _groupChannelName,
          channelDescription: '分组显示的通知',
          icon: 'notification_icon',
          importance: Importance.high,
          priority: Priority.high,
          groupKey: groupKey,
          setAsGroupSummary: groupSummary != null,
        );

        final iosDetails = DarwinNotificationDetails(
          threadIdentifier: groupKey, // iOS 使用 threadIdentifier 分组
        );

        final details = NotificationDetails(
          android: androidDetails,
          iOS: iosDetails,
        );

        final displayBody = groupSummary ?? body;
        await _notifications.show(
          id,
          title,
          displayBody,
          details,
          payload: payload,
        );

        _recordNotificationTime(id);
        _createNotificationState(id, title, body, payload);

        debugPrint('📂 发送分组通知: $title (分组: $groupKey)');
        return true;
      },
      '显示分组通知',
      false,
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
  }) async {
    return await _safeExecute(
      () async {
        await _ensureInitialized();

        if (_shouldRateLimit(id)) return false;
        await _handleDuplicateNotification(id);

        final androidDetails = AndroidNotificationDetails(
          _soundChannelId,
          _soundChannelName,
          channelDescription: '带自定义声音的通知',
          icon: 'notification_icon',
          importance: Importance.high,
          priority: Priority.high,
          sound: soundFile != null
              ? RawResourceAndroidNotificationSound(soundFile)
              : null,
        );

        final iosDetails = DarwinNotificationDetails(
          sound: soundFile,
          presentSound: true,
        );

        final details = NotificationDetails(
          android: androidDetails,
          iOS: iosDetails,
          windows: const WindowsNotificationDetails(),
        );

        await _notifications.show(id, title, body, details);

        _recordNotificationTime(id);
        _createNotificationState(id, title, body, null);

        debugPrint('🔊 发送声音通知: $title');
        return true;
      },
      '显示声音通知',
      false,
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
  /// 注意: Android 徽章由系统自动管理
  Future<bool> showNotificationWithBadge({
    required int id,
    required String title,
    required String body,
    int? badgeNumber,
  }) async {
    return await _safeExecute(
      () async {
        await _ensureInitialized();

        if (_shouldRateLimit(id)) return false;
        await _handleDuplicateNotification(id);

        const androidDetails = AndroidNotificationDetails(
          _badgeChannelId,
          _badgeChannelName,
          channelDescription: '带徽章数字的通知',
          icon: 'notification_icon',
          importance: Importance.high,
          priority: Priority.high,
        );

        final iosDetails = DarwinNotificationDetails(
          badgeNumber: badgeNumber,
          presentBadge: true,
        );

        final details = NotificationDetails(
          android: androidDetails,
          iOS: iosDetails,
          windows: const WindowsNotificationDetails(),
        );

        await _notifications.show(id, title, body, details);

        _recordNotificationTime(id);
        _createNotificationState(id, title, body, null);

        debugPrint('🔢 发送徽章通知: $title, 数字: $badgeNumber');
        return true;
      },
      '显示徽章通知',
      false,
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
    return await _safeExecute(
      () async {
        await _ensureInitialized();

        if (_shouldRateLimit(id)) return false;
        await _handleDuplicateNotification(id);

        final (importance, androidPriority) = _mapPriority(priority);

        final androidDetails = AndroidNotificationDetails(
          _defaultChannelId,
          _defaultChannelName,
          icon: 'notification_icon',
          importance: importance,
          priority: androidPriority,
        );

        final iosDetails = DarwinNotificationDetails(
          interruptionLevel: _mapIOSInterruptionLevel(priority),
        );

        final details = NotificationDetails(
          android: androidDetails,
          iOS: iosDetails,
        );

        await _notifications.show(id, title, body, details, payload: payload);

        _recordNotificationTime(id);
        _createNotificationState(id, title, body, payload);

        debugPrint('⚡ 发送优先级通知: $title (优先级: $priority)');
        return true;
      },
      '显示优先级通知',
      false,
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

    debugPrint(
      '📮 批量发送 ${notifications.length} 条通知，成功 ${results.where((r) => r).length} 条',
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
        debugPrint('❌ 取消通知: ID=$id');
        return true;
      },
      '取消通知',
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
        debugPrint('❌ 取消所有通知');
        return true;
      },
      '取消所有通知',
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
        debugPrint('📋 待处理通知数量: ${pending.length}');
        return pending;
      },
      '获取待处理通知',
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
        if (defaultTargetPlatform == TargetPlatform.android) {
          return await _getAndroidActiveNotifications();
        } else if (defaultTargetPlatform == TargetPlatform.iOS) {
          return await _getIOSActiveNotifications();
        }
        return <ActiveNotification>[];
      },
      '获取活动通知',
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
      debugPrint('📱 Android 活动通知数量: ${notifications.length}');
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
      debugPrint('📱 iOS 活动通知数量: ${notifications.length}');

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
      debugPrint('❌ $operationName 失败: $e');
      debugPrint('堆栈: $stackTrace');
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
    debugPrint('✅ 通知服务资源已清理');
  }
}
