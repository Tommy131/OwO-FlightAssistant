import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme_data.dart';
import '../../../../core/services/localization_service.dart';
import '../../localization/toolbox_localization_keys.dart';
import 'toolbox_section_card.dart';

class FlightCalculatorsTab extends StatefulWidget {
  const FlightCalculatorsTab({super.key});

  @override
  State<FlightCalculatorsTab> createState() => _FlightCalculatorsTabState();
}

class _FlightCalculatorsTabState extends State<FlightCalculatorsTab> {
  final TextEditingController _runwayHeadingController = TextEditingController(
    text: '270',
  );
  final TextEditingController _windDirectionController = TextEditingController(
    text: '300',
  );
  final TextEditingController _windSpeedController = TextEditingController(
    text: '18',
  );
  String _windResult = '';

  final TextEditingController _currentAltController = TextEditingController(
    text: '35000',
  );
  final TextEditingController _targetAltController = TextEditingController(
    text: '3000',
  );
  final TextEditingController _groundSpeedController = TextEditingController(
    text: '300',
  );
  final TextEditingController _descentRateController = TextEditingController(
    text: '1500',
  );
  final TextEditingController _distanceToGoController = TextEditingController(
    text: '110',
  );
  String _descentResult = '';

  final TextEditingController _distanceNmController = TextEditingController(
    text: '520',
  );
  final TextEditingController _cruiseSpeedController = TextEditingController(
    text: '430',
  );
  final TextEditingController _burnRateController = TextEditingController(
    text: '2500',
  );
  final TextEditingController _reserveMinController = TextEditingController(
    text: '45',
  );
  final TextEditingController _taxiFuelController = TextEditingController(
    text: '220',
  );
  final TextEditingController _extraPctController = TextEditingController(
    text: '5',
  );
  String _fuelResult = '';

  @override
  void dispose() {
    _runwayHeadingController.dispose();
    _windDirectionController.dispose();
    _windSpeedController.dispose();
    _currentAltController.dispose();
    _targetAltController.dispose();
    _groundSpeedController.dispose();
    _descentRateController.dispose();
    _distanceToGoController.dispose();
    _distanceNmController.dispose();
    _cruiseSpeedController.dispose();
    _burnRateController.dispose();
    _reserveMinController.dispose();
    _taxiFuelController.dispose();
    _extraPctController.dispose();
    super.dispose();
  }

  double? _parse(TextEditingController controller) {
    return double.tryParse(controller.text.trim());
  }

  void _calculateWind(BuildContext context) {
    final runwayHeading = _parse(_runwayHeadingController);
    final windDirection = _parse(_windDirectionController);
    final windSpeed = _parse(_windSpeedController);
    if (runwayHeading == null || windDirection == null || windSpeed == null) {
      setState(
        () => _windResult = ToolboxLocalizationKeys.commonInvalidNumber.tr(
          context,
        ),
      );
      return;
    }
    final delta = ((windDirection - runwayHeading) % 360 + 360) % 360;
    final angle = delta > 180 ? 360 - delta : delta;
    final rad = angle * math.pi / 180;
    final headwind = windSpeed * math.cos(rad);
    final crosswindRaw = windSpeed * math.sin(delta * math.pi / 180);
    final crosswind = crosswindRaw.abs();
    final crosswindFrom = crosswindRaw >= 0
        ? ToolboxLocalizationKeys.calcWindFromRight.tr(context)
        : ToolboxLocalizationKeys.calcWindFromLeft.tr(context);
    final level = crosswind <= 10
        ? ToolboxLocalizationKeys.calcWindRiskLow.tr(context)
        : crosswind <= 20
        ? ToolboxLocalizationKeys.calcWindRiskMedium.tr(context)
        : ToolboxLocalizationKeys.calcWindRiskHigh.tr(context);
    setState(() {
      _windResult =
          '${ToolboxLocalizationKeys.calcWindHeadwind.tr(context)} ${headwind.toStringAsFixed(1)} kt\n'
          '${ToolboxLocalizationKeys.calcWindCrosswind.tr(context)} ${crosswind.toStringAsFixed(1)} kt（$crosswindFrom）\n'
          '${ToolboxLocalizationKeys.calcWindRiskLevel.tr(context)}：$level';
    });
  }

  void _calculateDescent(BuildContext context) {
    final currentAlt = _parse(_currentAltController);
    final targetAlt = _parse(_targetAltController);
    final groundSpeed = _parse(_groundSpeedController);
    final descentRate = _parse(_descentRateController);
    final distanceToGo = _parse(_distanceToGoController);
    if (currentAlt == null ||
        targetAlt == null ||
        groundSpeed == null ||
        descentRate == null) {
      setState(
        () => _descentResult = ToolboxLocalizationKeys.commonInvalidNumber.tr(
          context,
        ),
      );
      return;
    }
    final altitudeToLose = (currentAlt - targetAlt).clamp(0, 50000).toDouble();
    if (altitudeToLose <= 0 || descentRate <= 0 || groundSpeed <= 0) {
      setState(
        () => _descentResult = ToolboxLocalizationKeys.commonInvalidRange.tr(
          context,
        ),
      );
      return;
    }
    final minutes = altitudeToLose / descentRate;
    final todDistance = groundSpeed * (minutes / 60);
    final ruleOf3Distance = (altitudeToLose / 1000) * 3;
    final requiredVs = distanceToGo == null || distanceToGo <= 0
        ? null
        : altitudeToLose / ((distanceToGo / groundSpeed) * 60);
    setState(() {
      _descentResult =
          '${ToolboxLocalizationKeys.calcDescentAltitudeToLose.tr(context)} ${altitudeToLose.toStringAsFixed(0)} ft\n'
          '${ToolboxLocalizationKeys.calcDescentTime.tr(context)} ${minutes.toStringAsFixed(1)} min\n'
          '${ToolboxLocalizationKeys.calcDescentTodDistance.tr(context)} ${todDistance.toStringAsFixed(1)} NM\n'
          '${ToolboxLocalizationKeys.calcDescentRuleDistance.tr(context)} ${ruleOf3Distance.toStringAsFixed(1)} NM'
          '${requiredVs == null ? '' : '\n${ToolboxLocalizationKeys.calcDescentRequiredVs.tr(context)} ${requiredVs.toStringAsFixed(0)} fpm'}';
    });
  }

  void _calculateFuel(BuildContext context) {
    final distanceNm = _parse(_distanceNmController);
    final cruiseSpeed = _parse(_cruiseSpeedController);
    final burnRate = _parse(_burnRateController);
    final reserveMin = _parse(_reserveMinController);
    final taxiFuel = _parse(_taxiFuelController);
    final extraPct = _parse(_extraPctController);
    if (distanceNm == null ||
        cruiseSpeed == null ||
        burnRate == null ||
        reserveMin == null ||
        taxiFuel == null ||
        extraPct == null) {
      setState(
        () => _fuelResult = ToolboxLocalizationKeys.commonInvalidNumber.tr(
          context,
        ),
      );
      return;
    }
    if (distanceNm < 0 ||
        cruiseSpeed <= 0 ||
        burnRate <= 0 ||
        reserveMin < 0 ||
        taxiFuel < 0 ||
        extraPct < 0) {
      setState(
        () => _fuelResult = ToolboxLocalizationKeys.commonInvalidRange.tr(
          context,
        ),
      );
      return;
    }
    final tripHours = distanceNm / cruiseSpeed;
    final tripFuel = burnRate * tripHours;
    final reserveFuel = burnRate * (reserveMin / 60);
    final extraFuel = tripFuel * (extraPct / 100);
    final totalFuel = tripFuel + reserveFuel + taxiFuel + extraFuel;
    setState(() {
      _fuelResult =
          '${ToolboxLocalizationKeys.calcFuelTrip.tr(context)} ${tripFuel.toStringAsFixed(0)} kg\n'
          '${ToolboxLocalizationKeys.calcFuelReserve.tr(context)} ${reserveFuel.toStringAsFixed(0)} kg\n'
          '${ToolboxLocalizationKeys.calcFuelTaxi.tr(context)} ${taxiFuel.toStringAsFixed(0)} kg\n'
          '${ToolboxLocalizationKeys.calcFuelExtra.tr(context)} ${extraFuel.toStringAsFixed(0)} kg\n'
          '${ToolboxLocalizationKeys.calcFuelTotal.tr(context)} ${totalFuel.toStringAsFixed(0)} kg';
    });
  }

  Widget _resultCard(String title, String value) {
    final theme = Theme.of(context);
    if (value.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: AppThemeData.spacingMedium),
      padding: const EdgeInsets.all(AppThemeData.spacingMedium),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppThemeData.borderRadiusMedium),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.labelLarge),
          const SizedBox(height: AppThemeData.spacingSmall),
          SelectableText(value, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }

  Widget _numberField(
    TextEditingController controller,
    String label,
    IconData icon,
  ) {
    return ToolboxTextField(
      label: label,
      hint: ToolboxLocalizationKeys.commonInputHint.tr(context),
      icon: icon,
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LocalizationService>();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppThemeData.spacingLarge),
      child: Column(
        children: [
          ToolboxSectionCard(
            title: ToolboxLocalizationKeys.calcWindSectionTitle.tr(context),
            icon: Icons.air,
            child: Column(
              children: [
                _numberField(
                  _runwayHeadingController,
                  ToolboxLocalizationKeys.calcWindRunwayHeading.tr(context),
                  Icons.explore,
                ),
                const SizedBox(height: AppThemeData.spacingSmall),
                _numberField(
                  _windDirectionController,
                  ToolboxLocalizationKeys.calcWindDirection.tr(context),
                  Icons.navigation,
                ),
                const SizedBox(height: AppThemeData.spacingSmall),
                _numberField(
                  _windSpeedController,
                  ToolboxLocalizationKeys.calcWindSpeed.tr(context),
                  Icons.speed,
                ),
                const SizedBox(height: AppThemeData.spacingMedium),
                ElevatedButton.icon(
                  onPressed: () => _calculateWind(context),
                  icon: const Icon(Icons.calculate),
                  label: Text(
                    ToolboxLocalizationKeys.calcWindButton.tr(context),
                  ),
                ),
                _resultCard(
                  ToolboxLocalizationKeys.calcWindResultTitle.tr(context),
                  _windResult,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppThemeData.spacingLarge),
          ToolboxSectionCard(
            title: ToolboxLocalizationKeys.calcDescentSectionTitle.tr(context),
            icon: Icons.south,
            child: Column(
              children: [
                _numberField(
                  _currentAltController,
                  ToolboxLocalizationKeys.calcDescentCurrentAlt.tr(context),
                  Icons.height,
                ),
                const SizedBox(height: AppThemeData.spacingSmall),
                _numberField(
                  _targetAltController,
                  ToolboxLocalizationKeys.calcDescentTargetAlt.tr(context),
                  Icons.flag,
                ),
                const SizedBox(height: AppThemeData.spacingSmall),
                _numberField(
                  _groundSpeedController,
                  ToolboxLocalizationKeys.calcDescentGroundSpeed.tr(context),
                  Icons.route,
                ),
                const SizedBox(height: AppThemeData.spacingSmall),
                _numberField(
                  _descentRateController,
                  ToolboxLocalizationKeys.calcDescentRate.tr(context),
                  Icons.trending_down,
                ),
                const SizedBox(height: AppThemeData.spacingSmall),
                _numberField(
                  _distanceToGoController,
                  ToolboxLocalizationKeys.calcDescentDistanceToGo.tr(context),
                  Icons.straighten,
                ),
                const SizedBox(height: AppThemeData.spacingMedium),
                ElevatedButton.icon(
                  onPressed: () => _calculateDescent(context),
                  icon: const Icon(Icons.calculate),
                  label: Text(
                    ToolboxLocalizationKeys.calcDescentButton.tr(context),
                  ),
                ),
                _resultCard(
                  ToolboxLocalizationKeys.calcDescentResultTitle.tr(context),
                  _descentResult,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppThemeData.spacingLarge),
          ToolboxSectionCard(
            title: ToolboxLocalizationKeys.calcFuelSectionTitle.tr(context),
            icon: Icons.local_gas_station,
            child: Column(
              children: [
                _numberField(
                  _distanceNmController,
                  ToolboxLocalizationKeys.calcFuelDistance.tr(context),
                  Icons.map,
                ),
                const SizedBox(height: AppThemeData.spacingSmall),
                _numberField(
                  _cruiseSpeedController,
                  ToolboxLocalizationKeys.calcFuelCruiseSpeed.tr(context),
                  Icons.airplanemode_active,
                ),
                const SizedBox(height: AppThemeData.spacingSmall),
                _numberField(
                  _burnRateController,
                  ToolboxLocalizationKeys.calcFuelBurnRate.tr(context),
                  Icons.local_fire_department,
                ),
                const SizedBox(height: AppThemeData.spacingSmall),
                _numberField(
                  _reserveMinController,
                  ToolboxLocalizationKeys.calcFuelReserveTime.tr(context),
                  Icons.timer,
                ),
                const SizedBox(height: AppThemeData.spacingSmall),
                _numberField(
                  _taxiFuelController,
                  ToolboxLocalizationKeys.calcFuelTaxiFuel.tr(context),
                  Icons.directions_car,
                ),
                const SizedBox(height: AppThemeData.spacingSmall),
                _numberField(
                  _extraPctController,
                  ToolboxLocalizationKeys.calcFuelExtraPct.tr(context),
                  Icons.add_circle_outline,
                ),
                const SizedBox(height: AppThemeData.spacingMedium),
                ElevatedButton.icon(
                  onPressed: () => _calculateFuel(context),
                  icon: const Icon(Icons.calculate),
                  label: Text(
                    ToolboxLocalizationKeys.calcFuelButton.tr(context),
                  ),
                ),
                _resultCard(
                  ToolboxLocalizationKeys.calcFuelResultTitle.tr(context),
                  _fuelResult,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
