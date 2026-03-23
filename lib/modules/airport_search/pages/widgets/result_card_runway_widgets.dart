import 'package:flutter/material.dart';

/// 跑道卡片的展示数据结构
class RunwayCardData {
  final String ident;
  final String length;
  final String surface;

  const RunwayCardData({
    required this.ident,
    required this.length,
    required this.surface,
  });
}

/// 结果卡片内的跑道信息块 (包含高度和路面类型)
class ResultRunwayCard extends StatelessWidget {
  final RunwayCardData data;

  const ResultRunwayCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: 104,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.17),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data.ident,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            data.length,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
          Text(
            data.surface,
            style: theme.textTheme.labelSmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
