import 'package:flutter/material.dart';
import '../../../../core/services/localization_service.dart';
import '../../../../core/theme/app_theme_data.dart';
import '../../localization/home_localization_keys.dart';
import '../../models/home_models.dart';
import 'flight_data_widgets.dart';

class SystemStatusPanel extends StatelessWidget {
  final HomeFlightData data;

  const SystemStatusPanel({super.key, required this.data});

  @override
  /// 功能：构建当前组件的界面结构并返回可渲染的控件树。
  /// 说明：该方法属于组件生命周期关键路径，会直接影响页面稳定性与交互体验。
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
                HomeLocalizationKeys.systemTitle.tr(context),
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
                HomeLocalizationKeys.systemSectionWarning.tr(context),
                [
                  if (data.masterWarning == true)
                    StatusBadge(
                      label: HomeLocalizationKeys.systemMasterWarning.tr(
                        context,
                      ),
                      color: warningColor,
                    ),
                  if (data.masterCaution == true)
                    StatusBadge(
                      label: HomeLocalizationKeys.systemMasterCaution.tr(
                        context,
                      ),
                      color: cautionColor,
                    ),
                  if (data.fireWarningEngine1 == true)
                    StatusBadge(
                      label: HomeLocalizationKeys.systemFireEngine1.tr(
                        context,
                      ),
                      color: fireColor,
                    ),
                  if (data.fireWarningEngine2 == true)
                    StatusBadge(
                      label: HomeLocalizationKeys.systemFireEngine2.tr(
                        context,
                      ),
                      color: fireColor,
                    ),
                  if (data.fireWarningAPU == true)
                    StatusBadge(
                      label: HomeLocalizationKeys.systemFireApu.tr(context),
                      color: fireColor,
                    ),
                ],
              ),
              _buildStatusSection(
                theme,
                HomeLocalizationKeys.systemSectionFlightControl.tr(context),
                [
                  if (data.onGround == true)
                    StatusBadge(
                      label: HomeLocalizationKeys.systemOnGround.tr(context),
                      color: onGroundColor,
                    ),
                  if (data.parkingBrake == true)
                    StatusBadge(
                      label: HomeLocalizationKeys.systemParkingBrake.tr(
                        context,
                      ),
                      color: parkingBrakeColor,
                    ),
                  if (data.speedBrake == true &&
                      (data.speedBrakeLabel ?? '').isNotEmpty)
                    StatusBadge(
                      label: HomeLocalizationKeys.systemSpeedBrake
                          .tr(context)
                          /// 功能：执行replaceAll的核心业务流程。
                          /// 说明：该方法封装单一职责逻辑，便于后续维护、定位问题与扩展功能。
                          .replaceAll('{value}', data.speedBrakeLabel ?? ''),
                      color: speedBrakeColor,
                    ),
                  if (data.spoilersDeployed == true)
                    StatusBadge(
                      label: HomeLocalizationKeys.systemSpoilers.tr(context),
                      color: speedBrakeColor,
                    ),
                  if ((data.autoBrakeLabel ?? '').isNotEmpty)
                    StatusBadge(
                      label: HomeLocalizationKeys.systemAutoBrake
                          .tr(context)
                          /// 功能：执行replaceAll的核心业务流程。
                          /// 说明：该方法封装单一职责逻辑，便于后续维护、定位问题与扩展功能。
                          .replaceAll('{value}', data.autoBrakeLabel ?? ''),
                      color: autoBrakeColor,
                    ),
                ],
              ),
              _buildStatusSection(
                theme,
                HomeLocalizationKeys.systemSectionGear.tr(context),
                [
                  if (data.gearDown == true)
                    StatusBadge(
                      label: HomeLocalizationKeys.systemGear.tr(context),
                      color: gearColor,
                    ),
                  if ((data.noseGearDown ?? 0) > 0.05)
                    StatusBadge(
                      label: HomeLocalizationKeys.systemNoseGear.tr(context),
                      color: gearColor,
                    ),
                  if ((data.leftGearDown ?? 0) > 0.05)
                    StatusBadge(
                      label: HomeLocalizationKeys.systemLeftGear.tr(context),
                      color: gearColor,
                    ),
                  if ((data.rightGearDown ?? 0) > 0.05)
                    StatusBadge(
                      label: HomeLocalizationKeys.systemRightGear.tr(context),
                      color: gearColor,
                    ),
                ],
              ),
              _buildStatusSection(
                theme,
                HomeLocalizationKeys.systemSectionFlaps.tr(context),
                [
                  if (data.flapsDeployed == true)
                    StatusBadge(
                      label: HomeLocalizationKeys.systemFlaps
                          .tr(context)
                          .replaceAll(
                            '{value}',
                            data.flapsLabel ??
                                (data.flapsAngle != null && data.flapsAngle! > 0
                                    /// 功能：执行toInt的核心业务流程。
                                    /// 说明：该方法封装单一职责逻辑，便于后续维护、定位问题与扩展功能。
                                    ? '${data.flapsAngle!.toInt()}°'
                                    : '${((data.flapsDeployRatio ?? 0) * 100).toStringAsFixed(0)}%'),
                          ),
                      color: flapsColor,
                    ),
                ],
              ),
              _buildStatusSection(
                theme,
                HomeLocalizationKeys.systemSectionPower.tr(context),
                [
                  if (data.apuRunning == true)
                    StatusBadge(
                      label: HomeLocalizationKeys.systemApu.tr(context),
                      color: apuColor,
                    ),
                  if (!showSecondEngine && data.engine1Running == true)
                    StatusBadge(
                      label: HomeLocalizationKeys.systemEngineSingle.tr(
                        context,
                      ),
                      color: engineColor,
                    ),
                  if (showSecondEngine && data.engine1Running == true)
                    StatusBadge(
                      label: HomeLocalizationKeys.systemEngineLeft.tr(
                        context,
                      ),
                      color: engineColor,
                    ),
                  if (showSecondEngine && data.engine2Running == true)
                    StatusBadge(
                      label: HomeLocalizationKeys.systemEngineRight.tr(
                        context,
                      ),
                      color: engineColor,
                    ),
                  if (data.autopilotEngaged == true)
                    StatusBadge(
                      label: HomeLocalizationKeys.systemAutopilot.tr(context),
                      color: autopilotColor,
                    ),
                  if (data.autothrottleEngaged == true)
                    StatusBadge(
                      label: HomeLocalizationKeys.systemAutothrottle.tr(
                        context,
                      ),
                      color: autothrottleColor,
                    ),
                ],
              ),
              _buildStatusSection(
                theme,
                HomeLocalizationKeys.systemSectionLights.tr(context),
                [
                  if (data.beacon == true)
                    StatusBadge(
                      label: HomeLocalizationKeys.systemBeacon.tr(context),
                      color: beaconColor,
                    ),
                  if (data.strobes == true)
                    StatusBadge(
                      label: HomeLocalizationKeys.systemStrobe.tr(context),
                      color: strobeColor,
                    ),
                  if (data.navLights == true)
                    StatusBadge(
                      label: HomeLocalizationKeys.systemNavLights.tr(context),
                      color: navLightsColor,
                    ),
                  if (data.logoLights == true)
                    StatusBadge(
                      label: HomeLocalizationKeys.systemLogoLights.tr(
                        context,
                      ),
                      color: logoLightsColor,
                    ),
                  if (data.wingLights == true)
                    StatusBadge(
                      label: HomeLocalizationKeys.systemWingLights.tr(
                        context,
                      ),
                      color: wingLightsColor,
                    ),
                  if (data.landingLights == true)
                    StatusBadge(
                      label: HomeLocalizationKeys.systemLandingLights.tr(
                        context,
                      ),
                      color: landingLightsColor,
                    ),
                  if (data.taxiLights == true)
                    StatusBadge(
                      label: HomeLocalizationKeys.systemTaxiLights.tr(
                        context,
                      ),
                      color: taxiLightsColor,
                    ),
                  if (data.runwayTurnoffLights == true)
                    StatusBadge(
                      label: HomeLocalizationKeys.systemRunwayTurnoff.tr(
                        context,
                      ),
                      color: runwayTurnoffColor,
                    ),
                  if (data.wheelWellLights == true)
                    StatusBadge(
                      label: HomeLocalizationKeys.systemWheelWell.tr(context),
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
