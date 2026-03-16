import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/services/localization_service.dart';
import '../../../../core/theme/app_theme_data.dart';
import '../../localization/common_localization_keys.dart';
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
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      final keyword = value.trim();
      if (!mounted) return;
      if (keyword.isEmpty) {
        setState(() {
          _results = [];
          _isSearching = false;
        });
        return;
      }
      setState(() {
        _isSearching = true;
      });
      final results = await widget.onSearch(keyword);
      if (!mounted) return;
      setState(() {
        _results = results;
        _isSearching = false;
      });
    });
  }

  @override
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
            hintText: CommonLocalizationKeys.searchHint.tr(context),
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
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
              CommonLocalizationKeys.searchEmpty.tr(context),
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
            ),
          )
        else ...[
          Text(
            CommonLocalizationKeys.navRecentAirports.tr(context),
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
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final airport = items[index];
                return ListTile(
                  leading: Icon(
                    Icons.flight_takeoff,
                    color: theme.colorScheme.primary,
                  ),
                  title: Text('${airport.icaoCode} / ${airport.iataCode}'),
                  subtitle: Text(airport.displayName),
                  trailing: const Icon(Icons.chevron_right),
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
