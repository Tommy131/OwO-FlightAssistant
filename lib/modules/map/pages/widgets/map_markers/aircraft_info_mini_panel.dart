import 'package:flutter/material.dart';

class AircraftInfoMiniPanel extends StatefulWidget {
  final Offset aircraftScreenOffset;
  final Size viewportSize;
  final double scale;
  final bool brightBackground;
  final String? flightNumber;
  final String? registration;
  final double? altitude;
  final double? groundSpeed;
  final String? transponderCode;
  final String? transponderState;

  const AircraftInfoMiniPanel({
    super.key,
    required this.aircraftScreenOffset,
    required this.viewportSize,
    required this.scale,
    required this.brightBackground,
    this.flightNumber,
    this.registration,
    this.altitude,
    this.groundSpeed,
    this.transponderCode,
    this.transponderState,
  });

  @override
  State<AircraftInfoMiniPanel> createState() => _AircraftInfoMiniPanelState();
}

class _AircraftInfoMiniPanelState extends State<AircraftInfoMiniPanel> {
  Offset _relativeOffset = const Offset(118, -92);

  @override
  Widget build(BuildContext context) {
    final scale = widget.scale;
    final panelWidth = 192.0 * scale;
    final panelHeight = 74.0 * scale;
    final margin = 10.0 * scale;
    final panelLeft = (widget.aircraftScreenOffset.dx + _relativeOffset.dx)
        .clamp(margin, widget.viewportSize.width - panelWidth - margin)
        .toDouble();
    final panelTop = (widget.aircraftScreenOffset.dy + _relativeOffset.dy)
        .clamp(margin, widget.viewportSize.height - panelHeight - margin)
        .toDouble();
    final panelCenter = Offset(
      panelLeft + panelWidth / 2,
      panelTop + panelHeight / 2,
    );
    final lineEnd = panelCenter.dx >= widget.aircraftScreenOffset.dx
        ? Offset(panelLeft, panelCenter.dy)
        : Offset(panelLeft + panelWidth, panelCenter.dy);
    final labelPrimary = _resolveMainLabel();
    final altitudeText = widget.altitude == null
        ? '--'
        : '${widget.altitude!.round()} ft';
    final speedText = widget.groundSpeed == null
        ? '--'
        : '${widget.groundSpeed!.round()} kts';
    final xpdrCode = _safeText(widget.transponderCode, fallback: '----');
    final xpdrState = _safeText(widget.transponderState, fallback: '--');
    final bright = widget.brightBackground;
    final backgroundColor = bright
        ? const Color(0xCC10141A)
        : const Color(0xDDF7FAFF);
    final borderColor = bright ? Colors.white30 : Colors.black26;
    final titleColor = bright ? Colors.white : const Color(0xFF13233A);
    final valueColor = bright ? Colors.white : Colors.black87;
    final labelColor = bright ? Colors.white70 : Colors.black54;
    final accentColor = bright ? Colors.amberAccent : const Color(0xFFAA4A00);
    final lineColor = bright
        ? Colors.black.withValues(alpha: 0.34)
        : Colors.white.withValues(alpha: 0.38);
    return Stack(
      children: [
        IgnorePointer(
          child: CustomPaint(
            size: widget.viewportSize,
            painter: _AircraftInfoConnectorPainter(
              start: widget.aircraftScreenOffset,
              end: lineEnd,
              color: lineColor,
              strokeWidth: (1.3 * scale).clamp(1.0, 2.2),
            ),
          ),
        ),
        Positioned(
          left: panelLeft,
          top: panelTop,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanUpdate: (details) {
              setState(() {
                _relativeOffset += details.delta;
              });
            },
            child: Container(
              width: panelWidth,
              height: panelHeight,
              padding: EdgeInsets.symmetric(
                horizontal: 9 * scale,
                vertical: 7 * scale,
              ),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(10 * scale),
                border: Border.all(color: borderColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.24),
                    blurRadius: 10 * scale,
                    offset: Offset(0, 3 * scale),
                  ),
                ],
              ),
              child: DefaultTextStyle(
                style: TextStyle(
                  color: valueColor,
                  fontSize: 12 * scale,
                  fontWeight: FontWeight.w600,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      labelPrimary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: titleColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 12 * scale,
                      ),
                    ),
                    SizedBox(height: 5 * scale),
                    Row(
                      children: [
                        _InfoCell(
                          label: 'ALT',
                          value: altitudeText,
                          labelColor: labelColor,
                          valueColor: accentColor,
                          scale: scale,
                        ),
                        SizedBox(width: 7 * scale),
                        _InfoCell(
                          label: 'SPD',
                          value: speedText,
                          labelColor: labelColor,
                          valueColor: valueColor,
                          scale: scale,
                        ),
                        SizedBox(width: 7 * scale),
                        Expanded(
                          child: _InfoCell(
                            label: 'XPDR',
                            value: '$xpdrCode $xpdrState',
                            labelColor: labelColor,
                            valueColor: valueColor,
                            scale: scale,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _resolveMainLabel() {
    final registration =
        _safeText(widget.registration, fallback: '--', uppercase: true) ?? '--';
    final flightNumber = _safeText(widget.flightNumber, uppercase: true);
    if (flightNumber == null) {
      return registration;
    }
    return '$flightNumber · $registration';
  }

  String? _safeText(String? value, {String? fallback, bool uppercase = false}) {
    final text = value?.trim();
    if (text == null || text.isEmpty) {
      return fallback;
    }
    return uppercase ? text.toUpperCase() : text;
  }
}

class _InfoCell extends StatelessWidget {
  final String label;
  final String value;
  final Color labelColor;
  final Color valueColor;
  final double scale;

  const _InfoCell({
    required this.label,
    required this.value,
    required this.labelColor,
    required this.valueColor,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: labelColor,
            fontSize: 9 * scale,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.45,
          ),
        ),
        SizedBox(height: 1 * scale),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: valueColor,
            fontSize: 11 * scale,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _AircraftInfoConnectorPainter extends CustomPainter {
  final Offset start;
  final Offset end;
  final Color color;
  final double strokeWidth;

  const _AircraftInfoConnectorPainter({
    required this.start,
    required this.end,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..lineTo(end.dx, end.dy);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _AircraftInfoConnectorPainter oldDelegate) {
    return oldDelegate.start != start ||
        oldDelegate.end != end ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
