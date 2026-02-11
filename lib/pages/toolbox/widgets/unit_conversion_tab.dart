import 'package:flutter/material.dart';
import '../../../core/theme/app_theme_data.dart';
import '../../settings/widgets/settings_widgets.dart';

class UnitConversionTab extends StatefulWidget {
  const UnitConversionTab({super.key});

  @override
  State<UnitConversionTab> createState() => _UnitConversionTabState();
}

class _UnitConversionTabState extends State<UnitConversionTab> {
  final TextEditingController _unitController = TextEditingController();
  String _unitResult = '';
  String _selectedUnitType = 'hPa to inHg';

  final List<String> _unitTypes = [
    'hPa to inHg',
    'inHg to hPa',
    'ft to m',
    'm to ft',
    'lb to kg',
    'kg to lb',
    'kt to km/h',
    'km/h to kt',
    'NM to km',
    'km to NM',
    'Celsius to Fahrenheit',
    'Fahrenheit to Celsius',
  ];

  @override
  void dispose() {
    _unitController.dispose();
    super.dispose();
  }

  void _convertUnit() {
    if (_unitController.text.isEmpty) return;
    double? val = double.tryParse(_unitController.text);
    if (val == null) {
      if (mounted) {
        setState(() => _unitResult = '无效数值');
      }
      return;
    }

    double result = 0;
    String unit = '';

    switch (_selectedUnitType) {
      case 'hPa to inHg':
        result = val * 0.02953;
        unit = 'inHg';
        break;
      case 'inHg to hPa':
        result = val / 0.02953;
        unit = 'hPa';
        break;
      case 'ft to m':
        result = val * 0.3048;
        unit = 'm';
        break;
      case 'm to ft':
        result = val / 0.3048;
        unit = 'ft';
        break;
      case 'lb to kg':
        result = val * 0.45359;
        unit = 'kg';
        break;
      case 'kg to lb':
        result = val / 0.45359;
        unit = 'lb';
        break;
      case 'kt to km/h':
        result = val * 1.852;
        unit = 'km/h';
        break;
      case 'km/h to kt':
        result = val / 1.852;
        unit = 'kt';
        break;
      case 'NM to km':
        result = val * 1.852;
        unit = 'km';
        break;
      case 'km to NM':
        result = val / 1.852;
        unit = 'NM';
        break;
      case 'Celsius to Fahrenheit':
        result = (val * 9 / 5) + 32;
        unit = '°F';
        break;
      case 'Fahrenheit to Celsius':
        result = (val - 32) * 5 / 9;
        unit = '°C';
        break;
    }

    if (mounted) {
      setState(() {
        _unitResult = '${result.toStringAsFixed(2)} $unit';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppThemeData.spacingLarge),
      child: Column(
        children: [
          SettingsCard(
            title: '数值换算',
            icon: Icons.sync_alt_rounded,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _selectedUnitType,
                  decoration: const InputDecoration(
                    labelText: '换算类型',
                    border: OutlineInputBorder(),
                  ),
                  items: _unitTypes
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedUnitType = val);
                      _convertUnit();
                    }
                  },
                ),
                const SizedBox(height: 20),
                SettingsInputField(
                  label: '输入数值',
                  hint: '请输入要换算的数字...',
                  controller: _unitController,
                  icon: Icons.edit_note_rounded,
                  onChanged: (val) => _convertUnit(),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _convertUnit,
                  icon: const Icon(Icons.calculate),
                  label: const Text('立即换算'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
                if (_unitResult.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withValues(
                        alpha: 0.3,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.primary.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text('换算结果', style: theme.textTheme.labelSmall),
                        const SizedBox(height: 8),
                        SelectableText(
                          _unitResult,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
