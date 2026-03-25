import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../core/services/localization_service.dart';
import '../../../../../core/theme/app_theme_data.dart';
import '../../../../common/providers/common_provider.dart';
import '../../../localization/home_localization_keys.dart';
import 'transponder_status_widget.dart';

/// 欢迎卡片，根据模拟器连接与飞行状态动态切换标题、副标题和状态图标
///
/// 状态分为：未连接 / 已暂停 / 就绪（含应答机徽章）
class WelcomeCard extends StatelessWidget {
  const WelcomeCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<HomeProvider>();

    final isConnected = provider.isConnected;
    final aircraftTitle = provider.aircraftTitle;
    final isPaused = provider.isPaused ?? false;
    final showTransponder =
        isConnected &&
        (provider.transponderState != null || provider.transponderCode != null);

    // 根据状态确定标题、副标题与状态图标
    String title;
    String subtitle;
    Widget? statusIndicator;

    if (!isConnected) {
      title = HomeLocalizationKeys.welcomeNotConnectedTitle.tr(context);
      subtitle = HomeLocalizationKeys.welcomeNotConnectedSubtitle.tr(context);
    } else if (isPaused) {
      title = HomeLocalizationKeys.welcomePausedTitle.tr(context);
      subtitle = HomeLocalizationKeys.welcomePausedSubtitle
          .tr(context)
          .replaceAll('{aircraft}', aircraftTitle ?? '-');
      statusIndicator = Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.yellow.withValues(alpha: 0.2),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.pause_circle_filled,
          color: Colors.yellow,
          size: 32,
        ),
      );
    } else {
      title = HomeLocalizationKeys.welcomeReadyTitle.tr(context);
      subtitle = aircraftTitle != null
          ? HomeLocalizationKeys.welcomeReadySubtitle
                .tr(context)
                .replaceAll('{aircraft}', aircraftTitle)
          : HomeLocalizationKeys.welcomeReadySubtitleWaiting.tr(context);
      statusIndicator = Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.greenAccent.withValues(alpha: 0.2),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.check_circle,
          color: Colors.greenAccent,
          size: 32,
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 740;

        final supportSimsRow = Row(
          children: [
            Icon(
              Icons.check_circle_outline,
              color: Colors.white.withValues(alpha: 0.8),
              size: 16,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                HomeLocalizationKeys.welcomeSupportSims.tr(context),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 12,
                ),
              ),
            ),
          ],
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppThemeData.spacingLarge),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(
                  AppThemeData.borderRadiusLarge,
                ),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: isCompact
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: AppThemeData.spacingSmall),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: AppThemeData.spacingLarge),
                        supportSimsRow,
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: AppThemeData.spacingSmall),
                              Text(
                                subtitle,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: AppThemeData.spacingLarge),
                              supportSimsRow,
                            ],
                          ),
                        ),
                        const SizedBox(width: AppThemeData.spacingLarge),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            statusIndicator ?? const SizedBox.shrink(),
                            if (showTransponder && statusIndicator != null)
                              const SizedBox(height: 8),
                            if (showTransponder)
                              TransponderStatusWidget(
                                code: provider.transponderCode,
                                state: provider.transponderState,
                              ),
                          ],
                        ),
                      ],
                    ),
            ),
            if (isCompact && isConnected)
              const SizedBox(height: AppThemeData.spacingSmall),
            if (isCompact && isConnected)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppThemeData.spacingMedium,
                  vertical: AppThemeData.spacingSmall,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(
                    AppThemeData.borderRadiusMedium,
                  ),
                  border: Border.all(color: AppThemeData.getBorderColor(theme)),
                ),
                child: Row(
                  children: [
                    if (showTransponder)
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: TransponderStatusWidget(
                            code: provider.transponderCode,
                            state: provider.transponderState,
                          ),
                        ),
                      )
                    else
                      const Spacer(),
                    if (statusIndicator != null)
                      Align(
                        alignment: Alignment.centerRight,
                        child: statusIndicator,
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
