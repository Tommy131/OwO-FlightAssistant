import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../apps/data/airports_database.dart';
import '../../../apps/models/airport_detail_data.dart';
import '../../apps/providers/simulator/simulator_provider.dart';
import '../../../apps/services/airport_detail_service.dart';
import '../../../apps/services/weather_service.dart';
import '../../../core/theme/app_theme_data.dart';
import '../../core/utils/logger.dart';
import '../../../core/widgets/common/dialog.dart';
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
  final Map<String, AirportDetailData> _onlineDetails = {};
  final Map<String, String> _fetchErrors = {};
  bool _isLoading = false;
  String? _dataSourceSwitchError;
  bool _skipAllUpdates = false;
  bool _updateAllUpdates = false;
  static const String _storageKey = 'saved_airports';
  final AirportDetailService _detailService = AirportDetailService();
  AirportDataSource _currentDataSource = AirportDataSource.lnmData;
  List<AirportDataSource> _availableDataSources = [];

  // Track the last known ICAOs to avoid unnecessary data fetching
  String? _lastNearestIcao;
  String? _lastDestIcao;
  String? _lastAltIcao;

  @override
  void initState() {
    super.initState();
    _initializeAppInfo();
  }

  Future<void> _initializeAppInfo() async {
    // 1. 加载数据源配置
    await _loadDataSource();

    // 2. 加载机场基础数据库 (从 LNM 或 X-Plane)
    if (AirportsDatabase.isEmpty) {
      if (mounted) setState(() => _isLoading = true);
      try {
        final prefs = await SharedPreferences.getInstance();
        final lnmPath = prefs.getString('lnm_nav_data_path');
        final xplanePath = prefs.getString('xplane_nav_data_path');
        AppLogger.debug(
          'Initialization check - LNM Path: $lnmPath, X-Plane Path: $xplanePath',
        );

        final airports = await _detailService.loadAllAirports(
          source: _currentDataSource,
        );
        if (airports.isNotEmpty) {
          AirportsDatabase.updateAirports(
            airports
                .map(
                  (a) => AirportInfo(
                    icaoCode: a['icao'] ?? '',
                    iataCode: a['iata'] ?? '',
                    nameChinese: a['name'] ?? '',
                    latitude: (a['lat'] as num?)?.toDouble() ?? 0.0,
                    longitude: (a['lon'] as num?)?.toDouble() ?? 0.0,
                  ),
                )
                .toList(),
          );
        } else {
          setState(() {
            _dataSourceSwitchError = '无法从当前数据源加载机场列表，请检查路径设置。';
          });
        }
      } catch (e) {
        setState(() {
          _dataSourceSwitchError = '初始化机场数据库失败: $e';
        });
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }

    // 3. 加载已保存机场
    await _loadSavedAirports();
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
    final available = await _detailService.getAvailableDataSources();
    if (mounted) {
      setState(() {
        // 如果当前是在线 API，自动切换到离线源（因为主选器已删除该项）
        if (source == AirportDataSource.aviationApi) {
          _currentDataSource = available.contains(AirportDataSource.xplaneData)
              ? AirportDataSource.xplaneData
              : AirportDataSource.lnmData;
          _detailService.setDataSource(_currentDataSource);
        } else {
          _currentDataSource = source;
        }
        _availableDataSources = available;
      });
    }
  }

  Future<void> _loadSavedAirports() async {
    final prefs = await SharedPreferences.getInstance();
    final savedIcaoCodes = prefs.getStringList(_storageKey) ?? [];

    final loadedAirports = <AirportInfo>[];
    for (final icao in savedIcaoCodes) {
      final airport =
          AirportsDatabase.findByIcao(icao) ?? AirportInfo.placeholder(icao);
      if (!loadedAirports.any((a) => a.icaoCode == icao)) {
        loadedAirports.add(airport);
      }
    }

    if (mounted) {
      setState(() {
        _userSavedAirports.clear();
        _userSavedAirports.addAll(loadedAirports);

        // 初始化缓存中的数据，避免切换 Tab 时闪烁或重新请求
        final weatherService = WeatherService();
        final expiryMinutes = prefs.getInt('metar_cache_expiry') ?? 60;
        for (final airport in loadedAirports) {
          final cachedMetar = weatherService.getCachedMetar(airport.icaoCode);
          if (cachedMetar != null && !cachedMetar.isExpired(expiryMinutes)) {
            _airportMetars[airport.icaoCode] = cachedMetar;
          }
          // 异步预加载本地和在线缓存
          _detailService.getCachedLocalDetail(airport.icaoCode).then((local) {
            if (local != null && mounted) {
              setState(() => _airportDetails[airport.icaoCode] = local);
            }
          });
          _detailService.getCachedOnlineDetail(airport.icaoCode).then((online) {
            if (online != null && mounted) {
              setState(() => _onlineDetails[airport.icaoCode] = online);
            }
          });
        }
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
  Future<void> _refreshAllData({bool force = false}) async {
    // 刷新可用数据源（检查 token 消耗是否超标）
    await _loadDataSource();

    final airports = _displayList;
    if (airports.isEmpty) return;

    final weatherService = WeatherService();
    final prefs = await SharedPreferences.getInstance();
    final expiryMinutes = prefs.getInt('metar_cache_expiry') ?? 60;

    // 预检查：如果所有显示的数据都已经缓存且未过期，则不需要显示加载状态
    bool needsFetch = force;
    if (!force) {
      for (final airport in airports) {
        final existingMetar = _airportMetars[airport.icaoCode];
        if (existingMetar == null || existingMetar.isExpired(expiryMinutes)) {
          needsFetch = true;
          break;
        }
        // 机场详细信息也需要检查
        final detail = _airportDetails[airport.icaoCode];
        final airportExpiryDays = prefs.getInt('airport_data_expiry') ?? 30;
        if (detail == null || detail.isExpired(airportExpiryDays)) {
          needsFetch = true;
          break;
        }
      }
    }

    if (needsFetch && mounted) {
      setState(() {
        _isLoading = true;
        _skipAllUpdates = false;
        _updateAllUpdates = false;
      });
      showLoadingDialog(context: context, message: '正在同步机场数据...');
    }

    for (final airport in airports) {
      // Fetch METAR
      final existingMetar = _airportMetars[airport.icaoCode];
      if (force ||
          existingMetar == null ||
          existingMetar.isExpired(expiryMinutes)) {
        try {
          final metar = await weatherService.fetchMetar(
            airport.icaoCode,
            forceRefresh: force,
          );
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
      final detail = _airportDetails[airport.icaoCode];
      final airportExpiryDays = prefs.getInt('airport_data_expiry') ?? 30;
      if (force || detail == null || detail.isExpired(airportExpiryDays)) {
        try {
          final freshDetail = await _detailService.fetchAirportDetail(
            airport.icaoCode,
            forceRefresh: force,
          );
          if (freshDetail != null && mounted) {
            await _processAirportDetailUpdate(airport, freshDetail);
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
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
      if (needsFetch) {
        hideLoadingDialog(context);
      }
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

  /// 处理机场详细数据更新的逻辑
  Future<void> _processAirportDetailUpdate(
    AirportInfo airport,
    AirportDetailData freshData,
  ) async {
    // 根据数据源选择对应的现有数据进行比对
    final existing = freshData.dataSource == AirportDataSourceType.aviationApi
        ? _onlineDetails[airport.icaoCode]
        : _airportDetails[airport.icaoCode];

    // 情况 A: 原本没数据，或者是占位符数据 (直接更新)
    if (existing == null) {
      _applyUpdate(airport, freshData);
      return;
    }

    // 情况 B: 对比差异不显著
    if (!existing.hasSignificantDifference(freshData)) {
      // 在线 API 数据如果差异不显著也直接更新，或者可以选择合并
      _applyUpdate(airport, freshData);
      return;
    }

    // 情况 C: 存在显著差异，根据全局状态处理
    if (_updateAllUpdates) {
      _applyUpdate(airport, freshData);
      return;
    }
    if (_skipAllUpdates) {
      return;
    }

    // 情况 D: 提示用户确认
    if (!mounted) return;
    final userChoice = await _showUpdateConfirmationDialog(airport, freshData);

    if (userChoice == 'new') {
      _applyUpdate(airport, freshData);
    } else if (userChoice == 'all_new') {
      setState(() => _updateAllUpdates = true);
      _applyUpdate(airport, freshData);
    } else if (userChoice == 'all_skip') {
      setState(() => _skipAllUpdates = true);
    }
    // 'old' 或者关闭弹窗则不更新
  }

  void _applyUpdate(AirportInfo airport, AirportDetailData data) {
    if (!mounted) return;
    setState(() {
      if (data.dataSource == AirportDataSourceType.aviationApi) {
        _onlineDetails[airport.icaoCode] = data;
      } else {
        _airportDetails[airport.icaoCode] = data;
      }

      _fetchErrors.remove(airport.icaoCode);

      // 如果数据中带有气象，也更新气象缓存以保持一致性
      if (data.metar != null) {
        _airportMetars[airport.icaoCode] = data.metar!;
      }

      // 如果是本地数据源更新，且机场在已保存列表中，则更新列表项显示（如名称）
      if (data.dataSource != AirportDataSourceType.aviationApi) {
        final index = _userSavedAirports.indexWhere(
          (a) => a.icaoCode == airport.icaoCode,
        );
        if (index != -1) {
          _userSavedAirports[index] = AirportInfo.fromDetail(data);
        }
      }
    });
  }

  Future<String?> _showUpdateConfirmationDialog(
    AirportInfo airport,
    AirportDetailData freshData,
  ) async {
    final existing = _airportDetails[airport.icaoCode]!;

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: Text('机场数据更新: ${airport.icaoCode}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('检测到新旧数据存在显著差异，请选择保留哪一份：'),
              const SizedBox(height: 16),
              _buildDiffInfo('机场名称', existing.name, freshData.name),
              _buildDiffInfo(
                '坐标',
                '${existing.latitude.toStringAsFixed(3)}, ${existing.longitude.toStringAsFixed(3)}',
                '${freshData.latitude.toStringAsFixed(3)}, ${freshData.longitude.toStringAsFixed(3)}',
              ),
              _buildDiffInfo(
                '跑道数量',
                existing.runways.length.toString(),
                freshData.runways.length.toString(),
              ),
              const SizedBox(height: 12),
              Text(
                '新数据源: ${freshData.dataSourceDisplay}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'all_skip'),
              child: const Text('全部跳过'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'old'),
              child: const Text('保留旧版本'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, 'new'),
              child: const Text('使用新数据'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, 'all_new'),
              child: const Text('一键更新所有'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDiffInfo(String label, String oldVal, String newVal) {
    final hasDiff = oldVal != newVal;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text('$label:', style: const TextStyle(color: Colors.grey)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  oldVal,
                  style: TextStyle(
                    color: hasDiff ? Colors.red : null,
                    fontSize: 13,
                  ),
                ),
                if (hasDiff)
                  Text(
                    newVal,
                    style: const TextStyle(
                      color: Colors.green,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAirportPickerDialog() {
    final TextEditingController searchController = TextEditingController();
    String searchQuery = '';
    AirportInfo? matchedAirport;
    bool addedByInput = false;
    List<AirportInfo> filteredAirports = [];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void updateMatch(String value) {
              final query = value.trim();
              if (query.isEmpty) {
                matchedAirport = null;
                addedByInput = false;
                return;
              }
              final byIcao = AirportsDatabase.findByIcao(query);

              // 查找 IATA
              AirportInfo? byIata;
              final upperCode = query.toUpperCase();
              for (final airport in AirportsDatabase.allAirports) {
                if (airport.iataCode.toUpperCase() == upperCode) {
                  byIata = airport;
                  break;
                }
              }

              matchedAirport = byIcao ?? byIata;

              // 如果本地数据库没找到，但输入看起来像 ICAO 代码 (4位字母/数字)，允许手动添加
              if (matchedAirport == null &&
                  query.length == 4 &&
                  RegExp(r'^[A-Z0-9]{4}$').hasMatch(query.toUpperCase())) {
                matchedAirport = AirportInfo.placeholder(query);
              }

              addedByInput = false;
              if (matchedAirport != null) {
                final isSaved = _userSavedAirports.any(
                  (a) => a.icaoCode == matchedAirport!.icaoCode,
                );
                if (!isSaved) {
                  // 不再自动保存，仅标记已匹配
                  addedByInput = true;
                }
              }
            }

            return AlertDialog(
              title: const Text('搜索并添加机场'),
              content: SizedBox(
                width: double.maxFinite,
                height: 500,
                child: Column(
                  children: [
                    TextField(
                      controller: searchController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: '输入 ICAO、三字码、名称或经纬度',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                        helperText:
                            '支持 ICAO/IATA 代码、机场名、经纬度 (如 31.2, 121.4) 搜索',
                      ),
                      onChanged: (value) {
                        setDialogState(() {
                          searchQuery = value.trim();
                          filteredAirports = searchQuery.isEmpty
                              ? []
                              : AirportsDatabase.search(searchQuery);
                          updateMatch(value);
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    if (matchedAirport != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.primaryContainer.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              matchedAirport!.nameChinese,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                _buildBadge(
                                  context,
                                  'ICAO',
                                  matchedAirport!.icaoCode,
                                ),
                                if (matchedAirport!.iataCode.isNotEmpty) ...[
                                  const SizedBox(width: 8),
                                  _buildBadge(
                                    context,
                                    'IATA',
                                    matchedAirport!.iataCode,
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '坐标: ${matchedAirport!.latitude.toStringAsFixed(3)}, '
                              '${matchedAirport!.longitude.toStringAsFixed(3)}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              addedByInput
                                  ? '已匹配到机场，可点击下方列表项加入'
                                  : (_userSavedAirports.any(
                                          (a) =>
                                              a.icaoCode ==
                                              matchedAirport!.icaoCode,
                                        )
                                        ? '机场已在列表中'
                                        : '已匹配到机场，可点击列表项加入'),
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: filteredAirports.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    searchQuery.isEmpty
                                        ? Icons.search_rounded
                                        : Icons.info_outline,
                                    size: 48,
                                    color: Colors.grey.withValues(alpha: 0.5),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    searchQuery.isEmpty ? '暂无机场数据' : '未找到匹配的机场',
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: filteredAirports.length,
                              itemBuilder: (context, index) {
                                final airport = filteredAirports[index];
                                final isSaved = _userSavedAirports.any(
                                  (a) => a.icaoCode == airport.icaoCode,
                                );

                                return ListTile(
                                  isThreeLine: true,
                                  title: Text(
                                    airport.nameChinese,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          _buildBadge(
                                            context,
                                            'ICAO',
                                            airport.icaoCode,
                                          ),
                                          if (airport.iataCode.isNotEmpty) ...[
                                            const SizedBox(width: 8),
                                            _buildBadge(
                                              context,
                                              'IATA',
                                              airport.iataCode,
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '坐标: ${airport.latitude.toStringAsFixed(3)}, ${airport.longitude.toStringAsFixed(3)}',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                  trailing: isSaved
                                      ? const Icon(
                                          Icons.check_circle,
                                          color: Colors.green,
                                        )
                                      : const Icon(Icons.add_circle_outline),
                                  onTap: () {
                                    if (!isSaved) {
                                      _saveAirportLocally(airport);
                                      _refreshAllData();
                                    } else {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            '机场 ${airport.icaoCode} 已在列表中',
                                          ),
                                        ),
                                      );
                                    }
                                    Navigator.pop(context);
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
                  onPressed: () => Navigator.pop(context),
                  child: const Text('关闭'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _saveAirportLocally(AirportInfo airport) async {
    if (!_userSavedAirports.any((a) => a.icaoCode == airport.icaoCode)) {
      setState(() {
        _userSavedAirports.add(airport);
      });
      _saveSavedAirportsToStorage();

      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        SnackBar(content: Text('✅ 已保存机场 ${airport.icaoCode} 到列表')),
      );

      // 保存后立即触发双源缓存
      // 1. 本地数据库缓存
      _detailService
          .fetchAirportDetail(
            airport.icaoCode,
            forceRefresh: true,
            preferredSource: _currentDataSource,
          )
          .then((detail) {
            if (detail != null && mounted) {
              setState(() => _airportDetails[airport.icaoCode] = detail);
            }
          });

      // 2. 在线 API 缓存
      _detailService
          .fetchAirportDetail(
            airport.icaoCode,
            forceRefresh: true,
            preferredSource: AirportDataSource.aviationApi,
          )
          .then((online) {
            if (online != null && mounted) {
              setState(() => _onlineDetails[airport.icaoCode] = online);
            }
          });
    }
  }

  void _removeAirport(AirportInfo airport) {
    setState(() {
      _userSavedAirports.removeWhere((a) => a.icaoCode == airport.icaoCode);
    });
    _saveSavedAirportsToStorage();
  }

  Widget _buildBadge(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
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
            if (_dataSourceSwitchError != null) _buildErrorBanner(theme),
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
                    onlineDetail: _onlineDetails[airport.icaoCode],
                    detailError: _fetchErrors[airport.icaoCode],
                    isSaved: _userSavedAirports.any(
                      (a) => a.icaoCode == airport.icaoCode,
                    ),
                    isLoading: _isLoading,
                    onSave: () => _saveAirportLocally(airport),
                    onRemove: () => _removeAirport(airport),
                    onRefreshDetail: () async {
                      showLoadingDialog(
                        context: context,
                        message: '正在更新本地缓存...',
                      );
                      setState(() => _isLoading = true);
                      try {
                        // 1. 确定当前数据源（非在线）
                        final source = await _detailService.getDataSource();
                        // 2. 仅清除该特定来源的缓存
                        await _detailService.clearAirportCache(
                          all: false,
                          icao: airport.icaoCode,
                          type: source.dataSourceType,
                        );
                        // 3. 重新获取该机场当前源详情
                        final fresh = await _detailService.fetchAirportDetail(
                          airport.icaoCode,
                          forceRefresh: true,
                          preferredSource: source,
                        );
                        if (fresh != null && mounted) {
                          await _processAirportDetailUpdate(airport, fresh);
                        }
                      } catch (e) {
                        if (mounted) {
                          setState(() {
                            _fetchErrors[airport.icaoCode] = '本地刷新失败: $e';
                          });
                        }
                      } finally {
                        if (mounted) {
                          setState(() => _isLoading = false);
                          hideLoadingDialog(context);
                        }
                      }
                    },
                    onOnlineFetch: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final prefs = await SharedPreferences.getInstance();
                      final expiryDays =
                          prefs.getInt('airport_data_expiry') ?? 30;
                      final onlineD = _onlineDetails[airport.icaoCode];

                      // 1. 检查 API 是否可用/超标
                      final isApiAvailable = await _detailService
                          .isDataSourceAvailable(AirportDataSource.aviationApi);
                      if (!isApiAvailable) {
                        if (mounted) {
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('❌ 无法使用在线 API：未配置 Token 或已超过消耗阈值'),
                            ),
                          );
                        }
                        return;
                      }

                      // 2. 检查缓存是否仍然有效（未过期则不重复请求）
                      if (onlineD != null && !onlineD.isExpired(expiryDays)) {
                        if (mounted) {
                          messenger.showSnackBar(
                            const SnackBar(content: Text('ℹ️ 在线 API 缓存依然有效')),
                          );
                        }
                        return;
                      }

                      // 3. 执行在线获取
                      showLoadingDialog(
                        context: context,
                        message: '正在从在线 API 获取...',
                      );
                      setState(() => _isLoading = true);
                      try {
                        // 清除在线缓存（仅清除在线部分）
                        await _detailService.clearAirportCache(
                          all: false,
                          icao: airport.icaoCode,
                          type: AirportDataSourceType.aviationApi,
                        );

                        final freshDetail = await _detailService
                            .fetchAirportDetail(
                              airport.icaoCode,
                              forceRefresh: true,
                              preferredSource: AirportDataSource.aviationApi,
                            );
                        if (freshDetail != null && mounted) {
                          await _processAirportDetailUpdate(
                            airport,
                            freshDetail,
                          );
                          await _processAirportDetailUpdate(
                            airport,
                            freshDetail,
                          );
                          if (mounted) {
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('✅ 已成功从在线 API 获取补充内容'),
                              ),
                            );
                          }
                        }
                      } catch (e) {
                        if (mounted) {
                          setState(
                            () => _fetchErrors[airport.icaoCode] = '在线获取失败: $e',
                          );
                        }
                      } finally {
                        if (mounted) {
                          setState(() => _isLoading = false);
                          hideLoadingDialog(context);
                        }
                      }
                    },
                    onRefreshMetar: () async {
                      showLoadingDialog(
                        context: context,
                        message: '正在刷新气象数据...',
                      );
                      setState(() => _isLoading = true);
                      try {
                        final weatherService = WeatherService();
                        final metar = await weatherService.fetchMetar(
                          airport.icaoCode,
                          forceRefresh: true,
                        );
                        if (mounted) {
                          setState(() {
                            if (metar != null) {
                              _airportMetars[airport.icaoCode] = metar;
                              _metarErrors.remove(airport.icaoCode);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('✅ 气象数据已更新')),
                              );
                            } else {
                              _metarErrors[airport.icaoCode] = '无法获取气象报文';
                            }
                          });
                        }
                      } catch (e) {
                        if (mounted) {
                          setState(() {
                            _metarErrors[airport.icaoCode] = '刷新失败: $e';
                          });
                        }
                      } finally {
                        if (mounted) {
                          setState(() => _isLoading = false);
                          hideLoadingDialog(context);
                        }
                      }
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorBanner(ThemeData theme) {
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
              _dataSourceSwitchError!,
              style: TextStyle(color: theme.colorScheme.onErrorContainer),
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _dataSourceSwitchError = null),
            icon: const Icon(Icons.close),
            color: theme.colorScheme.onErrorContainer,
            visualDensity: VisualDensity.compact,
          ),
        ],
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
          onPressed: _isLoading ? null : () => _refreshAllData(force: true),
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
              if (source != null && source != _currentDataSource) {
                setState(() => _isLoading = true);
                try {
                  final airports = await _detailService.loadAllAirports(
                    source: source,
                  );
                  if (airports.isEmpty) {
                    throw '新数据源未包含任何机场数据，切换已取消';
                  }

                  await _detailService.setDataSource(source);
                  AirportsDatabase.updateAirports(
                    airports
                        .map(
                          (a) => AirportInfo(
                            icaoCode: a['icao'] ?? '',
                            iataCode: a['iata'] ?? '',
                            nameChinese: a['name'] ?? '',
                            latitude: (a['lat'] as num?)?.toDouble() ?? 0.0,
                            longitude: (a['lon'] as num?)?.toDouble() ?? 0.0,
                          ),
                        )
                        .toList(),
                  );

                  setState(() {
                    _currentDataSource = source;
                    _dataSourceSwitchError = null;
                  });
                  // 切换数据源后，必须强制刷新，以忽略旧数据源的缓存
                  _refreshAllData(force: true);
                } catch (e) {
                  setState(() {
                    _dataSourceSwitchError = '数据源切换失败: $e';
                  });
                } finally {
                  if (mounted) setState(() => _isLoading = false);
                }
              }
            },
            items: AirportDataSource.values
                .where((s) => s != AirportDataSource.aviationApi)
                .map((source) {
                  final isAvailable = _availableDataSources.contains(source);
                  return DropdownMenuItem(
                    value: source,
                    enabled: isAvailable,
                    child: Row(
                      children: [
                        Text(
                          source.displayName,
                          style: TextStyle(
                            color: isAvailable ? null : theme.disabledColor,
                          ),
                        ),
                        if (!isAvailable) ...[
                          const SizedBox(width: 4),
                          Icon(
                            Icons.lock_outline,
                            size: 12,
                            color: theme.disabledColor,
                          ),
                        ],
                      ],
                    ),
                  );
                })
                .toList(),
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
