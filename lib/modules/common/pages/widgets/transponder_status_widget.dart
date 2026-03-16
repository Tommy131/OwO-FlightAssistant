import 'package:flutter/material.dart';
import '../../../../core/services/localization_service.dart';
import '../../localization/common_localization_keys.dart';

class TransponderStatusWidget extends StatelessWidget {
  final String? code;
  final String? state;

  const TransponderStatusWidget({super.key, this.code, this.state});

  @override
  Widget build(BuildContext context) {
    final normalizedCode = code?.trim();
    final normalizedState = state?.trim();
    if ((normalizedCode == null || normalizedCode.isEmpty) &&
        (normalizedState == null || normalizedState.isEmpty)) {
      return const SizedBox.shrink();
    }
    final prefix = CommonLocalizationKeys.transponderPrefix.tr(context);
    final statusText = _resolveStatusText(
      context,
      normalizedCode,
      normalizedState,
    );
    final color = _resolveColor(normalizedCode);
    final codeText = (normalizedCode == null || normalizedCode.isEmpty)
        ? normalizedState!
        : '$prefix $normalizedCode';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            codeText,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (statusText != null && statusText.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              statusText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String? _resolveStatusText(
    BuildContext context,
    String? normalizedCode,
    String? normalizedState,
  ) {
    switch (normalizedCode) {
      case '7700':
        return CommonLocalizationKeys.transponderEmergency.tr(context);
      case '7600':
        return CommonLocalizationKeys.transponderRadioFailure.tr(context);
      case '7500':
        return CommonLocalizationKeys.transponderHijack.tr(context);
      default:
        return normalizedState;
    }
  }

  Color _resolveColor(String? normalizedCode) {
    switch (normalizedCode) {
      case '7700':
        return Colors.redAccent;
      case '7600':
        return Colors.orangeAccent;
      case '7500':
        return Colors.purpleAccent;
      default:
        return Colors.blueAccent;
    }
  }
}
