import 'package:flutter/material.dart';
import '../../../../core/services/localization_service.dart';
import '../../../../core/theme/app_theme_data.dart';
import '../../localization/airport_search_localization_keys.dart';
import '../../models/airport_search_models.dart';

class FavoriteAirportsList extends StatelessWidget {
  final List<FavoriteAirportEntry> favorites;
  final void Function(String icao) onOpen;

  const FavoriteAirportsList({
    super.key,
    required this.favorites,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
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
            AirportSearchLocalizationKeys.favoritesTitle.tr(context),
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppThemeData.spacingSmall),
          if (favorites.isEmpty)
            Text(
              AirportSearchLocalizationKeys.favoritesEmpty.tr(context),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).hintColor,
              ),
            )
          else
            ...favorites.map((entry) {
              return Container(
                margin: const EdgeInsets.only(
                  bottom: AppThemeData.spacingSmall,
                ),
                padding: const EdgeInsets.all(AppThemeData.spacingSmall),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(
                    AppThemeData.borderRadiusSmall,
                  ),
                  color: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.flight, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${entry.icao} · ${entry.name ?? '-'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            '${AirportSearchLocalizationKeys.airportLatLonLabel.tr(context)}: '
                            '${entry.latitude?.toStringAsFixed(4) ?? '-'}, '
                            '${entry.longitude?.toStringAsFixed(4) ?? '-'}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => onOpen(entry.icao),
                      child: Text(
                        AirportSearchLocalizationKeys.searchButton.tr(context),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
