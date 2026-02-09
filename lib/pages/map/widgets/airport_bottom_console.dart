import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../apps/models/airport_detail_data.dart';
import '../../../apps/providers/simulator/simulator_provider.dart';
import '../../../apps/providers/map_provider.dart';
import '../../../apps/services/weather_service.dart';
import 'approach_profile_painter.dart';

/// 机场底部控制台与进近辅助
class AirportBottomConsole extends StatefulWidget {
  final double scale;
  final AirportDetailData? airport;
  final bool onGround;
  final bool compact;

  const AirportBottomConsole({
    super.key,
    required this.scale,
    required this.airport,
    required this.onGround,
    required this.compact,
  });

  @override
  State<AirportBottomConsole> createState() => _AirportBottomConsoleState();
}

class _AirportBottomConsoleState extends State<AirportBottomConsole> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final sim = context.watch<SimulatorProvider>();
    final mapProvider = context.watch<MapProvider>();
    final airport = widget.airport;

    if (widget.compact || airport == null) {
      if (!sim.isConnected && airport == null) {
        return const SizedBox.shrink();
      }
      return _buildShortBottom(sim, airport);
    }

    final mainFreqs = airport.frequencies.all
        .where(
          (f) => ['ATIS', 'TWR', 'GND', 'APP', 'DEP', 'CTA'].contains(f.type),
        )
        .take(4)
        .toList();

    return Positioned(
      bottom: 24 * widget.scale,
      left: 24 * widget.scale,
      right: 24 * widget.scale,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24 * widget.scale),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: Container(
              padding: EdgeInsets.all(20 * widget.scale),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(24 * widget.scale),
                border: Border.all(
                  color: Colors.orangeAccent.withValues(alpha: 0.2),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black54,
                    blurRadius: 20 * widget.scale,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  airport.icaoCode,
                                  style: TextStyle(
                                    color: Colors.orangeAccent,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14 * widget.scale,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                                if (airport.iataCode != null) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    '/ ${airport.iataCode}',
                                    style: TextStyle(
                                      color: Colors.orangeAccent.withValues(
                                        alpha: 0.6,
                                      ),
                                      fontSize: 12 * widget.scale,
                                    ),
                                  ),
                                ],
                                const SizedBox(width: 12),
                                _buildSourceBadge(airport.dataSourceDisplay),
                              ],
                            ),
                            Text(
                              airport.name,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18 * widget.scale,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          if (mapProvider.currentRunway != null &&
                              mapProvider.currentRunwayAirportIcao ==
                                  airport.icaoCode) ...[
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 10 * widget.scale,
                                vertical: 4 * widget.scale,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(
                                  8 * widget.scale,
                                ),
                                border: Border.all(
                                  color: Colors.green.withValues(alpha: 0.5),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.near_me,
                                    size: 10 * widget.scale,
                                    color: Colors.greenAccent,
                                  ),
                                  SizedBox(width: 4 * widget.scale),
                                  Text(
                                    'ON RWY ${mapProvider.currentRunway}',
                                    style: TextStyle(
                                      color: Colors.greenAccent,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10 * widget.scale,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: 8 * widget.scale),
                          ],
                          if (airport.runways.isNotEmpty)
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 10 * widget.scale,
                                vertical: 4 * widget.scale,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orangeAccent.withValues(
                                  alpha: 0.1,
                                ),
                                borderRadius: BorderRadius.circular(
                                  8 * widget.scale,
                                ),
                                border: Border.all(
                                  color: Colors.orangeAccent.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                              ),
                              child: Text(
                                '${airport.runways.length} RWY',
                                style: TextStyle(
                                  color: Colors.orangeAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10 * widget.scale,
                                ),
                              ),
                            ),
                          SizedBox(width: 12 * widget.scale),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () =>
                                  setState(() => _expanded = !_expanded),
                              borderRadius: BorderRadius.circular(
                                8 * widget.scale,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: Icon(
                                  _expanded
                                      ? Icons.keyboard_arrow_down
                                      : Icons.keyboard_arrow_up,
                                  color: Colors.white54,
                                  size: 24 * widget.scale,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (_expanded) ...[
                    SizedBox(height: 12 * widget.scale),
                    Row(
                      children: [
                        _buildMetaItem(
                          Icons.terrain_outlined,
                          '${airport.elevation ?? 0} FT',
                        ),
                        _buildMetaDivider(),
                        _buildMetaItem(
                          Icons.local_parking_outlined,
                          '${airport.parkings.length} SPOTS',
                        ),
                        _buildMetaDivider(),
                        _buildMetaItem(
                          Icons.location_city_outlined,
                          airport.city ?? airport.country ?? 'UNK',
                        ),
                        const Spacer(),
                        if (airport.metar != null)
                          _buildMetarTag(airport.metar!),
                      ],
                    ),
                    SizedBox(height: 16 * widget.scale),
                    if (mainFreqs.isNotEmpty)
                      SizedBox(
                        height: 32 * widget.scale,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: mainFreqs.length,
                          separatorBuilder: (c, i) =>
                              SizedBox(width: 8 * widget.scale),
                          itemBuilder: (c, i) {
                            final f = mainFreqs[i];
                            return Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 10 * widget.scale,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(
                                  6 * widget.scale,
                                ),
                                border: Border.all(color: Colors.white10),
                              ),
                              child: Center(
                                child: Row(
                                  children: [
                                    Text(
                                      '${f.type}: ',
                                      style: TextStyle(
                                        color: Colors.white54,
                                        fontSize: 10 * widget.scale,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      '${f.frequency.toStringAsFixed(3)} MHz',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11 * widget.scale,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    if (airport.metar != null) ...[
                      SizedBox(height: 12 * widget.scale),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(10 * widget.scale),
                        decoration: BoxDecoration(
                          color: Colors.blueAccent.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8 * widget.scale),
                          border: Border.all(
                            color: Colors.blueAccent.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Text(
                          airport.metar!.raw,
                          style: TextStyle(
                            color: Colors.blue.shade100,
                            fontSize: 10 * widget.scale,
                            fontFamily: 'monospace',
                            letterSpacing: 0.5,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                    if (!widget.onGround) ...[
                      SizedBox(height: 20 * widget.scale),
                      SizedBox(
                        height: 80 * widget.scale,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(
                                    12 * widget.scale,
                                  ),
                                  border: Border.all(color: Colors.white10),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: CustomPaint(
                                  painter: ApproachProfilePainter(
                                    altitude: sim.simulatorData.altitude ?? 0,
                                    distToRwy:
                                        (sim.remainingDistance ?? 0) * 1.852,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 16 * widget.scale),
                            _buildGlideSlopeIndicator(sim),
                          ],
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShortBottom(SimulatorProvider sim, AirportDetailData? airport) {
    return Positioned(
      bottom: 24,
      left: 24,
      right: 24,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              airport?.icaoCode ?? 'ENROUTE',
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            Text(
              '${sim.remainingDistance?.toStringAsFixed(1) ?? '--'} NM TO DEST',
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlideSlopeIndicator(SimulatorProvider sim) {
    final distM = (sim.remainingDistance ?? 0) * 1852;
    final targetAlt = distM * math.tan(3 * math.pi / 180);
    final diff = (sim.simulatorData.altitude ?? 0) - targetAlt;
    final dev = (diff / 200).clamp(-1.0, 1.0);

    return Column(
      children: [
        const Text(
          'G/S',
          style: TextStyle(
            color: Colors.white38,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: Container(
            width: 24,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                for (int i = -2; i <= 2; i++)
                  if (i != 0)
                    Positioned(
                      top: 40 + (i * 15.0) - 1,
                      child: Container(
                        width: 4,
                        height: 1,
                        color: Colors.white24,
                      ),
                    ),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white38, width: 1),
                    shape: BoxShape.circle,
                  ),
                ),
                Positioned(
                  bottom: 40 - (dev * 30) - 5,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Colors.pinkAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMetaItem(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14 * widget.scale, color: Colors.white38),
        SizedBox(width: 4 * widget.scale),
        Text(
          label,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 11 * widget.scale,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildMetaDivider() {
    return Container(
      height: 12 * widget.scale,
      width: 1,
      margin: EdgeInsets.symmetric(horizontal: 12 * widget.scale),
      color: Colors.white12,
    );
  }

  Widget _buildSourceBadge(String source) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 6 * widget.scale,
        vertical: 2 * widget.scale,
      ),
      decoration: BoxDecoration(
        color: Colors.blueGrey.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4 * widget.scale),
      ),
      child: Text(
        source.toUpperCase(),
        style: TextStyle(
          color: Colors.blueGrey.shade100,
          fontSize: 8 * widget.scale,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildMetarTag(MetarData metar) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 8 * widget.scale,
        vertical: 3 * widget.scale,
      ),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6 * widget.scale),
        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.wb_sunny_outlined,
            size: 12 * widget.scale,
            color: Colors.greenAccent,
          ),
          SizedBox(width: 4 * widget.scale),
          Text(
            'VFR',
            style: TextStyle(
              color: Colors.greenAccent,
              fontSize: 10 * widget.scale,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
