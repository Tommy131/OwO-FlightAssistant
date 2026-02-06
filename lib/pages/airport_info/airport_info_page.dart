import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../apps/data/airports_database.dart';
import '../../../apps/models/airport_detail_data.dart';
import '../../apps/providers/simulator/simulator_provider.dart';
import '../../../apps/services/airport_detail_service.dart';
import '../../../apps/services/weather_service.dart';
import '../../../core/theme/app_theme_data.dart';
import 'widgets/airport_card.dart';

/// 机场信息页面
class AirportInfoPage extends StatefulWidget {
  const AirportInfoPage({super.key});

  @override
  State<AirportInfoPage> createState() => _AirportInfoPageState();
}

class _AirportInfoPageState extends State<AirportInfoPage> {
  final List<AirportInfo> _userSavedAirports = [];
  final Map<String, MetarData> _airportMetars = {};
  final Map<String, String> _metarErrors = {};
  final Map<String, AirportDetailData> _airportDetails = {};
  final Map<String, String> _fetchErrors = {};
  bool _isLoading = false;
  static const String _storageKey = 'saved_airports';
  final AirportDetailService _detailService = AirportDetailService();
  AirportDataSource _currentDataSource = AirportDataSource.aviationApi;

  // Track the last known ICAOs to avoid unnecessary data fetching
  String? _lastNearestIcao;
  String? _lastDestIcao;
  String? _lastAltIcao;

  @override
  void initState() {
    super.initState();
    _loadDataSource();
    _loadSavedAirports();
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
        if (mounted) {
          _refreshAllData();
        }
      });
    }
  }

  Future<void> _loadDataSource() async {
    final source = await _detailService.getDataSource();
    if (mounted) {
      setState(() {
        _currentDataSource = source;
      });
    }
  }

  Future<void> _loadSavedAirports() async {
    final prefs = await SharedPreferences.getInstance();
    final savedIcaoCodes = prefs.getStringList(_storageKey) ?? [];

    final loadedAirports = <AirportInfo>[];
    for (final icao in savedIcaoCodes) {
      final airport = AirportsDatabase.findByIcao(icao);
      if (airport != null && !loadedAirports.any((a) => a.icaoCode == icao)) {
        loadedAirports.add(airport);
      }
    }

    if (mounted) {
      setState(() {
        _userSavedAirports.clear();
        _userSavedAirports.addAll(loadedAirports);
      });
      _refreshAllData();
    }
  }

  Future<void> _saveSavedAirportsToStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final icaoCodes = _userSavedAirports.map((a) => a.icaoCode).toList();
    await prefs.setStringList(_storageKey, icaoCodes);
  }

  /// Refreshes data for all airports currently in display
  Future<void> _refreshAllData() async {
    final airports = _displayList;
    if (airports.isEmpty) return;

    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    final weatherService = WeatherService();
    final prefs = await SharedPreferences.getInstance();
    final expiryMinutes = prefs.getInt('metar_cache_expiry') ?? 60;
    final now = DateTime.now();

    for (final airport in airports) {
      // Check if we already have a fresh METAR
      final existingMetar = _airportMetars[airport.icaoCode];
      if (existingMetar != null &&
          now.difference(existingMetar.timestamp).inMinutes < expiryMinutes) {
        // Just continue if METAR is still fresh
      } else {
        // Fetch METAR
        try {
          final metar = await weatherService.fetchMetar(airport.icaoCode);
          if (mounted) {
            setState(() {
              if (metar != null) {
                _airportMetars[airport.icaoCode] = metar;
                _metarErrors.remove(airport.icaoCode);
              } else {
                _metarErrors[airport.icaoCode] = '无法获取气象报文';
              }
            });
          }
        } catch (e) {
          if (mounted) {
            setState(() {
              _metarErrors[airport.icaoCode] = '气象报文获取失败: $e';
            });
          }
        }
      }

      // Fetch detailed airport info
      try {
        final detail = await _detailService.fetchAirportDetail(
          airport.icaoCode,
        );
        if (detail != null && mounted) {
          setState(() {
            _airportDetails[airport.icaoCode] = detail;
            _fetchErrors.remove(airport.icaoCode);
          });
        } else if (mounted) {
          setState(() {
            _fetchErrors[airport.icaoCode] = '无法获取详细信息';
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _fetchErrors[airport.icaoCode] = '详细信息获取失败: $e';
          });
        }
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Computes the dynamic list: Simulator Topped + User Saved
  List<AirportInfo> get _displayList {
    final simProvider = context.read<SimulatorProvider>();
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
    for (final saved in _userSavedAirports) {
      if (!seenIcaos.contains(saved.icaoCode)) {
        result.add(saved);
      }
    }
    return result;
  }

  void _showAirportPickerDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final airports = AirportsDatabase.allAirports;
        return AlertDialog(
          title: const Text('添加机场'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: ListView.builder(
              itemCount: airports.length,
              itemBuilder: (context, index) {
                final airport = airports[index];
                final isSaved = _userSavedAirports.any(
                  (a) => a.icaoCode == airport.icaoCode,
                );

                return ListTile(
                  title: Text(airport.displayName),
                  subtitle: Text(
                    'LAT: ${airport.latitude}, LON: ${airport.longitude}',
                  ),
                  trailing: isSaved
                      ? const Icon(Icons.check, color: Colors.green)
                      : null,
                  onTap: () {
                    if (!isSaved) {
                      setState(() {
                        _userSavedAirports.add(airport);
                      });
                      _saveSavedAirportsToStorage();
                      _refreshAllData();
                    }
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
          ],
        );
      },
    );
  }

  void _saveAirportLocally(AirportInfo airport) {
    if (!_userSavedAirports.any((a) => a.icaoCode == airport.icaoCode)) {
      setState(() {
        _userSavedAirports.add(airport);
      });
      _saveSavedAirportsToStorage();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ 已保存机场 ${airport.icaoCode} 到列表')),
      );
    }
  }

  void _removeAirport(AirportInfo airport) {
    setState(() {
      _userSavedAirports.removeWhere((a) => a.icaoCode == airport.icaoCode);
    });
    _saveSavedAirportsToStorage();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayList = _displayList;

    return Container(
      color: theme.scaffoldBackgroundColor,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppThemeData.spacingLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(theme),
            const SizedBox(height: AppThemeData.spacingMedium),
            if (displayList.isEmpty)
              _buildEmptyState(theme)
            else
              ...displayList.map(
                (airport) => Padding(
                  padding: const EdgeInsets.only(
                    bottom: AppThemeData.spacingMedium,
                  ),
                  child: AirportCard(
                    airport: airport,
                    metar: _airportMetars[airport.icaoCode],
                    metarError: _metarErrors[airport.icaoCode],
                    detail: _airportDetails[airport.icaoCode],
                    detailError: _fetchErrors[airport.icaoCode],
                    isSaved: _userSavedAirports.any(
                      (a) => a.icaoCode == airport.icaoCode,
                    ),
                    isLoading: _isLoading,
                    onSave: () => _saveAirportLocally(airport),
                    onRemove: () => _removeAirport(airport),
                    onRefreshDetail: () async {
                      await _detailService.clearCache(airport.icaoCode);
                      _refreshAllData();
                    },
                    currentDataSourceName: _currentDataSource.displayName,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Row(
      children: [
        Text(
          '机场信息',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        _buildDataSourcePicker(theme),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: _showAirportPickerDialog,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('添加机场'),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: _isLoading ? null : _refreshAllData,
          icon: _isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh),
          tooltip: '刷新数据',
        ),
      ],
    );
  }

  Widget _buildDataSourcePicker(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.storage, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          DropdownButton<AirportDataSource>(
            value: _currentDataSource,
            underline: const SizedBox(),
            isDense: true,
            style: theme.textTheme.bodySmall,
            onChanged: (source) async {
              if (source != null) {
                await _detailService.setDataSource(source);
                setState(() {
                  _currentDataSource = source;
                });
                _refreshAllData();
              }
            },
            items: AirportDataSource.values.map((source) {
              return DropdownMenuItem(
                value: source,
                child: Text(source.displayName),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(AppThemeData.spacingLarge * 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppThemeData.borderRadiusMedium),
        border: Border.all(color: AppThemeData.getBorderColor(theme)),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.flight_takeoff,
              size: 64,
              color: theme.colorScheme.outline.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              '暂无列表项',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '连接模拟器或手动添加机场',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
