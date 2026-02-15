import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/services/localization_service.dart';
import '../../../core/theme/app_theme_data.dart';
import '../localization/monitor_localization_keys.dart';
import '../providers/monitor_provider.dart';
import 'widgets/compass_section.dart';
import 'widgets/landing_gear_card.dart';
import 'widgets/monitor_charts.dart';
import 'widgets/monitor_header.dart';
import 'widgets/systems_status_card.dart';

class MonitorPage extends StatelessWidget {
  const MonitorPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<MonitorProvider>(
      builder: (context, provider, _) {
        final theme = Theme.of(context);
        if (!provider.isConnected) {
          return _buildNoConnectionPlaceholder(context, theme);
        }

        final data = provider.data;

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(AppThemeData.spacingLarge),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MonitorHeader(data: data),
                const SizedBox(height: AppThemeData.spacingLarge),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          CompassSection(data: data),
                          const SizedBox(height: AppThemeData.spacingLarge),
                          SystemsStatusCard(data: data),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppThemeData.spacingLarge),
                    Expanded(child: LandingGearCard(data: data)),
                  ],
                ),
                const SizedBox(height: AppThemeData.spacingLarge),
                MonitorCharts(provider: provider),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNoConnectionPlaceholder(BuildContext context, ThemeData theme) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppThemeData.spacingLarge * 2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        theme.colorScheme.primary.withValues(alpha: 0.15),
                        theme.colorScheme.primary.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.colorScheme.surface,
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withValues(alpha: 0.2),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.sensors_off_rounded,
                    size: 60,
                    color: theme.colorScheme.primary.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 48),
            ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.secondary,
                ],
              ).createShader(bounds),
              child: Text(
                MonitorLocalizationKeys.noConnectionTitle.tr(context),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Text(
                MonitorLocalizationKeys.noConnectionSubtitle.tr(context),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  height: 1.6,
                ),
              ),
            ),
            const SizedBox(height: 56),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildStep(
                  context,
                  MonitorLocalizationKeys.noConnectionStepHome.tr(context),
                  Icons.home_outlined,
                ),
                _buildArrow(theme),
                _buildStep(
                  context,
                  MonitorLocalizationKeys.noConnectionStepConnect.tr(context),
                  Icons.link_rounded,
                ),
                _buildArrow(theme),
                _buildStep(
                  context,
                  MonitorLocalizationKeys.noConnectionStepStart.tr(context),
                  Icons.check_circle_outline_rounded,
                ),
              ],
            ),
            const SizedBox(height: 80),
            Opacity(
              opacity: 0.3,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(width: 24),
                  _buildStatusDot(theme, "X-Plane 11/12", true),
                  const SizedBox(width: 24),
                  _buildStatusDot(theme, "MSFS 2020/2024", true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(BuildContext context, String label, IconData icon) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(AppThemeData.spacingMedium),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
            ),
          ),
          child: Icon(icon, color: theme.colorScheme.primary),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildArrow(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      margin: const EdgeInsets.only(bottom: 24),
      child: Icon(
        Icons.chevron_right_rounded,
        color: theme.colorScheme.primary.withValues(alpha: 0.3),
      ),
    );
  }

  Widget _buildStatusDot(ThemeData theme, String label, bool supported) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: supported ? Colors.greenAccent : Colors.grey,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
