import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/services/localization_service.dart';
import '../../../core/theme/app_theme_data.dart';
import '../../../core/widgets/common/snack_bar.dart';
import '../localization/airport_search_localization_keys.dart';
import '../providers/airport_search_provider.dart';
import 'widgets/airport_result_card.dart';
import 'widgets/favorite_airports_list.dart';
import 'widgets/icao_search_input.dart';

class AirportSearchPage extends StatefulWidget {
  const AirportSearchPage({super.key});

  @override
  State<AirportSearchPage> createState() => _AirportSearchPageState();
}

class _AirportSearchPageState extends State<AirportSearchPage> {
  final TextEditingController _icaoController = TextEditingController();
  Timer? _suggestionDebounce;
  bool _initialized = false;

  @override
  void dispose() {
    _suggestionDebounce?.cancel();
    _icaoController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AirportSearchProvider>().init();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AirportSearchProvider>(
      builder: (context, provider, child) {
        _showError(provider);
        final result = provider.latestResult;
        final isFavorite =
            result != null && provider.isFavorite(result.airport.icao);

        return Scaffold(
          body: SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: 70,
                  floating: false,
                  pinned: true,
                  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                  flexibleSpace: FlexibleSpaceBar(
                    titlePadding: const EdgeInsets.symmetric(
                      horizontal: AppThemeData.spacingMedium,
                      vertical: AppThemeData.spacingMedium,
                    ),
                    title: Text(
                      AirportSearchLocalizationKeys.pageTitle.tr(context),
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    centerTitle: false,
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.all(AppThemeData.spacingMedium),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _SearchOverviewCard(
                        suggestionCount: provider.suggestions.length,
                        favoritesCount: provider.favorites.length,
                      ),
                      const SizedBox(height: AppThemeData.spacingLarge),
                      IcaoSearchInput(
                        controller: _icaoController,
                        isBusy: provider.isSearching,
                        isSuggesting: provider.isSuggesting,
                        suggestions: provider.suggestions,
                        onChanged: (value) => _onInputChanged(provider, value),
                        onSelectSuggestion: (item) {
                          _icaoController.text = item.icao;
                          provider.querySuggestion(item);
                        },
                        onSearch: () =>
                            provider.queryAirport(_icaoController.text),
                      ),
                      const SizedBox(height: AppThemeData.spacingMedium),
                      AirportResultCard(
                        result: result,
                        isFavorite: isFavorite,
                        isUpdating: provider.isUpdating,
                        onToggleFavorite: provider.toggleFavoriteForLatest,
                        onRefreshFavorite: () {
                          if (result == null) return;
                          provider.refreshFavorite(result.airport.icao);
                        },
                      ),
                      const SizedBox(height: AppThemeData.spacingMedium),
                      FavoriteAirportsList(
                        favorites: provider.favorites,
                        isUpdating: provider.isUpdating,
                        onOpen: (icao) {
                          _icaoController.text = icao;
                          provider.selectFavoriteAndQuery(icao);
                        },
                        onRefresh: provider.refreshFavorite,
                      ),
                      const SizedBox(height: AppThemeData.spacingLarge),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showError(AirportSearchProvider provider) {
    final errorKey = provider.errorKey;
    if (errorKey == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      SnackBarHelper.showError(context, _mapErrorText(errorKey));
      context.read<AirportSearchProvider>().clearError();
    });
  }

  String _mapErrorText(String errorKey) {
    switch (errorKey) {
      case 'invalidIcao':
        return AirportSearchLocalizationKeys.invalidIcao.tr(context);
      case 'queryFailed':
        return AirportSearchLocalizationKeys.queryFailed.tr(context);
      case 'favoriteSaveFailed':
        return AirportSearchLocalizationKeys.favoriteSaveFailed.tr(context);
      case 'favoriteLoadFailed':
        return AirportSearchLocalizationKeys.favoriteLoadFailed.tr(context);
      case 'favoriteUpdateFailed':
        return AirportSearchLocalizationKeys.favoriteUpdateFailed.tr(context);
      default:
        return AirportSearchLocalizationKeys.queryFailed.tr(context);
    }
  }

  void _onInputChanged(AirportSearchProvider provider, String input) {
    _suggestionDebounce?.cancel();
    _suggestionDebounce = Timer(const Duration(milliseconds: 260), () {
      if (!mounted) return;
      provider.updateSuggestions(input);
    });
  }
}

class _SearchOverviewCard extends StatelessWidget {
  final int suggestionCount;
  final int favoritesCount;

  const _SearchOverviewCard({
    required this.suggestionCount,
    required this.favoritesCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppThemeData.spacingMedium),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.16),
            Theme.of(
              context,
            ).colorScheme.secondaryContainer.withValues(alpha: 0.3),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppThemeData.borderRadiusMedium),
      ),
      child: Row(
        children: [
          const Icon(Icons.travel_explore_rounded, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${AirportSearchLocalizationKeys.suggestionsTitle.tr(context)}: $suggestionCount   ${AirportSearchLocalizationKeys.favoritesTitle.tr(context)}: $favoritesCount',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
