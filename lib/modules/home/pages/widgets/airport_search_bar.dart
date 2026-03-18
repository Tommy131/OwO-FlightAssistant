import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/services/localization_service.dart';
import '../../../../core/theme/app_theme_data.dart';
import '../../localization/home_localization_keys.dart';
import '../../models/home_models.dart';

class AirportSearchBar extends StatefulWidget {
  final Future<List<HomeAirportInfo>> Function(String keyword) onSearch;
  final void Function(HomeAirportInfo airport) onSelect;
  final List<HomeAirportInfo> suggestedAirports;

  const AirportSearchBar({
    super.key,
    required this.onSearch,
    required this.onSelect,
    required this.suggestedAirports,
  });

  @override
  State<AirportSearchBar> createState() => _AirportSearchBarState();
}

class _AirportSearchBarState extends State<AirportSearchBar> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  List<HomeAirportInfo> _results = [];
  bool _isSearching = false;

  @override
  /// 功能：释放控制器、订阅和定时器等资源，避免内存泄漏。
  /// 说明：该方法属于组件生命周期关键路径，会直接影响页面稳定性与交互体验。
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// 功能：响应on search changed事件并驱动交互流程。
  /// 说明：该方法封装单一职责逻辑，便于后续维护、定位问题与扩展功能。
  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      final keyword = value.trim();
      if (!mounted) return;
      if (keyword.isEmpty) {
        /// 功能：更新set state相关状态并触发后续同步流程。
        /// 说明：该方法封装单一职责逻辑，便于后续维护、定位问题与扩展功能。
        setState(() {
          _results = [];
          _isSearching = false;
        });
        return;
      }

      /// 功能：更新set state相关状态并触发后续同步流程。
      /// 说明：该方法封装单一职责逻辑，便于后续维护、定位问题与扩展功能。
      setState(() {
        _isSearching = true;
      });
      final results = await widget.onSearch(keyword);
      if (!mounted) return;

      /// 功能：更新set state相关状态并触发后续同步流程。
      /// 说明：该方法封装单一职责逻辑，便于后续维护、定位问题与扩展功能。
      setState(() {
        _results = results;
        _isSearching = false;
      });
    });
  }

  @override
  /// 功能：构建当前组件的界面结构并返回可渲染的控件树。
  /// 说明：该方法属于组件生命周期关键路径，会直接影响页面稳定性与交互体验。
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final query = _controller.text.trim();
    final showingSuggestions = query.isEmpty;
    final items = showingSuggestions ? widget.suggestedAirports : _results;

    return Column(
      children: [
        TextField(
          controller: _controller,
          onChanged: _onSearchChanged,
          decoration: InputDecoration(
            hintText: HomeLocalizationKeys.searchHint.tr(context),
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    /// 功能：执行onPressed的核心业务流程。
                    /// 说明：该方法封装单一职责逻辑，便于后续维护、定位问题与扩展功能。
                    onPressed: () {
                      _controller.clear();
                      _onSearchChanged('');
                    },
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                AppThemeData.borderRadiusSmall,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (_isSearching)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: CircularProgressIndicator(),
          )
        else if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              HomeLocalizationKeys.searchEmpty.tr(context),
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
            ),
          )
        else ...[
          Text(
            HomeLocalizationKeys.navRecentAirports.tr(context),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 260),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: items.length,
              /// 功能：执行separatorBuilder的核心业务流程。
              /// 说明：该方法封装单一职责逻辑，便于后续维护、定位问题与扩展功能。
              separatorBuilder: (context, index) => const Divider(height: 1),
              /// 功能：执行itemBuilder的核心业务流程。
              /// 说明：该方法封装单一职责逻辑，便于后续维护、定位问题与扩展功能。
              itemBuilder: (context, index) {
                final airport = items[index];
                return ListTile(
                  leading: Icon(
                    Icons.flight_takeoff,
                    color: theme.colorScheme.primary,
                  ),
                  /// 功能：执行Text的核心业务流程。
                  /// 说明：该方法封装单一职责逻辑，便于后续维护、定位问题与扩展功能。
                  title: Text('${airport.icaoCode} / ${airport.iataCode}'),
                  subtitle: Text(airport.displayName),
                  trailing: const Icon(Icons.chevron_right),
                  /// 功能：执行onTap的核心业务流程。
                  /// 说明：该方法封装单一职责逻辑，便于后续维护、定位问题与扩展功能。
                  onTap: () => widget.onSelect(airport),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}
