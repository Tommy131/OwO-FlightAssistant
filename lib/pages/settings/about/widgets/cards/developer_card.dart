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
import '../common/clickable_info_row.dart';
import '../common/card_header.dart';

class DeveloperCard extends StatelessWidget {
  const DeveloperCard({super.key});

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CardHeader(icon: Icons.code_rounded, title: '开发者信息'),
            Divider(height: 24),
            ClickableInfoRow(
              label: '开发者',
              value: AppConstants.developerName,
              url: AppConstants.githubUrl,
              icon: Icons.person,
            ),
            SizedBox(height: 12),
            ClickableInfoRow(
              label: '联系邮箱',
              value: AppConstants.developerEmail,
              url: 'mailto:${AppConstants.developerEmail}',
              icon: Icons.email_rounded,
            ),
            SizedBox(height: 12),
            ClickableInfoRow(
              label: 'GitHub',
              value: AppConstants.githubUsername,
              url: AppConstants.githubUrl,
              icon: Icons.code_rounded,
            ),
            SizedBox(height: 12),
            ClickableInfoRow(
              label: 'OwO Service',
              value: 'owoblog.com',
              url: AppConstants.owoServiceUrl,
              icon: Icons.web_rounded,
            ),
            SizedBox(height: 12),
            ClickableInfoRow(
              label: 'Instagram',
              value: '@${AppConstants.instagramName}',
              url: AppConstants.instagramUrl,
              icon: Icons.photo_camera_rounded,
            ),
          ],
        ),
      ),
    );
  }
}
