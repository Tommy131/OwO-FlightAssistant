import 'package:flutter/material.dart';
import '../../core/theme/app_theme_data.dart';
import '../settings/widgets/settings_widgets.dart';

class ToolboxPage extends StatefulWidget {
  const ToolboxPage({super.key});

  @override
  State<ToolboxPage> createState() => _ToolboxPageState();
}

class _ToolboxPageState extends State<ToolboxPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _unitController = TextEditingController();
  final TextEditingController _translateController = TextEditingController();
  String _unitResult = '';
  String _translateResult = '';
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

  final Map<String, String> _aviationTerms = {
    'V1': '起飞决断速度 (Takeoff Decision Speed)',
    'VR': '抬头速度 (Rotation Speed)',
    'V2': '起飞安全速度 (Takeoff Safety Speed)',
    'Vref': '参考进近速度 (Reference Landing Speed)',
    'Vne': '绝不超过速度 (Never Exceed Speed)',
    'METAR': '例行天气报告 (Meteorological Aerodrome Report)',
    'TAF': '机场天气预报 (Terminal Aerodrome Forecast)',
    'ILS': '仪表着陆系统 (Instrument Landing System)',
    'VOR': '甚高频全向信标 (VHF Omni-directional Range)',
    'NDB': '无方向性信标 (Non-Directional Beacon)',
    'DME': '测距仪 (Distance Measuring Equipment)',
    'QNH': '修正海平面气压 (Altimeter setting relative to sea level)',
    'QFE': '场面气压 (Altimeter setting relative to airport elevation)',
    'Standard': '标准气压 (1013.25 hPa / 29.92 inHg)',
    'FL': '飞行高度层 (Flight Level)',
    'Transition Altitude': '过渡高度',
    'Transition Level': '过渡高度层',
    'MSL': '平均海平面 (Mean Sea Level)',
    'AGL': '地面高度 (Above Ground Level)',
    'IAS': '指示空速 (Indicated Airspeed)',
    'TAS': '真空速 (True Airspeed)',
    'GS': '地速 (Ground Speed)',
    'MACH': '马赫数',
    'IFR': '仪表飞行规则 (Instrument Flight Rules)',
    'VFR': '视觉飞行规则 (Visual Flight Rules)',
    'ATIS': '自动终端情报服务 (Automatic Terminal Information Service)',
    'SQUAWK': '应答机代码',
    'SID': '标准仪表离场 (Standard Instrument Departure)',
    'STAR': '标准终端进场 (Standard Terminal Arrival Route)',
    'MAYDAY': '最高紧急情况呼叫 (紧急求救)',
    'PAN-PAN': '次级紧急情况呼叫 (紧急情况)',
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _unitController.dispose();
    _translateController.dispose();
    super.dispose();
  }

  void _convertUnit() {
    if (_unitController.text.isEmpty) return;
    double? val = double.tryParse(_unitController.text);
    if (val == null) {
      setState(() => _unitResult = '无效数值');
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

    setState(() {
      _unitResult = '${result.toStringAsFixed(2)} $unit';
    });
  }

  void _translateTerm() {
    String input = _translateController.text.trim().toUpperCase();
    if (input.isEmpty) {
      setState(() => _translateResult = '');
      return;
    }

    String? found = _aviationTerms[input];
    if (found == null) {
      // 模糊匹配
      final matches = _aviationTerms.keys
          .where((k) => k.contains(input))
          .map((k) => '$k: ${_aviationTerms[k]}')
          .toList();

      setState(() {
        if (matches.isNotEmpty) {
          _translateResult = '未找到精确匹配，相似项:\n${matches.join('\n')}';
        } else {
          _translateResult = '未找到该术语';
        }
      });
    } else {
      setState(() => _translateResult = found);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('航空工具箱'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.calculate_outlined), text: '单位换算'),
            Tab(icon: Icon(Icons.translate_outlined), text: '术语翻译'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildUnitConversionTab(), _buildTermsTranslationTab()],
      ),
    );
  }

  Widget _buildUnitConversionTab() {
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
                  value: _selectedUnitType,
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
                      color: Theme.of(
                        context,
                      ).colorScheme.primaryContainer.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '换算结果',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _unitResult,
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
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

  Widget _buildTermsTranslationTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppThemeData.spacingLarge),
      child: Column(
        children: [
          SettingsCard(
            title: '航空术语翻译',
            icon: Icons.language_rounded,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SettingsInputField(
                  label: '输入英文术语/简写',
                  hint: '例如: V1, ILS, QNH...',
                  controller: _translateController,
                  icon: Icons.search_rounded,
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _translateTerm,
                  icon: const Icon(Icons.translate),
                  label: const Text('翻译'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
                if (_translateResult.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.secondaryContainer.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.secondary.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '翻译结果',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _translateResult,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                Text('常见术语参考', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _aviationTerms.keys
                      .take(12)
                      .map(
                        (k) => ActionChip(
                          label: Text(k),
                          onPressed: () {
                            _translateController.text = k;
                            _translateTerm();
                          },
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
