import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme_data.dart';
import '../../../map/providers/map_weather_utils.dart';
import 'toolbox_section_card.dart';

class WeatherDecodeTab extends StatefulWidget {
  const WeatherDecodeTab({super.key});

  @override
  State<WeatherDecodeTab> createState() => _WeatherDecodeTabState();
}

class _WeatherDecodeTabState extends State<WeatherDecodeTab> {
  final TextEditingController _metarController = TextEditingController();
  final TextEditingController _tafController = TextEditingController();
  String _metarSummary = '';
  String _tafSummary = '';
  String _riskSummary = '';

  @override
  void dispose() {
    _metarController.dispose();
    _tafController.dispose();
    super.dispose();
  }

  void _decode() {
    final metar = _metarController.text.trim().toUpperCase();
    final taf = _tafController.text.trim().toUpperCase();
    setState(() {
      _metarSummary = _decodeMetar(metar);
      _tafSummary = _decodeTaf(taf);
      _riskSummary = _buildRisk(metar, taf);
    });
  }

  String _decodeMetar(String metar) {
    if (metar.isEmpty) return '未输入 METAR';
    final windMatch = RegExp(r'(\d{3}|VRB)(\d{2,3})(G(\d{2,3}))?KT').firstMatch(
      metar,
    );
    final visMatch = RegExp(r'\b(\d{4}|P?\d+/\d+SM|P?\d+SM)\b').firstMatch(metar);
    final qnhMatch = RegExp(r'\b(Q\d{4}|A\d{4})\b').firstMatch(metar);
    final tempMatch = RegExp(r'\b(M?\d{2})/(M?\d{2})\b').firstMatch(metar);
    final cloudMatches = RegExp(r'\b(FEW|SCT|BKN|OVC|VV)\d{3}\b')
        .allMatches(metar)
        .map((e) => e.group(0)!)
        .toList();
    final visibilitySm = MapWeatherUtils.parseVisibilitySm(visMatch?.group(1));
    final ceilingFt = MapWeatherUtils.parseCeilingFt(cloudMatches.join(' '));
    final rule = _resolveRule(visibilitySm, ceilingFt);
    return [
      '风：${windMatch?.group(0) ?? '--'}',
      '能见度：${visMatch?.group(1) ?? '--'}${visibilitySm == null ? '' : ' (${visibilitySm.toStringAsFixed(1)}SM)'}',
      '云况：${cloudMatches.isEmpty ? '--' : cloudMatches.join(' ')}',
      '云底：${ceilingFt == null ? '--' : '${ceilingFt.toStringAsFixed(0)} ft'}',
      '温度/露点：${tempMatch == null ? '--' : '${tempMatch.group(1)}/${tempMatch.group(2)}'}',
      '修压：${qnhMatch?.group(1) ?? '--'}',
      '飞行规则：$rule',
    ].join('\n');
  }

  String _decodeTaf(String taf) {
    if (taf.isEmpty) return '未输入 TAF';
    final tokens = <String>[];
    if (taf.contains('TEMPO')) tokens.add('包含短时变化 TEMPO');
    if (taf.contains('BECMG')) tokens.add('包含渐变时段 BECMG');
    if (taf.contains('PROB30') || taf.contains('PROB40')) {
      tokens.add('包含概率预报 PROB');
    }
    if (taf.contains('TS') || taf.contains('CB')) tokens.add('含雷暴对流信号');
    final worstVis = _extractWorstVisibility(taf);
    final lowestCeiling = _extractLowestCeiling(taf);
    return [
      if (tokens.isEmpty) '结构特征：常规',
      ...tokens,
      '最差能见度：${worstVis == null ? '--' : '${worstVis.toStringAsFixed(1)} SM'}',
      '最低云底：${lowestCeiling == null ? '--' : '${lowestCeiling.toStringAsFixed(0)} ft'}',
    ].join('\n');
  }

  String _buildRisk(String metar, String taf) {
    final risks = <String>[];
    final metarText = metar.toUpperCase();
    final tafText = taf.toUpperCase();
    final metarVis = _extractWorstVisibility(metarText);
    final metarCeiling = _extractLowestCeiling(metarText);
    if (metarVis != null && metarVis < 3) {
      risks.add('当前能见度低于 3SM');
    }
    if (metarCeiling != null && metarCeiling < 1000) {
      risks.add('当前云底低于 1000ft');
    }
    if (metarText.contains('WS') || tafText.contains('WS')) {
      risks.add('存在风切变信号');
    }
    if (metarText.contains('TS') || tafText.contains('TS')) {
      risks.add('存在雷暴风险');
    }
    if (metarText.contains('FZ') || tafText.contains('FZ')) {
      risks.add('存在结冰风险');
    }
    if (metarText.contains('G') || tafText.contains('G')) {
      risks.add('存在阵风波动');
    }
    if (risks.isEmpty) return '未识别到高风险关键字';
    return risks.map((e) => '• $e').join('\n');
  }

  String _resolveRule(double? visibilitySm, double? ceilingFt) {
    if ((ceilingFt != null && ceilingFt < 500) ||
        (visibilitySm != null && visibilitySm < 1)) {
      return 'LIFR';
    }
    if ((ceilingFt != null && ceilingFt < 1000) ||
        (visibilitySm != null && visibilitySm < 3)) {
      return 'IFR';
    }
    if ((ceilingFt != null && ceilingFt <= 3000) ||
        (visibilitySm != null && visibilitySm <= 5)) {
      return 'MVFR';
    }
    return 'VFR';
  }

  double? _extractWorstVisibility(String raw) {
    final matches = RegExp(r'(\d{4}|P?\d+/\d+SM|P?\d+SM)')
        .allMatches(raw)
        .map((m) => m.group(1)!)
        .toList();
    double? minVis;
    for (final token in matches) {
      final vis = MapWeatherUtils.parseVisibilitySm(token);
      if (vis == null) continue;
      if (minVis == null || vis < minVis) {
        minVis = vis;
      }
    }
    return minVis;
  }

  double? _extractLowestCeiling(String raw) {
    return MapWeatherUtils.parseCeilingFt(raw);
  }

  Widget _resultBlock(String title, String value) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: AppThemeData.spacingMedium),
      padding: const EdgeInsets.all(AppThemeData.spacingMedium),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(AppThemeData.borderRadiusMedium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleSmall),
          const SizedBox(height: AppThemeData.spacingSmall),
          SelectableText(value, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppThemeData.spacingLarge),
      child: ToolboxSectionCard(
        title: 'METAR / TAF 解码',
        icon: Icons.cloud,
        child: Column(
          children: [
            ToolboxTextField(
              label: 'METAR 原文',
              hint: '例如: ZBAA 121400Z 34008KT 6000 BKN020 12/04 Q1018',
              icon: Icons.cloud_queue,
              controller: _metarController,
            ),
            const SizedBox(height: AppThemeData.spacingSmall),
            TextField(
              controller: _tafController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'TAF 原文',
                hintText: '例如: TAF ZBAA 121100Z ...',
                prefixIcon: Icon(Icons.summarize),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppThemeData.spacingMedium),
            ElevatedButton.icon(
              onPressed: _decode,
              icon: const Icon(Icons.translate),
              label: const Text('解码天气'),
            ),
            if (_metarSummary.isNotEmpty) _resultBlock('METAR 解析', _metarSummary),
            if (_tafSummary.isNotEmpty) _resultBlock('TAF 解析', _tafSummary),
            if (_riskSummary.isNotEmpty) _resultBlock('风险提示', _riskSummary),
          ],
        ),
      ),
    );
  }
}
