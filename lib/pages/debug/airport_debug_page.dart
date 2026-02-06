import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../apps/data/airports_database.dart';
import '../../apps/services/airport_detail_service.dart';

class AirportDebugPage extends StatefulWidget {
  final VoidCallback? onBack;
  const AirportDebugPage({super.key, this.onBack});

  @override
  State<AirportDebugPage> createState() => _AirportDebugPageState();
}

class _AirportDebugPageState extends State<AirportDebugPage> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final AirportDetailService _airportService = AirportDetailService();
  AirportDataSource _currentSource = AirportDataSource.lnmData;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentSource();
  }

  Future<void> _loadCurrentSource() async {
    final source = await _airportService.getDataSource();
    if (mounted) {
      setState(() {
        if (source == AirportDataSource.aviationApi) {
          _currentSource = AirportDataSource.lnmData;
        } else {
          _currentSource = source;
        }
      });
    }
  }

  Future<void> _switchSource(AirportDataSource source) async {
    if (_currentSource == source) return;

    setState(() => _isLoading = true);
    try {
      // 1. 保存新的数据源设置
      await _airportService.setDataSource(source);

      // 2. 加载新数据源的机场列表
      final airports = await _airportService.loadAllAirports(source: source);

      // 3. 更新全局数据库
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

      if (mounted) {
        setState(() {
          _currentSource = source;
          _isLoading = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('已切换至 ${source.displayName}')));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('切换失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allAirports = AirportsDatabase.allAirports;
    final filteredAirports = _searchQuery.isEmpty
        ? allAirports
        : allAirports
              .where(
                (a) =>
                    a.icaoCode.toLowerCase().contains(
                      _searchQuery.toLowerCase(),
                    ) ||
                    a.nameChinese.toLowerCase().contains(
                      _searchQuery.toLowerCase(),
                    ),
              )
              .toList();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('机场数据诊断'),
        centerTitle: false,
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        leading: widget.onBack != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: widget.onBack,
              )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _isLoading ? null : () => _switchSource(_currentSource),
            tooltip: '重新加载当前数据源',
          ),
          IconButton(
            icon: const Icon(Icons.copy_all),
            onPressed: () {
              final icaos = allAirports.map((a) => a.icaoCode).join(', ');
              Clipboard.setData(ClipboardData(text: icaos));
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('已复制所有 ICAO 到剪贴板')));
            },
            tooltip: '复制所有 ICAO',
          ),
        ],
      ),
      body: Column(
        children: [
          // 数据源切换区域
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: theme.cardColor,
              border: Border(
                bottom: BorderSide(color: theme.dividerColor, width: 0.5),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.storage_rounded,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text('当前数据源', style: theme.textTheme.titleSmall),
                    const Spacer(),
                    if (_isLoading)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: AirportDataSource.values
                        .where((s) => s != AirportDataSource.aviationApi)
                        .map((source) {
                          final isSelected = _currentSource == source;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(source.displayName),
                              selected: isSelected,
                              onSelected: _isLoading
                                  ? null
                                  : (selected) {
                                      if (selected) _switchSource(source);
                                    },
                            ),
                          );
                        })
                        .toList(),
                  ),
                ),
              ],
            ),
          ),

          // 状态摘要
          Container(
            padding: const EdgeInsets.all(16),
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.3,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '总计: ${allAirports.length} 机场',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '~${(allAirports.length * 0.5).toStringAsFixed(1)} KB',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: '搜索 ICAO 或名称...',
                    prefixIcon: const Icon(Icons.search),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    filled: true,
                    fillColor: theme.cardColor,
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                _searchController.clear();
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
              ],
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredAirports.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 64,
                          color: theme.disabledColor,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          allAirports.isEmpty ? '数据库为空' : '未找到匹配结果',
                          style: TextStyle(color: theme.disabledColor),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: filteredAirports.length,
                    itemBuilder: (context, index) {
                      final airport = filteredAirports[index];
                      return ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundColor: theme.colorScheme.primaryContainer,
                          child: Text(
                            airport.icaoCode.substring(0, 1),
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          airport.icaoCode,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          airport.nameChinese,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Text(
                          '${airport.latitude.toStringAsFixed(2)}, ${airport.longitude.toStringAsFixed(2)}',
                          style: theme.textTheme.bodySmall,
                        ),
                        onTap: () {
                          Clipboard.setData(
                            ClipboardData(text: airport.icaoCode),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('已复制 ${airport.icaoCode}'),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
