import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../core/services/localization_service.dart';
import '../../localization/map_localization_keys.dart';
import '../../models/map_models.dart';
import 'selected_airport/airport_detail_primitives.dart';

class SelectedAirportBottomCard extends StatefulWidget {
  final double scale;
  final MapAirportMarker airport;
  final MapSelectedAirportDetail? detail;
  final bool isLoading;
  final bool isExpanded;
  final ValueChanged<bool> onExpandedChanged;

  const SelectedAirportBottomCard({
    super.key,
    required this.scale,
    required this.airport,
    required this.detail,
    required this.isLoading,
    required this.isExpanded,
    required this.onExpandedChanged,
  });

  @override
  State<SelectedAirportBottomCard> createState() =>
      _SelectedAirportBottomCardState();
}

class _SelectedAirportBottomCardState extends State<SelectedAirportBottomCard> {
  bool _showDecodedMetar = false;

  @override
  void didUpdateWidget(covariant SelectedAirportBottomCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.airport.code != widget.airport.code) {
      _showDecodedMetar = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final runwayCount = widget.detail?.runwayGeometries.length ?? 0;
    final parkingCount = widget.detail?.parkingSpots.length ?? 0;
    final sourceText = (widget.detail?.source ?? '').trim().toUpperCase();
    final title = (widget.airport.name ?? '').trim().isNotEmpty
        ? widget.airport.name!
        : '-';
    final frequencyBadges = widget.detail?.frequencyBadges ?? const <String>[];
    final headlineFontSize = 15 * widget.scale;
    final headlineStyle = TextStyle(
      color: Colors.white,
      fontSize: headlineFontSize,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.15,
      height: 1.1,
    );
    final rawMetar = (widget.detail?.rawMetar ?? widget.detail?.atis ?? '')
        .trim();
    final decodedMetar = (widget.detail?.decodedMetar ?? '').trim();
    final weatherText = _showDecodedMetar
        ? (decodedMetar.isNotEmpty
              ? decodedMetar
              : (rawMetar.isNotEmpty
                    ? rawMetar
                    : MapLocalizationKeys.weatherNoData.tr(context)))
        : (rawMetar.isNotEmpty
              ? rawMetar
              : (decodedMetar.isNotEmpty
                    ? decodedMetar
                    : MapLocalizationKeys.weatherNoData.tr(context)));
    final approachRule = (widget.detail?.approachRule ?? 'UNK').toUpperCase();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(22 * widget.scale),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: EdgeInsets.fromLTRB(
            14 * widget.scale,
            12 * widget.scale,
            14 * widget.scale,
            widget.isExpanded ? 12 * widget.scale : 10 * widget.scale,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [
                      Colors.black.withValues(alpha: 0.78),
                      const Color(0xFF06090E).withValues(alpha: 0.82),
                    ]
                  : [
                      Colors.white.withValues(alpha: 0.82),
                      Colors.white.withValues(alpha: 0.78),
                    ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(22 * widget.scale),
            border: Border.all(
              color: isDark
                  ? Colors.orangeAccent.withValues(alpha: 0.25)
                  : Colors.orangeAccent.withValues(alpha: 0.45),
            ),
            boxShadow: [
              BoxShadow(
                color: (isDark ? Colors.black : Colors.black26).withValues(
                  alpha: 0.25,
                ),
                blurRadius: 20 * widget.scale,
                offset: Offset(0, 8 * widget.scale),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Text(
                          widget.airport.code,
                          style: headlineStyle.copyWith(
                            color: Colors.orangeAccent,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.45,
                          ),
                        ),
                        SizedBox(width: 8 * widget.scale),
                        Expanded(
                          child: Row(
                            children: [
                              Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: headlineStyle.copyWith(
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              if (sourceText.isNotEmpty) ...[
                                SizedBox(width: 8 * widget.scale),
                                SourceBadge(
                                  scale: widget.scale,
                                  label: sourceText,
                                  isDark: isDark,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 8 * widget.scale),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 9 * widget.scale,
                      vertical: 5 * widget.scale,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orangeAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(9 * widget.scale),
                      border: Border.all(
                        color: Colors.orangeAccent.withValues(alpha: 0.55),
                      ),
                    ),
                    child: Text(
                      '$runwayCount RWY',
                      style: TextStyle(
                        color: Colors.orangeAccent,
                        fontSize: 11 * widget.scale,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  SizedBox(width: 6 * widget.scale),
                  ApproachRuleBadge(
                    scale: widget.scale,
                    label: approachRule,
                    isDark: isDark,
                  ),
                  SizedBox(width: 6 * widget.scale),
                  IconButton(
                    onPressed: () =>
                        widget.onExpandedChanged(!widget.isExpanded),
                    icon: Icon(
                      widget.isExpanded
                          ? Icons.keyboard_arrow_down_rounded
                          : Icons.keyboard_arrow_up_rounded,
                      color: isDark ? Colors.white70 : Colors.black54,
                      size: 22 * widget.scale,
                    ),
                    splashRadius: 16 * widget.scale,
                  ),
                ],
              ),
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 220),
                crossFadeState: widget.isExpanded
                    ? CrossFadeState.showFirst
                    : CrossFadeState.showSecond,
                firstChild: Padding(
                  padding: EdgeInsets.only(top: 10 * widget.scale),
                  child: widget.isLoading
                      ? Row(
                          children: [
                            SizedBox(
                              width: 16 * widget.scale,
                              height: 16 * widget.scale,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.orangeAccent,
                              ),
                            ),
                            SizedBox(width: 8 * widget.scale),
                            Text(
                              MapLocalizationKeys.loadingAirportDetail.tr(
                                context,
                              ),
                              style: TextStyle(
                                color: isDark ? Colors.white70 : Colors.black54,
                                fontSize: 12 * widget.scale,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 12 * widget.scale,
                              runSpacing: 8 * widget.scale,
                              children: [
                                AirportMetaItem(
                                  scale: widget.scale,
                                  icon: Icons.straighten_rounded,
                                  value:
                                      '${widget.detail?.runways.length ?? 0}',
                                  unit: 'RWY',
                                  isDark: isDark,
                                ),
                                AirportMetaItem(
                                  scale: widget.scale,
                                  icon: Icons.local_parking_rounded,
                                  value: '$parkingCount',
                                  unit: 'SPOTS',
                                  isDark: isDark,
                                ),
                                AirportMetaItem(
                                  scale: widget.scale,
                                  icon: Icons.location_on_outlined,
                                  value:
                                      '${widget.airport.position.latitude.toStringAsFixed(3)}, ${widget.airport.position.longitude.toStringAsFixed(3)}',
                                  unit: '',
                                  isDark: isDark,
                                ),
                              ],
                            ),
                            if (frequencyBadges.isNotEmpty) ...[
                              SizedBox(height: 10 * widget.scale),
                              Wrap(
                                spacing: 8 * widget.scale,
                                runSpacing: 8 * widget.scale,
                                children: frequencyBadges
                                    .map(
                                      (item) => FrequencyBadge(
                                        scale: widget.scale,
                                        label: item,
                                        isDark: isDark,
                                      ),
                                    )
                                    .toList(),
                              ),
                            ],
                            SizedBox(height: 10 * widget.scale),
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.symmetric(
                                horizontal: 10 * widget.scale,
                                vertical: 6 * widget.scale,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF07111F)
                                    : Colors.blue.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(
                                  10 * widget.scale,
                                ),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.white12
                                      : Colors.blue.withValues(alpha: 0.15),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: Text(
                                      weatherText,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.lightBlue.shade100
                                            : Colors.blue.shade800,
                                        fontSize: 11 * widget.scale,
                                        fontWeight: FontWeight.w600,
                                        height: 1,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 6 * widget.scale),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _showDecodedMetar
                                            ? MapLocalizationKeys
                                                  .metarDecodedShort
                                                  .tr(context)
                                            : MapLocalizationKeys.metarRawShort
                                                  .tr(context),
                                        style: TextStyle(
                                          color: isDark
                                              ? Colors.white70
                                              : Colors.black54,
                                          fontSize: 9 * widget.scale,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      SizedBox(width: 6 * widget.scale),
                                      MetarMiniToggle(
                                        scale: widget.scale,
                                        value: _showDecodedMetar,
                                        isDark: isDark,
                                        onChanged: (value) {
                                          setState(() {
                                            _showDecodedMetar = value;
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                ),
                secondChild: const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
