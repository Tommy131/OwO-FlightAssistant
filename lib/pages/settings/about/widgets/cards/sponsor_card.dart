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

import '../../../../../core/constants/app_constants.dart';
import '../../../../../core/utils/url_launcher_helper.dart';
import '../common/card_header.dart';

class SponsorCard extends StatelessWidget {
  const SponsorCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CardHeader(
              icon: Icons.volunteer_activism_rounded,
              title: '赞助与杰出贡献者',
            ),
            const SizedBox(height: 16),
            Text(
              '开发与服务器维护需要持续的测试以及资金投入，感谢以下每一位朋友的鼎力相助！',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 20),

            // 赞助排行榜
            const Text(
              '捐赠鸣谢 (最近)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const Divider(height: 16),
            _buildSponsorList(context),

            const SizedBox(height: 5),

            // 赞助排行榜
            const Text(
              '问题反馈鸣谢 (最近)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const Divider(height: 16),
            _buildHelperList(context),

            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () =>
                    UrlLauncherHelper.launchURL(AppConstants.donationUrl),
                icon: const Icon(Icons.coffee_rounded),
                label: const Text('请作者喝杯咖啡'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSponsorList(BuildContext context) {
    return Column(
      children: [
        {
          'name': '狗狗星星',
          'amount': 'MSFS 2024 Standard Version',
          'message': '支持一下。',
          'rank': 1,
        },
        {
          'name': '像风一样',
          'amount': 'X-Plane 12',
          'message': '非常棒的工具！',
          'rank': 2,
        },
      ].map((s) => _buildSponsorItem(context, s)).toList(),
    );
  }

  Widget _buildHelperList(BuildContext context) {
    return Column(
      children: [
        {'name': '狗狗星星', 'amount': '10 次', 'rank': 1},
        {'name': '像风一样', 'amount': '5 次', 'rank': 2},
      ].map((s) => _buildSponsorItem(context, s)).toList(),
    );
  }

  Widget _buildSponsorItem(BuildContext context, Map<String, dynamic> array) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Color badgeColor;
    if (array['rank'] == 1) {
      badgeColor = Colors.amber;
    } else if (array['rank'] == 2) {
      badgeColor = Colors.grey.shade400;
    } else {
      badgeColor = Colors.brown.shade300;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: badgeColor.withValues(alpha: 0.2), width: 1),
      ),
      child: Row(
        children: [
          Icon(Icons.stars_rounded, color: badgeColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  array['name'],
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (array['message'] != null)
                  Text(
                    array['message'],
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? Colors.grey.shade400
                          : Colors.grey.shade600,
                    ),
                  ),
              ],
            ),
          ),
          if (array['amount'] != null)
            Text(
              array['amount'].toString(),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
        ],
      ),
    );
  }
}
