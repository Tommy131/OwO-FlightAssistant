import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/services/localization_service.dart';
import '../../../../core/theme/app_theme_data.dart';
import '../../localization/home_localization_keys.dart';
import '../../models/home_models.dart';
import '../../providers/home_provider.dart';
import 'airport_search_bar.dart';
import 'flight_data_widgets.dart';
import 'metar_display_widget.dart';
import 'system_status_panel.dart';

class FlightDataDashboard extends StatelessWidget {
  const FlightDataDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer<HomeProvider>(
      /// 功能：执行builder的核心业务流程。
      /// 说明：该方法封装单一职责逻辑，便于后续维护、定位问题与扩展功能。
      builder: (context, provider, _) {
        if (!provider.isConnected) {
          return _buildNoConnectionPlaceholder(context, theme);
        }

        final data = provider.flightData;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              HomeLocalizationKeys.dashboardTitle.tr(context),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppThemeData.spacingMedium),
            _buildPrimaryFlightData(context, theme, data),
            const SizedBox(height: AppThemeData.spacingMedium),
            _buildNavigationData(context, theme, data),
            const SizedBox(height: AppThemeData.spacingMedium),
            _buildEnvironmentData(context, theme, data),
            const SizedBox(height: AppThemeData.spacingMedium),
            _buildEngineAndFuelData(context, theme, data),
            const SizedBox(height: AppThemeData.spacingMedium),
            _buildWeatherSection(context, provider),
            const SizedBox(height: AppThemeData.spacingMedium),
            SystemStatusPanel(data: data),
          ],
        );
      },
    );
  }

  /// 功能：执行_buildNoConnectionPlaceholder的核心业务流程。
  /// 说明：该方法封装单一职责逻辑，便于后续维护、定位问题与扩展功能。
  Widget _buildNoConnectionPlaceholder(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(AppThemeData.spacingLarge * 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppThemeData.borderRadiusMedium),
        border: Border.all(color: AppThemeData.getBorderColor(theme)),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.flight_takeoff,
              size: 64,
              color: theme.colorScheme.outline.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              HomeLocalizationKeys.dashboardNoConnectionTitle.tr(context),
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              HomeLocalizationKeys.dashboardNoConnectionSubtitle.tr(context),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrimaryFlightData(
    BuildContext context,
    ThemeData theme,
    HomeFlightData data,
  ) {
    final isFuelOk = context.watch<HomeProvider>().isFuelSufficient;

    final fuelStatusLabel = isFuelOk == null
        ? HomeLocalizationKeys.primaryFuelUnknown.tr(context)
        : isFuelOk
        ? HomeLocalizationKeys.primaryFuelOk.tr(context)
        : HomeLocalizationKeys.primaryFuelLow.tr(context);
    final fuelColor = isFuelOk == null
        ? Colors.grey
        : isFuelOk
        ? Colors.teal
        : Colors.red;

    return GridView.count(
      crossAxisCount: 5,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: AppThemeData.spacingSmall,
      mainAxisSpacing: AppThemeData.spacingMedium,
      childAspectRatio: 1.1,
      children: [
        DataCard(
          icon: Icons.speed,
          label: HomeLocalizationKeys.primaryAirspeed.tr(context),
          value: data.airspeed != null
              /// 功能：执行toStringAsFixed的核心业务流程。
              /// 说明：该方法封装单一职责逻辑，便于后续维护、定位问题与扩展功能。
              ? '${data.airspeed!.toStringAsFixed(0)} kt'
              : 'N/A',
          subValue: data.machNumber != null && data.machNumber! > 0.1
              /// 功能：执行toStringAsFixed的核心业务流程。
              /// 说明：该方法封装单一职责逻辑，便于后续维护、定位问题与扩展功能。
              ? 'M ${data.machNumber!.toStringAsFixed(3)}'
              : null,
          color: Colors.blue,
        ),
        DataCard(
          icon: Icons.height,
          label: HomeLocalizationKeys.primaryAltitude.tr(context),
          value: data.altitude != null
              /// 功能：执行toStringAsFixed的核心业务流程。
              /// 说明：该方法封装单一职责逻辑，便于后续维护、定位问题与扩展功能。
              ? '${data.altitude!.toStringAsFixed(0)} ft'
              : 'N/A',
          color: Colors.green,
        ),
        DataCard(
          icon: Icons.explore,
          label: HomeLocalizationKeys.primaryHeading.tr(context),
          value: data.heading != null
              /// 功能：执行toStringAsFixed的核心业务流程。
              /// 说明：该方法封装单一职责逻辑，便于后续维护、定位问题与扩展功能。
              ? '${data.heading!.toStringAsFixed(0)}°'
              : 'N/A',
          color: Colors.purple,
        ),
        DataCard(
          icon: Icons.trending_up,
          label: HomeLocalizationKeys.primaryVerticalSpeed.tr(context),
          value: data.verticalSpeed != null
              /// 功能：执行toStringAsFixed的核心业务流程。
              /// 说明：该方法封装单一职责逻辑，便于后续维护、定位问题与扩展功能。
              ? '${data.verticalSpeed!.toStringAsFixed(0)} fpm'
              : 'N/A',
          color: Colors.orange,
        ),
        DataCard(
          icon: Icons.local_gas_station,
          label: HomeLocalizationKeys.primaryFuelStatus.tr(context),
          value: fuelStatusLabel,
          color: fuelColor,
        ),
      ],
    );
  }

  Widget _buildNavigationData(
    BuildContext context,
    ThemeData theme,
    HomeFlightData data,
  ) {
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
              Icon(Icons.map, color: theme.colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                HomeLocalizationKeys.navTitle.tr(context),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppThemeData.spacingMedium),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              InfoChip(
                label: HomeLocalizationKeys.navGroundSpeed.tr(context),
                value: data.groundSpeed != null
                    /// 功能：执行toStringAsFixed的核心业务流程。
                    /// 说明：该方法封装单一职责逻辑，便于后续维护、定位问题与扩展功能。
                    ? '${data.groundSpeed!.toStringAsFixed(0)} kt'
                    : 'N/A',
              ),
              InfoChip(
                label: HomeLocalizationKeys.navTrueAirspeed.tr(context),
                value: data.trueAirspeed != null
                    /// 功能：执行toStringAsFixed的核心业务流程。
                    /// 说明：该方法封装单一职责逻辑，便于后续维护、定位问题与扩展功能。
                    ? '${data.trueAirspeed!.toStringAsFixed(0)} kt'
                    : 'N/A',
              ),
              InfoChip(
                label: HomeLocalizationKeys.navLatitude.tr(context),
                value: data.latitude != null
                    ? data.latitude!.toStringAsFixed(4)
                    : 'N/A',
              ),
              InfoChip(
                label: HomeLocalizationKeys.navLongitude.tr(context),
                value: data.longitude != null
                    ? data.longitude!.toStringAsFixed(4)
                    : 'N/A',
              ),
              if ((data.aircraftDisplayName ?? '').trim().isNotEmpty)
                InfoChip(
                  label: HomeLocalizationKeys.navAircraft.tr(context),
                  value: data.aircraftDisplayName!,
                )
              else if ((data.aircraftModel ?? '').trim().isNotEmpty)
                InfoChip(
                  label: HomeLocalizationKeys.navAircraft.tr(context),
                  value: data.aircraftModel!,
                ),
              if ((data.aircraftIcao ?? '').trim().isNotEmpty)
                InfoChip(
                  label: HomeLocalizationKeys.navAircraftIcao.tr(context),
                  value: data.aircraftIcao!,
                ),
              if (data.departureAirport != null)
                InfoChip(
                  label: HomeLocalizationKeys.navDeparture.tr(context),
                  value: data.departureAirport!,
                ),
              if (data.arrivalAirport != null)
                InfoChip(
                  label: HomeLocalizationKeys.navArrival.tr(context),
                  value: data.arrivalAirport!,
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(
                Icons.settings_input_antenna,
                color: theme.colorScheme.primary.withValues(alpha: 0.7),
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                /// 功能：执行tr的核心业务流程。
                /// 说明：该方法封装单一职责逻辑，便于后续维护、定位问题与扩展功能。
                '${HomeLocalizationKeys.navCom1.tr(context)}:',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                data.com1Frequency != null
                    /// 功能：执行toStringAsFixed的核心业务流程。
                    /// 说明：该方法封装单一职责逻辑，便于后续维护、定位问题与扩展功能。
                    ? '${data.com1Frequency!.toStringAsFixed(2)} MHz'
                    : 'N/A',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'Monospace',
                ),
              ),
              const Spacer(),
              _buildAirportPickers(context),
            ],
          ),
        ],
      ),
    );
  }

  /// 功能：执行_buildAirportPickers的核心业务流程。
  /// 说明：该方法封装单一职责逻辑，便于后续维护、定位问题与扩展功能。
  Widget _buildAirportPickers(BuildContext context) {
    final provider = context.watch<HomeProvider>();
    final dep = provider.departureAirport;
    final dest = provider.destinationAirport;
    final alt = provider.alternateAirport;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildPickerButton(
          context,
          label: dep != null
              /// 功能：执行tr的核心业务流程。
              /// 说明：该方法封装单一职责逻辑，便于后续维护、定位问题与扩展功能。
              ? '${HomeLocalizationKeys.navDeparture.tr(context)}: ${dep.icaoCode}'
              : HomeLocalizationKeys.navSetDeparture.tr(context),
          icon: dep != null ? Icons.flight_takeoff : Icons.add_location_alt,
          /// 功能：执行onPressed的核心业务流程。
          /// 说明：该方法封装单一职责逻辑，便于后续维护、定位问题与扩展功能。
          onPressed: () => _showAirportPickerDialog(
            context,
            isDeparture: true,
            isAlternate: false,
          ),
        ),
        const SizedBox(width: 8),
        _buildPickerButton(
          context,
          label: dest != null
              /// 功能：执行tr的核心业务流程。
              /// 说明：该方法封装单一职责逻辑，便于后续维护、定位问题与扩展功能。
              ? '${HomeLocalizationKeys.navDestination.tr(context)}: ${dest.icaoCode}'
              : HomeLocalizationKeys.navSetDestination.tr(context),
          icon: dest != null ? Icons.location_on : Icons.add_location,
          /// 功能：执行onPressed的核心业务流程。
          /// 说明：该方法封装单一职责逻辑，便于后续维护、定位问题与扩展功能。
          onPressed: () =>
              _showAirportPickerDialog(context, isAlternate: false),
        ),
        const SizedBox(width: 8),
        _buildPickerButton(
          context,
          label: alt != null
              /// 功能：执行tr的核心业务流程。
              /// 说明：该方法封装单一职责逻辑，便于后续维护、定位问题与扩展功能。
              ? '${HomeLocalizationKeys.navAlternate.tr(context)}: ${alt.icaoCode}'
              : HomeLocalizationKeys.navSetAlternate.tr(context),
          icon: alt != null ? Icons.alt_route : Icons.add_road,
          /// 功能：执行onPressed的核心业务流程。
          /// 说明：该方法封装单一职责逻辑，便于后续维护、定位问题与扩展功能。
          onPressed: () => _showAirportPickerDialog(context, isAlternate: true),
        ),
      ],
    );
  }

  Widget _buildPickerButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 14),
      label: Text(label, style: const TextStyle(fontSize: 11)),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  void _showAirportPickerDialog(
    BuildContext context, {
    bool isDeparture = false,
    bool isAlternate = false,
  }) {
    final provider = context.read<HomeProvider>();
    showDialog(
      context: context,
      /// 功能：执行builder的核心业务流程。
      /// 说明：该方法封装单一职责逻辑，便于后续维护、定位问题与扩展功能。
      builder: (context) {
        return AlertDialog(
          title: Text(
            isDeparture
                ? HomeLocalizationKeys.navPickDepartureTitle.tr(context)
                : (isAlternate
                      ? HomeLocalizationKeys.navPickAlternateTitle.tr(context)
                      : HomeLocalizationKeys.navPickDestinationTitle.tr(
                          context,
                        )),
          ),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AirportSearchBar(
                  onSearch: provider.searchAirports,
                  /// 功能：执行onSelect的核心业务流程。
                  /// 说明：该方法封装单一职责逻辑，便于后续维护、定位问题与扩展功能。
                  onSelect: (airport) async {
                    if (isDeparture) {
                      await provider.setDeparture(airport);
                    } else if (isAlternate) {
                      await provider.setAlternate(airport);
                    } else {
                      await provider.setDestination(airport);
                    }
                    if (context.mounted) Navigator.pop(context);
                  },
                  suggestedAirports: provider.suggestedAirports,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              /// 功能：执行onPressed的核心业务流程。
              /// 说明：该方法封装单一职责逻辑，便于后续维护、定位问题与扩展功能。
              onPressed: () async {
                if (isDeparture) {
                  await provider.setDeparture(null);
                } else if (isAlternate) {
                  await provider.setAlternate(null);
                } else {
                  await provider.setDestination(null);
                }
                if (context.mounted) Navigator.pop(context);
              },
              child: Text(HomeLocalizationKeys.navClearSelection.tr(context)),
            ),
            TextButton(
              /// 功能：执行onPressed的核心业务流程。
              /// 说明：该方法封装单一职责逻辑，便于后续维护、定位问题与扩展功能。
              onPressed: () => Navigator.pop(context),
              child: Text(HomeLocalizationKeys.navCancel.tr(context)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEnvironmentData(
    BuildContext context,
    ThemeData theme,
    HomeFlightData data,
  ) {
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
              Icon(Icons.wb_sunny, color: theme.colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                HomeLocalizationKeys.environmentTitle.tr(context),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppThemeData.spacingMedium),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              InfoChip(
                label: HomeLocalizationKeys.environmentOat.tr(context),
                value: data.outsideAirTemperature != null
                    /// 功能：执行toStringAsFixed的核心业务流程。
                    /// 说明：该方法封装单一职责逻辑，便于后续维护、定位问题与扩展功能。
                    ? '${data.outsideAirTemperature!.toStringAsFixed(1)} °C'
                    : 'N/A',
              ),
              InfoChip(
                label: HomeLocalizationKeys.environmentTat.tr(context),
                value: data.totalAirTemperature != null
                    /// 功能：执行toStringAsFixed的核心业务流程。
                    /// 说明：该方法封装单一职责逻辑，便于后续维护、定位问题与扩展功能。
                    ? '${data.totalAirTemperature!.toStringAsFixed(1)} °C'
                    : 'N/A',
              ),
              InfoChip(
                label: HomeLocalizationKeys.environmentWind.tr(context),
                value: (data.windSpeed != null && data.windDirection != null)
                    /// 功能：执行toStringAsFixed的核心业务流程。
                    /// 说明：该方法封装单一职责逻辑，便于后续维护、定位问题与扩展功能。
                    ? '${data.windDirection!.toStringAsFixed(0)}° / ${data.windSpeed!.toStringAsFixed(0)} kt'
                    : 'N/A',
              ),
              InfoChip(
                label: HomeLocalizationKeys.environmentQnh.tr(context),
                value: data.baroPressure != null
                    /// 功能：执行toStringAsFixed的核心业务流程。
                    /// 说明：该方法封装单一职责逻辑，便于后续维护、定位问题与扩展功能。
                    ? '${data.baroPressure!.toStringAsFixed(2)} ${data.baroPressureUnit ?? "inHg"}'
                    : 'N/A',
              ),
              InfoChip(
                label: HomeLocalizationKeys.environmentVisibility.tr(context),
                value: data.visibility != null
                    ? (data.visibility! >= 9999
                          ? '> 10 km'
                          : data.visibility! >= 1000
                          ? '${(data.visibility! / 1000).toStringAsFixed(1)} km'
                          /// 功能：执行toStringAsFixed的核心业务流程。
                          /// 说明：该方法封装单一职责逻辑，便于后续维护、定位问题与扩展功能。
                          : '${data.visibility!.toStringAsFixed(0)} m')
                    : 'N/A',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEngineAndFuelData(
    BuildContext context,
    ThemeData theme,
    HomeFlightData data,
  ) {
    final showSecondEngine = (data.numEngines ?? 2) > 1;
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
              Icon(Icons.settings, color: theme.colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                HomeLocalizationKeys.engineTitle.tr(context),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppThemeData.spacingMedium),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              InfoChip(
                label: HomeLocalizationKeys.engineFob.tr(context),
                value: data.fuelQuantity != null
                    /// 功能：执行toStringAsFixed的核心业务流程。
                    /// 说明：该方法封装单一职责逻辑，便于后续维护、定位问题与扩展功能。
                    ? '${data.fuelQuantity!.toStringAsFixed(0)} kg'
                    : 'N/A',
              ),
              InfoChip(
                label: HomeLocalizationKeys.engineFf.tr(context),
                value: data.fuelFlow != null
                    /// 功能：执行toStringAsFixed的核心业务流程。
                    /// 说明：该方法封装单一职责逻辑，便于后续维护、定位问题与扩展功能。
                    ? '${data.fuelFlow!.toStringAsFixed(1)} kg/h'
                    : 'N/A',
              ),
              InfoChip(
                label: HomeLocalizationKeys.engineEng1N1.tr(context),
                value: data.engine1N1 != null
                    /// 功能：执行toStringAsFixed的核心业务流程。
                    /// 说明：该方法封装单一职责逻辑，便于后续维护、定位问题与扩展功能。
                    ? '${data.engine1N1!.toStringAsFixed(1)}%'
                    : 'N/A',
              ),
              if (showSecondEngine)
                InfoChip(
                  label: HomeLocalizationKeys.engineEng2N1.tr(context),
                  value: data.engine2N1 != null
                      /// 功能：执行toStringAsFixed的核心业务流程。
                      /// 说明：该方法封装单一职责逻辑，便于后续维护、定位问题与扩展功能。
                      ? '${data.engine2N1!.toStringAsFixed(1)}%'
                      : 'N/A',
                ),
              InfoChip(
                label: HomeLocalizationKeys.engineEng1Egt.tr(context),
                value: data.engine1EGT != null
                    /// 功能：执行toStringAsFixed的核心业务流程。
                    /// 说明：该方法封装单一职责逻辑，便于后续维护、定位问题与扩展功能。
                    ? '${data.engine1EGT!.toStringAsFixed(0)}°C'
                    : 'N/A',
              ),
              if (showSecondEngine)
                InfoChip(
                  label: HomeLocalizationKeys.engineEng2Egt.tr(context),
                  value: data.engine2EGT != null
                      /// 功能：执行toStringAsFixed的核心业务流程。
                      /// 说明：该方法封装单一职责逻辑，便于后续维护、定位问题与扩展功能。
                      ? '${data.engine2EGT!.toStringAsFixed(0)}°C'
                      : 'N/A',
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// 功能：执行_buildWeatherSection的核心业务流程。
  /// 说明：该方法封装单一职责逻辑，便于后续维护、定位问题与扩展功能。
  Widget _buildWeatherSection(BuildContext context, HomeProvider provider) {
    final metars = <String, HomeMetarData>{};
    final errors = <String, String>{};
    final refreshCallbacks = <String, VoidCallback>{};
    final refreshingStates = <String, bool>{};

    final current = provider.nearestAirport;
    if (current != null) {
      final label =
          '${HomeLocalizationKeys.navDeparture.tr(context)} (${current.icaoCode})';
      final icao = current.icaoCode.trim().toUpperCase();
      if (provider.metarsByIcao.containsKey(icao)) {
        metars[label] = provider.metarsByIcao[icao]!;
      } else if (provider.metarErrorsByIcao.containsKey(icao)) {
        errors[label] = provider.metarErrorsByIcao[icao]!;
      }
      refreshCallbacks[label] = () => provider.refreshMetar(current);
      refreshingStates[label] = provider.metarRefreshingIcaos.contains(icao);
    }

    final dest = provider.destinationAirport;
    if (dest != null) {
      final label =
          '${HomeLocalizationKeys.navDestination.tr(context)} (${dest.icaoCode})';
      final icao = dest.icaoCode.trim().toUpperCase();
      if (provider.metarsByIcao.containsKey(icao)) {
        metars[label] = provider.metarsByIcao[icao]!;
      } else if (provider.metarErrorsByIcao.containsKey(icao)) {
        errors[label] = provider.metarErrorsByIcao[icao]!;
      }
      refreshCallbacks[label] = () => provider.refreshMetar(dest);
      refreshingStates[label] = provider.metarRefreshingIcaos.contains(icao);
    }

    final alt = provider.alternateAirport;
    if (alt != null) {
      final label =
          '${HomeLocalizationKeys.navAlternate.tr(context)} (${alt.icaoCode})';
      final icao = alt.icaoCode.trim().toUpperCase();
      if (provider.metarsByIcao.containsKey(icao)) {
        metars[label] = provider.metarsByIcao[icao]!;
      } else if (provider.metarErrorsByIcao.containsKey(icao)) {
        errors[label] = provider.metarErrorsByIcao[icao]!;
      }
      refreshCallbacks[label] = () => provider.refreshMetar(alt);
      refreshingStates[label] = provider.metarRefreshingIcaos.contains(icao);
    }

    return MetarSectionWidget(
      metars: metars,
      errors: errors,
      refreshCallbacks: refreshCallbacks,
      refreshingStates: refreshingStates,
    );
  }
}
