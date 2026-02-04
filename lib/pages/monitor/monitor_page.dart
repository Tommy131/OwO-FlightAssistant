import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/providers/simulator_provider.dart';
import '../../core/models/simulator_data.dart';
import '../../core/theme/app_theme_data.dart';

class MonitorPage extends StatefulWidget {
  const MonitorPage({super.key});

  @override
  State<MonitorPage> createState() => _MonitorPageState();
}

class _MonitorPageState extends State<MonitorPage> {
  final List<FlSpot> _gForceSpots = [];
  final List<FlSpot> _altitudeSpots = [];
  final List<FlSpot> _pressureSpots = [];
  double _time = 0;
  static const int _maxSpots = 300; // 5次/秒 * 60秒 = 300个点 (1分钟历史)

  @override
  void initState() {
    super.initState();
    // 数据监听在 build 中通过 Consumer 处理，这里只需处理定时清理或特殊逻辑
  }

  void _updateSpots(SimulatorData data) {
    _time += 0.2; // 假设采样率

    // G-Force
    _gForceSpots.add(FlSpot(_time, data.gForce ?? 1.0));
    if (_gForceSpots.length > _maxSpots) _gForceSpots.removeAt(0);

    // Altitude
    _altitudeSpots.add(FlSpot(_time, data.altitude ?? 0));
    if (_altitudeSpots.length > _maxSpots) _altitudeSpots.removeAt(0);

    // Air Pressure
    _pressureSpots.add(FlSpot(_time, data.baroPressure ?? 29.92));
    if (_pressureSpots.length > _maxSpots) _pressureSpots.removeAt(0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer<SimulatorProvider>(
      builder: (context, simProvider, _) {
        final data = simProvider.simulatorData;
        _updateSpots(data);

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(AppThemeData.spacingLarge),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(theme, data),
                const SizedBox(height: AppThemeData.spacingLarge),

                // 航向仪表 (指南针)
                _buildCompassSection(theme, data),

                const SizedBox(height: AppThemeData.spacingLarge),

                // 图表网格
                LayoutBuilder(
                  builder: (context, constraints) {
                    bool isThreeColumn = constraints.maxWidth > 1000;

                    if (isThreeColumn) {
                      return Row(
                        spacing: AppThemeData.spacingLarge,
                        children: [
                          Expanded(
                            child: _buildChartCard(
                              theme,
                              '重力监控 (G-Force)',
                              '${data.gForce?.toStringAsFixed(2) ?? "1.00"} G',
                              _gForceSpots,
                              Colors.orangeAccent,
                              0,
                              2, // G力通常在0-2波动
                            ),
                          ),
                          Expanded(
                            child: _buildChartCard(
                              theme,
                              '高度趋势 (Altitude)',
                              '${data.altitude?.toStringAsFixed(0) ?? "0"} FT',
                              _altitudeSpots,
                              theme.colorScheme.primary,
                              null,
                              null,
                            ),
                          ),
                          Expanded(
                            child: _buildChartCard(
                              theme,
                              '大气压强 (Baro)',
                              '${data.baroPressure?.toStringAsFixed(2) ?? "29.92"} inHg',
                              _pressureSpots,
                              Colors.cyanAccent,
                              28,
                              31,
                            ),
                          ),
                        ],
                      );
                    } else {
                      return Column(
                        spacing: AppThemeData.spacingLarge,
                        children: [
                          _buildChartCard(
                            theme,
                            '重力监控 (G-Force)',
                            '${data.gForce?.toStringAsFixed(2) ?? "1.00"} G',
                            _gForceSpots,
                            Colors.orangeAccent,
                            0,
                            2,
                          ),
                          _buildChartCard(
                            theme,
                            '高度趋势 (Altitude)',
                            '${data.altitude?.toStringAsFixed(0) ?? "0"} FT',
                            _altitudeSpots,
                            theme.colorScheme.primary,
                            null,
                            null,
                          ),
                          _buildChartCard(
                            theme,
                            '大气压强 (Baro)',
                            '${data.baroPressure?.toStringAsFixed(2) ?? "29.92"} inHg',
                            _pressureSpots,
                            Colors.cyanAccent,
                            28,
                            31,
                          ),
                        ],
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(ThemeData theme, SimulatorData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '实时飞行监控',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        Text(
          data.isConnected ? '正在接收来自 X-Plane 的实时数据' : '模拟器未连接',
          style: TextStyle(color: theme.hintColor),
        ),
      ],
    );
  }

  Widget _buildCompassSection(ThemeData theme, SimulatorData data) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppThemeData.spacingLarge),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(AppThemeData.borderRadiusLarge),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          const Text(
            '磁航向 (Magnetic Heading)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            width: double.infinity,
            child: HeadingCompass(heading: data.heading ?? 0),
          ),
          const SizedBox(height: 10),
          Text(
            '${(data.heading ?? 0).toStringAsFixed(0)}°',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              fontFamily: 'Monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartCard(
    ThemeData theme,
    String title,
    String value,
    List<FlSpot> spots,
    Color color,
    double? minY,
    double? maxY,
  ) {
    return Container(
      height: 300,
      padding: const EdgeInsets.all(AppThemeData.spacingMedium),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(AppThemeData.borderRadiusLarge),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: theme.hintColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  value,
                  style: TextStyle(color: color, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const Expanded(child: SizedBox(height: 10)),
          Expanded(
            flex: 8,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                minX: spots.isNotEmpty ? _time - 60 : 0,
                maxX: _time,
                minY: minY,
                maxY: maxY,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: color,
                    barWidth: 2,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: color.withValues(alpha: 0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 高度还原指南针仪表效果
class HeadingCompass extends StatelessWidget {
  final double heading;

  const HeadingCompass({super.key, required this.heading});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: CompassPainter(
        heading: heading,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

class CompassPainter extends CustomPainter {
  final double heading;
  final Color color;

  CompassPainter({required this.heading, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;

    // 绘制外圈
    final outerCirclePaint = Paint()
      ..color = color.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius, outerCirclePaint);

    // 旋转画布以适应航向
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-heading * math.pi / 180);

    final tickPaint = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    // 绘制刻度
    for (int i = 0; i < 360; i += 10) {
      final angle = i * math.pi / 180;
      final isMajor = i % 30 == 0;
      final tickLength = isMajor ? 15.0 : 8.0;

      final start = Offset(
        math.sin(angle) * (radius - tickLength),
        -math.cos(angle) * (radius - tickLength),
      );
      final end = Offset(math.sin(angle) * radius, -math.cos(angle) * radius);

      canvas.drawLine(start, end, tickPaint..strokeWidth = isMajor ? 2 : 1);

      if (isMajor) {
        String label = i == 0
            ? 'N'
            : i == 90
            ? 'E'
            : i == 180
            ? 'S'
            : i == 270
            ? 'W'
            : (i ~/ 10).toString();
        textPainter.text = TextSpan(
          text: label,
          style: TextStyle(
            color:
                (label == 'N' || label == 'E' || label == 'S' || label == 'W')
                ? Colors.orangeAccent
                : color,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        );
        textPainter.layout();

        final textOffset = Offset(
          math.sin(angle) * (radius - 35) - textPainter.width / 2,
          -math.cos(angle) * (radius - 35) - textPainter.height / 2,
        );

        // 保持文字正向 (相对于仪表) - 这里我们先平移回正再画或者简单点
        canvas.save();
        canvas.translate(
          textOffset.dx + textPainter.width / 2,
          textOffset.dy + textPainter.height / 2,
        );
        canvas.rotate(
          i * math.pi / 180,
        ); // 抵消外层旋转+自身角度使文字始终垂直于圆心向外？不，航空仪表文字通常是正的。
        canvas.rotate(heading * math.pi / 180); // 抵消全局旋转
        canvas.translate(-textPainter.width / 2, -textPainter.height / 2);
        textPainter.paint(canvas, Offset.zero);
        canvas.restore();
      }
    }

    canvas.restore();

    // 绘制中央指示器 (飞机形状)
    final airplanePaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(center.dx, center.dy - 20); // 鼻
    path.lineTo(center.dx - 15, center.dy + 10); // 左翼末
    path.lineTo(center.dx - 3, center.dy + 5); // 躯干
    path.lineTo(center.dx - 5, center.dy + 15); // 左尾
    path.lineTo(center.dx, center.dy + 12); // 尾
    path.lineTo(center.dx + 5, center.dy + 15); // 右尾
    path.lineTo(center.dx + 3, center.dy + 5); // 躯干
    path.lineTo(center.dx + 15, center.dy + 10); // 右翼末
    path.close();

    canvas.drawPath(path, airplanePaint);

    // 绘制顶部的航向指示标
    final topPointerPaint = Paint()..color = Colors.orangeAccent;
    final pointerPath = Path();
    pointerPath.moveTo(center.dx, center.dy - radius - 5);
    pointerPath.lineTo(center.dx - 8, center.dy - radius - 20);
    pointerPath.lineTo(center.dx + 8, center.dy - radius - 20);
    pointerPath.close();
    canvas.drawPath(pointerPath, topPointerPaint);
  }

  @override
  bool shouldRepaint(covariant CompassPainter oldDelegate) =>
      oldDelegate.heading != heading;
}
