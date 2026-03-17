import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../core/services/localization_service.dart';
import '../../../../../core/theme/app_theme_data.dart';
import '../../../localization/map_localization_keys.dart';
import '../../../models/map_models.dart';
import '../../../providers/map_provider.dart';

class AirportSearchBar extends StatefulWidget {
  final List<MapAirportMarker> airports;
  final ValueChanged<MapAirportMarker> onSelect;
  final int clearToken;
  final ValueChanged<bool> onSearchInputChanged;

  const AirportSearchBar({
    super.key,
    required this.airports,
    required this.onSelect,
    required this.clearToken,
    required this.onSearchInputChanged,
  });

  @override
  State<AirportSearchBar> createState() => _AirportSearchBarState();
}

class _AirportSearchBarState extends State<AirportSearchBar> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  Timer? _searchDebounce;
  List<MapAirportMarker> _results = [];
  bool _isSearching = false;

  @override
  void didUpdateWidget(covariant AirportSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.clearToken != oldWidget.clearToken) {
      _clearSearchInputState(notifyParent: false);
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    _hideOverlay();
    super.dispose();
  }

  void _showOverlay() {
    if (_overlayEntry != null) return;
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final size = renderBox.size;
    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0, size.height + 6),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(8),
            clipBehavior: Clip.antiAlias,
            child: Container(
              constraints: const BoxConstraints(maxHeight: 280),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withAlpha(50),
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: _results.isEmpty
                  ? (_isSearching
                        ? const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Center(
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          )
                        : Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(
                              MapLocalizationKeys.searchNoResult.tr(context),
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.outline,
                                  ),
                            ),
                          ))
                  : ListView.separated(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: _results.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final airport = _results[index];
                        return ListTile(
                          dense: true,
                          title: Text(
                            airport.code,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            airport.name ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Text(
                            '${airport.position.latitude.toStringAsFixed(2)}, ${airport.position.longitude.toStringAsFixed(2)}',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                          ),
                          onTap: () {
                            widget.onSelect(airport);
                            _controller.text = airport.code;
                            _controller.selection = TextSelection.collapsed(
                              offset: _controller.text.length,
                            );
                            _notifySearchInputChanged();
                            setState(() {
                              _results = [];
                              _isSearching = false;
                            });
                            _hideOverlay();
                            _focusNode.unfocus();
                          },
                        );
                      },
                    ),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _notifySearchInputChanged() {
    widget.onSearchInputChanged(_controller.text.trim().isNotEmpty);
  }

  void _clearSearchInputState({bool notifyParent = true}) {
    _controller.clear();
    setState(() {
      _results = [];
      _isSearching = false;
    });
    _hideOverlay();
    if (notifyParent) {
      _notifySearchInputChanged();
    }
  }

  void _onSearch(String value) {
    _searchDebounce?.cancel();
    final query = value.trim();
    _notifySearchInputChanged();
    if (query.isEmpty) {
      setState(() {
        _results = [];
        _isSearching = false;
      });
      _hideOverlay();
      return;
    }
    setState(() {
      _isSearching = true;
    });
    if (_overlayEntry == null) {
      _showOverlay();
    } else {
      _overlayEntry!.markNeedsBuild();
    }
    _searchDebounce = Timer(const Duration(milliseconds: 260), () async {
      final remoteResults = await context.read<MapProvider>().searchAirports(
        query,
      );
      final localResults = widget.airports.where((airport) {
        final name = airport.name?.toLowerCase() ?? '';
        final lowerQuery = query.toLowerCase();
        return airport.code.toLowerCase().contains(lowerQuery) ||
            name.contains(lowerQuery);
      }).toList();
      final merged = <MapAirportMarker>[
        ...remoteResults,
        ...localResults.where(
          (local) => !remoteResults.any((remote) => remote.code == local.code),
        ),
      ];
      if (!mounted) return;
      setState(() {
        _results = merged;
        _isSearching = false;
      });
      if (_overlayEntry == null) {
        _showOverlay();
      } else {
        _overlayEntry!.markNeedsBuild();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        autofocus: false,
        decoration: InputDecoration(
          hintText: MapLocalizationKeys.searchHint.tr(context),
          hintStyle: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.outline,
          ),
          prefixIcon: const Icon(Icons.search, size: 20),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppThemeData.spacingMedium,
            vertical: AppThemeData.spacingSmall,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: theme.colorScheme.outline.withAlpha(50),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: theme.colorScheme.outline.withAlpha(50),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
          ),
          filled: true,
          fillColor: theme.colorScheme.surface,
        ),
        onChanged: _onSearch,
        onTap: () {
          if (_controller.text.isNotEmpty) {
            _onSearch(_controller.text);
          }
        },
      ),
    );
  }
}
