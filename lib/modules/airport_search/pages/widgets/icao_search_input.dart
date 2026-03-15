import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/services/localization_service.dart';
import '../../../../core/theme/app_theme_data.dart';
import '../../localization/airport_search_localization_keys.dart';
import '../../models/airport_search_models.dart';

class IcaoSearchInput extends StatelessWidget {
  final TextEditingController controller;
  final bool isBusy;
  final bool isSuggesting;
  final List<AirportSuggestionData> suggestions;
  final ValueChanged<String> onChanged;
  final ValueChanged<AirportSuggestionData> onSelectSuggestion;
  final VoidCallback onSearch;

  const IcaoSearchInput({
    super.key,
    required this.controller,
    required this.isBusy,
    required this.isSuggesting,
    required this.suggestions,
    required this.onChanged,
    required this.onSelectSuggestion,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppThemeData.spacingMedium),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.surface,
            Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
          ],
        ),
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
            AirportSearchLocalizationKeys.icaoLabel.tr(context),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppThemeData.spacingSmall),
          TextField(
            controller: controller,
            textCapitalization: TextCapitalization.characters,
            maxLength: 4,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
              LengthLimitingTextInputFormatter(4),
              TextInputFormatter.withFunction((oldValue, newValue) {
                return newValue.copyWith(
                  text: newValue.text.toUpperCase(),
                  selection: TextSelection.collapsed(
                    offset: newValue.text.length,
                  ),
                );
              }),
            ],
            decoration: InputDecoration(
              counterText: '',
              hintText: AirportSearchLocalizationKeys.icaoHint.tr(context),
              prefixIcon: const Icon(Icons.pin_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                  AppThemeData.borderRadiusSmall,
                ),
              ),
            ),
            onChanged: onChanged,
            onSubmitted: (_) => onSearch(),
          ),
          const SizedBox(height: 6),
          Text(
            '${AirportSearchLocalizationKeys.formatHint.tr(context)} · ${AirportSearchLocalizationKeys.fuzzyHint.tr(context)}',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Theme.of(context).hintColor),
          ),
          if (isSuggesting || suggestions.isNotEmpty) ...[
            const SizedBox(height: AppThemeData.spacingSmall),
            _SuggestionList(
              isSuggesting: isSuggesting,
              suggestions: suggestions,
              onSelect: onSelectSuggestion,
            ),
          ],
          const SizedBox(height: AppThemeData.spacingSmall),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: isBusy ? null : onSearch,
              icon: isBusy
                  ? const SizedBox(
                      height: 14,
                      width: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.search),
              label: Text(
                AirportSearchLocalizationKeys.searchButton.tr(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggestionList extends StatelessWidget {
  final bool isSuggesting;
  final List<AirportSuggestionData> suggestions;
  final ValueChanged<AirportSuggestionData> onSelect;

  const _SuggestionList({
    required this.isSuggesting,
    required this.suggestions,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(AppThemeData.borderRadiusSmall),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppThemeData.spacingSmall),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AirportSearchLocalizationKeys.suggestionsTitle.tr(context),
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            if (isSuggesting)
              const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else if (suggestions.isEmpty)
              Text(
                AirportSearchLocalizationKeys.suggestionsEmpty.tr(context),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).hintColor,
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: suggestions
                    .map(
                      (item) => ActionChip(
                        onPressed: () => onSelect(item),
                        avatar: const Icon(Icons.flight_takeoff, size: 16),
                        label: Text(
                          '${item.icao} · ${item.name ?? '-'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }
}
