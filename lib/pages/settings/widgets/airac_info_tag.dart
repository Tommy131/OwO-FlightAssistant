import 'package:flutter/material.dart';

class AiracInfoTag extends StatelessWidget {
  final String? airac;
  final String? expiry;
  final bool isExpired;
  final bool showAiracLabel;

  const AiracInfoTag({
    super.key,
    required this.airac,
    this.expiry,
    this.isExpired = false,
    this.showAiracLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    if (airac == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isExpired
            ? colorScheme.errorContainer
            : colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            showAiracLabel ? 'AIRAC $airac' : airac!,
            style: theme.textTheme.labelSmall?.copyWith(
              color: isExpired
                  ? colorScheme.onErrorContainer
                  : colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (expiry != null && expiry!.isNotEmpty) ...[
            const SizedBox(width: 4),
            Text(
              isExpired
                  ? '(已过期: $expiry)'
                  : (showAiracLabel ? '(有效期至: $expiry)' : expiry!),
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: showAiracLabel ? 9 : 10,
                color: isExpired
                    ? colorScheme.onErrorContainer
                    : colorScheme.onPrimaryContainer.withAlpha(
                        showAiracLabel ? 180 : 255,
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
