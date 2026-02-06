import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../apps/providers/simulator_provider.dart';
import '../../../apps/models/simulator_data.dart';
import '../../../core/theme/app_theme_data.dart';
import 'flight_data_widgets.dart';
import 'system_status_panel.dart';
import '../../../apps/data/airports_database.dart';

class FlightDataDashboard extends StatelessWidget {
  const FlightDataDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer<SimulatorProvider>(
      builder: (context, simProvider, _) {
        if (!simProvider.isConnected) {
          return _buildNoConnectionPlaceholder(theme);
        }

        final data = simProvider.simulatorData;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '实时飞行数据',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppThemeData.spacingMedium),

            // 主要飞行参数
            _buildPrimaryFlightData(theme, data),

            const SizedBox(height: AppThemeData.spacingMedium),

            // 导航和位置
            _buildNavigationData(context, theme, data),

            const SizedBox(height: AppThemeData.spacingMedium),

            // 环境数据
            _buildEnvironmentData(theme, data),

            const SizedBox(height: AppThemeData.spacingMedium),

            // 发动机和燃油
            _buildEngineAndFuelData(theme, data),

            const SizedBox(height: AppThemeData.spacingMedium),

            // 系统状态
            SystemStatusPanel(data: data),
          ],
        );
      },
    );
  }

  Widget _buildNoConnectionPlaceholder(ThemeData theme) {
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
              '连接模拟器以查看实时飞行数据',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '点击上方"连接"按钮开始',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrimaryFlightData(ThemeData theme, SimulatorData data) {
    return Consumer<SimulatorProvider>(
      builder: (context, simProvider, _) {
        final isFuelOk = simProvider.isFuelSufficient;

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
              label: '指示空速',
              value: data.airspeed != null
                  ? '${data.airspeed!.toStringAsFixed(0)} kt'
                  : 'N/A',
              color: Colors.blue,
            ),
            DataCard(
              icon: Icons.height,
              label: '高度',
              value: data.altitude != null
                  ? '${data.altitude!.toStringAsFixed(0)} ft'
                  : 'N/A',
              color: Colors.green,
            ),
            DataCard(
              icon: Icons.explore,
              label: '航向',
              value: data.heading != null
                  ? '${data.heading!.toStringAsFixed(0)}°'
                  : 'N/A',
              color: Colors.purple,
            ),
            DataCard(
              icon: Icons.trending_up,
              label: '垂直速度',
              value: data.verticalSpeed != null
                  ? '${data.verticalSpeed!.toStringAsFixed(0)} fpm'
                  : 'N/A',
              color: Colors.orange,
            ),
            DataCard(
              icon: isFuelOk == false
                  ? Icons.local_gas_station
                  : Icons.local_gas_station,
              label: '燃油状态',
              value: isFuelOk == null
                  ? '未知'
                  : isFuelOk
                  ? '充足'
                  : '不足!',
              color: isFuelOk == null
                  ? Colors.grey
                  : isFuelOk
                  ? Colors.teal
                  : Colors.red,
            ),
          ],
        );
      },
    );
  }

  Widget _buildNavigationData(
    BuildContext context,
    ThemeData theme,
    SimulatorData data,
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
                '导航与位置',
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
                label: '地速',
                value: data.groundSpeed != null
                    ? '${data.groundSpeed!.toStringAsFixed(0)} kt'
                    : 'N/A',
              ),
              InfoChip(
                label: '真空速',
                value: data.trueAirspeed != null
                    ? '${data.trueAirspeed!.toStringAsFixed(0)} kt'
                    : 'N/A',
              ),
              InfoChip(
                label: '纬度',
                value: data.latitude != null
                    ? data.latitude!.toStringAsFixed(4)
                    : 'N/A',
              ),
              InfoChip(
                label: '经度',
                value: data.longitude != null
                    ? data.longitude!.toStringAsFixed(4)
                    : 'N/A',
              ),
              if (data.departureAirport != null)
                InfoChip(label: '起飞机场', value: data.departureAirport!),
              if (data.arrivalAirport != null)
                InfoChip(label: '目的机场', value: data.arrivalAirport!),
            ],
          ),
          const SizedBox(height: 16),
          // 通信频率与导航设置
          Row(
            children: [
              Icon(
                Icons.settings_input_antenna,
                color: theme.colorScheme.primary.withValues(alpha: 0.7),
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                '通信频率:',
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
              _buildDestinationPicker(context),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDestinationPicker(BuildContext context) {
    final simProvider = context.watch<SimulatorProvider>();
    final dest = simProvider.destinationAirport;

    return TextButton.icon(
      onPressed: () => _showAirportPickerDialog(context),
      icon: Icon(
        dest != null ? Icons.edit_location : Icons.add_location,
        size: 16,
      ),
      label: Text(
        dest != null ? '目的地: ${dest.icaoCode}' : '设置目的地',
        style: const TextStyle(fontSize: 12),
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  void _showAirportPickerDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        final airports = AirportsDatabase.allAirports;
        return AlertDialog(
          title: const Text('选择目的地机场'),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: ListView.builder(
              itemCount: airports.length,
              itemBuilder: (context, index) {
                final airport = airports[index];
                return ListTile(
                  title: Text(airport.displayName),
                  subtitle: Text(
                    'LAT: ${airport.latitude}, LON: ${airport.longitude}',
                  ),
                  onTap: () {
                    context.read<SimulatorProvider>().setDestination(airport);
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

  Widget _buildEnvironmentData(ThemeData theme, SimulatorData data) {
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
                '环境数据',
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
                label: '外部温度',
                value: data.outsideAirTemperature != null
                    ? '${data.outsideAirTemperature!.toStringAsFixed(1)}°C'
                    : 'N/A',
              ),
              InfoChip(
                label: '总温度',
                value: data.totalAirTemperature != null
                    ? '${data.totalAirTemperature!.toStringAsFixed(1)}°C'
                    : 'N/A',
              ),
              InfoChip(
                label: '风速',
                value: data.windSpeed != null
                    ? '${data.windSpeed!.toStringAsFixed(0)} kt'
                    : 'N/A',
              ),
              InfoChip(
                label: '风向',
                value: data.windDirection != null
                    ? '${data.windDirection!.toStringAsFixed(0)}°'
                    : 'N/A',
              ),
              InfoChip(
                label: '报告能见度',
                value: data.visibility != null
                    ? (data.visibility! >= 9999
                          ? '10km+'
                          : data.visibility! >= 1000
                          ? '${(data.visibility! / 1000).toStringAsFixed(1)}km'
                          : '${data.visibility!.toStringAsFixed(0)}m')
                    : 'N/A',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEngineAndFuelData(ThemeData theme, SimulatorData data) {
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
                '发动机与燃油',
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
                label: '燃油总量',
                value: data.fuelQuantity != null
                    ? '${data.fuelQuantity!.toStringAsFixed(0)} kg'
                    : 'N/A',
              ),
              InfoChip(
                label: '燃油流量',
                value: data.fuelFlow != null
                    ? '${data.fuelFlow!.toStringAsFixed(1)} kg/h'
                    : 'N/A',
              ),
              InfoChip(
                label: 'ENG1 N1',
                value: data.engine1N1 != null
                    ? '${data.engine1N1!.toStringAsFixed(1)}%'
                    : 'N/A',
              ),
              InfoChip(
                label: 'ENG2 N1',
                value: data.engine2N1 != null
                    ? '${data.engine2N1!.toStringAsFixed(1)}%'
                    : 'N/A',
              ),
              InfoChip(
                label: 'ENG1 EGT',
                value: data.engine1EGT != null
                    ? '${data.engine1EGT!.toStringAsFixed(0)}°C'
                    : 'N/A',
              ),
              InfoChip(
                label: 'ENG2 EGT',
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
}
