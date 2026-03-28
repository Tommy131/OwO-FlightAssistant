import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/services/localization_service.dart';
import '../../../../core/theme/app_theme_data.dart';
import '../../localization/toolbox_localization_keys.dart';
import 'toolbox_section_card.dart';

class PerformanceToolsTab extends StatefulWidget {
  const PerformanceToolsTab({super.key});

  @override
  State<PerformanceToolsTab> createState() => _PerformanceToolsTabState();
}

class _PerformanceToolsTabState extends State<PerformanceToolsTab> {
  final TextEditingController _bewController = TextEditingController(
    text: '42000',
  );
  final TextEditingController _bewArmController = TextEditingController(
    text: '15.0',
  );
  final TextEditingController _frontWeightController = TextEditingController(
    text: '420',
  );
  final TextEditingController _rearWeightController = TextEditingController(
    text: '280',
  );
  final TextEditingController _cargoWeightController = TextEditingController(
    text: '1200',
  );
  final TextEditingController _fuelWeightController = TextEditingController(
    text: '7800',
  );
  final TextEditingController _frontArmController = TextEditingController(
    text: '12.5',
  );
  final TextEditingController _rearArmController = TextEditingController(
    text: '18.2',
  );
  final TextEditingController _cargoArmController = TextEditingController(
    text: '24.5',
  );
  final TextEditingController _fuelArmController = TextEditingController(
    text: '14.0',
  );
  final TextEditingController _mtowController = TextEditingController(
    text: '73500',
  );
  final TextEditingController _cgForwardController = TextEditingController(
    text: '13.0',
  );
  final TextEditingController _cgAftController = TextEditingController(
    text: '17.5',
  );
  String _wbResult = '';

  final TextEditingController _runwayLengthController = TextEditingController(
    text: '3200',
  );
  final TextEditingController _pressureAltitudeController =
      TextEditingController(text: '1200');
  final TextEditingController _oatController = TextEditingController(
    text: '30',
  );
  final TextEditingController _headwindController = TextEditingController(
    text: '8',
  );
  final TextEditingController _aircraftWeightController = TextEditingController(
    text: '68000',
  );
  bool _wetRunway = false;
  String _perfResult = '';

  @override
  void dispose() {
    _bewController.dispose();
    _bewArmController.dispose();
    _frontWeightController.dispose();
    _rearWeightController.dispose();
    _cargoWeightController.dispose();
    _fuelWeightController.dispose();
    _frontArmController.dispose();
    _rearArmController.dispose();
    _cargoArmController.dispose();
    _fuelArmController.dispose();
    _mtowController.dispose();
    _cgForwardController.dispose();
    _cgAftController.dispose();
    _runwayLengthController.dispose();
    _pressureAltitudeController.dispose();
    _oatController.dispose();
    _headwindController.dispose();
    _aircraftWeightController.dispose();
    super.dispose();
  }

  double? _v(TextEditingController c) => double.tryParse(c.text.trim());

  void _calculateWeightBalance(BuildContext context) {
    final bew = _v(_bewController);
    final bewArm = _v(_bewArmController);
    final frontWeight = _v(_frontWeightController);
    final rearWeight = _v(_rearWeightController);
    final cargoWeight = _v(_cargoWeightController);
    final fuelWeight = _v(_fuelWeightController);
    final frontArm = _v(_frontArmController);
    final rearArm = _v(_rearArmController);
    final cargoArm = _v(_cargoArmController);
    final fuelArm = _v(_fuelArmController);
    final mtow = _v(_mtowController);
    final cgForward = _v(_cgForwardController);
    final cgAft = _v(_cgAftController);
    if ([
      bew,
      bewArm,
      frontWeight,
      rearWeight,
      cargoWeight,
      fuelWeight,
      frontArm,
      rearArm,
      cargoArm,
      fuelArm,
      mtow,
      cgForward,
      cgAft,
    ].contains(null)) {
      setState(
        () =>
            _wbResult = ToolboxLocalizationKeys.commonInvalidNumber.tr(context),
      );
      return;
    }
    final totalWeight =
        bew! + frontWeight! + rearWeight! + cargoWeight! + fuelWeight!;
    final totalMoment =
        bew * bewArm! +
        frontWeight * frontArm! +
        rearWeight * rearArm! +
        cargoWeight * cargoArm! +
        fuelWeight * fuelArm!;
    final cg = totalMoment / totalWeight;
    final withinWeight = totalWeight <= mtow!;
    final withinCg = cg >= cgForward! && cg <= cgAft!;
    final status = withinWeight && withinCg
        ? ToolboxLocalizationKeys.perfDispatchable.tr(context)
        : ToolboxLocalizationKeys.perfOutOfLimit.tr(context);
    setState(() {
      _wbResult =
          '${ToolboxLocalizationKeys.perfWbTotalWeight.tr(context)} ${totalWeight.toStringAsFixed(0)} kg\n'
          '${ToolboxLocalizationKeys.perfWbCgPosition.tr(context)} ${cg.toStringAsFixed(2)}\n'
          '${ToolboxLocalizationKeys.perfWbWeightLimit.tr(context)} ${withinWeight ? ToolboxLocalizationKeys.perfSatisfied.tr(context) : ToolboxLocalizationKeys.perfExceeded.tr(context)}\n'
          '${ToolboxLocalizationKeys.perfWbCgLimit.tr(context)} ${withinCg ? ToolboxLocalizationKeys.perfSatisfied.tr(context) : ToolboxLocalizationKeys.perfExceeded.tr(context)}\n'
          '${ToolboxLocalizationKeys.perfWbStatus.tr(context)}：$status';
    });
  }

  void _calculatePerformance(BuildContext context) {
    final runwayLength = _v(_runwayLengthController);
    final pressureAltitude = _v(_pressureAltitudeController);
    final oat = _v(_oatController);
    final headwind = _v(_headwindController);
    final aircraftWeight = _v(_aircraftWeightController);
    if ([
      runwayLength,
      pressureAltitude,
      oat,
      headwind,
      aircraftWeight,
    ].contains(null)) {
      setState(
        () => _perfResult = ToolboxLocalizationKeys.commonInvalidNumber.tr(
          context,
        ),
      );
      return;
    }
    if (runwayLength! <= 0 || aircraftWeight! <= 0) {
      setState(
        () => _perfResult = ToolboxLocalizationKeys.commonInvalidRange.tr(
          context,
        ),
      );
      return;
    }
    final weightRatio = aircraftWeight / 60000;
    final takeoffBase = 1200 * math.pow(weightRatio, 1.05);
    final landingBase = 1000 * math.pow(weightRatio, 1.03);
    final altFactor = 1 + (pressureAltitude! / 10000) * 0.12;
    final tempFactor = 1 + math.max(oat! - 15, -30) / 100 * 0.1;
    final takeoffWindFactor = (1 - headwind! * 0.01).clamp(0.75, 1.4);
    final landingWindFactor = (1 - headwind * 0.008).clamp(0.78, 1.4);
    final wetFactor = _wetRunway ? 1.15 : 1.0;
    final takeoffRequired =
        takeoffBase * altFactor * tempFactor * takeoffWindFactor * wetFactor;
    final landingRequired =
        landingBase * altFactor * tempFactor * landingWindFactor * wetFactor;
    final tkMargin = runwayLength - takeoffRequired;
    final ldMargin = runwayLength - landingRequired;
    final level = tkMargin >= 300 && ldMargin >= 300
        ? ToolboxLocalizationKeys.perfMarginHigh.tr(context)
        : tkMargin >= 0 && ldMargin >= 0
        ? ToolboxLocalizationKeys.perfAcceptable.tr(context)
        : ToolboxLocalizationKeys.perfNotMet.tr(context);
    setState(() {
      _perfResult =
          '${ToolboxLocalizationKeys.perfTakeoffRequired.tr(context)} ${takeoffRequired.toStringAsFixed(0)} m\n'
          '${ToolboxLocalizationKeys.perfLandingRequired.tr(context)} ${landingRequired.toStringAsFixed(0)} m\n'
          '${ToolboxLocalizationKeys.perfTakeoffMargin.tr(context)} ${tkMargin.toStringAsFixed(0)} m\n'
          '${ToolboxLocalizationKeys.perfLandingMargin.tr(context)} ${ldMargin.toStringAsFixed(0)} m\n'
          '${ToolboxLocalizationKeys.perfRunwayLevel.tr(context)}：$level';
    });
  }

  Widget _field(TextEditingController c, String label, IconData icon) {
    return ToolboxTextField(
      label: label,
      hint: ToolboxLocalizationKeys.commonInputHint.tr(context),
      icon: icon,
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
    );
  }

  Widget _result(String title, String value) {
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
          SelectableText(value),
        ],
      ),
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
            title: ToolboxLocalizationKeys.perfWbSectionTitle.tr(context),
            icon: Icons.balance,
            child: Column(
              children: [
                _field(
                  _bewController,
                  ToolboxLocalizationKeys.perfBew.tr(context),
                  Icons.inventory_2,
                ),
                const SizedBox(height: AppThemeData.spacingSmall),
                _field(
                  _bewArmController,
                  ToolboxLocalizationKeys.perfBewArm.tr(context),
                  Icons.straighten,
                ),
                const SizedBox(height: AppThemeData.spacingSmall),
                _field(
                  _frontWeightController,
                  ToolboxLocalizationKeys.perfFrontWeight.tr(context),
                  Icons.airline_seat_recline_extra,
                ),
                const SizedBox(height: AppThemeData.spacingSmall),
                _field(
                  _rearWeightController,
                  ToolboxLocalizationKeys.perfRearWeight.tr(context),
                  Icons.airline_seat_legroom_extra,
                ),
                const SizedBox(height: AppThemeData.spacingSmall),
                _field(
                  _cargoWeightController,
                  ToolboxLocalizationKeys.perfCargoWeight.tr(context),
                  Icons.work,
                ),
                const SizedBox(height: AppThemeData.spacingSmall),
                _field(
                  _fuelWeightController,
                  ToolboxLocalizationKeys.perfFuelWeight.tr(context),
                  Icons.local_gas_station,
                ),
                const SizedBox(height: AppThemeData.spacingSmall),
                _field(
                  _frontArmController,
                  ToolboxLocalizationKeys.perfFrontArm.tr(context),
                  Icons.pin_drop,
                ),
                const SizedBox(height: AppThemeData.spacingSmall),
                _field(
                  _rearArmController,
                  ToolboxLocalizationKeys.perfRearArm.tr(context),
                  Icons.pin_drop_outlined,
                ),
                const SizedBox(height: AppThemeData.spacingSmall),
                _field(
                  _cargoArmController,
                  ToolboxLocalizationKeys.perfCargoArm.tr(context),
                  Icons.pin_drop,
                ),
                const SizedBox(height: AppThemeData.spacingSmall),
                _field(
                  _fuelArmController,
                  ToolboxLocalizationKeys.perfFuelArm.tr(context),
                  Icons.pin_drop,
                ),
                const SizedBox(height: AppThemeData.spacingSmall),
                _field(
                  _mtowController,
                  ToolboxLocalizationKeys.perfMtow.tr(context),
                  Icons.monitor_weight,
                ),
                const SizedBox(height: AppThemeData.spacingSmall),
                _field(
                  _cgForwardController,
                  ToolboxLocalizationKeys.perfCgForward.tr(context),
                  Icons.keyboard_double_arrow_left,
                ),
                const SizedBox(height: AppThemeData.spacingSmall),
                _field(
                  _cgAftController,
                  ToolboxLocalizationKeys.perfCgAft.tr(context),
                  Icons.keyboard_double_arrow_right,
                ),
                const SizedBox(height: AppThemeData.spacingMedium),
                ElevatedButton.icon(
                  onPressed: () => _calculateWeightBalance(context),
                  icon: const Icon(Icons.calculate),
                  label: Text(ToolboxLocalizationKeys.perfWbButton.tr(context)),
                ),
                _result(
                  ToolboxLocalizationKeys.perfWbResultTitle.tr(context),
                  _wbResult,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppThemeData.spacingLarge),
          ToolboxSectionCard(
            title: ToolboxLocalizationKeys.perfRunwaySectionTitle.tr(context),
            icon: Icons.flight_land,
            child: Column(
              children: [
                _field(
                  _runwayLengthController,
                  ToolboxLocalizationKeys.perfRunwayLength.tr(context),
                  Icons.swap_horiz,
                ),
                const SizedBox(height: AppThemeData.spacingSmall),
                _field(
                  _pressureAltitudeController,
                  ToolboxLocalizationKeys.perfPressureAltitude.tr(context),
                  Icons.terrain,
                ),
                const SizedBox(height: AppThemeData.spacingSmall),
                _field(
                  _oatController,
                  ToolboxLocalizationKeys.perfOat.tr(context),
                  Icons.thermostat,
                ),
                const SizedBox(height: AppThemeData.spacingSmall),
                _field(
                  _headwindController,
                  ToolboxLocalizationKeys.perfHeadwind.tr(context),
                  Icons.air,
                ),
                const SizedBox(height: AppThemeData.spacingSmall),
                _field(
                  _aircraftWeightController,
                  ToolboxLocalizationKeys.perfAircraftWeight.tr(context),
                  Icons.monitor_weight_outlined,
                ),
                const SizedBox(height: AppThemeData.spacingSmall),
                SwitchListTile(
                  value: _wetRunway,
                  onChanged: (value) => setState(() => _wetRunway = value),
                  title: Text(
                    ToolboxLocalizationKeys.perfWetRunway.tr(context),
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: AppThemeData.spacingMedium),
                ElevatedButton.icon(
                  onPressed: () => _calculatePerformance(context),
                  icon: const Icon(Icons.calculate),
                  label: Text(
                    ToolboxLocalizationKeys.perfRunwayButton.tr(context),
                  ),
                ),
                _result(
                  ToolboxLocalizationKeys.perfRunwayResultTitle.tr(context),
                  _perfResult,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
