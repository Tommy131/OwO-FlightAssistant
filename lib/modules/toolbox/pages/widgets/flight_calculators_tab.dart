import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme_data.dart';
import 'toolbox_section_card.dart';

class FlightCalculatorsTab extends StatefulWidget {
  const FlightCalculatorsTab({super.key});

  @override
  State<FlightCalculatorsTab> createState() => _FlightCalculatorsTabState();
}

class _FlightCalculatorsTabState extends State<FlightCalculatorsTab> {
  final TextEditingController _runwayHeadingController = TextEditingController(
    text: '270',
  );
  final TextEditingController _windDirectionController = TextEditingController(
    text: '300',
  );
  final TextEditingController _windSpeedController = TextEditingController(
    text: '18',
  );
  String _windResult = '';

  final TextEditingController _currentAltController = TextEditingController(
    text: '35000',
  );
  final TextEditingController _targetAltController = TextEditingController(
    text: '3000',
  );
  final TextEditingController _groundSpeedController = TextEditingController(
    text: '300',
  );
  final TextEditingController _descentRateController = TextEditingController(
    text: '1500',
  );
  final TextEditingController _distanceToGoController = TextEditingController(
    text: '110',
  );
  String _descentResult = '';

  final TextEditingController _distanceNmController = TextEditingController(
    text: '520',
  );
  final TextEditingController _cruiseSpeedController = TextEditingController(
    text: '430',
  );
  final TextEditingController _burnRateController = TextEditingController(
    text: '2500',
  );
  final TextEditingController _reserveMinController = TextEditingController(
    text: '45',
  );
  final TextEditingController _taxiFuelController = TextEditingController(
    text: '220',
  );
  final TextEditingController _extraPctController = TextEditingController(
    text: '5',
  );
  String _fuelResult = '';

  @override
  void dispose() {
    _runwayHeadingController.dispose();
    _windDirectionController.dispose();
    _windSpeedController.dispose();
    _currentAltController.dispose();
    _targetAltController.dispose();
    _groundSpeedController.dispose();
    _descentRateController.dispose();
    _distanceToGoController.dispose();
    _distanceNmController.dispose();
    _cruiseSpeedController.dispose();
    _burnRateController.dispose();
    _reserveMinController.dispose();
    _taxiFuelController.dispose();
    _extraPctController.dispose();
    super.dispose();
  }

  double? _parse(TextEditingController controller) {
    return double.tryParse(controller.text.trim());
  }

  void _calculateWind() {
    final runwayHeading = _parse(_runwayHeadingController);
    final windDirection = _parse(_windDirectionController);
    final windSpeed = _parse(_windSpeedController);
    if (runwayHeading == null || windDirection == null || windSpeed == null) {
      setState(() => _windResult = '请输入有效数字');
      return;
    }
    final delta = ((windDirection - runwayHeading) % 360 + 360) % 360;
    final angle = delta > 180 ? 360 - delta : delta;
    final rad = angle * math.pi / 180;
    final headwind = windSpeed * math.cos(rad);
    final crosswindRaw = windSpeed * math.sin(delta * math.pi / 180);
    final crosswind = crosswindRaw.abs();
    final crosswindFrom = crosswindRaw >= 0 ? '右侧' : '左侧';
    final level = crosswind <= 10
        ? '低'
        : crosswind <= 20
        ? '中'
        : '高';
    setState(() {
      _windResult =
          '迎/顺风分量 ${headwind.toStringAsFixed(1)} kt\n'
          '侧风分量 ${crosswind.toStringAsFixed(1)} kt（$crosswindFrom）\n'
          '侧风风险等级：$level';
    });
  }

  void _calculateDescent() {
    final currentAlt = _parse(_currentAltController);
    final targetAlt = _parse(_targetAltController);
    final groundSpeed = _parse(_groundSpeedController);
    final descentRate = _parse(_descentRateController);
    final distanceToGo = _parse(_distanceToGoController);
    if (currentAlt == null ||
        targetAlt == null ||
        groundSpeed == null ||
        descentRate == null) {
      setState(() => _descentResult = '请输入有效数字');
      return;
    }
    final altitudeToLose = (currentAlt - targetAlt).clamp(0, 50000).toDouble();
    if (altitudeToLose <= 0 || descentRate <= 0 || groundSpeed <= 0) {
      setState(() => _descentResult = '参数范围无效');
      return;
    }
    final minutes = altitudeToLose / descentRate;
    final todDistance = groundSpeed * (minutes / 60);
    final ruleOf3Distance = (altitudeToLose / 1000) * 3;
    final requiredVs = distanceToGo == null || distanceToGo <= 0
        ? null
        : altitudeToLose / ((distanceToGo / groundSpeed) * 60);
    setState(() {
      _descentResult =
          '需下降高度 ${altitudeToLose.toStringAsFixed(0)} ft\n'
          '预计下降时间 ${minutes.toStringAsFixed(1)} min\n'
          'TOD 参考距离 ${todDistance.toStringAsFixed(1)} NM\n'
          '3:1 规则距离 ${ruleOf3Distance.toStringAsFixed(1)} NM'
          '${requiredVs == null ? '' : '\n按剩余距离所需下降率 ${requiredVs.toStringAsFixed(0)} fpm'}';
    });
  }

  void _calculateFuel() {
    final distanceNm = _parse(_distanceNmController);
    final cruiseSpeed = _parse(_cruiseSpeedController);
    final burnRate = _parse(_burnRateController);
    final reserveMin = _parse(_reserveMinController);
    final taxiFuel = _parse(_taxiFuelController);
    final extraPct = _parse(_extraPctController);
    if (distanceNm == null ||
        cruiseSpeed == null ||
        burnRate == null ||
        reserveMin == null ||
        taxiFuel == null ||
        extraPct == null) {
      setState(() => _fuelResult = '请输入有效数字');
      return;
    }
    if (distanceNm < 0 ||
        cruiseSpeed <= 0 ||
        burnRate <= 0 ||
        reserveMin < 0 ||
        taxiFuel < 0 ||
        extraPct < 0) {
      setState(() => _fuelResult = '参数范围无效');
      return;
    }
    final tripHours = distanceNm / cruiseSpeed;
    final tripFuel = burnRate * tripHours;
    final reserveFuel = burnRate * (reserveMin / 60);
    final extraFuel = tripFuel * (extraPct / 100);
    final totalFuel = tripFuel + reserveFuel + taxiFuel + extraFuel;
    setState(() {
      _fuelResult =
          '航程油量 ${tripFuel.toStringAsFixed(0)} kg\n'
          '备份油量 ${reserveFuel.toStringAsFixed(0)} kg\n'
          '滑行油量 ${taxiFuel.toStringAsFixed(0)} kg\n'
          '额外油量 ${extraFuel.toStringAsFixed(0)} kg\n'
          '总建议油量 ${totalFuel.toStringAsFixed(0)} kg';
    });
  }

  Widget _resultCard(String title, String value) {
    final theme = Theme.of(context);
    if (value.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: AppThemeData.spacingMedium),
      padding: const EdgeInsets.all(AppThemeData.spacingMedium),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppThemeData.borderRadiusMedium),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.labelLarge),
          const SizedBox(height: AppThemeData.spacingSmall),
          SelectableText(value, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }

  Widget _numberField(
    TextEditingController controller,
    String label,
    IconData icon,
  ) {
    return ToolboxTextField(
      label: label,
      hint: '请输入',
      icon: icon,
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppThemeData.spacingLarge),
      child: Column(
        children: [
          ToolboxSectionCard(
            title: '侧风 / 逆风分量计算',
            icon: Icons.air,
            child: Column(
              children: [
                _numberField(
                  _runwayHeadingController,
                  '跑道航向(°)',
                  Icons.explore,
                ),
                const SizedBox(height: AppThemeData.spacingSmall),
                _numberField(
                  _windDirectionController,
                  '风向(°)',
                  Icons.navigation,
                ),
                const SizedBox(height: AppThemeData.spacingSmall),
                _numberField(_windSpeedController, '风速(kt)', Icons.speed),
                const SizedBox(height: AppThemeData.spacingMedium),
                ElevatedButton.icon(
                  onPressed: _calculateWind,
                  icon: const Icon(Icons.calculate),
                  label: const Text('计算分量'),
                ),
                _resultCard('计算结果', _windResult),
              ],
            ),
          ),
          const SizedBox(height: AppThemeData.spacingLarge),
          ToolboxSectionCard(
            title: '下降规划 / TOD',
            icon: Icons.south,
            child: Column(
              children: [
                _numberField(_currentAltController, '当前高度(ft)', Icons.height),
                const SizedBox(height: AppThemeData.spacingSmall),
                _numberField(_targetAltController, '目标高度(ft)', Icons.flag),
                const SizedBox(height: AppThemeData.spacingSmall),
                _numberField(_groundSpeedController, '地速(kt)', Icons.route),
                const SizedBox(height: AppThemeData.spacingSmall),
                _numberField(
                  _descentRateController,
                  '下降率(fpm)',
                  Icons.trending_down,
                ),
                const SizedBox(height: AppThemeData.spacingSmall),
                _numberField(
                  _distanceToGoController,
                  '当前剩余距离(NM)',
                  Icons.straighten,
                ),
                const SizedBox(height: AppThemeData.spacingMedium),
                ElevatedButton.icon(
                  onPressed: _calculateDescent,
                  icon: const Icon(Icons.calculate),
                  label: const Text('计算TOD'),
                ),
                _resultCard('规划结果', _descentResult),
              ],
            ),
          ),
          const SizedBox(height: AppThemeData.spacingLarge),
          ToolboxSectionCard(
            title: '燃油快速评估',
            icon: Icons.local_gas_station,
            child: Column(
              children: [
                _numberField(_distanceNmController, '计划航程(NM)', Icons.map),
                const SizedBox(height: AppThemeData.spacingSmall),
                _numberField(
                  _cruiseSpeedController,
                  '巡航速度(kt)',
                  Icons.airplanemode_active,
                ),
                const SizedBox(height: AppThemeData.spacingSmall),
                _numberField(
                  _burnRateController,
                  '平均耗油(kg/h)',
                  Icons.local_fire_department,
                ),
                const SizedBox(height: AppThemeData.spacingSmall),
                _numberField(_reserveMinController, '储备时间(min)', Icons.timer),
                const SizedBox(height: AppThemeData.spacingSmall),
                _numberField(
                  _taxiFuelController,
                  '滑行油量(kg)',
                  Icons.directions_car,
                ),
                const SizedBox(height: AppThemeData.spacingSmall),
                _numberField(
                  _extraPctController,
                  '额外油量(%)',
                  Icons.add_circle_outline,
                ),
                const SizedBox(height: AppThemeData.spacingMedium),
                ElevatedButton.icon(
                  onPressed: _calculateFuel,
                  icon: const Icon(Icons.calculate),
                  label: const Text('估算油量'),
                ),
                _resultCard('估算结果', _fuelResult),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
