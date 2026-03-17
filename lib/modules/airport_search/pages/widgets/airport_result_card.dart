import 'package:flutter/material.dart';
import '../../../../core/services/localization_service.dart';
import '../../../../core/theme/app_theme_data.dart';
import '../../../common/pages/widgets/wind_direction_indicator.dart';
import '../../localization/airport_search_localization_keys.dart';
import '../../models/airport_search_models.dart';

class AirportResultCard extends StatelessWidget {
  final AirportQueryResult? result;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;

  const AirportResultCard({
    super.key,
    required this.result,
    required this.isFavorite,
    required this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    final query = result;
    if (query == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppThemeData.spacingMedium),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppThemeData.borderRadiusMedium),
          border: Border.all(
            color: AppThemeData.getBorderColor(
              Theme.of(context),
            ).withValues(alpha: 0.5),
          ),
        ),
        child: Text(
          AirportSearchLocalizationKeys.noResultHint.tr(context),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    final airport = query.airport;
    final metar = query.metar;
    final title = airport.name ?? airport.icao;
    final frequencyRows = _mergeFrequencyRows(airport.frequencies);
    final wind = _extractWind(metar);
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final cardBackground = Color.alphaBlend(
      accent.withValues(alpha: 0.1),
      theme.colorScheme.surface,
    );
    final panelBackground = Color.alphaBlend(
      accent.withValues(alpha: 0.5),
      theme.colorScheme.surfaceContainerHighest,
    );
    final lineColor = accent.withValues(alpha: 0.35);
    final locationText = _buildLocationText(airport);
    final runwayCards = _buildRunwayCards(airport.runways);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppThemeData.spacingMedium),
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(AppThemeData.borderRadiusMedium),
        border: Border.all(color: lineColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                airport.icao,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    if (airport.iata != null && airport.iata!.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      _TagChip(text: airport.iata!),
                    ] else if (airport.source != null &&
                        airport.source!.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      _TagChip(text: airport.source!),
                    ],
                  ],
                ),
              ),
              IconButton(
                onPressed: onToggleFavorite,
                tooltip: isFavorite
                    ? AirportSearchLocalizationKeys.favoriteRemove.tr(context)
                    : AirportSearchLocalizationKeys.favoriteAdd.tr(context),
                icon: Icon(
                  isFavorite ? Icons.star : Icons.star_outline,
                  size: 20,
                  color: Colors.amber,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Divider(color: lineColor),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final rightPanel = _buildRightPanel(
                context,
                airport,
                metar,
                locationText,
                runwayCards,
                panelBackground,
              );
              if (constraints.maxWidth < 860) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildWindPanel(context, wind),
                    const SizedBox(height: 8),
                    rightPanel,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 155, child: _buildWindPanel(context, wind)),
                  const SizedBox(width: 10),
                  Expanded(child: rightPanel),
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          Divider(color: lineColor),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.settings_input_antenna, size: 16, color: accent),
              const SizedBox(width: 6),
              Text(
                AirportSearchLocalizationKeys.frequenciesTitle.tr(context),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppThemeData.spacingSmall),
          if (frequencyRows.isEmpty)
            Text(
              AirportSearchLocalizationKeys.frequenciesEmpty.tr(context),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.hintColor,
              ),
            )
          else
            _FrequencyTable(rows: frequencyRows),
        ],
      ),
    );
  }

  Widget _buildRightPanel(
    BuildContext context,
    AirportDetailData airport,
    MetarData metar,
    String locationText,
    List<_RunwayCardData> runwayCards,
    Color panelBackground,
  ) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          icon: Icons.place_outlined,
          title: AirportSearchLocalizationKeys.positionSectionTitle.tr(context),
        ),
        const SizedBox(height: 4),
        Container(
          // width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: panelBackground,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            locationText,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 8),
        _SectionHeader(
          icon: Icons.cloud_outlined,
          title: AirportSearchLocalizationKeys.weatherSectionTitle.tr(context),
        ),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            color: panelBackground,
            borderRadius: BorderRadius.circular(AppThemeData.borderRadiusSmall),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: SelectableText(
            (metar.raw ?? '').trim().isEmpty
                ? AirportSearchLocalizationKeys.metarEmpty.tr(context)
                : metar.raw!,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _MetaBadge(
              label: AirportSearchLocalizationKeys.metarWind.tr(context),
              value: metar.wind ?? '-',
            ),
            _MetaBadge(
              label: AirportSearchLocalizationKeys.metarVisibility.tr(context),
              value: metar.visibility ?? '-',
            ),
            _MetaBadge(
              label: AirportSearchLocalizationKeys.metarTemperature.tr(context),
              value: metar.temperature ?? '-',
            ),
            _MetaBadge(
              label: AirportSearchLocalizationKeys.metarAltimeter.tr(context),
              value: metar.altimeter ?? '-',
            ),
          ],
        ),
        const SizedBox(height: 8),
        _SectionHeader(
          icon: Icons.flight_land_outlined,
          title: AirportSearchLocalizationKeys.runwaySectionTitle.tr(context),
        ),
        const SizedBox(height: 4),
        if (runwayCards.isEmpty)
          Text(
            AirportSearchLocalizationKeys.runwaysEmpty.tr(context),
            style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor),
          )
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: runwayCards
                .map((item) => _RunwayCard(data: item))
                .toList(),
          ),
      ],
    );
  }

  String _buildLocationText(AirportDetailData airport) {
    final lat = airport.latitude?.toStringAsFixed(5) ?? '-';
    final lon = airport.longitude?.toStringAsFixed(5) ?? '-';
    final elev = airport.elevationFt == null
        ? '-'
        : '${airport.elevationFt} ft';
    return 'LAT: $lat   LON: $lon   ELEV: $elev';
  }

  List<_RunwayCardData> _buildRunwayCards(List<AirportRunwayData> runways) {
    return runways
        .map(
          (runway) => _RunwayCardData(
            ident: runway.ident,
            length: runway.lengthM == null
                ? '-'
                : '${runway.lengthM!.toStringAsFixed(0)} m',
            surface: runway.surface ?? '-',
          ),
        )
        .toList();
  }

  Widget _buildWindPanel(BuildContext context, _WindSnapshot wind) {
    Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          WindDirectionIndicator(
            windDirection: wind.direction,
            windSpeed: wind.speedKt,
            size: 120,
          ),
        ],
      ),
    );
  }

  _WindSnapshot _extractWind(MetarData metar) {
    final raw = metar.raw ?? '';
    final rawMatch = RegExp(
      r'\b(?:(\d{3})|VRB)(\d{2,3})(?:G\d{2,3})?KT\b',
      caseSensitive: false,
    ).firstMatch(raw);
    if (rawMatch != null) {
      return _WindSnapshot(
        direction: double.tryParse(rawMatch.group(1) ?? ''),
        speedKt: double.tryParse(rawMatch.group(2) ?? ''),
        rawText: metar.wind,
      );
    }
    final windText = metar.wind ?? metar.decoded ?? '';
    final directionMatch = RegExp(r'(\d{1,3})\s*[°度]').firstMatch(windText);
    final speedMatch = RegExp(
      r'(?:/|\s)(\d{1,3})(?:\s*(?:kt|kts|m/s|米/秒))?',
      caseSensitive: false,
    ).firstMatch(windText);
    return _WindSnapshot(
      direction: double.tryParse(directionMatch?.group(1) ?? ''),
      speedKt: double.tryParse(speedMatch?.group(1) ?? ''),
      rawText: metar.wind,
    );
  }
}

class _WindSnapshot {
  final double? direction;
  final double? speedKt;
  final String? rawText;

  const _WindSnapshot({this.direction, this.speedKt, this.rawText});
}

class _TagChip extends StatelessWidget {
  final String text;

  const _TagChip({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          fontSize: 10,
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 15, color: theme.colorScheme.primary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}

class _RunwayCardData {
  final String ident;
  final String length;
  final String surface;

  const _RunwayCardData({
    required this.ident,
    required this.length,
    required this.surface,
  });
}

class _RunwayCard extends StatelessWidget {
  final _RunwayCardData data;

  const _RunwayCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 104,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.17),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data.ident,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            data.length,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
          Text(data.surface, style: theme.textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _FrequencyTable extends StatelessWidget {
  final List<List<String>> rows;

  const _FrequencyTable({required this.rows});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final borderColor = primary.withValues(alpha: 0.28);
    final headerColor = primary.withValues(alpha: 0.2);
    final rowColor = primary.withValues(alpha: 0.1);
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(8),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Table(
            defaultColumnWidth: const IntrinsicColumnWidth(),
            border: TableBorder(
              horizontalInside: BorderSide(color: borderColor),
              verticalInside: BorderSide(color: borderColor),
            ),
            children: [
              TableRow(
                decoration: BoxDecoration(color: headerColor),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    child: Text(
                      AirportSearchLocalizationKeys.frequencyTypeLabel.tr(
                        context,
                      ),
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    child: Text(
                      AirportSearchLocalizationKeys.frequencyValueLabel.tr(
                        context,
                      ),
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              ...rows.map(
                (row) => TableRow(
                  decoration: BoxDecoration(color: rowColor),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      child: Text(
                        row[0],
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      child: Text(
                        row[1],
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaBadge extends StatelessWidget {
  final String label;
  final String value;

  const _MetaBadge({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$label: $value',
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

List<List<String>> _mergeFrequencyRows(List<AirportFrequencyData> items) {
  final grouped = <String, List<String>>{};
  for (final item in items) {
    final type = (item.type ?? '').trim().isEmpty ? '-' : item.type!.trim();
    final value = (item.value ?? '').trim().isEmpty ? '-' : item.value!.trim();
    final currentValues = grouped.putIfAbsent(type, () => <String>[]);
    if (!currentValues.contains(value)) {
      currentValues.add(value);
    }
  }
  return grouped.entries
      .map((entry) => [entry.key, entry.value.join(' / ')])
      .toList();
}
