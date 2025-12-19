/*
 * NotificationService 完整使用示例
 *
 * 展示所有功能的使用方法
 */

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../core/services/notification_service.dart';

class NotificationDemoPage extends StatefulWidget {
  const NotificationDemoPage({super.key});

  @override
  State<NotificationDemoPage> createState() => _NotificationDemoPageState();
}

class _NotificationDemoPageState extends State<NotificationDemoPage> {
  final NotificationService _notificationService = NotificationService();
  int _progress = 0;
  int _notificationId = 1;

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
  }

  /// 初始化通知服务
  Future<void> _initializeNotifications() async {
    // 1. 初始化服务
    final success = await _notificationService.initialize();

    if (!success) {
      _showSnackBar('通知服务初始化失败');
      return;
    }

    // 2. 设置通用回调
    _notificationService.onNotificationTapped = (response) {
      _showSnackBar('通知被点击: ${response.payload ?? "无数据"}');
    };

    // 3. 注册操作按钮回调
    _notificationService.registerActionCallback('confirm', (response) {
      _showSnackBar('用户点击了"确认"按钮');
    });

    _notificationService.registerActionCallback('cancel', (response) {
      _showSnackBar('用户点击了"取消"按钮');
    });

    _notificationService.registerActionCallback('reply', (response) {
      final replyText = response.input ?? '(空)';
      _showSnackBar('用户回复: $replyText');
    });

    _showSnackBar('通知服务初始化成功');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('通知服务示例'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showStats,
            tooltip: '统计信息',
          ),
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: _showHistory,
            tooltip: '通知历史',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSection('基础通知', [
            _buildButton('简单通知', _showSimpleNotification),
            _buildButton('优先级通知', _showPriorityNotification),
            _buildButton('带声音通知', _showSoundNotification),
            _buildButton('带徽章通知', _showBadgeNotification),
          ]),

          _buildSection('富媒体通知', [
            _buildButton('大文本通知', _showBigTextNotification),
            _buildButton('本地图片通知', _showLocalImageNotification),
            _buildButton('网络图片通知', _showNetworkImageNotification),
          ]),

          _buildSection('进度通知', [
            _buildButton('开始进度通知', _startProgressNotification),
            _buildButton('不确定进度', _showIndeterminateProgress),
          ]),

          _buildSection('定时通知', [
            _buildButton('5秒后通知', _scheduleNotification5Seconds),
            _buildButton('每分钟通知', _schedulePeriodicNotification),
            _buildButton('自定义周期(30秒)', _scheduleCustomPeriodic),
          ]),

          _buildSection('交互通知', [
            _buildButton('操作按钮通知', _showActionNotification),
            _buildButton('快速回复通知', _showInlineReplyNotification),
          ]),

          _buildSection('分组通知', [
            _buildButton('发送消息组(3条)', _showGroupedMessages),
            _buildButton('发送系统组(2条)', _showGroupedSystem),
          ]),

          _buildSection('批量操作', [
            _buildButton('批量发送(5条)', _showBatchNotifications),
            _buildButton('取消所有通知', _cancelAllNotifications),
          ]),

          _buildSection('权限和状态', [
            _buildButton('检查权限', _checkPermissions),
            _buildButton('获取待处理通知', _getPendingNotifications),
            _buildButton('获取活动通知', _getActiveNotifications),
          ]),

          _buildSection('历史管理', [
            _buildButton('查看统计信息', _showStats),
            _buildButton('查看通知历史', _showHistory),
            _buildButton('清除过期历史', _clearExpiredHistory),
            _buildButton('清除所有历史', _clearAllHistory),
          ]),
        ],
      ),
    );
  }

  // ==================== UI 构建方法 ====================

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ...children,
        const Divider(height: 32),
      ],
    );
  }

  Widget _buildButton(String label, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 48),
        ),
        child: Text(label),
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // ==================== 示例方法 ====================

  /// 1. 简单通知
  Future<void> _showSimpleNotification() async {
    final success = await _notificationService.showNotification(
      id: _getNextId(),
      title: '简单通知',
      body: '这是一条基础的通知消息',
      payload: 'simple_notification_data',
    );
    _showSnackBar(success ? '发送成功' : '发送失败');
  }

  /// 2. 优先级通知
  Future<void> _showPriorityNotification() async {
    await _notificationService.showPriorityNotification(
      id: _getNextId(),
      title: '紧急通知',
      body: '这是一条高优先级通知',
      priority: NotificationPriority.urgent,
    );
    _showSnackBar('已发送紧急通知');
  }

  /// 3. 带声音通知
  Future<void> _showSoundNotification() async {
    await _notificationService.showNotificationWithSound(
      id: _getNextId(),
      title: '声音通知',
      body: '带有自定义提示音',
      soundFile: 'notification_sound', // 需要在 res/raw/ 中准备音频文件
    );
    _showSnackBar('已发送声音通知');
  }

  /// 4. 带徽章通知
  Future<void> _showBadgeNotification() async {
    await _notificationService.showNotificationWithBadge(
      id: _getNextId(),
      title: '徽章通知',
      body: '应用图标显示数字徽章',
      badgeNumber: _notificationService.getUnreadCount() + 1,
    );
    _showSnackBar('已发送徽章通知');
  }

  /// 5. 大文本通知
  Future<void> _showBigTextNotification() async {
    await _notificationService.showBigTextNotification(
      id: _getNextId(),
      title: '长文本通知',
      body: '点击展开查看完整内容',
      bigText: '''
这是一段很长的文本内容，需要展开才能完整查看。

通知服务支持在 Android 上使用 BigTextStyle 来显示大量文本。
用户可以展开通知查看完整内容，非常适合显示新闻、消息等长文本场景。

iOS 上会显示摘要文本。
      ''',
    );
    _showSnackBar('已发送大文本通知');
  }

  /// 6. 本地图片通知
  Future<void> _showLocalImageNotification() async {
    // 注意：需要准备本地图片文件
    await _notificationService.showBigPictureNotification(
      id: _getNextId(),
      title: '图片通知',
      body: '查看图片内容',
      imageUrl: '/path/to/local/image.jpg', // 替换为实际路径
    );
    _showSnackBar('已发送图片通知');
  }

  /// 7. 网络图片通知
  Future<void> _showNetworkImageNotification() async {
    _showSnackBar('正在下载图片...');
    await _notificationService.showNotificationWithNetworkImage(
      id: _getNextId(),
      title: '网络图片通知',
      body: '自动下载并显示',
      imageUrl: 'https://picsum.photos/800/400', // 示例图片
    );
    _showSnackBar('已发送网络图片通知');
  }

  /// 8. 开始进度通知
  Future<void> _startProgressNotification() async {
    final progressId = _getNextId();
    _progress = 0;

    // 模拟下载进度
    for (int i = 0; i <= 100; i += 10) {
      _progress = i;
      await _notificationService.showProgressNotification(
        id: progressId,
        title: '下载中',
        progress: _progress,
        maxProgress: 100,
      );
      await Future.delayed(const Duration(milliseconds: 500));
    }

    // 完成后显示完成通知
    await _notificationService.showNotification(
      id: progressId,
      title: '下载完成',
      body: '文件已成功下载',
    );
    _showSnackBar('下载完成');
  }

  /// 9. 不确定进度
  Future<void> _showIndeterminateProgress() async {
    final progressId = _getNextId();
    await _notificationService.showProgressNotification(
      id: progressId,
      title: '处理中',
      progress: 0,
      maxProgress: 0,
      indeterminate: true,
    );

    // 3秒后完成
    await Future.delayed(const Duration(seconds: 3));
    await _notificationService.showNotification(
      id: progressId,
      title: '处理完成',
      body: '操作已成功完成',
    );
    _showSnackBar('处理完成');
  }

  /// 10. 5秒后通知
  Future<void> _scheduleNotification5Seconds() async {
    final scheduledTime = DateTime.now().add(const Duration(seconds: 5));
    await _notificationService.scheduleNotification(
      id: _getNextId(),
      title: '定时通知',
      body: '这条通知在5秒后显示',
      scheduledTime: scheduledTime,
    );
    _showSnackBar('已设置5秒后的定时通知');
  }

  /// 11. 每分钟通知
  Future<void> _schedulePeriodicNotification() async {
    await _notificationService.showPeriodicNotification(
      id: 999, // 使用固定 ID，方便取消
      title: '周期通知',
      body: '每分钟重复提醒',
      interval: RepeatInterval.everyMinute,
    );
    _showSnackBar('已设置每分钟周期通知');
  }

  /// 12. 自定义周期(30秒)
  Future<void> _scheduleCustomPeriodic() async {
    await _notificationService.scheduleCustomPeriodicNotification(
      id: 998,
      title: '自定义周期',
      body: '每30秒重复',
      interval: const Duration(seconds: 30),
    );
    _showSnackBar('已设置30秒周期通知');
  }

  /// 13. 操作按钮通知
  Future<void> _showActionNotification() async {
    await _notificationService.showNotificationWithActions(
      id: _getNextId(),
      title: '操作通知',
      body: '请选择一个操作',
    );
    _showSnackBar('已发送操作通知');
  }

  /// 14. 快速回复通知
  Future<void> _showInlineReplyNotification() async {
    await _notificationService.showNotificationWithInlineReply(
      id: _getNextId(),
      title: '新消息',
      body: '张三: 在吗？',
    );
    _showSnackBar('已发送快速回复通知');
  }

  /// 15. 发送消息组
  Future<void> _showGroupedMessages() async {
    final groupKey = 'messages';

    await _notificationService.showGroupedNotification(
      id: _getNextId(),
      title: '张三',
      body: '你好，在吗？',
      groupKey: groupKey,
    );

    await Future.delayed(const Duration(milliseconds: 500));

    await _notificationService.showGroupedNotification(
      id: _getNextId(),
      title: '李四',
      body: '周末一起吃饭吗？',
      groupKey: groupKey,
    );

    await Future.delayed(const Duration(milliseconds: 500));

    await _notificationService.showGroupedNotification(
      id: _getNextId(),
      title: '王五',
      body: '项目文档发你了',
      groupKey: groupKey,
    );

    _showSnackBar('已发送3条分组消息');
  }

  /// 16. 发送系统组
  Future<void> _showGroupedSystem() async {
    final groupKey = 'system';

    await _notificationService.showGroupedNotification(
      id: _getNextId(),
      title: '系统更新',
      body: '有新版本可用',
      groupKey: groupKey,
    );

    await Future.delayed(const Duration(milliseconds: 500));

    await _notificationService.showGroupedNotification(
      id: _getNextId(),
      title: '备份完成',
      body: '数据已成功备份',
      groupKey: groupKey,
    );

    _showSnackBar('已发送2条系统通知');
  }

  /// 17. 批量发送
  Future<void> _showBatchNotifications() async {
    final notifications = List.generate(
      5,
      (index) => NotificationData(
        id: _getNextId(),
        title: '批量通知 ${index + 1}',
        body: '这是第 ${index + 1} 条批量发送的通知',
        priority: NotificationPriority.normal,
      ),
    );

    final results = await _notificationService.showMultipleNotifications(
      notifications,
    );
    final successCount = results.where((r) => r).length;
    _showSnackBar('批量发送完成: $successCount/${notifications.length}');
  }

  /// 18. 取消所有通知
  Future<void> _cancelAllNotifications() async {
    await _notificationService.cancelAllNotifications();
    _showSnackBar('已取消所有通知');
  }

  /// 19. 检查权限
  Future<void> _checkPermissions() async {
    final hasPermission = await _notificationService.checkPermissions();
    _showSnackBar(hasPermission ? '已授予通知权限' : '未授予通知权限');
  }

  /// 20. 获取待处理通知
  Future<void> _getPendingNotifications() async {
    final pending = await _notificationService.getPendingNotifications();
    _showDialog(
      '待处理通知',
      pending.isEmpty
          ? '无待处理通知'
          : pending.map((n) => '${n.id}: ${n.title}').join('\n'),
    );
  }

  /// 21. 获取活动通知
  Future<void> _getActiveNotifications() async {
    final active = await _notificationService.getActiveNotifications();
    _showDialog(
      '活动通知',
      active.isEmpty
          ? '无活动通知'
          : active.map((n) => '${n.id}: ${n.title}').join('\n'),
    );
  }

  /// 22. 显示统计信息
  void _showStats() {
    final stats = _notificationService.getStats();
    final unreadCount = _notificationService.getUnreadCount();

    _showDialog('统计信息', '''
总发送: ${stats.totalSent} 条
已点击: ${stats.totalClicked} 条 (${(stats.clickRate * 100).toStringAsFixed(1)}%)
已读: ${stats.totalRead} 条 (${(stats.readRate * 100).toStringAsFixed(1)}%)
未读: $unreadCount 条
最后发送: ${_formatDateTime(stats.lastSentAt)}
      ''');
  }

  /// 23. 显示通知历史
  void _showHistory() {
    final history = _notificationService.getAllNotificationStates();

    if (history.isEmpty) {
      _showDialog('通知历史', '暂无历史记录');
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('通知历史'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: history.length,
            itemBuilder: (context, index) {
              final state = history[index];
              return ListTile(
                leading: CircleAvatar(child: Text('${state.id}')),
                title: Text(state.title),
                subtitle: Text(
                  '${state.body}\n${_formatDateTime(state.createdAt)}',
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (state.isClicked)
                      const Icon(
                        Icons.touch_app,
                        size: 16,
                        color: Colors.green,
                      ),
                    if (state.isRead && !state.isClicked)
                      const Icon(
                        Icons.visibility,
                        size: 16,
                        color: Colors.blue,
                      ),
                  ],
                ),
                isThreeLine: true,
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  /// 24. 清除过期历史
  Future<void> _clearExpiredHistory() async {
    await _notificationService.clearExpiredHistory(days: 7);
    _showSnackBar('已清除7天前的历史记录');
  }

  /// 25. 清除所有历史
  Future<void> _clearAllHistory() async {
    await _notificationService.clearHistory();
    _showSnackBar('已清除所有历史记录');
  }

  // ==================== 辅助方法 ====================

  int _getNextId() => _notificationId++;

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-'
        '${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}';
  }

  void _showDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _notificationService.dispose();
    super.dispose();
  }
}

// ==================== 使用示例 - main.dart ====================

/*
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化通知服务
  final notificationService = NotificationService();
  await notificationService.initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '通知服务示例',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const NotificationDemoPage(),
    );
  }
}
*/
