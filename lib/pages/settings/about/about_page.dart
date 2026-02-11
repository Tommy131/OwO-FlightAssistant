/*
 *        _____   _          __  _____   _____   _       _____   _____
 *      /  _  \ | |        / / /  _  \ |  _  \ | |     /  _  \ /  ___|
 *      | | | | | |  __   / /  | | | | | |_| | | |     | | | | | |
 *      | | | | | | /  | / /   | | | | |  _  { | |     | | | | | |   _
 *      | |_| | | |/   |/ /    | |_| | | |_| | | |___  | |_| | | |_| |
 *      \_____/ |___/|___/     \_____/ |_____/ |_____| \_____/ \_____/
 *
 *  Copyright (c) 2023 by OwOTeam-DGMT (OwOBlog).
 * @Date         : 2025-10-22
 * @Author       : HanskiJay
 * @LastEditors  : HanskiJay
 * @LastEditTime : 2025-10-22
 * @E-Mail       : support@owoblog.com
 * @Telegram     : https://t.me/HanskiJay
 * @GitHub       : https://github.com/Tommy131
 */
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_constants.dart';
import '../../../apps/services/app_core/update_service.dart';
import '../../../core/widgets/common/dialog.dart';

import 'widgets/cards/app_info_card.dart';
import 'widgets/cards/developer_card.dart';
import 'widgets/cards/update_card.dart';
import 'widgets/cards/acknowledgement_card.dart';
import 'widgets/cards/legal_card.dart';
import 'widgets/cards/copyright_card.dart';
import 'widgets/cards/sponsor_card.dart';
import 'widgets/cards/troubleshooting_card.dart';

class AboutPage extends StatefulWidget {
  final VoidCallback onBack;

  const AboutPage({super.key, required this.onBack});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  bool _isCheckingUpdate = false;

  Future<void> _checkUpdate(BuildContext context) async {
    if (_isCheckingUpdate) return;

    setState(() => _isCheckingUpdate = true);

    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 12),
            Text('正在检查应用更新...'),
          ],
        ),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );

    try {
      final updateInfo = await UpdateService.checkUpdate();

      if (!mounted) return;
      setState(() => _isCheckingUpdate = false);

      messenger.hideCurrentSnackBar();

      if (updateInfo['error'] != null) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('❌ 更新检测失败'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
        if (!context.mounted) return;
        await showAdvancedConfirmDialog(
          context: context,
          title: '更新检测失败',
          content: '无法连接到更新服务器：${updateInfo['error']}',
          icon: Icons.error_outline_rounded,
          confirmColor: Colors.orange,
          confirmText: '好的',
          cancelText: '',
        );
      } else if (updateInfo['hasUpdate'] == true) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('🚀 发现新版本！'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
        if (!context.mounted) return;
        final shouldUpdate = await showAdvancedConfirmDialog(
          context: context,
          title: '发现新版本',
          content:
              '发现最新版本 ${updateInfo['remoteVersion']} (当前: ${AppConstants.appVersion})。是否跳转至 GitHub 下载更新？',
          icon: Icons.system_update_rounded,
          confirmText: '去下载',
          cancelText: '暂不更新',
        );

        if (shouldUpdate == true && mounted) {
          final downloadUrl = updateInfo['downloadUrl'] as String?;
          final uri = Uri.parse(downloadUrl ?? UpdateService.releasePageUrl);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        }
      } else {
        messenger.clearSnackBars();
        messenger.showSnackBar(
          const SnackBar(
            content: Text('✅ 已是最新版本'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        setState(() => _isCheckingUpdate = false);
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          const SnackBar(
            content: Text('⚠️ 更新检测异常'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
        await showAdvancedConfirmDialog(
          context: context,
          title: '更新检测异常',
          content: '在检查更新时发生了错误：$e',
          icon: Icons.warning_amber_rounded,
          confirmColor: Colors.redAccent,
          confirmText: '好的',
          cancelText: '',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: widget.onBack,
        ),
        title: Text(
          '关于应用',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AppInfoCard(),
              const SizedBox(height: 16),
              UpdateCard(
                onCheckUpdate: _checkUpdate,
                isCheckingUpdate: _isCheckingUpdate,
              ),
              const SizedBox(height: 16),
              const SponsorCard(),
              const SizedBox(height: 16),
              const DeveloperCard(),
              const SizedBox(height: 16),
              const AcknowledgementCard(),
              const SizedBox(height: 16),
              const LegalCard(),
              const SizedBox(height: 16),
              const TroubleshootingCard(),
              const SizedBox(height: 16),
              const CopyrightCard(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
