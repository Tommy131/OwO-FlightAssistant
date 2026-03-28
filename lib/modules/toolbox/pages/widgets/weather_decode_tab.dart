import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/services/localization_service.dart';
import '../../../../core/theme/app_theme_data.dart';
import '../../localization/toolbox_localization_keys.dart';
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

  void _decode(BuildContext context) {
    final metar = _metarController.text.trim().toUpperCase();
    final taf = _tafController.text.trim().toUpperCase();
    setState(() {
      _metarSummary = _decodeMetar(context, metar);
      _tafSummary = _decodeTaf(context, taf);
      _riskSummary = _buildRisk(context, metar, taf);
    });
  }

  String _decodeMetar(BuildContext context, String metar) {
    if (metar.isEmpty) {
      return ToolboxLocalizationKeys.weatherNoMetarInput.tr(context);
    }
    final windMatch = RegExp(
      r'(\d{3}|VRB)(\d{2,3})(G(\d{2,3}))?KT',
    ).firstMatch(metar);
    final visMatch = RegExp(
      r'\b(\d{4}|P?\d+/\d+SM|P?\d+SM)\b',
    ).firstMatch(metar);
    final qnhMatch = RegExp(r'\b(Q\d{4}|A\d{4})\b').firstMatch(metar);
    final tempMatch = RegExp(r'\b(M?\d{2})/(M?\d{2})\b').firstMatch(metar);
    final cloudMatches = RegExp(
      r'\b(FEW|SCT|BKN|OVC|VV)\d{3}\b',
    ).allMatches(metar).map((e) => e.group(0)!).toList();
    final visibilitySm = MapWeatherUtils.parseVisibilitySm(visMatch?.group(1));
    final ceilingFt = MapWeatherUtils.parseCeilingFt(cloudMatches.join(' '));
    final rule = _resolveRule(visibilitySm, ceilingFt);
    return [
      '${ToolboxLocalizationKeys.weatherFieldWind.tr(context)}：${windMatch?.group(0) ?? '--'}',
      '${ToolboxLocalizationKeys.weatherFieldVisibility.tr(context)}：${visMatch?.group(1) ?? '--'}${visibilitySm == null ? '' : ' (${visibilitySm.toStringAsFixed(1)}SM)'}',
      '${ToolboxLocalizationKeys.weatherFieldCloud.tr(context)}：${cloudMatches.isEmpty ? '--' : cloudMatches.join(' ')}',
      '${ToolboxLocalizationKeys.weatherFieldCeiling.tr(context)}：${ceilingFt == null ? '--' : '${ceilingFt.toStringAsFixed(0)} ft'}',
      '${ToolboxLocalizationKeys.weatherFieldTempDew.tr(context)}：${tempMatch == null ? '--' : '${tempMatch.group(1)}/${tempMatch.group(2)}'}',
      '${ToolboxLocalizationKeys.weatherFieldQnh.tr(context)}：${qnhMatch?.group(1) ?? '--'}',
      '${ToolboxLocalizationKeys.weatherFieldRule.tr(context)}：$rule',
    ].join('\n');
  }

  String _decodeTaf(BuildContext context, String taf) {
    if (taf.isEmpty)
      return ToolboxLocalizationKeys.weatherNoTafInput.tr(context);
    final tokens = <String>[];
    if (taf.contains('TEMPO')) {
      tokens.add(ToolboxLocalizationKeys.weatherTafTempo.tr(context));
    }
    if (taf.contains('BECMG')) {
      tokens.add(ToolboxLocalizationKeys.weatherTafBecmg.tr(context));
    }
    if (taf.contains('PROB30') || taf.contains('PROB40')) {
      tokens.add(ToolboxLocalizationKeys.weatherTafProb.tr(context));
    }
    if (taf.contains('TS') || taf.contains('CB')) {
      tokens.add(ToolboxLocalizationKeys.weatherTafTsCb.tr(context));
    }
    final worstVis = _extractWorstVisibility(taf);
    final lowestCeiling = _extractLowestCeiling(taf);
    return [
      if (tokens.isEmpty) ToolboxLocalizationKeys.weatherTafNormal.tr(context),
      ...tokens,
      '${ToolboxLocalizationKeys.weatherWorstVisibility.tr(context)}：${worstVis == null ? '--' : '${worstVis.toStringAsFixed(1)} SM'}',
      '${ToolboxLocalizationKeys.weatherLowestCeiling.tr(context)}：${lowestCeiling == null ? '--' : '${lowestCeiling.toStringAsFixed(0)} ft'}',
    ].join('\n');
  }

  String _buildRisk(BuildContext context, String metar, String taf) {
    final risks = <String>[];
    final metarText = metar.toUpperCase();
    final tafText = taf.toUpperCase();
    final metarVis = _extractWorstVisibility(metarText);
    final metarCeiling = _extractLowestCeiling(metarText);
    if (metarVis != null && metarVis < 3) {
      risks.add(ToolboxLocalizationKeys.weatherRiskLowVis.tr(context));
    }
    if (metarCeiling != null && metarCeiling < 1000) {
      risks.add(ToolboxLocalizationKeys.weatherRiskLowCeiling.tr(context));
    }
    if (metarText.contains('WS') || tafText.contains('WS')) {
      risks.add(ToolboxLocalizationKeys.weatherRiskWindShear.tr(context));
    }
    if (metarText.contains('TS') || tafText.contains('TS')) {
      risks.add(ToolboxLocalizationKeys.weatherRiskThunder.tr(context));
    }
    if (metarText.contains('FZ') || tafText.contains('FZ')) {
      risks.add(ToolboxLocalizationKeys.weatherRiskIcing.tr(context));
    }
    if (metarText.contains('G') || tafText.contains('G')) {
      risks.add(ToolboxLocalizationKeys.weatherRiskGust.tr(context));
    }
    if (risks.isEmpty)
      return ToolboxLocalizationKeys.weatherRiskNone.tr(context);
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
    final matches = RegExp(
      r'(\d{4}|P?\d+/\d+SM|P?\d+SM)',
    ).allMatches(raw).map((m) => m.group(1)!).toList();
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
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.45,
        ),
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
    context.watch<LocalizationService>();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppThemeData.spacingLarge),
      child: ToolboxSectionCard(
        title: ToolboxLocalizationKeys.weatherSectionTitle.tr(context),
        icon: Icons.cloud,
        child: Column(
          children: [
            ToolboxTextField(
              label: ToolboxLocalizationKeys.weatherMetarLabel.tr(context),
              hint: ToolboxLocalizationKeys.weatherMetarHint.tr(context),
              icon: Icons.cloud_queue,
              controller: _metarController,
            ),
            const SizedBox(height: AppThemeData.spacingSmall),
            TextField(
              controller: _tafController,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: ToolboxLocalizationKeys.weatherTafLabel.tr(context),
                hintText: ToolboxLocalizationKeys.weatherTafHint.tr(context),
                prefixIcon: const Icon(Icons.summarize),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppThemeData.spacingMedium),
            ElevatedButton.icon(
              onPressed: () => _decode(context),
              icon: const Icon(Icons.translate),
              label: Text(
                ToolboxLocalizationKeys.weatherDecodeButton.tr(context),
              ),
            ),
            if (_metarSummary.isNotEmpty)
              _resultBlock(
                ToolboxLocalizationKeys.weatherMetarResultTitle.tr(context),
                _metarSummary,
              ),
            if (_tafSummary.isNotEmpty)
              _resultBlock(
                ToolboxLocalizationKeys.weatherTafResultTitle.tr(context),
                _tafSummary,
              ),
            if (_riskSummary.isNotEmpty)
              _resultBlock(
                ToolboxLocalizationKeys.weatherRiskResultTitle.tr(context),
                _riskSummary,
              ),
          ],
        ),
      ),
    );
  }
}
