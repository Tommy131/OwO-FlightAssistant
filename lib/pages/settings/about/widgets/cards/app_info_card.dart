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
import '../common/info_row.dart';
import '../common/card_header.dart';

class AppInfoCard extends StatelessWidget {
  const AppInfoCard({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CardHeader(icon: Icons.info_rounded, title: '应用信息'),
            const Divider(height: 24),
            InfoRow(label: '应用名称', value: AppConstants.appName, isDark: isDark),
            const SizedBox(height: 12),
            InfoRow(
              label: '应用版本',
              value:
                  "v${AppConstants.appVersion} (${AppConstants.appBuildVersion})",
              isDark: isDark,
            ),
            const SizedBox(height: 12),
            InfoRow(
              label: '开发者控制台',
              value: 'Flight Assistant Engine',
              isDark: isDark,
            ),
            const SizedBox(height: 12),
            InfoRow(label: '软件协议', value: AppConstants.license, isDark: isDark),
          ],
        ),
      ),
    );
  }
}
