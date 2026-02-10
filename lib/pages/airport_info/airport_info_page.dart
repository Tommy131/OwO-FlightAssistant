import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../apps/data/airports_database.dart';
import '../../apps/providers/simulator/simulator_provider.dart';
import '../../core/theme/app_theme_data.dart';
import '../../apps/providers/airport_info_provider.dart';
import 'widgets/airport_empty_state.dart';
import 'widgets/airport_info_header.dart';
import 'widgets/airport_list.dart';

/// 机场信息页面
class AirportInfoPage extends StatefulWidget {
  const AirportInfoPage({super.key});

  @override
  State<AirportInfoPage> createState() => _AirportInfoPageState();
}

class _AirportInfoPageState extends State<AirportInfoPage> {
  // Track the last known ICAOs to avoid unnecessary data fetching
  String? _lastNearestIcao;
  String? _lastDestIcao;
  String? _lastAltIcao;

  @override
  void initState() {
    super.initState();
    // Initialize provider data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AirportInfoProvider>().initialize();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Listen to simulator provider for auto-topping updates
    final simProvider = context.watch<SimulatorProvider>();
    _handleSimulatorUpdate(simProvider);
  }

  void _handleSimulatorUpdate(SimulatorProvider simProvider) {
    final nearest = simProvider.nearestAirport?.icaoCode;
    final dest = simProvider.destinationAirport?.icaoCode;
    final alt = simProvider.alternateAirport?.icaoCode;

    // If any of the pinned airports changed, refresh data
    if (nearest != _lastNearestIcao ||
        dest != _lastDestIcao ||
        alt != _lastAltIcao) {
      _lastNearestIcao = nearest;
      _lastDestIcao = dest;
      _lastAltIcao = alt;

      // Trigger a refresh of METARs and details for the new airports
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // We need to calculate the list again and refresh
        if (mounted) {
          final displayList = _getDisplayList();
          context.read<AirportInfoProvider>().refreshData(displayList);
        }
      });
    }
  }

  List<AirportInfo> _getDisplayList() {
    final simProvider = context.read<SimulatorProvider>();
    final infoProvider = context.read<AirportInfoProvider>();

    final List<AirportInfo> topList = [];

    if (simProvider.isConnected) {
      if (simProvider.nearestAirport != null) {
        topList.add(simProvider.nearestAirport!);
      }
      if (simProvider.destinationAirport != null) {
        topList.add(simProvider.destinationAirport!);
      }
      if (simProvider.alternateAirport != null) {
        topList.add(simProvider.alternateAirport!);
      }
    }

    // Deduplicate topList based on ICAO
    final uniqueTopList = <AirportInfo>[];
    final seenIcaos = <String>{};
    for (final a in topList) {
      if (seenIcaos.add(a.icaoCode)) {
        uniqueTopList.add(a);
      }
    }

    // Combine with saved list, excluding those already in topList
    final result = [...uniqueTopList];
    for (final saved in infoProvider.savedAirports) {
      if (!seenIcaos.contains(saved.icaoCode)) {
        result.add(saved);
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Consumers to rebuild on changes
    final infoProvider = context.watch<AirportInfoProvider>();
    // We also need to watch SimulatorProvider to rebuild list when sim state changes
    final simProvider = context.watch<SimulatorProvider>();

    // Calculate display list
    final List<AirportInfo> topList = [];
    if (simProvider.isConnected) {
      if (simProvider.nearestAirport != null) {
        topList.add(simProvider.nearestAirport!);
      }
      if (simProvider.destinationAirport != null) {
        topList.add(simProvider.destinationAirport!);
      }
      if (simProvider.alternateAirport != null) {
        topList.add(simProvider.alternateAirport!);
      }
    }

    final uniqueTopList = <AirportInfo>[];
    final seenIcaos = <String>{};
    for (final a in topList) {
      if (seenIcaos.add(a.icaoCode)) {
        uniqueTopList.add(a);
      }
    }

    final displayList = [...uniqueTopList];
    for (final saved in infoProvider.savedAirports) {
      if (!seenIcaos.contains(saved.icaoCode)) {
        displayList.add(saved);
      }
    }

    return Container(
      color: theme.scaffoldBackgroundColor,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppThemeData.spacingLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (infoProvider.dataSourceSwitchError != null)
              _buildErrorBanner(context, theme, infoProvider),

            AirportInfoHeader(
              onRefresh: () =>
                  infoProvider.refreshData(displayList, force: true),
            ),

            const SizedBox(height: AppThemeData.spacingMedium),

            if (displayList.isEmpty)
              const AirportEmptyState()
            else
              AirportList(airports: displayList),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorBanner(
    BuildContext context,
    ThemeData theme,
    AirportInfoProvider provider,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: theme.colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              provider.dataSourceSwitchError!,
              style: TextStyle(color: theme.colorScheme.onErrorContainer),
            ),
          ),
          IconButton(
            onPressed: () => provider.clearDataSourceError(),
            icon: const Icon(Icons.close),
            color: theme.colorScheme.onErrorContainer,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
