import 'package:flutter/material.dart';
import '../../../apps/data/airports_database.dart';
import '../../../core/theme/app_theme_data.dart';

class AirportSearchBar extends StatefulWidget {
  final Function(AirportInfo) onSelect;
  final String hintText;
  final bool autofocus;

  const AirportSearchBar({
    super.key,
    required this.onSelect,
    this.hintText = '搜索机场 (ICAO/IATA/名称/经纬度)',
    this.autofocus = false,
  });

  @override
  State<AirportSearchBar> createState() => _AirportSearchBarState();
}

class _AirportSearchBarState extends State<AirportSearchBar> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  List<AirportInfo> _results = [];

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _hideOverlay();
    super.dispose();
  }

  void _showOverlay() {
    if (_overlayEntry != null) return;

    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0, size.height + 5),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(8),
            clipBehavior: Clip.antiAlias,
            child: Container(
              constraints: const BoxConstraints(maxHeight: 300),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withAlpha(50),
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: _results.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        '未找到相关机场',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    )
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
                            '${airport.icaoCode}${airport.iataCode.isNotEmpty ? ' / ${airport.iataCode}' : ''}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            airport.nameChinese,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Text(
                            '${airport.latitude.toStringAsFixed(2)}, ${airport.longitude.toStringAsFixed(2)}',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                          ),
                          onTap: () {
                            widget.onSelect(airport);
                            _controller.clear();
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

  void _onSearch(String value) {
    if (value.trim().isEmpty) {
      _hideOverlay();
      return;
    }

    setState(() {
      _results = AirportsDatabase.search(value.trim());
    });

    if (_overlayEntry == null) {
      _showOverlay();
    } else {
      _overlayEntry!.markNeedsBuild();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return CompositedTransformTarget(
      link: _layerLink,
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        autofocus: widget.autofocus,
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.outline,
          ),
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: _controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    _controller.clear();
                    _hideOverlay();
                  },
                )
              : null,
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
