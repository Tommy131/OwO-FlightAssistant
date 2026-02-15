import 'package:flutter/material.dart';
import '../../../../core/services/localization_service.dart';
import '../../../../core/theme/app_theme_data.dart';
import '../../localization/monitor_localization_keys.dart';
import '../../models/monitor_models.dart';

class LandingGearCard extends StatelessWidget {
  final MonitorData data;

  const LandingGearCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final panelColor = const Color(0xFF2A2A2A);
    final panelBorderColor = const Color(0xFF1A1A1A);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppThemeData.spacingLarge),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(AppThemeData.borderRadiusLarge),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            MonitorLocalizationKeys.landingGearTitle.tr(context),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 20),
          Center(
            child: Container(
              width: 280,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: panelColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: panelBorderColor, width: 4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildIndicators(context),
                  const SizedBox(height: 24),
                  _buildGearHandle(context),
                  const SizedBox(height: 16),
                  _buildLimitText(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIndicators(BuildContext context) {
    int getStatus(double? ratio) {
      if (ratio == null) return 0;
      if (ratio <= 0.02) return 0;
      if (ratio >= 0.98) return 2;
      return 1;
    }

    return Column(
      children: [
        _buildLightBox(
          MonitorLocalizationKeys.gearNoseLabel.tr(context),
          getStatus(data.noseGearDown),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLightBox(
              MonitorLocalizationKeys.gearLeftLabel.tr(context),
              getStatus(data.leftGearDown),
            ),
            const SizedBox(width: 24),
            _buildLightBox(
              MonitorLocalizationKeys.gearRightLabel.tr(context),
              getStatus(data.rightGearDown),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLightBox(String text, int status) {
    final showRed = status == 1;
    final showGreen = status == 1 || status == 2;

    return Column(
      children: [
        _buildSingleLight(text, Colors.redAccent, showRed),
        const SizedBox(height: 4),
        _buildSingleLight(text, const Color(0xFF4CAF50), showGreen),
      ],
    );
  }

  Widget _buildSingleLight(String text, Color color, bool isLit) {
    return Container(
      width: 60,
      height: 40,
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border.all(color: Colors.grey[800]!, width: 2),
        borderRadius: BorderRadius.circular(4),
        boxShadow: isLit
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.6),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: isLit ? color : Colors.grey.withValues(alpha: 0.3),
          fontSize: 10,
          fontWeight: FontWeight.bold,
          height: 1.1,
          fontFamily: 'monospace',
        ),
      ),
    );
  }

  Widget _buildGearHandle(BuildContext context) {
    final avg =
        ((data.noseGearDown ?? 0) +
            (data.leftGearDown ?? 0) +
            (data.rightGearDown ?? 0)) /
        3.0;
    final sliderValue = (avg * 2) - 1;

    return SizedBox(
      height: 200,
      width: 100,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 40,
            height: 200,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey[800]!, width: 2),
            ),
          ),
          Positioned(
            top: 10,
            left: 0,
            child: Text(
              MonitorLocalizationKeys.gearPositionUp.tr(context),
              style: const TextStyle(color: Colors.white70, fontSize: 10),
            ),
          ),
          Positioned(
            top: 95,
            left: 0,
            child: Text(
              MonitorLocalizationKeys.gearPositionOff.tr(context),
              style: const TextStyle(color: Colors.white70, fontSize: 10),
            ),
          ),
          Positioned(
            bottom: 10,
            left: 0,
            child: Text(
              MonitorLocalizationKeys.gearPositionDown.tr(context),
              style: const TextStyle(color: Colors.white70, fontSize: 10),
            ),
          ),
          AnimatedAlign(
            duration: const Duration(milliseconds: 300),
            alignment: Alignment(0, sliderValue),
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey[300],
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black54,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.white, Colors.grey[400]!],
                ),
              ),
              child: Center(
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.transparent,
                    border: Border.all(color: Colors.grey[600]!, width: 2),
                  ),
                  child: const Icon(Icons.circle, color: Colors.grey, size: 30),
                ),
              ),
            ),
          ),
          Positioned(
            left: -25,
            top: 50,
            child: RotatedBox(
              quarterTurns: 3,
              child: Text(
                MonitorLocalizationKeys.gearHandleLabel.tr(context),
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 10,
                  letterSpacing: 2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLimitText(BuildContext context) {
    return Column(
      children: [
        Text(
          MonitorLocalizationKeys.gearLimitTitle.tr(context),
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          MonitorLocalizationKeys.gearLimitContent.tr(context),
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 8,
            fontFamily: 'Monospace',
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
