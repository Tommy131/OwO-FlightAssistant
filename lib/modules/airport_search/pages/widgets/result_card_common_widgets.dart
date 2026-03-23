import 'package:flutter/material.dart';

/// 结果卡片内的标签 Chip (小巧且圆角)
class ResultCardTagChip extends StatelessWidget {
  final String text;

  const ResultCardTagChip({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          fontSize: 10,
        ),
      ),
    );
  }
}

/// 结果卡片内的小节标题 (Icon + 标题文本)
class ResultCardSectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;

  const ResultCardSectionHeader({
    super.key,
    required this.icon,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 15, color: theme.colorScheme.primary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}

/// 气象信息徽章 (Label: Value 形式)
class ResultCardMetaBadge extends StatelessWidget {
  final String label;
  final String value;

  const ResultCardMetaBadge({
    super.key,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$label: $value',
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
