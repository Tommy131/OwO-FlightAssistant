import 'package:flutter/material.dart';
import '../../core/theme/app_theme_data.dart';
import '../../apps/services/app_core/database_loader.dart';

class DataCacheSettingsPage extends StatefulWidget {
  final VoidCallback? onBack;

  const DataCacheSettingsPage({super.key, this.onBack});

  @override
  State<DataCacheSettingsPage> createState() => _DataCacheSettingsPageState();
}

class _DataCacheSettingsPageState extends State<DataCacheSettingsPage> {
  bool _isLoading = true;
  int _metarExpiryMinutes = 60;
  int _airportExpiryDays = 30;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = DatabaseSettingsService();
    await settings.ensureSynced();
    final metarExpiry =
        await settings.getInt(DatabaseSettingsService.metarExpiryKey) ?? 60;
    final airportExpiry =
        await settings.getInt(DatabaseSettingsService.airportExpiryKey) ?? 30;
    setState(() {
      _metarExpiryMinutes = metarExpiry;
      _airportExpiryDays = airportExpiry;
      _isLoading = false;
    });
  }

  Future<void> _saveMetarExpiry(int minutes) async {
    final settings = DatabaseSettingsService();
    await settings.setInt(DatabaseSettingsService.metarExpiryKey, minutes);
    setState(() => _metarExpiryMinutes = minutes);
  }

  Future<void> _saveAirportExpiry(int days) async {
    final settings = DatabaseSettingsService();
    await settings.setInt(DatabaseSettingsService.airportExpiryKey, days);
    setState(() => _airportExpiryDays = days);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('数据缓存设置'),
        centerTitle: false,
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        leading: widget.onBack != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: widget.onBack,
              )
            : null,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppThemeData.spacingMedium),
              children: [
                _buildSection(
                  context,
                  title: '气象报文 (METAR)',
                  description: '设置自动刷新的时间间隔以及缓存有效期。有效期内的数据将直接显示，不会重新请求。',
                  child: Column(
                    children: [
                      _buildSliderTile(
                        context,
                        title: '有效期时长',
                        value: _metarExpiryMinutes.toDouble(),
                        min: 15,
                        max: 240,
                        divisions: 15,
                        unit: '分钟',
                        onChanged: (val) => _saveMetarExpiry(val.toInt()),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '建议值: 60 分钟。设置为较短时间可获取更实时的天气，但会增加网络请求。',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppThemeData.spacingLarge),
                _buildSection(
                  context,
                  title: '机场详情数据',
                  description: '机场跑道、频率等详细信息的本地缓存有效期。',
                  child: Column(
                    children: [
                      _buildSliderTile(
                        context,
                        title: '有效期时长',
                        value: _airportExpiryDays.toDouble(),
                        min: 1,
                        max: 180,
                        divisions: 179,
                        unit: '天',
                        onChanged: (val) => _saveAirportExpiry(val.toInt()),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required String description,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppThemeData.spacingMedium),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppThemeData.borderRadiusMedium),
        border: Border.all(
          color: AppThemeData.getBorderColor(theme).withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: AppThemeData.spacingMedium),
          child,
        ],
      ),
    );
  }

  Widget _buildSliderTile(
    BuildContext context, {
    required String title,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String unit,
    required ValueChanged<double> onChanged,
  }) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: theme.textTheme.bodyMedium),
            Text(
              '${value.toInt()} $unit',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          label: '${value.toInt()} $unit',
          onChanged: onChanged,
        ),
      ],
    );
  }
}
