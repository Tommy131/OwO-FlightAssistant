import 'package:flutter/material.dart';
import '../../../../core/services/localization_service.dart';
import '../../../../core/theme/app_theme_data.dart';
import '../../localization/airport_search_localization_keys.dart';
import '../../models/airport_search_models.dart';

class AirportResultCard extends StatelessWidget {
  final AirportQueryResult? result;
  final bool isFavorite;
  final bool isUpdating;
  final VoidCallback onToggleFavorite;
  final VoidCallback onRefreshFavorite;

  const AirportResultCard({
    super.key,
    required this.result,
    required this.isFavorite,
    required this.isUpdating,
    required this.onToggleFavorite,
    required this.onRefreshFavorite,
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
    final subtitleParts = [
      airport.icao,
      if (airport.iata != null && airport.iata!.isNotEmpty) airport.iata!,
      if (airport.city != null && airport.city!.isNotEmpty) airport.city!,
      if (airport.country != null && airport.country!.isNotEmpty)
        airport.country!,
    ];
    final frequencyRows = _mergeFrequencyRows(airport.frequencies);

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AirportSearchLocalizationKeys.latestResultTitle.tr(context),
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppThemeData.spacingSmall),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            subtitleParts.join(' · '),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).hintColor,
            ),
          ),
          const SizedBox(height: AppThemeData.spacingSmall),
          _InfoRow(
            label: AirportSearchLocalizationKeys.airportNameLabel.tr(context),
            value: airport.name ?? '-',
          ),
          _InfoRow(
            label: AirportSearchLocalizationKeys.airportIcaoLabel.tr(context),
            value: airport.icao,
          ),
          _InfoRow(
            label: AirportSearchLocalizationKeys.airportLatLonLabel.tr(context),
            value: airport.latitude != null && airport.longitude != null
                ? '${airport.latitude!.toStringAsFixed(4)}, ${airport.longitude!.toStringAsFixed(4)}'
                : '-',
          ),
          const SizedBox(height: AppThemeData.spacingMedium),
          Row(
            children: [
              FilledButton.tonalIcon(
                onPressed: onToggleFavorite,
                icon: Icon(isFavorite ? Icons.star : Icons.star_outline),
                label: Text(
                  isFavorite
                      ? AirportSearchLocalizationKeys.favoriteRemove.tr(context)
                      : AirportSearchLocalizationKeys.favoriteAdd.tr(context),
                ),
              ),
              const SizedBox(width: AppThemeData.spacingSmall),
              if (isFavorite)
                OutlinedButton.icon(
                  onPressed: isUpdating ? null : onRefreshFavorite,
                  icon: isUpdating
                      ? const SizedBox(
                          height: 14,
                          width: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  label: Text(
                    AirportSearchLocalizationKeys.favoriteRefresh.tr(context),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppThemeData.spacingMedium),
          Text(
            AirportSearchLocalizationKeys.runwaysTitle.tr(context),
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppThemeData.spacingSmall),
          _CompactTable(
            headers: [
              AirportSearchLocalizationKeys.runwayNameLabel.tr(context),
              AirportSearchLocalizationKeys.runwayLengthLabel.tr(context),
              AirportSearchLocalizationKeys.runwayTypeLabel.tr(context),
            ],
            emptyText: AirportSearchLocalizationKeys.runwaysEmpty.tr(context),
            maxHeight: 180,
            rows: airport.runways
                .map(
                  (runway) => [
                    runway.ident,
                    runway.lengthM == null
                        ? '-'
                        : '${runway.lengthM!.toStringAsFixed(0)} m',
                    runway.surface ?? '-',
                  ],
                )
                .toList(),
          ),
          const SizedBox(height: AppThemeData.spacingMedium),
          Text(
            AirportSearchLocalizationKeys.frequenciesTitle.tr(context),
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppThemeData.spacingSmall),
          _CompactTable(
            headers: [
              AirportSearchLocalizationKeys.frequencyTypeLabel.tr(context),
              AirportSearchLocalizationKeys.frequencyValueLabel.tr(context),
            ],
            emptyText: AirportSearchLocalizationKeys.frequenciesEmpty.tr(
              context,
            ),
            maxHeight: null,
            rows: frequencyRows,
          ),
          const SizedBox(height: AppThemeData.spacingMedium),
          Text(
            AirportSearchLocalizationKeys.metarTitle.tr(context),
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppThemeData.spacingSmall),
          _MetarRow(
            label: AirportSearchLocalizationKeys.metarRawLabel.tr(context),
            value: metar.raw,
          ),
          const SizedBox(height: 8),
          _MetarRow(
            label: AirportSearchLocalizationKeys.metarDecodedLabel.tr(context),
            value: metar.decoded,
          ),
        ],
      ),
    );
  }
}

class _CompactTable extends StatelessWidget {
  final List<String> headers;
  final List<List<String>> rows;
  final String emptyText;
  final double? maxHeight;

  const _CompactTable({
    required this.headers,
    required this.rows,
    required this.emptyText,
    this.maxHeight,
  });

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return Text(
        emptyText,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: Theme.of(context).hintColor),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(AppThemeData.borderRadiusSmall),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppThemeData.borderRadiusSmall),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: headers.length < 3
                ? MediaQuery.sizeOf(context).width - AppThemeData.spacingLarge
                : null,
            child: maxHeight == null
                ? _buildDataTable(context)
                : ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: maxHeight!),
                    child: SingleChildScrollView(
                      child: _buildDataTable(context),
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildDataTable(BuildContext context) {
    return DataTable(
      horizontalMargin: 12,
      columnSpacing: 20,
      headingRowHeight: 36,
      dataRowMinHeight: 32,
      dataRowMaxHeight: 40,
      columns: headers
          .map(
            (header) => DataColumn(
              label: Text(
                header,
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          )
          .toList(),
      rows: rows
          .map(
            (row) => DataRow(
              cells: row
                  .map(
                    (value) => DataCell(
                      Text(value, style: Theme.of(context).textTheme.bodySmall),
                    ),
                  )
                  .toList(),
            ),
          )
          .toList(),
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

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: RichText(
        text: TextSpan(
          text: '$label: ',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
          children: [
            TextSpan(
              text: value,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.normal),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetarRow extends StatelessWidget {
  final String label;
  final String? value;

  const _MetarRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final text = (value ?? '').trim().isEmpty
        ? AirportSearchLocalizationKeys.metarEmpty.tr(context)
        : value!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppThemeData.spacingSmall),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AppThemeData.borderRadiusSmall),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          SelectableText(text, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
