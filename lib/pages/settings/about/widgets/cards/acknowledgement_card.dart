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
import '../common/card_header.dart';
import '../common/clickable_info_row.dart';

class AcknowledgementCard extends StatelessWidget {
  const AcknowledgementCard({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CardHeader(icon: Icons.favorite_rounded, title: '鸣谢与致敬'),
            const SizedBox(height: 16),
            Text(
              '本项目基于 Flutter 开发，并使用了以下优秀的开源组件与数据服务：',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '开源项目',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const Divider(height: 16),
            const Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _TechBadge(label: 'flutter_map'),
                _TechBadge(label: 'fl_chart'),
                _TechBadge(label: 'sqlite3'),
                _TechBadge(label: 'window_manager'),
                _TechBadge(label: 'provider'),
                _TechBadge(label: 'flex_color_picker'),
                _TechBadge(label: 'latlong2'),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              '数据服务',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const Divider(height: 16),
            const ClickableInfoRow(
              label: 'AviationAPI / NOAA',
              value: '实时 METAR 气象数据',
              url: 'https://www.aviationapi.com',
              icon: Icons.cloud_queue_rounded,
            ),
            const SizedBox(height: 12),
            const ClickableInfoRow(
              label: 'AirportDB.io',
              value: '全球机场详细资料',
              url: 'https://airportdb.io',
              icon: Icons.local_airport_rounded,
            ),
            const SizedBox(height: 12),
            const ClickableInfoRow(
              label: 'OpenStreetMap',
              value: '基础矢量地图瓦片',
              url: 'https://www.openstreetmap.org',
              icon: Icons.map_rounded,
            ),
            const SizedBox(height: 12),
            const ClickableInfoRow(
              label: 'Esri Satellite',
              value: '高清卫星影像图',
              url: 'https://www.esri.com',
              icon: Icons.satellite_alt_rounded,
            ),
          ],
        ),
      ),
    );
  }
}

class _TechBadge extends StatelessWidget {
  final String label;

  const _TechBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
