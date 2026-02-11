import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import '../../../../apps/data/airports_database.dart';
import '../../../../apps/providers/map_provider.dart';
import '../../../../core/widgets/common/dialog.dart';
import '../airport_pin_widget.dart';
import '../../utils/map_utils.dart';

/// 附近机场图钉图层组件
class NearbyAirportsLayer extends StatefulWidget {
  final double minLat;
  final double maxLat;
  final double minLon;
  final double maxLon;
  final double scale;
  final double zoom;
  final MapProvider mapProvider;
  final Set<String> excludeIcaoCodes; // 排除已显示的机场

  const NearbyAirportsLayer({
    super.key,
    required this.minLat,
    required this.maxLat,
    required this.minLon,
    required this.maxLon,
    required this.scale,
    required this.zoom,
    required this.mapProvider,
    this.excludeIcaoCodes = const {},
  });

  @override
  State<NearbyAirportsLayer> createState() => _NearbyAirportsLayerState();
}

class _NearbyAirportsLayerState extends State<NearbyAirportsLayer> {
  final Set<String> _prefetched = {};
  DateTime? _lastPrefetch;
  final Set<String> _lastExclude = {};
  List<AirportInfo> _airports = [];
  bool _isLoading = false;
  bool _loadingDialogVisible = false;
  Timer? _debounceTimer;
  Timer? _loadingDelayTimer;
  double? _lastMinLat;
  double? _lastMaxLat;
  double? _lastMinLon;
  double? _lastMaxLon;
  int? _lastMaxResults;

  @override
  void initState() {
    super.initState();
    _scheduleLoad();
  }

  @override
  void didUpdateWidget(covariant NearbyAirportsLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_shouldReload()) {
      _scheduleLoad();
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _loadingDelayTimer?.cancel();
    if (_loadingDialogVisible) {
      hideLoadingDialog(context);
    }
    super.dispose();
  }

  void _prefetchIfNeeded(List<AirportInfo> airports) {
    if (widget.zoom < 12) return;
    final now = DateTime.now();
    if (_lastPrefetch != null &&
        now.difference(_lastPrefetch!).inMilliseconds < 1500) {
      return;
    }

    final pending = <String>{};
    for (final airport in airports.take(3)) {
      final icao = airport.icaoCode.toUpperCase();
      if (_prefetched.contains(icao)) continue;
      if (widget.mapProvider.getCachedAirportDetail(icao) != null) {
        _prefetched.add(icao);
        continue;
      }
      pending.add(icao);
    }

    if (pending.isEmpty) return;
    _lastPrefetch = now;
    _prefetched.addAll(pending);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.mapProvider.prefetchAirportDetails(pending);
    });
  }

  bool _shouldReload() {
    final maxResults = _calculateMaxResults();
    if (_lastMinLat == null) return true;
    if ((widget.minLat - _lastMinLat!).abs() > 0.08) return true;
    if ((widget.maxLat - _lastMaxLat!).abs() > 0.08) return true;
    if ((widget.minLon - _lastMinLon!).abs() > 0.08) return true;
    if ((widget.maxLon - _lastMaxLon!).abs() > 0.08) return true;
    if (_lastMaxResults != maxResults) return true;
    if (_lastExclude.length != widget.excludeIcaoCodes.length) return true;
    for (final icao in widget.excludeIcaoCodes) {
      if (!_lastExclude.contains(icao)) return true;
    }
    return false;
  }

  int _calculateMaxResults() {
    if (widget.zoom < 10) return 15;
    if (widget.zoom < 12) return 25;
    return 40;
  }

  void _scheduleLoad() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 160), _loadAirports);
  }

  void _showLoadingIfNeeded() {
    _loadingDelayTimer?.cancel();
    _loadingDelayTimer = Timer(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      if (_loadingDialogVisible || !_isLoading) return;
      showLoadingDialog(context: context, message: '正在加载附近机场...');
      _loadingDialogVisible = true;
    });
  }

  void _hideLoadingIfNeeded() {
    _loadingDelayTimer?.cancel();
    if (_loadingDialogVisible) {
      hideLoadingDialog(context);
      _loadingDialogVisible = false;
    }
  }

  Future<void> _loadAirports() async {
    if (!mounted) return;
    final maxResults = _calculateMaxResults();

    setState(() {
      _isLoading = true;
    });
    _showLoadingIfNeeded();

    await Future<void>.delayed(const Duration(milliseconds: 16));
    final airports =
        AirportsDatabase.findInBounds(
              minLat: widget.minLat,
              maxLat: widget.maxLat,
              minLon: widget.minLon,
              maxLon: widget.maxLon,
              maxResults: maxResults,
            )
            .where(
              (airport) => !widget.excludeIcaoCodes.contains(airport.icaoCode),
            )
            .toList();

    if (!mounted) return;
    setState(() {
      _airports = airports;
      _isLoading = false;
      _lastMinLat = widget.minLat;
      _lastMaxLat = widget.maxLat;
      _lastMinLon = widget.minLon;
      _lastMaxLon = widget.maxLon;
      _lastMaxResults = maxResults;
      _lastExclude
        ..clear()
        ..addAll(widget.excludeIcaoCodes);
    });
    _hideLoadingIfNeeded();
    _prefetchIfNeeded(airports);
  }

  @override
  Widget build(BuildContext context) {
    if (_airports.isEmpty) {
      return const SizedBox.shrink();
    }

    return MarkerLayer(
      markers: _airports.map((airport) {
        final detail = widget.mapProvider.getCachedAirportDetail(
          airport.icaoCode,
        );
        final point = getAirportMarkerPoint(
          latitude: airport.latitude,
          longitude: airport.longitude,
          detail: detail,
        );
        return Marker(
          point: point,
          width: 60,
          height: 60,
          alignment: Alignment.center,
          child: AirportPinWidget(
            icon: Icons.location_on,
            color: Colors.blueGrey,
            label: airport.icaoCode,
            scale: widget.scale,
          ),
        );
      }).toList(),
    );
  }
}
