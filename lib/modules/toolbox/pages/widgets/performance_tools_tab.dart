import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/services/localization_service.dart';
import '../../../../core/theme/app_theme_data.dart';
import '../../../http/models/http_exception.dart';
import '../../../http/services/middleware_http_service.dart';
import '../../localization/toolbox_localization_keys.dart';
import 'toolbox_section_card.dart';

class PerformanceToolsTab extends StatefulWidget {
  const PerformanceToolsTab({super.key});

  @override
  State<PerformanceToolsTab> createState() => _PerformanceToolsTabState();
}

class _PerformanceToolsTabState extends State<PerformanceToolsTab> {
  final MiddlewareHttpService _httpService = MiddlewareHttpService();
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
  bool _perfCalculating = false;
  String _selectedAircraft = '';
  List<_AircraftProfile> _aircraftProfiles = const [];
  bool _aircraftProfilesLoading = false;
  String _aircraftProfilesError = '';

  @override
  void initState() {
    super.initState();
    _loadAircraftProfiles();
  }

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

  _AircraftProfile? get _selectedAircraftProfile {
    for (final profile in _aircraftProfiles) {
      if (profile.id == _selectedAircraft) {
        return profile;
      }
    }
    return null;
  }

  String _aircraftName(BuildContext context, _AircraftProfile profile) {
    switch (profile.id) {
      case 'toliss_a320':
        return ToolboxLocalizationKeys.perfAircraftTolissA320.tr(context);
      case 'pmdg_737':
        return ToolboxLocalizationKeys.perfAircraftPmdgB737.tr(context);
      default:
        return profile.displayName;
    }
  }

  Future<void> _loadAircraftProfiles() async {
    if (!mounted) return;
    setState(() {
      _aircraftProfilesLoading = true;
      _aircraftProfilesError = '';
    });
    try {
      await _httpService.init();
      final response = await _httpService.getPerformanceAircraftProfiles();
      final body = response.decodedBody;
      if (body is! Map<String, dynamic>) {
        throw StateError('Invalid aircraft profile response');
      }
      final rawProfiles = body['profiles'];
      if (rawProfiles is! List) {
        throw StateError('Missing aircraft profiles');
      }
      final profiles = rawProfiles
          .whereType<Map>()
          .map(
            (item) =>
                _AircraftProfile.fromMap(item.map((k, v) => MapEntry('$k', v))),
          )
          .toList();
      if (profiles.isEmpty) {
        throw StateError('Aircraft profiles unavailable');
      }
      final selected = profiles.any((p) => p.id == _selectedAircraft)
          ? _selectedAircraft
          : profiles.first.id;
      final selectedProfile = profiles.firstWhere((p) => p.id == selected);
      if (!mounted) return;
      setState(() {
        _aircraftProfiles = profiles;
        _selectedAircraft = selected;
        _aircraftWeightController.text = selectedProfile.referenceWeight
            .toStringAsFixed(0);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _aircraftProfilesError = '$e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _aircraftProfilesLoading = false;
        });
      }
    }
  }

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

  String _runwayLevelText(BuildContext context, String code) {
    switch (code) {
      case 'high':
        return ToolboxLocalizationKeys.perfMarginHigh.tr(context);
      case 'acceptable':
        return ToolboxLocalizationKeys.perfAcceptable.tr(context);
      default:
        return ToolboxLocalizationKeys.perfNotMet.tr(context);
    }
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? 0;
  }

  Future<void> _calculatePerformance(BuildContext context) async {
    final profile = _selectedAircraftProfile;
    if (profile == null) {
      setState(() => _perfResult = 'Aircraft profiles unavailable');
      return;
    }
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
    setState(() {
      _perfCalculating = true;
    });
    try {
      final response = await _httpService.calculatePerformance(
        aircraftId: profile.id,
        runwayLength: runwayLength,
        pressureAltitude: pressureAltitude!,
        oat: oat!,
        headwind: headwind!,
        aircraftWeight: aircraftWeight,
        wetRunway: _wetRunway,
      );
      final body = response.decodedBody;
      if (body is! Map<String, dynamic>) {
        throw StateError('Invalid performance response');
      }
      final v1 = _toDouble(body['v1']);
      final vr = _toDouble(body['vr']);
      final v2 = _toDouble(body['v2']);
      final takeoffRequired = _toDouble(body['takeoff_required']);
      final landingRequired = _toDouble(body['landing_required']);
      final tkMargin = _toDouble(body['takeoff_margin']);
      final ldMargin = _toDouble(body['landing_margin']);
      final flexRecommended = body['flex_recommended'] == true;
      final flexTemperature = _toDouble(body['flex_temperature']);
      final runwayLevelCode = (body['runway_level_code'] ?? '').toString();
      final flexText = flexRecommended
          ? '${flexTemperature.toStringAsFixed(0)}°C'
          : ToolboxLocalizationKeys.perfFlexNotRecommended.tr(context);
      if (!mounted) return;
      setState(() {
        _perfResult =
            '${ToolboxLocalizationKeys.perfAircraftType.tr(context)} ${_aircraftName(context, profile)}\n'
            '${ToolboxLocalizationKeys.perfV1.tr(context)} ${v1.toStringAsFixed(0)} kt\n'
            '${ToolboxLocalizationKeys.perfVr.tr(context)} ${vr.toStringAsFixed(0)} kt\n'
            '${ToolboxLocalizationKeys.perfV2.tr(context)} ${v2.toStringAsFixed(0)} kt\n'
            '${ToolboxLocalizationKeys.perfFlexTemp.tr(context)} $flexText\n'
            '${ToolboxLocalizationKeys.perfTakeoffRequired.tr(context)} ${takeoffRequired.toStringAsFixed(0)} m\n'
            '${ToolboxLocalizationKeys.perfLandingRequired.tr(context)} ${landingRequired.toStringAsFixed(0)} m\n'
            '${ToolboxLocalizationKeys.perfTakeoffMargin.tr(context)} ${tkMargin.toStringAsFixed(0)} m\n'
            '${ToolboxLocalizationKeys.perfLandingMargin.tr(context)} ${ldMargin.toStringAsFixed(0)} m\n'
            '${ToolboxLocalizationKeys.perfRunwayLevel.tr(context)}：${_runwayLevelText(context, runwayLevelCode)}';
      });
    } on MiddlewareHttpException catch (e) {
      String message = e.message;
      final data = e.data;
      if (data is Map<String, dynamic>) {
        final errorCode = (data['error'] ?? '').toString().trim();
        if (errorCode == 'weight_out_of_range') {
          message =
              '${ToolboxLocalizationKeys.perfWeightRangeHint.tr(context)} ${profile.minWeight.toStringAsFixed(0)}-${profile.maxWeight.toStringAsFixed(0)} kg';
        } else if (errorCode == 'invalid_range') {
          message = ToolboxLocalizationKeys.commonInvalidRange.tr(context);
        }
      }
      if (!mounted) return;
      setState(() {
        _perfResult = message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _perfResult = '$e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _perfCalculating = false;
        });
      }
    }
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
                if (_aircraftProfilesLoading)
                  const Padding(
                    padding: EdgeInsets.only(bottom: AppThemeData.spacingSmall),
                    child: LinearProgressIndicator(),
                  ),
                if (_aircraftProfilesError.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(
                      bottom: AppThemeData.spacingSmall,
                    ),
                    child: Text(
                      _aircraftProfilesError,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                DropdownButtonFormField<String>(
                  initialValue: _selectedAircraft.isEmpty
                      ? null
                      : _selectedAircraft,
                  items: _aircraftProfiles
                      .map(
                        (profile) => DropdownMenuItem(
                          value: profile.id,
                          child: Text(_aircraftName(context, profile)),
                        ),
                      )
                      .toList(),
                  onChanged: _aircraftProfiles.isEmpty
                      ? null
                      : (value) {
                          if (value == null) return;
                          final profile = _aircraftProfiles.firstWhere(
                            (item) => item.id == value,
                          );
                          setState(() {
                            _selectedAircraft = value;
                            _aircraftWeightController.text = profile
                                .referenceWeight
                                .toStringAsFixed(0);
                          });
                        },
                  decoration: InputDecoration(
                    labelText: ToolboxLocalizationKeys.perfAircraftType.tr(
                      context,
                    ),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: AppThemeData.spacingSmall),
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
                  onPressed: _aircraftProfilesLoading || _perfCalculating
                      ? null
                      : () => _calculatePerformance(context),
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

class _AircraftProfile {
  final String id;
  final String sourceProfile;
  final String manufacturer;
  final String family;
  final String model;
  final double referenceWeight;
  final double minWeight;
  final double maxWeight;
  final double takeoffBaseDistance;
  final double landingBaseDistance;
  final double v1Base;
  final double vrBase;
  final double v2Base;
  final double speedPerTon;

  String get displayName {
    final raw = [
      manufacturer,
      model,
    ].where((e) => e.trim().isNotEmpty).join(' ');
    if (raw.trim().isNotEmpty) {
      return raw.trim();
    }
    final source = sourceProfile.trim();
    if (source.isNotEmpty) {
      return source;
    }
    return id;
  }

  const _AircraftProfile({
    required this.id,
    required this.sourceProfile,
    required this.manufacturer,
    required this.family,
    required this.model,
    required this.referenceWeight,
    required this.minWeight,
    required this.maxWeight,
    required this.takeoffBaseDistance,
    required this.landingBaseDistance,
    required this.v1Base,
    required this.vrBase,
    required this.v2Base,
    required this.speedPerTon,
  });

  factory _AircraftProfile.fromMap(Map<String, dynamic> map) {
    return _AircraftProfile(
      id: (map['id'] ?? '').toString().trim(),
      sourceProfile: (map['source_profile'] ?? '').toString().trim(),
      manufacturer: (map['manufacturer'] ?? '').toString().trim(),
      family: (map['family'] ?? '').toString().trim(),
      model: (map['model'] ?? '').toString().trim(),
      referenceWeight: _toDouble(map['reference_weight']),
      minWeight: _toDouble(map['min_weight']),
      maxWeight: _toDouble(map['max_weight']),
      takeoffBaseDistance: _toDouble(map['takeoff_base_distance']),
      landingBaseDistance: _toDouble(map['landing_base_distance']),
      v1Base: _toDouble(map['v1_base']),
      vrBase: _toDouble(map['vr_base']),
      v2Base: _toDouble(map['v2_base']),
      speedPerTon: _toDouble(map['speed_per_ton']),
    );
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? 0;
  }
}
