import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/services/back_handler_service.dart';
import '../../../core/services/localization_service.dart';
import '../../../core/theme/app_theme_data.dart';
import '../../../core/widgets/common/snack_bar.dart';
import '../localization/airport_search_localization_keys.dart';
import '../providers/airport_search_provider.dart';
import 'widgets/airport_result_card.dart';
import 'widgets/favorite_airports_list.dart';
import 'widgets/icao_search_input.dart';
import 'widgets/search_overview_card.dart';

/// 机场查询主页面
/// 提供 ICAO 代码搜索、自动联想建议以及收藏列表功能
class AirportSearchPage extends StatefulWidget {
  const AirportSearchPage({super.key});

  @override
  State<AirportSearchPage> createState() => _AirportSearchPageState();
}

class _AirportSearchPageState extends State<AirportSearchPage> {
  /// ICAO 文本输入控制器 (强制大写)
  final TextEditingController _icaoController = TextEditingController();

  /// 搜素建议防抖定时器
  Timer? _suggestionDebounce;

  /// 初始化标记，防止 didChangeDependencies 重复触发
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    BackHandlerService().register(_onBack);
  }

  @override
  void dispose() {
    BackHandlerService().unregister(_onBack);
    _suggestionDebounce?.cancel();
    _icaoController.dispose();
    super.dispose();
  }

  bool _onBack() {
    if (!mounted) return false;
    final provider = context.read<AirportSearchProvider>();
    if (provider.latestResult != null ||
        provider.suggestions.isNotEmpty ||
        _icaoController.text.isNotEmpty) {
      _icaoController.clear();
      provider.clearResult();
      return true;
    }
    return false;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;

    // 在首帧渲染后进行 Provider 初始化
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AirportSearchProvider>().init();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AirportSearchProvider>(
      builder: (context, provider, child) {
        // 渲染异常状态提示
        _showError(provider);

        final result = provider.latestResult;
        // 判断当前查询结果是否已在收藏列表中
        final isFavorite =
            result != null && provider.isFavorite(result.airport.icao);

        return Scaffold(
          body: SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.all(AppThemeData.spacingMedium),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // 1. 顶部状态概览
                      SearchOverviewCard(
                        suggestionCount: provider.suggestions.length,
                        favoritesCount: provider.favorites.length,
                      ),
                      const SizedBox(height: AppThemeData.spacingLarge),

                      // 2. ICAO 输入与搜索框
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

                      // 3. 查询结果卡片 (包含天气、跑道、频率等)
                      AirportResultCard(
                        result: result,
                        isFavorite: isFavorite,
                        onToggleFavorite: provider.toggleFavoriteForLatest,
                      ),
                      const SizedBox(height: AppThemeData.spacingMedium),

                      // 4. 收藏机场快速入口列表
                      FavoriteAirportsList(
                        favorites: provider.favorites,
                        onOpen: (icao) {
                          _icaoController.text = icao;
                          provider.selectFavoriteAndQuery(icao);
                        },
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

  /// 检查 provider 是否有待显示的错误
  void _showError(AirportSearchProvider provider) {
    final errorKey = provider.errorKey;
    if (errorKey == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // 显示错误 Snack bar
      SnackBarHelper.showError(context, _mapErrorText(errorKey));
      // 弹出后清除 provider 内部错误状态
      context.read<AirportSearchProvider>().clearError();
    });
  }

  /// 将硬编码的错误 Key 映射为国际化显示文本
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
      default:
        return AirportSearchLocalizationKeys.queryFailed.tr(context);
    }
  }

  /// 响应输入框变化，进行 260ms 的防抖搜索建议请求
  void _onInputChanged(AirportSearchProvider provider, String input) {
    _suggestionDebounce?.cancel();
    _suggestionDebounce = Timer(const Duration(milliseconds: 260), () {
      if (!mounted) return;
      provider.updateSuggestions(input);
    });
  }
}
