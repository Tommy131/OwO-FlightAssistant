import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/services/localization_service.dart';
import '../../../../core/theme/app_theme_data.dart';
import '../../localization/common_localization_keys.dart';
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
      builder: (context, provider, _) {
        if (!provider.isConnected) {
          return _buildNoConnectionPlaceholder(context, theme);
        }

        final data = provider.flightData;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              CommonLocalizationKeys.dashboardTitle.tr(context),
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
              CommonLocalizationKeys.dashboardNoConnectionTitle.tr(context),
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              CommonLocalizationKeys.dashboardNoConnectionSubtitle.tr(context),
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
        ? CommonLocalizationKeys.primaryFuelUnknown.tr(context)
        : isFuelOk
        ? CommonLocalizationKeys.primaryFuelOk.tr(context)
        : CommonLocalizationKeys.primaryFuelLow.tr(context);
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
          label: CommonLocalizationKeys.primaryAirspeed.tr(context),
          value: data.airspeed != null
              ? '${data.airspeed!.toStringAsFixed(0)} kt'
              : 'N/A',
          subValue: data.machNumber != null && data.machNumber! > 0.1
              ? 'M ${data.machNumber!.toStringAsFixed(3)}'
              : null,
          color: Colors.blue,
        ),
        DataCard(
          icon: Icons.height,
          label: CommonLocalizationKeys.primaryAltitude.tr(context),
          value: data.altitude != null
              ? '${data.altitude!.toStringAsFixed(0)} ft'
              : 'N/A',
          color: Colors.green,
        ),
        DataCard(
          icon: Icons.explore,
          label: CommonLocalizationKeys.primaryHeading.tr(context),
          value: data.heading != null
              ? '${data.heading!.toStringAsFixed(0)}°'
              : 'N/A',
          color: Colors.purple,
        ),
        DataCard(
          icon: Icons.trending_up,
          label: CommonLocalizationKeys.primaryVerticalSpeed.tr(context),
          value: data.verticalSpeed != null
              ? '${data.verticalSpeed!.toStringAsFixed(0)} fpm'
              : 'N/A',
          color: Colors.orange,
        ),
        DataCard(
          icon: Icons.local_gas_station,
          label: CommonLocalizationKeys.primaryFuelStatus.tr(context),
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
                CommonLocalizationKeys.navTitle.tr(context),
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
                label: CommonLocalizationKeys.navGroundSpeed.tr(context),
                value: data.groundSpeed != null
                    ? '${data.groundSpeed!.toStringAsFixed(0)} kt'
                    : 'N/A',
              ),
              InfoChip(
                label: CommonLocalizationKeys.navTrueAirspeed.tr(context),
                value: data.trueAirspeed != null
                    ? '${data.trueAirspeed!.toStringAsFixed(0)} kt'
                    : 'N/A',
              ),
              InfoChip(
                label: CommonLocalizationKeys.navLatitude.tr(context),
                value: data.latitude != null
                    ? data.latitude!.toStringAsFixed(4)
                    : 'N/A',
              ),
              InfoChip(
                label: CommonLocalizationKeys.navLongitude.tr(context),
                value: data.longitude != null
                    ? data.longitude!.toStringAsFixed(4)
                    : 'N/A',
              ),
              if (data.departureAirport != null)
                InfoChip(
                  label: CommonLocalizationKeys.navDeparture.tr(context),
                  value: data.departureAirport!,
                ),
              if (data.arrivalAirport != null)
                InfoChip(
                  label: CommonLocalizationKeys.navArrival.tr(context),
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
                '${CommonLocalizationKeys.navCom1.tr(context)}:',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                data.com1Frequency != null
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

  Widget _buildAirportPickers(BuildContext context) {
    final provider = context.watch<HomeProvider>();
    final dest = provider.destinationAirport;
    final alt = provider.alternateAirport;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildPickerButton(
          context,
          label: dest != null
              ? '${CommonLocalizationKeys.navDestination.tr(context)}: ${dest.icaoCode}'
              : CommonLocalizationKeys.navSetDestination.tr(context),
          icon: dest != null ? Icons.location_on : Icons.add_location,
          onPressed: () =>
              _showAirportPickerDialog(context, isAlternate: false),
        ),
        const SizedBox(width: 8),
        _buildPickerButton(
          context,
          label: alt != null
              ? '${CommonLocalizationKeys.navAlternate.tr(context)}: ${alt.icaoCode}'
              : CommonLocalizationKeys.navSetAlternate.tr(context),
          icon: alt != null ? Icons.alt_route : Icons.add_road,
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
    required bool isAlternate,
  }) {
    showDialog(
      context: context,
      builder: (context) {
        final provider = context.read<HomeProvider>();
        return AlertDialog(
          title: Text(
            isAlternate
                ? CommonLocalizationKeys.navPickAlternateTitle.tr(context)
                : CommonLocalizationKeys.navPickDestinationTitle.tr(context),
          ),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AirportSearchBar(
                  onSearch: provider.searchAirports,
                  onSelect: (airport) async {
                    if (isAlternate) {
                      await provider.setAlternate(airport);
                    } else {
                      await provider.setDestination(airport);
                    }
                    if (context.mounted) Navigator.pop(context);
                  },
                  suggestedAirports: provider.suggestedAirports,
                ),
                const SizedBox(height: 16),
                Text(
                  CommonLocalizationKeys.navRecentAirports.tr(context),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 250),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: provider.suggestedAirports.length > 5
                        ? 5
                        : provider.suggestedAirports.length,
                    itemBuilder: (context, index) {
                      final airport = provider.suggestedAirports[index];
                      return ListTile(
                        dense: true,
                        title: Text(airport.displayName),
                        onTap: () async {
                          if (isAlternate) {
                            await provider.setAlternate(airport);
                          } else {
                            await provider.setDestination(airport);
                          }
                          if (context.mounted) Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                if (isAlternate) {
                  await provider.setAlternate(null);
                } else {
                  await provider.setDestination(null);
                }
                if (context.mounted) Navigator.pop(context);
              },
              child: Text(CommonLocalizationKeys.navClearSelection.tr(context)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(CommonLocalizationKeys.navCancel.tr(context)),
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
                CommonLocalizationKeys.environmentTitle.tr(context),
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
                label: CommonLocalizationKeys.environmentOat.tr(context),
                value: data.outsideAirTemperature != null
                    ? '${data.outsideAirTemperature!.toStringAsFixed(1)} °C'
                    : 'N/A',
              ),
              InfoChip(
                label: CommonLocalizationKeys.environmentTat.tr(context),
                value: data.totalAirTemperature != null
                    ? '${data.totalAirTemperature!.toStringAsFixed(1)} °C'
                    : 'N/A',
              ),
              InfoChip(
                label: CommonLocalizationKeys.environmentWind.tr(context),
                value: (data.windSpeed != null && data.windDirection != null)
                    ? '${data.windDirection!.toStringAsFixed(0)}° / ${data.windSpeed!.toStringAsFixed(0)} kt'
                    : 'N/A',
              ),
              InfoChip(
                label: CommonLocalizationKeys.environmentQnh.tr(context),
                value: data.baroPressure != null
                    ? '${data.baroPressure!.toStringAsFixed(2)} ${data.baroPressureUnit ?? "inHg"}'
                    : 'N/A',
              ),
              InfoChip(
                label: CommonLocalizationKeys.environmentVisibility.tr(context),
                value: data.visibility != null
                    ? (data.visibility! >= 9999
                          ? '> 10 km'
                          : data.visibility! >= 1000
                          ? '${(data.visibility! / 1000).toStringAsFixed(1)} km'
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
                CommonLocalizationKeys.engineTitle.tr(context),
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
                label: CommonLocalizationKeys.engineFob.tr(context),
                value: data.fuelQuantity != null
                    ? '${data.fuelQuantity!.toStringAsFixed(0)} kg'
                    : 'N/A',
              ),
              InfoChip(
                label: CommonLocalizationKeys.engineFf.tr(context),
                value: data.fuelFlow != null
                    ? '${data.fuelFlow!.toStringAsFixed(1)} kg/h'
                    : 'N/A',
              ),
              InfoChip(
                label: CommonLocalizationKeys.engineEng1N1.tr(context),
                value: data.engine1N1 != null
                    ? '${data.engine1N1!.toStringAsFixed(1)}%'
                    : 'N/A',
              ),
              if (showSecondEngine)
                InfoChip(
                  label: CommonLocalizationKeys.engineEng2N1.tr(context),
                  value: data.engine2N1 != null
                      ? '${data.engine2N1!.toStringAsFixed(1)}%'
                      : 'N/A',
                ),
              InfoChip(
                label: CommonLocalizationKeys.engineEng1Egt.tr(context),
                value: data.engine1EGT != null
                    ? '${data.engine1EGT!.toStringAsFixed(0)}°C'
                    : 'N/A',
              ),
              if (showSecondEngine)
                InfoChip(
                  label: CommonLocalizationKeys.engineEng2Egt.tr(context),
                  value: data.engine2EGT != null
                      ? '${data.engine2EGT!.toStringAsFixed(0)}°C'
                      : 'N/A',
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherSection(BuildContext context, HomeProvider provider) {
    final metars = <String, HomeMetarData>{};
    final errors = <String, String>{};
    final refreshCallbacks = <String, VoidCallback>{};

    final current = provider.nearestAirport;
    if (current != null) {
      final label =
          '${CommonLocalizationKeys.navDeparture.tr(context)} (${current.icaoCode})';
      final icao = current.icaoCode;
      if (provider.metarsByIcao.containsKey(icao)) {
        metars[label] = provider.metarsByIcao[icao]!;
      } else if (provider.metarErrorsByIcao.containsKey(icao)) {
        errors[label] = provider.metarErrorsByIcao[icao]!;
      }
      refreshCallbacks[label] = () => provider.refreshMetar(current);
    }

    final dest = provider.destinationAirport;
    if (dest != null) {
      final label =
          '${CommonLocalizationKeys.navDestination.tr(context)} (${dest.icaoCode})';
      final icao = dest.icaoCode;
      if (provider.metarsByIcao.containsKey(icao)) {
        metars[label] = provider.metarsByIcao[icao]!;
      } else if (provider.metarErrorsByIcao.containsKey(icao)) {
        errors[label] = provider.metarErrorsByIcao[icao]!;
      }
      refreshCallbacks[label] = () => provider.refreshMetar(dest);
    }

    final alt = provider.alternateAirport;
    if (alt != null) {
      final label =
          '${CommonLocalizationKeys.navAlternate.tr(context)} (${alt.icaoCode})';
      final icao = alt.icaoCode;
      if (provider.metarsByIcao.containsKey(icao)) {
        metars[label] = provider.metarsByIcao[icao]!;
      } else if (provider.metarErrorsByIcao.containsKey(icao)) {
        errors[label] = provider.metarErrorsByIcao[icao]!;
      }
      refreshCallbacks[label] = () => provider.refreshMetar(alt);
    }

    return MetarSectionWidget(
      metars: metars,
      errors: errors,
      refreshCallbacks: refreshCallbacks,
    );
  }
}
