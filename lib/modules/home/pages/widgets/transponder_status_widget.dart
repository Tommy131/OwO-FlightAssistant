import 'package:flutter/material.dart';
import '../../../../core/services/localization_service.dart';
import '../../localization/home_localization_keys.dart';

class TransponderStatusWidget extends StatelessWidget {
  final String? code;
  final String? state;

  const TransponderStatusWidget({super.key, this.code, this.state});

  @override
  /// 功能：构建当前组件的界面结构并返回可渲染的控件树。
  /// 说明：该方法属于组件生命周期关键路径，会直接影响页面稳定性与交互体验。
  Widget build(BuildContext context) {
    final normalizedCode = code?.trim();
    final normalizedState = state?.trim();
    if ((normalizedCode == null || normalizedCode.isEmpty) &&
        (normalizedState == null || normalizedState.isEmpty)) {
      return const SizedBox.shrink();
    }
    final prefix = HomeLocalizationKeys.transponderPrefix.tr(context);
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
        return HomeLocalizationKeys.transponderEmergency.tr(context);
      case '7600':
        return HomeLocalizationKeys.transponderRadioFailure.tr(context);
      case '7500':
        return HomeLocalizationKeys.transponderHijack.tr(context);
      default:
        return normalizedState;
    }
  }

  /// 功能：执行resolveColor的核心业务流程。
  /// 说明：该方法封装单一职责逻辑，便于后续维护、定位问题与扩展功能。
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
