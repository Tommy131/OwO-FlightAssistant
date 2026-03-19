import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/module_registry/settings_page/settings_page_item.dart';
import '../../../core/services/localization_service.dart';
import '../../../core/theme/app_theme_data.dart';
import '../../../core/widgets/common/snack_bar.dart';
import '../../home/providers/home_provider.dart';
import '../localization/map_localization_keys.dart';
import '../models/map_models.dart';
import '../providers/map_provider.dart';

class MapModuleSettingsPageItem extends SettingsPageItem {
  @override
  String get id => 'map_module_settings';

  @override
  String getTitle(BuildContext context) =>
      MapLocalizationKeys.moduleSettings.tr(context);

  @override
  IconData get icon => Icons.map_outlined;

  @override
  int get priority => 70;

  @override
  String getDescription(BuildContext context) =>
      MapLocalizationKeys.moduleSettingsDesc.tr(context);

  @override
  Widget build(BuildContext context) {
    return const _MapModuleSettingsView();
  }
}

class _MapModuleSettingsView extends StatefulWidget {
  const _MapModuleSettingsView();

  @override
  State<_MapModuleSettingsView> createState() => _MapModuleSettingsViewState();
}

class _MapModuleSettingsViewState extends State<_MapModuleSettingsView> {
  final TextEditingController _homeAirportIcaoController =
      TextEditingController();
  final TextEditingController _climbWarningThresholdController =
      TextEditingController();
  final TextEditingController _climbDangerThresholdController =
      TextEditingController();
  final TextEditingController _descentWarningThresholdController =
      TextEditingController();
  final TextEditingController _descentDangerThresholdController =
      TextEditingController();
  final FocusNode _climbWarningFocusNode = FocusNode();
  final FocusNode _climbDangerFocusNode = FocusNode();
  final FocusNode _descentWarningFocusNode = FocusNode();
  final FocusNode _descentDangerFocusNode = FocusNode();
  Timer? _homeAirportSearchDebounce;
  List<MapAirportMarker> _homeAirportSuggestions = const [];
  bool _isHomeAirportSaving = false;
  bool _isAlertSettingsSaving = false;
  bool _isHomeAirportSearching = false;
  int _homeAirportSearchToken = 0;
  String? _alertThresholdSignature;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_refreshBackendHealth());
    });
  }

  @override
  void dispose() {
    _homeAirportSearchDebounce?.cancel();
    _homeAirportIcaoController.dispose();
    _climbWarningThresholdController.dispose();
    _climbDangerThresholdController.dispose();
    _descentWarningThresholdController.dispose();
    _descentDangerThresholdController.dispose();
    _climbWarningFocusNode.dispose();
    _climbDangerFocusNode.dispose();
    _descentWarningFocusNode.dispose();
    _descentDangerFocusNode.dispose();
    super.dispose();
  }

  Future<void> _refreshBackendHealth() async {
    final homeProvider = context.read<HomeProvider?>();
    await homeProvider?.refreshBackendHealth();
  }

  Future<void> _saveHomeAirport(BuildContext context) async {
    final mapProvider = context.read<MapProvider?>();
    final homeProvider = context.read<HomeProvider?>();
    if (mapProvider == null) {
      return;
    }
    if (homeProvider?.isBackendReachable != true) {
      return;
    }
    final icao = _homeAirportIcaoController.text.trim().toUpperCase();
    if (icao.isEmpty) {
      SnackBarHelper.showError(
        context,
        MapLocalizationKeys.homeAirportNotFound.tr(context),
      );
      return;
    }
    setState(() {
      _isHomeAirportSaving = true;
    });
    try {
      final result = await mapProvider.searchAirports(icao);
      MapAirportMarker? target;
      for (final airport in result) {
        if (airport.code.toUpperCase() == icao) {
          target = airport;
          break;
        }
      }
      target ??= result.isNotEmpty ? result.first : null;
      if (target == null) {
        if (!mounted) {
          return;
        }
        SnackBarHelper.showError(
          context,
          MapLocalizationKeys.homeAirportNotFound.tr(context),
        );
        return;
      }
      await mapProvider.setHomeAirport(target);
      if (!mounted) {
        return;
      }
      setState(() {
        _homeAirportIcaoController.text = target!.code;
      });
      SnackBarHelper.showSuccess(
        context,
        MapLocalizationKeys.homeAirportSaved.tr(context),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isHomeAirportSaving = false;
        });
      }
    }
  }

  Future<void> _clearHomeAirport(BuildContext context) async {
    final mapProvider = context.read<MapProvider?>();
    final homeProvider = context.read<HomeProvider?>();
    if (mapProvider == null) {
      return;
    }
    if (homeProvider?.isBackendReachable != true) {
      return;
    }
    await mapProvider.clearHomeAirport();
    if (!mounted) {
      return;
    }
    setState(() {
      _homeAirportIcaoController.clear();
      _homeAirportSuggestions = const [];
      _isHomeAirportSearching = false;
    });
    SnackBarHelper.showSuccess(
      context,
      MapLocalizationKeys.homeAirportCleared.tr(context),
    );
  }

  Future<void> _saveAutoHudTimerEnabled(
    BuildContext context,
    bool value,
  ) async {
    final mapProvider = context.read<MapProvider?>();
    if (mapProvider == null) {
      return;
    }
    await mapProvider.setAutoHudTimerEnabled(value);
    if (!mounted) {
      return;
    }
    SnackBarHelper.showSuccess(
      context,
      MapLocalizationKeys.timerSettingsSaved.tr(context),
    );
  }

  Future<void> _saveAutoTimerStartMode(
    BuildContext context,
    MapAutoTimerStartMode mode,
  ) async {
    final mapProvider = context.read<MapProvider?>();
    if (mapProvider == null) {
      return;
    }
    await mapProvider.setAutoTimerStartMode(mode);
    if (!mounted) {
      return;
    }
    SnackBarHelper.showSuccess(
      context,
      MapLocalizationKeys.timerSettingsSaved.tr(context),
    );
  }

  Future<void> _saveAutoTimerStopMode(
    BuildContext context,
    MapAutoTimerStopMode mode,
  ) async {
    final mapProvider = context.read<MapProvider?>();
    if (mapProvider == null) {
      return;
    }
    await mapProvider.setAutoTimerStopMode(mode);
    if (!mounted) {
      return;
    }
    SnackBarHelper.showSuccess(
      context,
      MapLocalizationKeys.timerSettingsSaved.tr(context),
    );
  }

  void _syncAlertThresholdControllers(MapProvider mapProvider) {
    final hasFocusedField =
        _climbWarningFocusNode.hasFocus ||
        _climbDangerFocusNode.hasFocus ||
        _descentWarningFocusNode.hasFocus ||
        _descentDangerFocusNode.hasFocus;
    if (hasFocusedField || _isAlertSettingsSaving) {
      return;
    }
    final signature =
        '${mapProvider.climbRateWarningFpm}|${mapProvider.climbRateDangerFpm}|${mapProvider.descentRateWarningFpm}|${mapProvider.descentRateDangerFpm}';
    if (signature == _alertThresholdSignature) {
      return;
    }
    _climbWarningThresholdController.text =
        '${mapProvider.climbRateWarningFpm}';
    _climbDangerThresholdController.text = '${mapProvider.climbRateDangerFpm}';
    _descentWarningThresholdController.text =
        '${mapProvider.descentRateWarningFpm}';
    _descentDangerThresholdController.text =
        '${mapProvider.descentRateDangerFpm}';
    _alertThresholdSignature = signature;
  }

  Future<void> _saveAlertThresholdSettings(
    BuildContext context,
    MapProvider mapProvider,
  ) async {
    final climbWarning = int.tryParse(
      _climbWarningThresholdController.text.trim(),
    );
    final climbDanger = int.tryParse(
      _climbDangerThresholdController.text.trim(),
    );
    final descentWarning = int.tryParse(
      _descentWarningThresholdController.text.trim(),
    );
    final descentDanger = int.tryParse(
      _descentDangerThresholdController.text.trim(),
    );
    final isValid =
        climbWarning != null &&
        climbDanger != null &&
        descentWarning != null &&
        descentDanger != null &&
        climbWarning > 0 &&
        climbDanger > climbWarning &&
        descentWarning > 0 &&
        descentDanger > descentWarning;
    if (!isValid) {
      SnackBarHelper.showError(
        context,
        MapLocalizationKeys.invalidAlertThreshold.tr(context),
      );
      return;
    }
    setState(() {
      _isAlertSettingsSaving = true;
    });
    try {
      await mapProvider.setVerticalRateThresholds(
        climbWarningFpm: climbWarning,
        climbDangerFpm: climbDanger,
        descentWarningFpm: descentWarning,
        descentDangerFpm: descentDanger,
      );
      if (!mounted) {
        return;
      }
      _syncAlertThresholdControllers(mapProvider);
      SnackBarHelper.showSuccess(
        context,
        MapLocalizationKeys.alertSettingsSaved.tr(context),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isAlertSettingsSaving = false;
        });
      }
    }
  }

  void _onHomeAirportInputChanged(String value) {
    _homeAirportSearchDebounce?.cancel();
    final query = value.trim();
    if (query.isEmpty) {
      setState(() {
        _homeAirportSuggestions = const [];
        _isHomeAirportSearching = false;
      });
      return;
    }
    setState(() {
      _isHomeAirportSearching = true;
    });
    final token = ++_homeAirportSearchToken;
    _homeAirportSearchDebounce = Timer(const Duration(milliseconds: 260), () {
      unawaited(_fetchHomeAirportSuggestions(query, token));
    });
  }

  Future<void> _fetchHomeAirportSuggestions(String query, int token) async {
    final mapProvider = context.read<MapProvider?>();
    if (mapProvider == null) {
      if (!mounted || token != _homeAirportSearchToken) {
        return;
      }
      setState(() {
        _homeAirportSuggestions = const [];
        _isHomeAirportSearching = false;
      });
      return;
    }
    final results = await mapProvider.searchAirports(query);
    if (!mounted || token != _homeAirportSearchToken) {
      return;
    }
    final normalizedQuery = query.toUpperCase();
    final deduped = <String, MapAirportMarker>{};
    for (final airport in results) {
      final key = airport.code.trim().toUpperCase();
      if (key.isEmpty || deduped.containsKey(key)) {
        continue;
      }
      deduped[key] = airport;
    }
    final suggestions = deduped.values.toList()
      ..sort((a, b) {
        final aCode = a.code.trim().toUpperCase();
        final bCode = b.code.trim().toUpperCase();
        final aPrefix = aCode.startsWith(normalizedQuery);
        final bPrefix = bCode.startsWith(normalizedQuery);
        if (aPrefix != bPrefix) {
          return aPrefix ? -1 : 1;
        }
        return aCode.compareTo(bCode);
      });
    setState(() {
      _homeAirportSuggestions = suggestions.take(8).toList();
      _isHomeAirportSearching = false;
    });
  }

  void _selectHomeAirportSuggestion(MapAirportMarker airport) {
    final code = airport.code.trim().toUpperCase();
    _homeAirportSearchDebounce?.cancel();
    _homeAirportSearchToken += 1;
    setState(() {
      _homeAirportIcaoController.text = code;
      _homeAirportIcaoController.selection = TextSelection.collapsed(
        offset: code.length,
      );
      _homeAirportSuggestions = const [];
      _isHomeAirportSearching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Consumer2<MapProvider, HomeProvider>(
      builder: (context, mapProvider, homeProvider, child) {
        _syncAlertThresholdControllers(mapProvider);
        if (_homeAirportIcaoController.text.trim().isEmpty &&
            mapProvider.homeAirport != null) {
          _homeAirportIcaoController.text = mapProvider.homeAirport!.code;
        }
        final canConfigureHomeAirport = homeProvider.isBackendReachable;
        final homeAirport = mapProvider.homeAirport;
        final homeAirportDisplay = homeAirport == null
            ? '-'
            : '${homeAirport.code} (${homeAirport.position.latitude.toStringAsFixed(4)}, ${homeAirport.position.longitude.toStringAsFixed(4)})';
        final showHomeAirportSuggestions =
            canConfigureHomeAirport &&
            _homeAirportIcaoController.text.trim().isNotEmpty &&
            (_isHomeAirportSearching || _homeAirportSuggestions.isNotEmpty);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                _SectionCard(
                  icon: Icons.home_work_outlined,
                  title: MapLocalizationKeys.homeAirportSectionTitle.tr(
                    context,
                  ),
                  subtitle: MapLocalizationKeys.homeAirportSectionDesc.tr(
                    context,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _homeAirportIcaoController,
                        enabled:
                            canConfigureHomeAirport && !_isHomeAirportSaving,
                        textCapitalization: TextCapitalization.characters,
                        maxLength: 6,
                        decoration: InputDecoration(
                          labelText: MapLocalizationKeys.homeAirportIcaoLabel
                              .tr(context),
                          hintText: MapLocalizationKeys.homeAirportIcaoHint.tr(
                            context,
                          ),
                          prefixIcon: const Icon(Icons.flight_land_rounded),
                          counterText: '',
                        ),
                        onChanged: _onHomeAirportInputChanged,
                      ),
                      if (showHomeAirportSuggestions) ...[
                        const SizedBox(height: AppThemeData.spacingSmall),
                        Container(
                          constraints: const BoxConstraints(maxHeight: 220),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(
                              AppThemeData.borderRadiusSmall,
                            ),
                            border: Border.all(
                              color: theme.colorScheme.outline.withValues(
                                alpha: 0.22,
                              ),
                            ),
                          ),
                          child: _isHomeAirportSearching
                              ? const Padding(
                                  padding: EdgeInsets.all(14),
                                  child: Center(
                                    child: SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  ),
                                )
                              : ListView.separated(
                                  shrinkWrap: true,
                                  itemCount: _homeAirportSuggestions.length,
                                  separatorBuilder: (context, index) =>
                                      const Divider(height: 1),
                                  itemBuilder: (context, index) {
                                    final airport =
                                        _homeAirportSuggestions[index];
                                    return ListTile(
                                      dense: true,
                                      title: Text(
                                        airport.code,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                      subtitle: Text(
                                        airport.name ?? '',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      trailing: Text(
                                        '${airport.position.latitude.toStringAsFixed(2)}, ${airport.position.longitude.toStringAsFixed(2)}',
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                              color: theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                      ),
                                      onTap: () {
                                        _selectHomeAirportSuggestion(airport);
                                      },
                                    );
                                  },
                                ),
                        ),
                      ],
                      const SizedBox(height: AppThemeData.spacingSmall),
                      Text(
                        MapLocalizationKeys.homeAirportCurrent
                            .tr(context)
                            .replaceFirst('{value}', homeAirportDisplay),
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: AppThemeData.spacingMedium),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed:
                                  !canConfigureHomeAirport ||
                                      _isHomeAirportSaving
                                  ? null
                                  : () => _saveHomeAirport(context),
                              icon: _isHomeAirportSaving
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.save_outlined, size: 18),
                              label: Text(
                                _isHomeAirportSaving
                                    ? MapLocalizationKeys.saving.tr(context)
                                    : MapLocalizationKeys.saveButton.tr(
                                        context,
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppThemeData.spacingSmall),
                          OutlinedButton.icon(
                            onPressed:
                                !canConfigureHomeAirport ||
                                    homeAirport == null ||
                                    _isHomeAirportSaving
                                ? null
                                : () => _clearHomeAirport(context),
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            label: Text(
                              MapLocalizationKeys.clearButton.tr(context),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (!canConfigureHomeAirport)
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(
                        AppThemeData.borderRadiusMedium,
                      ),
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                        child: Container(
                          color: theme.colorScheme.surface.withValues(
                            alpha: 0.72,
                          ),
                          padding: const EdgeInsets.all(
                            AppThemeData.spacingMedium,
                          ),
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.error,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  MapLocalizationKeys
                                      .homeAirportServiceUnavailableTag
                                      .tr(context),
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.onError,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(height: AppThemeData.spacingSmall),
                              Text(
                                MapLocalizationKeys
                                    .homeAirportServiceUnavailableHint
                                    .tr(context),
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppThemeData.spacingMedium),
            _SectionCard(
              icon: Icons.warning_amber_rounded,
              title: MapLocalizationKeys.alertSettingsSectionTitle.tr(context),
              subtitle: MapLocalizationKeys.alertSettingsSectionDesc.tr(
                context,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    value: mapProvider.alertsEnabled,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      MapLocalizationKeys.alertSettingsEnableAll.tr(context),
                    ),
                    onChanged: (value) {
                      unawaited(mapProvider.setAlertsEnabled(value));
                    },
                  ),
                  const SizedBox(height: 4),
                  Text(
                    MapLocalizationKeys.alertSettingsSelectAlerts.tr(context),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: AppThemeData.spacingSmall,
                    runSpacing: AppThemeData.spacingSmall,
                    children: mapProvider.configurableAlertIds.map((alertId) {
                      final labelKey =
                          mapProvider.alertMessageKeyForId(alertId) ?? alertId;
                      final selected = mapProvider.isAlertEnabled(alertId);
                      return _AlertToggleTag(
                        label: labelKey.tr(context),
                        selected: selected,
                        enabled: mapProvider.alertsEnabled,
                        onTap: () {
                          unawaited(
                            mapProvider.setAlertEnabled(alertId, !selected),
                          );
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: AppThemeData.spacingSmall),
                  Text(
                    MapLocalizationKeys.alertSettingsThresholdTitle.tr(context),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppThemeData.spacingSmall),
                  TextField(
                    controller: _climbWarningThresholdController,
                    focusNode: _climbWarningFocusNode,
                    enabled:
                        mapProvider.alertsEnabled && !_isAlertSettingsSaving,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: MapLocalizationKeys
                          .alertThresholdClimbWarningLabel
                          .tr(context),
                      prefixIcon: const Icon(Icons.trending_up_rounded),
                    ),
                  ),
                  const SizedBox(height: AppThemeData.spacingSmall),
                  TextField(
                    controller: _climbDangerThresholdController,
                    focusNode: _climbDangerFocusNode,
                    enabled:
                        mapProvider.alertsEnabled && !_isAlertSettingsSaving,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: MapLocalizationKeys
                          .alertThresholdClimbDangerLabel
                          .tr(context),
                      prefixIcon: const Icon(Icons.trending_up_rounded),
                    ),
                  ),
                  const SizedBox(height: AppThemeData.spacingSmall),
                  TextField(
                    controller: _descentWarningThresholdController,
                    focusNode: _descentWarningFocusNode,
                    enabled:
                        mapProvider.alertsEnabled && !_isAlertSettingsSaving,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: MapLocalizationKeys
                          .alertThresholdDescentWarningLabel
                          .tr(context),
                      prefixIcon: const Icon(Icons.trending_down_rounded),
                    ),
                  ),
                  const SizedBox(height: AppThemeData.spacingSmall),
                  TextField(
                    controller: _descentDangerThresholdController,
                    focusNode: _descentDangerFocusNode,
                    enabled:
                        mapProvider.alertsEnabled && !_isAlertSettingsSaving,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: MapLocalizationKeys
                          .alertThresholdDescentDangerLabel
                          .tr(context),
                      prefixIcon: const Icon(Icons.trending_down_rounded),
                    ),
                  ),
                  const SizedBox(height: AppThemeData.spacingSmall),
                  Text(
                    MapLocalizationKeys.alertThresholdHint.tr(context),
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppThemeData.spacingMedium),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed:
                          mapProvider.alertsEnabled && !_isAlertSettingsSaving
                          ? () => _saveAlertThresholdSettings(
                              context,
                              mapProvider,
                            )
                          : null,
                      icon: _isAlertSettingsSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined, size: 18),
                      label: Text(
                        _isAlertSettingsSaving
                            ? MapLocalizationKeys.saving.tr(context)
                            : MapLocalizationKeys.saveButton.tr(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppThemeData.spacingMedium),
            _SectionCard(
              icon: Icons.timer_outlined,
              title: MapLocalizationKeys.timerSectionTitle.tr(context),
              subtitle: MapLocalizationKeys.timerSectionDesc.tr(context),
              child: Column(
                children: [
                  SwitchListTile(
                    value: mapProvider.autoHudTimerEnabled,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      MapLocalizationKeys.timerAutoEnable.tr(context),
                    ),
                    onChanged: (value) {
                      unawaited(_saveAutoHudTimerEnabled(context, value));
                    },
                  ),
                  const SizedBox(height: 8),
                  _GroupTitle(
                    title: MapLocalizationKeys.timerStartCondition.tr(context),
                  ),
                  const SizedBox(height: 8),
                  _SelectionTile(
                    selected:
                        mapProvider.autoTimerStartMode ==
                        MapAutoTimerStartMode.runwayMovement,
                    label: MapLocalizationKeys.timerStartRunwayMovement.tr(
                      context,
                    ),
                    icon: Icons.flight_takeoff_rounded,
                    onTap: () {
                      unawaited(
                        _saveAutoTimerStartMode(
                          context,
                          MapAutoTimerStartMode.runwayMovement,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  _SelectionTile(
                    selected:
                        mapProvider.autoTimerStartMode ==
                        MapAutoTimerStartMode.pushback,
                    label: MapLocalizationKeys.timerStartPushback.tr(context),
                    icon: Icons.push_pin_outlined,
                    onTap: () {
                      unawaited(
                        _saveAutoTimerStartMode(
                          context,
                          MapAutoTimerStartMode.pushback,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  _SelectionTile(
                    selected:
                        mapProvider.autoTimerStartMode ==
                        MapAutoTimerStartMode.anyMovement,
                    label: MapLocalizationKeys.timerStartAnyMovement.tr(
                      context,
                    ),
                    icon: Icons.directions_run_rounded,
                    onTap: () {
                      unawaited(
                        _saveAutoTimerStartMode(
                          context,
                          MapAutoTimerStartMode.anyMovement,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  _GroupTitle(
                    title: MapLocalizationKeys.timerStopCondition.tr(context),
                  ),
                  const SizedBox(height: 8),
                  _SelectionTile(
                    selected:
                        mapProvider.autoTimerStopMode ==
                        MapAutoTimerStopMode.stableLanding,
                    label: MapLocalizationKeys.timerStopStableLanding.tr(
                      context,
                    ),
                    icon: Icons.flight_land_rounded,
                    onTap: () {
                      unawaited(
                        _saveAutoTimerStopMode(
                          context,
                          MapAutoTimerStopMode.stableLanding,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  _SelectionTile(
                    selected:
                        mapProvider.autoTimerStopMode ==
                        MapAutoTimerStopMode.runwayExitAfterLanding,
                    label: MapLocalizationKeys.timerStopRunwayExit.tr(context),
                    icon: Icons.turn_right_rounded,
                    onTap: () {
                      unawaited(
                        _saveAutoTimerStopMode(
                          context,
                          MapAutoTimerStopMode.runwayExitAfterLanding,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  _SelectionTile(
                    selected:
                        mapProvider.autoTimerStopMode ==
                        MapAutoTimerStopMode.parkingArrival,
                    label: MapLocalizationKeys.timerStopParkingArrival.tr(
                      context,
                    ),
                    icon: Icons.local_parking_rounded,
                    onTap: () {
                      unawaited(
                        _saveAutoTimerStopMode(
                          context,
                          MapAutoTimerStopMode.parkingArrival,
                        ),
                      );
                    },
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

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppThemeData.spacingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(
                      AppThemeData.borderRadiusSmall,
                    ),
                  ),
                  child: Icon(icon, color: theme.colorScheme.primary, size: 20),
                ),
                const SizedBox(width: AppThemeData.spacingSmall),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(subtitle, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppThemeData.spacingMedium),
            child,
          ],
        ),
      ),
    );
  }
}

class _AlertToggleTag extends StatelessWidget {
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _AlertToggleTag({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeColor = theme.colorScheme.primary;
    final borderColor = selected
        ? activeColor
        : theme.colorScheme.outline.withValues(alpha: 0.5);
    final textColor = enabled
        ? (selected ? activeColor : theme.colorScheme.onSurface)
        : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.65);
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: borderColor),
          color: selected
              ? activeColor.withValues(alpha: enabled ? 0.12 : 0.06)
              : Colors.transparent,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 16,
              color: textColor,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: textColor,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupTitle extends StatelessWidget {
  final String title;

  const _GroupTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
    );
  }
}

class _SelectionTile extends StatelessWidget {
  final bool selected;
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _SelectionTile({
    required this.selected,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = selected
        ? theme.colorScheme.primary
        : theme.colorScheme.outlineVariant;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppThemeData.borderRadiusSmall),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(
          horizontal: AppThemeData.spacingSmall,
          vertical: AppThemeData.spacingSmall,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppThemeData.borderRadiusSmall),
          border: Border.all(color: borderColor),
          color: selected
              ? theme.colorScheme.primary.withValues(alpha: 0.06)
              : Colors.transparent,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? theme.colorScheme.primary : null,
            ),
            const SizedBox(width: AppThemeData.spacingSmall),
            Expanded(child: Text(label)),
            Icon(
              selected ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 18,
              color: selected ? theme.colorScheme.primary : null,
            ),
          ],
        ),
      ),
    );
  }
}
