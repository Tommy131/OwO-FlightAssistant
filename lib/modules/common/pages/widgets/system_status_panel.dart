import 'package:flutter/material.dart';
import '../../../../core/services/localization_service.dart';
import '../../../../core/theme/app_theme_data.dart';
import '../../localization/common_localization_keys.dart';
import '../../models/home_models.dart';
import 'flight_data_widgets.dart';

class SystemStatusPanel extends StatelessWidget {
  final HomeFlightData data;

  const SystemStatusPanel({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showSecondEngine = (data.numEngines ?? 2) > 1;

    const warningColor = Color(0xFFD32F2F);
    const cautionColor = Color(0xFFFFA000);
    const fireColor = Color(0xFFFF5252);
    const beaconColor = Color(0xFFE53935);
    const strobeColor = Color(0xFFFFFFFF);
    const navLightsColor = Color(0xFF1E88E5);
    const logoLightsColor = Color(0xFF26C6DA);
    const wingLightsColor = Color(0xFF66BB6A);
    const taxiLightsColor = Color(0xFFFDD835);
    const runwayTurnoffColor = Color(0xFFFFB300);
    const wheelWellColor = Color(0xFFFFCA28);
    const landingLightsColor = Color(0xFF7CB342);
    const gearColor = Color(0xFF5E35B1);
    const parkingBrakeColor = Color(0xFFFF6F00);
    const speedBrakeColor = Color(0xFFE91E63);
    const autoBrakeColor = Color(0xFF00BCD4);
    const flapsColor = Color(0xFF9C27B0);
    const apuColor = Color(0xFF8E24AA);
    const engineColor = Color(0xFF43A047);
    const autopilotColor = Color(0xFF00ACC1);
    const autothrottleColor = Color(0xFF00897B);

    final onGroundColor = theme.brightness == Brightness.dark
        ? const Color(0xFFA1887F)
        : const Color(0xFF6D4C41);

    return Container(
      padding: const EdgeInsets.all(AppThemeData.spacingLarge),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppThemeData.borderRadiusMedium),
        border: Border.all(color: AppThemeData.getBorderColor(theme)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.dashboard, color: theme.colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                CommonLocalizationKeys.systemTitle.tr(context),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppThemeData.spacingLarge),
          Wrap(
            spacing: AppThemeData.spacingLarge,
            runSpacing: AppThemeData.spacingLarge,
            children: [
              _buildStatusSection(
                theme,
                CommonLocalizationKeys.systemSectionWarning.tr(context),
                [
                  if (data.masterWarning == true)
                    StatusBadge(
                      label: CommonLocalizationKeys.systemMasterWarning.tr(
                        context,
                      ),
                      color: warningColor,
                    ),
                  if (data.masterCaution == true)
                    StatusBadge(
                      label: CommonLocalizationKeys.systemMasterCaution.tr(
                        context,
                      ),
                      color: cautionColor,
                    ),
                  if (data.fireWarningEngine1 == true)
                    StatusBadge(
                      label: CommonLocalizationKeys.systemFireEngine1.tr(
                        context,
                      ),
                      color: fireColor,
                    ),
                  if (data.fireWarningEngine2 == true)
                    StatusBadge(
                      label: CommonLocalizationKeys.systemFireEngine2.tr(
                        context,
                      ),
                      color: fireColor,
                    ),
                  if (data.fireWarningAPU == true)
                    StatusBadge(
                      label: CommonLocalizationKeys.systemFireApu.tr(context),
                      color: fireColor,
                    ),
                ],
              ),
              _buildStatusSection(
                theme,
                CommonLocalizationKeys.systemSectionFlightControl.tr(context),
                [
                  if (data.onGround == true)
                    StatusBadge(
                      label: CommonLocalizationKeys.systemOnGround.tr(context),
                      color: onGroundColor,
                    ),
                  if (data.parkingBrake == true)
                    StatusBadge(
                      label: CommonLocalizationKeys.systemParkingBrake.tr(
                        context,
                      ),
                      color: parkingBrakeColor,
                    ),
                  if (data.speedBrake == true &&
                      (data.speedBrakeLabel ?? '').isNotEmpty)
                    StatusBadge(
                      label: CommonLocalizationKeys.systemSpeedBrake
                          .tr(context)
                          .replaceAll('{value}', data.speedBrakeLabel ?? ''),
                      color: speedBrakeColor,
                    ),
                  if (data.spoilersDeployed == true)
                    StatusBadge(
                      label: CommonLocalizationKeys.systemSpoilers.tr(context),
                      color: speedBrakeColor,
                    ),
                  if ((data.autoBrakeLabel ?? '').isNotEmpty)
                    StatusBadge(
                      label: CommonLocalizationKeys.systemAutoBrake
                          .tr(context)
                          .replaceAll('{value}', data.autoBrakeLabel ?? ''),
                      color: autoBrakeColor,
                    ),
                ],
              ),
              _buildStatusSection(
                theme,
                CommonLocalizationKeys.systemSectionGear.tr(context),
                [
                  if (data.gearDown == true)
                    StatusBadge(
                      label: CommonLocalizationKeys.systemGear.tr(context),
                      color: gearColor,
                    ),
                  if ((data.noseGearDown ?? 0) > 0.05)
                    StatusBadge(
                      label: CommonLocalizationKeys.systemNoseGear.tr(context),
                      color: gearColor,
                    ),
                  if ((data.leftGearDown ?? 0) > 0.05)
                    StatusBadge(
                      label: CommonLocalizationKeys.systemLeftGear.tr(context),
                      color: gearColor,
                    ),
                  if ((data.rightGearDown ?? 0) > 0.05)
                    StatusBadge(
                      label: CommonLocalizationKeys.systemRightGear.tr(context),
                      color: gearColor,
                    ),
                ],
              ),
              _buildStatusSection(
                theme,
                CommonLocalizationKeys.systemSectionFlaps.tr(context),
                [
                  if (data.flapsDeployed == true)
                    StatusBadge(
                      label: CommonLocalizationKeys.systemFlaps
                          .tr(context)
                          .replaceAll(
                            '{value}',
                            data.flapsLabel ??
                                (data.flapsAngle != null && data.flapsAngle! > 0
                                    ? '${data.flapsAngle!.toInt()}°'
                                    : '${((data.flapsDeployRatio ?? 0) * 100).toStringAsFixed(0)}%'),
                          ),
                      color: flapsColor,
                    ),
                ],
              ),
              _buildStatusSection(
                theme,
                CommonLocalizationKeys.systemSectionPower.tr(context),
                [
                  if (data.apuRunning == true)
                    StatusBadge(
                      label: CommonLocalizationKeys.systemApu.tr(context),
                      color: apuColor,
                    ),
                  if (!showSecondEngine && data.engine1Running == true)
                    StatusBadge(
                      label: CommonLocalizationKeys.systemEngineSingle.tr(
                        context,
                      ),
                      color: engineColor,
                    ),
                  if (showSecondEngine && data.engine1Running == true)
                    StatusBadge(
                      label: CommonLocalizationKeys.systemEngineLeft.tr(
                        context,
                      ),
                      color: engineColor,
                    ),
                  if (showSecondEngine && data.engine2Running == true)
                    StatusBadge(
                      label: CommonLocalizationKeys.systemEngineRight.tr(
                        context,
                      ),
                      color: engineColor,
                    ),
                  if (data.autopilotEngaged == true)
                    StatusBadge(
                      label: CommonLocalizationKeys.systemAutopilot.tr(context),
                      color: autopilotColor,
                    ),
                  if (data.autothrottleEngaged == true)
                    StatusBadge(
                      label: CommonLocalizationKeys.systemAutothrottle.tr(
                        context,
                      ),
                      color: autothrottleColor,
                    ),
                ],
              ),
              _buildStatusSection(
                theme,
                CommonLocalizationKeys.systemSectionLights.tr(context),
                [
                  if (data.beacon == true)
                    StatusBadge(
                      label: CommonLocalizationKeys.systemBeacon.tr(context),
                      color: beaconColor,
                    ),
                  if (data.strobes == true)
                    StatusBadge(
                      label: CommonLocalizationKeys.systemStrobe.tr(context),
                      color: strobeColor,
                    ),
                  if (data.navLights == true)
                    StatusBadge(
                      label: CommonLocalizationKeys.systemNavLights.tr(context),
                      color: navLightsColor,
                    ),
                  if (data.logoLights == true)
                    StatusBadge(
                      label: CommonLocalizationKeys.systemLogoLights.tr(
                        context,
                      ),
                      color: logoLightsColor,
                    ),
                  if (data.wingLights == true)
                    StatusBadge(
                      label: CommonLocalizationKeys.systemWingLights.tr(
                        context,
                      ),
                      color: wingLightsColor,
                    ),
                  if (data.landingLights == true)
                    StatusBadge(
                      label: CommonLocalizationKeys.systemLandingLights.tr(
                        context,
                      ),
                      color: landingLightsColor,
                    ),
                  if (data.taxiLights == true)
                    StatusBadge(
                      label: CommonLocalizationKeys.systemTaxiLights.tr(
                        context,
                      ),
                      color: taxiLightsColor,
                    ),
                  if (data.runwayTurnoffLights == true)
                    StatusBadge(
                      label: CommonLocalizationKeys.systemRunwayTurnoff.tr(
                        context,
                      ),
                      color: runwayTurnoffColor,
                    ),
                  if (data.wheelWellLights == true)
                    StatusBadge(
                      label: CommonLocalizationKeys.systemWheelWell.tr(context),
                      color: wheelWellColor,
                    ),
                ],
              ),
            ].whereType<Widget>().toList(),
          ),
        ],
      ),
    );
  }

  Widget? _buildStatusSection(
    ThemeData theme,
    String title,
    List<Widget> children,
  ) {
    if (children.isEmpty) return null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.hintColor,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: children),
      ],
    );
  }
}
