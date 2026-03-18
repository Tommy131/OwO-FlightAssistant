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
  final TextEditingController _flightDataIntervalController =
      TextEditingController();
  int _currentFlightDataIntervalMs =
      MiddlewareHomeDataAdapter.defaultPollIntervalMs;
  bool _isFlightDataIntervalSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadFlightDataInterval();
    });
  }

  @override
  void dispose() {
    _flightDataIntervalController.dispose();
    super.dispose();
  }

  Future<void> _loadFlightDataInterval() async {
    final homeProvider = context.read<HomeProvider?>();
    final intervalMs =
        await homeProvider?.getFlightDataIntervalMs() ??
        MiddlewareHomeDataAdapter.defaultPollIntervalMs;
    if (!mounted) {
      return;
    }
    setState(() {
      _currentFlightDataIntervalMs = intervalMs;
      _flightDataIntervalController.text = '$intervalMs';
    });
  }

  Future<void> _saveFlightDataInterval(BuildContext context) async {
    final text = _flightDataIntervalController.text.trim();
    final intervalMs = int.tryParse(text);
    if (intervalMs == null ||
        intervalMs < MiddlewareHomeDataAdapter.minPollIntervalMs ||
        intervalMs > MiddlewareHomeDataAdapter.maxPollIntervalMs) {
      SnackBarHelper.showError(
        context,
        MapLocalizationKeys.invalidFlightDataInterval.tr(context),
      );
      return;
    }
    final homeProvider = context.read<HomeProvider?>();
    if (homeProvider == null) {
      return;
    }
    setState(() {
      _isFlightDataIntervalSaving = true;
    });
    try {
      await homeProvider.setFlightDataIntervalMs(intervalMs);
      if (!mounted) {
        return;
      }
      setState(() {
        _currentFlightDataIntervalMs = intervalMs;
        _flightDataIntervalController.text = '$intervalMs';
      });
      SnackBarHelper.showSuccess(
        context,
        MapLocalizationKeys.flightDataIntervalSaved.tr(context),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isFlightDataIntervalSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Consumer<MapProvider>(
      builder: (context, mapProvider, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                    onChanged: mapProvider.setAutoHudTimerEnabled,
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
                      mapProvider.setAutoTimerStartMode(
                        MapAutoTimerStartMode.runwayMovement,
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
                      mapProvider.setAutoTimerStartMode(
                        MapAutoTimerStartMode.pushback,
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
                      mapProvider.setAutoTimerStartMode(
                        MapAutoTimerStartMode.anyMovement,
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
                      mapProvider.setAutoTimerStopMode(
                        MapAutoTimerStopMode.stableLanding,
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
                      mapProvider.setAutoTimerStopMode(
                        MapAutoTimerStopMode.runwayExitAfterLanding,
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
                      mapProvider.setAutoTimerStopMode(
                        MapAutoTimerStopMode.parkingArrival,
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppThemeData.spacingMedium),
            _SectionCard(
              icon: Icons.speed_outlined,
              title: MapLocalizationKeys.flightDataSectionTitle.tr(context),
              subtitle: MapLocalizationKeys.flightDataSectionDesc.tr(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _flightDataIntervalController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: MapLocalizationKeys.flightDataIntervalLabel.tr(
                        context,
                      ),
                      hintText: MapLocalizationKeys.flightDataIntervalHint.tr(
                        context,
                      ),
                      prefixIcon: const Icon(Icons.timer_outlined),
                    ),
                  ),
                  const SizedBox(height: AppThemeData.spacingSmall),
                  Text(
                    MapLocalizationKeys.currentFlightDataInterval
                        .tr(context)
                        .replaceFirst(
                          '{value}',
                          '$_currentFlightDataIntervalMs',
                        ),
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppThemeData.spacingMedium),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isFlightDataIntervalSaving
                          ? null
                          : () => _saveFlightDataInterval(context),
                      icon: _isFlightDataIntervalSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined, size: 18),
                      label: Text(
                        _isFlightDataIntervalSaving
                            ? MapLocalizationKeys.saving.tr(context)
                            : MapLocalizationKeys.saveButton.tr(context),
                      ),
                    ),
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
