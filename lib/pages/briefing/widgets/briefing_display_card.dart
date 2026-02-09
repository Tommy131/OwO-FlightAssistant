import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../apps/models/flight_briefing.dart';
import '../../../apps/models/airport_detail_data.dart';
import '../../../apps/services/weather_service.dart';
import '../../../core/theme/app_theme_data.dart';

/// 简报显示卡片组件
class BriefingDisplayCard extends StatelessWidget {
  final FlightBriefing briefing;

  const BriefingDisplayCard({super.key, required this.briefing});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppThemeData.spacingLarge),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题栏
          _buildHeader(context, theme),
          const SizedBox(height: 24),

          // 航班信息 - 蓝色主题
          _buildColoredSection(
            theme: theme,
            title: '航班信息',
            icon: Icons.flight,
            color: Colors.blue,
            children: [
              _buildInfoRow('航班号', briefing.formattedFlightNumber),
              _buildInfoRow('生成时间', briefing.formattedGeneratedTime),
              _buildAirportInfoRow(
                '起飞机场',
                briefing.departureAirport,
                Colors.green,
              ),
              _buildAirportInfoRow(
                '到达机场',
                briefing.arrivalAirport,
                Colors.orange,
              ),
              if (briefing.alternateAirport != null)
                _buildAirportInfoRow(
                  '备降机场',
                  briefing.alternateAirport!,
                  Colors.purple,
                ),
            ],
          ),
          const SizedBox(height: AppThemeData.spacingLarge),

          // 航路信息 - 青色主题
          _buildColoredSection(
            theme: theme,
            title: '航路信息',
            icon: Icons.route,
            color: Colors.cyan,
            children: [
              _buildInfoRow('航路', briefing.route ?? 'DCT'),
              _buildInfoRow(
                '巡航高度',
                briefing.cruiseAltitude != null
                    ? 'FL${(briefing.cruiseAltitude! / 100).toStringAsFixed(0)}'
                    : 'N/A',
              ),
              _buildInfoRow(
                '距离',
                briefing.distance != null
                    ? '${briefing.distance!.toStringAsFixed(0)} NM'
                    : 'N/A',
              ),
              _buildInfoRow(
                '预计飞行时间',
                briefing.estimatedFlightTime != null
                    ? '${(briefing.estimatedFlightTime! / 60).floor()}h ${briefing.estimatedFlightTime! % 60}min'
                    : 'N/A',
              ),
            ],
          ),
          const SizedBox(height: AppThemeData.spacingLarge),

          // 天气信息 - 靛蓝主题
          _buildWeatherSection(theme),
          const SizedBox(height: AppThemeData.spacingLarge),

          // 跑道信息 - 深橙主题
          _buildColoredSection(
            theme: theme,
            title: '跑道信息',
            icon: Icons.airplanemode_active,
            color: Colors.deepOrange,
            children: [
              _buildRunwayInfoRow('起飞跑道', briefing.departureRunway, true),
              _buildRunwayInfoRow('到达跑道', briefing.arrivalRunway, false),
            ],
          ),
          const SizedBox(height: AppThemeData.spacingLarge),

          // 燃油计划 - 琥珀色主题
          _buildColoredSection(
            theme: theme,
            title: '燃油计划',
            icon: Icons.local_gas_station,
            color: Colors.amber.shade700,
            children: [
              _buildInfoRow(
                '航程燃油',
                briefing.tripFuel != null
                    ? '${briefing.tripFuel!.toStringAsFixed(0)} kg'
                    : 'N/A',
              ),
              if (briefing.alternateFuel != null && briefing.alternateFuel! > 0)
                _buildInfoRow(
                  '备降燃油',
                  '${briefing.alternateFuel!.toStringAsFixed(0)} kg',
                ),
              _buildInfoRow(
                '储备燃油',
                briefing.reserveFuel != null
                    ? '${briefing.reserveFuel!.toStringAsFixed(0)} kg'
                    : 'N/A',
              ),
              _buildInfoRow(
                '滑行燃油',
                briefing.taxiFuel != null
                    ? '${briefing.taxiFuel!.toStringAsFixed(0)} kg'
                    : 'N/A',
              ),
              const Divider(height: 24),
              _buildInfoRow(
                '总燃油',
                briefing.totalFuel != null
                    ? '${briefing.totalFuel!.toStringAsFixed(0)} kg'
                    : 'N/A',
                isBold: true,
              ),
            ],
          ),
          const SizedBox(height: AppThemeData.spacingLarge),

          // 重量信息 - 棕色主题
          _buildColoredSection(
            theme: theme,
            title: '重量信息',
            icon: Icons.scale,
            color: Colors.brown,
            children: [
              _buildInfoRow(
                '零燃油重量',
                briefing.zeroFuelWeight != null
                    ? '${briefing.zeroFuelWeight!} kg'
                    : 'N/A',
              ),
              _buildInfoRow(
                '起飞重量',
                briefing.takeoffWeight != null
                    ? '${briefing.takeoffWeight!} kg'
                    : 'N/A',
              ),
              _buildInfoRow(
                '落地重量',
                briefing.landingWeight != null
                    ? '${briefing.landingWeight!} kg'
                    : 'N/A',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primary.withValues(alpha: 0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.description, size: 32, color: Colors.white),
          ),
          const SizedBox(width: AppThemeData.spacingMedium),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '飞行简报',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${briefing.departureAirport.icaoCode} → ${briefing.arrivalAirport.icaoCode}',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy, color: Colors.white),
            tooltip: '复制简报',
            onPressed: () => _copyBriefing(context),
          ),
        ],
      ),
    );
  }

  Widget _buildColoredSection({
    required ThemeData theme,
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题栏
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(icon, size: 20, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          // 内容
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAirportInfoRow(
    String label,
    AirportDetailData airport,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    airport.icaoCode,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(airport.name, style: const TextStyle(fontSize: 13)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRunwayInfoRow(String label, String? runway, bool isDeparture) {
    final icon = isDeparture ? Icons.flight_takeoff : Icons.flight_land;
    final color = isDeparture ? Colors.green : Colors.blue;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 120,
            child: Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Text(
                runway != null ? 'RWY $runway' : 'N/A',
                style: TextStyle(fontWeight: FontWeight.bold, color: color),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherSection(ThemeData theme) {
    return _buildColoredSection(
      theme: theme,
      title: '天气信息',
      icon: Icons.cloud,
      color: Colors.indigo,
      children: [
        // 起飞机场天气
        _buildWeatherSubSection(
          '起飞机场 (${briefing.departureAirport.icaoCode})',
          briefing.departureMetar,
          Colors.green,
        ),
        const SizedBox(height: 16),

        // 到达机场天气
        _buildWeatherSubSection(
          '到达机场 (${briefing.arrivalAirport.icaoCode})',
          briefing.arrivalMetar,
          Colors.orange,
        ),

        // 备降机场天气
        if (briefing.alternateAirport != null) ...[
          const SizedBox(height: 16),
          _buildWeatherSubSection(
            '备降机场 (${briefing.alternateAirport!.icaoCode})',
            briefing.alternateMetar,
            Colors.purple,
          ),
        ],
      ],
    );
  }

  Widget _buildWeatherSubSection(String title, MetarData? metar, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(Icons.location_on, size: 14, color: Colors.white),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (metar != null)
            _buildMetarInfo(metar)
          else
            Text(
              '无天气数据',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
        ],
      ),
    );
  }

  Widget _buildMetarInfo(MetarData metar) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCompactInfoRow('风向风速', metar.displayWind),
        _buildCompactInfoRow('能见度', metar.displayVisibility),
        _buildCompactInfoRow('温度/露点', metar.displayTemperature),
        _buildCompactInfoRow('修正海压', metar.displayAltimeter),
        if (metar.clouds != null) _buildCompactInfoRow('云况', metar.clouds!),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            metar.raw,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey[700], fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  void _copyBriefing(BuildContext context) {
    final text = _generateBriefingText();
    Clipboard.setData(ClipboardData(text: text));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('简报已复制到剪贴板'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  String _generateBriefingText() {
    final buffer = StringBuffer();
    buffer.writeln('========== 飞行简报 ==========');
    buffer.writeln('航班号: ${briefing.formattedFlightNumber}');
    buffer.writeln('生成时间: ${briefing.generatedAt}');
    buffer.writeln();
    buffer.writeln(
      '起飞机场: ${briefing.departureAirport.icaoCode} - ${briefing.departureAirport.name}',
    );
    buffer.writeln(
      '到达机场: ${briefing.arrivalAirport.icaoCode} - ${briefing.arrivalAirport.name}',
    );
    if (briefing.alternateAirport != null) {
      buffer.writeln(
        '备降机场: ${briefing.alternateAirport!.icaoCode} - ${briefing.alternateAirport!.name}',
      );
    }
    buffer.writeln();
    buffer.writeln('航路: ${briefing.route ?? "DCT"}');
    buffer.writeln(
      '巡航高度: FL${(briefing.cruiseAltitude! / 100).toStringAsFixed(0)}',
    );
    buffer.writeln('距离: ${briefing.distance!.toStringAsFixed(0)} NM');
    buffer.writeln(
      '预计飞行时间: ${(briefing.estimatedFlightTime! / 60).floor()}h ${briefing.estimatedFlightTime! % 60}min',
    );
    buffer.writeln();
    buffer.writeln('总燃油: ${briefing.totalFuel!.toStringAsFixed(0)} kg');
    buffer.writeln('起飞重量: ${briefing.takeoffWeight} kg');
    buffer.writeln('落地重量: ${briefing.landingWeight} kg');
    buffer.writeln('==============================');

    return buffer.toString();
  }
}
