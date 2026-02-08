import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../apps/models/airport_detail_data.dart';
import '../../../apps/models/airport_info.dart';
import '../../../apps/services/airport_detail_service.dart'; // for AirportDataSource/Type
import '../../../core/theme/app_theme_data.dart';
import '../../../core/widgets/common/dialog.dart';
import '../providers/airport_info_provider.dart';
import 'airport_card.dart';

class AirportList extends StatefulWidget {
  final List<AirportInfo> airports;

  const AirportList({super.key, required this.airports});

  @override
  State<AirportList> createState() => _AirportListState();
}

class _AirportListState extends State<AirportList> {
  // Flags for bulk operations in this session - though here we handle single items usually
  bool _skipAllUpdates = false;
  bool _updateAllUpdates = false;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AirportInfoProvider>();

    return Column(
      children: widget.airports.map((airport) {
        return Padding(
          padding: const EdgeInsets.only(bottom: AppThemeData.spacingMedium),
          child: AirportCard(
            airport: airport,
            metar: provider.airportMetars[airport.icaoCode],
            metarError: provider.metarErrors[airport.icaoCode],
            detail: provider.airportDetails[airport.icaoCode],
            onlineDetail: provider.onlineDetails[airport.icaoCode],
            detailError: provider.fetchErrors[airport.icaoCode],
            isSaved: provider.savedAirports.any(
              (a) => a.icaoCode == airport.icaoCode,
            ),
            isLoading: provider.isLoading,
            onSave: () => provider.saveAirport(airport),
            onRemove: () => provider.removeAirport(airport),
            onRefreshDetail: () => provider.refreshSingleAirport(airport),
            onOnlineFetch: () => _handleOnlineFetch(context, provider, airport),
            onRefreshMetar: () =>
                _handleMetarRefresh(context, provider, airport),
          ),
        );
      }).toList(),
    );
  }

  Future<void> _handleMetarRefresh(
    BuildContext context,
    AirportInfoProvider provider,
    AirportInfo airport,
  ) async {
    // We can't easily call a single metar refresh on provider exposed public method
    // But we can trigger refreshData with one airport.
    await provider.refreshData([airport], force: true);
    if (mounted) {
      if (provider.metarErrors.containsKey(airport.icaoCode)) {
        // Error handled by provider state
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('✅ 气象数据已更新')));
      }
    }
  }

  Future<void> _handleOnlineFetch(
    BuildContext context,
    AirportInfoProvider provider,
    AirportInfo airport,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final prefs = await SharedPreferences.getInstance();
    final expiryDays = prefs.getInt('airport_data_expiry') ?? 30;
    final onlineD = provider.onlineDetails[airport.icaoCode];

    // 1. Check API availability
    final isApiAvailable = await provider.isDataSourceAvailable(
      AirportDataSource.aviationApi,
    );
    if (!isApiAvailable) {
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('❌ 无法使用在线 API：未配置 Token 或已超过消耗阈值')),
        );
      }
      return;
    }

    // 2. Check cache
    if (onlineD != null && !onlineD.isExpired(expiryDays)) {
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('ℹ️ 在线 API 缓存依然有效')),
        );
      }
      return;
    }

    // 3. Fetch
    showLoadingDialog(context: context, message: '正在从在线 API 获取...');

    // Clear online cache first
    await provider.clearOnlineCache(airport.icaoCode);

    final freshDetail = await provider.fetchOnlineDetail(airport.icaoCode);

    if (mounted) {
      hideLoadingDialog(context);

      if (freshDetail != null) {
        await _processAirportDetailUpdate(
          context,
          provider,
          airport,
          freshDetail,
        );
        if (mounted) {
          messenger.showSnackBar(
            const SnackBar(content: Text('✅ 已成功从在线 API 获取补充内容')),
          );
        }
      }
    }
  }

  Future<void> _processAirportDetailUpdate(
    BuildContext context,
    AirportInfoProvider provider,
    AirportInfo airport,
    AirportDetailData freshData,
  ) async {
    final existing =
        provider.onlineDetails[airport.icaoCode] ??
        provider.airportDetails[airport.icaoCode];

    if (existing == null || !existing.hasSignificantDifference(freshData)) {
      provider.applyUpdate(airport, freshData);
      return;
    }

    if (_updateAllUpdates) {
      provider.applyUpdate(airport, freshData);
      return;
    }
    if (_skipAllUpdates) {
      return;
    }

    final userChoice = await _showUpdateConfirmationDialog(
      context,
      airport,
      existing,
      freshData,
    );

    if (userChoice == 'new') {
      provider.applyUpdate(airport, freshData);
    } else if (userChoice == 'all_new') {
      setState(() => _updateAllUpdates = true);
      provider.applyUpdate(airport, freshData);
    } else if (userChoice == 'all_skip') {
      setState(() => _skipAllUpdates = true);
    }
  }

  Future<String?> _showUpdateConfirmationDialog(
    BuildContext context,
    AirportInfo airport,
    AirportDetailData existing,
    AirportDetailData freshData,
  ) async {
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
}
