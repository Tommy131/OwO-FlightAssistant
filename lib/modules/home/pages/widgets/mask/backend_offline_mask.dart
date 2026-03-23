import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../../core/services/localization_service.dart';
import '../../../../../core/theme/app_theme_data.dart';
import '../../../localization/home_localization_keys.dart';

/// 后端离线遮罩层
///
/// 当 Backend 不可达时覆盖整个 HomePage，提供毛玻璃背景效果与提示卡片。
/// 提示卡片包含错误图标、说明文字和重试按钮。
///
/// 参数说明：
/// - [opacity]：遮罩透明度（0 = 完全透明，1 = 完全不透明），可通过动画驱动
/// - [showHelpCard]：是否展示连接帮助卡片
/// - [isRetrying]：当前是否正在重试连接
/// - [onRetry]：重试回调
class BackendOfflineMask extends StatelessWidget {
  /// 遮罩整体透明度
  final double opacity;

  /// 是否展示帮助卡片
  final bool showHelpCard;

  /// 是否正在重试中（重试过程中禁用按钮并显示加载指示器）
  final bool isRetrying;

  /// 点击重试时的回调
  final VoidCallback? onRetry;

  /// 透明度动画结束时的回调（用于在透明度归零后移除遮罩 Widget）
  final VoidCallback? onFadeEnd;

  /// 是否吸收用户交互（遮罩可见时阻止底层点击）
  final bool absorbPointer;

  const BackendOfflineMask({
    super.key,
    required this.opacity,
    required this.showHelpCard,
    required this.isRetrying,
    this.onRetry,
    this.onFadeEnd,
    this.absorbPointer = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Stack(
      children: [
        // 毛玻璃模糊背景层（可吸收点击）
        AbsorbPointer(
          absorbing: absorbPointer,
          child: AnimatedOpacity(
            opacity: opacity,
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            onEnd: onFadeEnd,
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  color: theme.colorScheme.surface.withValues(alpha: 0.35),
                ),
              ),
            ),
          ),
        ),

        // 后端不可达帮助卡片（居中显示）
        if (showHelpCard)
          Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 520),
              margin: const EdgeInsets.all(AppThemeData.spacingLarge),
              padding: const EdgeInsets.all(AppThemeData.spacingLarge + 4),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    theme.colorScheme.surface.withValues(alpha: 0.93),
                    theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.9,
                    ),
                  ],
                ),
                borderRadius: BorderRadius.circular(
                  AppThemeData.borderRadiusLarge,
                ),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.35),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.28),
                    blurRadius: 36,
                    offset: const Offset(0, 18),
                  ),
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.2),
                    blurRadius: 22,
                    spreadRadius: 2,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 错误图标
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.error.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.cloud_off_rounded,
                      color: theme.colorScheme.error,
                      size: 34,
                    ),
                  ),
                  const SizedBox(height: AppThemeData.spacingMedium),
                  // 标题
                  Text(
                    HomeLocalizationKeys.homeMaskConnectBackendTitle.tr(
                      context,
                    ),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppThemeData.spacingSmall),
                  // 副标题
                  Text(
                    HomeLocalizationKeys.homeMaskConnectBackendSubtitle.tr(
                      context,
                    ),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.85,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppThemeData.spacingMedium),
                  // 重试按钮
                  FilledButton.icon(
                    onPressed: isRetrying ? null : onRetry,
                    icon: isRetrying
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh_rounded, size: 18),
                    label: Text(
                      isRetrying
                          ? HomeLocalizationKeys.homeMaskRetryingButton.tr(
                              context,
                            )
                          : HomeLocalizationKeys.homeMaskRetryButton.tr(
                              context,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
