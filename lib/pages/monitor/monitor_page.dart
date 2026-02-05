import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../apps/providers/simulator_provider.dart';
import '../../apps/models/simulator_data.dart';
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

  // 用于检测变更以防过度绘制
  double? _lastAltitude;
  double? _lastGForce;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    // 数据监听在 build 中通过 Consumer 处理，这里只需处理定时清理或特殊逻辑
  }

  void _updateSpots(SimulatorData data) {
    if (!data.isConnected) return;

    // 如果数据和上一帧完全一样（且不是初始帧），则跳过，防止X轴空转
    if (_initialized &&
        data.altitude == _lastAltitude &&
        data.gForce == _lastGForce) {
      return;
    }

    _time += 0.2;
    _initialized = true;
    _lastAltitude = data.altitude;
    _lastGForce = data.gForce;

    // G-Force (保持 1.0 为默认)
    _gForceSpots.add(FlSpot(_time, data.gForce ?? 1.0));
    if (_gForceSpots.length > _maxSpots) _gForceSpots.removeAt(0);

    // Altitude (仅在有数据时记录，防止从0跳变)
    if (data.altitude != null) {
      _altitudeSpots.add(FlSpot(_time, data.altitude!));
      if (_altitudeSpots.length > _maxSpots) _altitudeSpots.removeAt(0);
    }

    // Air Pressure
    if (data.baroPressure != null) {
      _pressureSpots.add(FlSpot(_time, data.baroPressure!));
      if (_pressureSpots.length > _maxSpots) _pressureSpots.removeAt(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer<SimulatorProvider>(
      builder: (context, simProvider, _) {
        final data = simProvider.simulatorData;

        // 只有当数据真正更新或时间流逝时才更新点
        // 这里简单处理：如果数据对象发生变化，则记录一点
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

                // 顶层仪表行: 航向/系统状态 与 起落架 并行
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          _buildCompassSection(theme, data),
                          const SizedBox(height: AppThemeData.spacingLarge),
                          _buildSystemsStatusCard(theme, data),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppThemeData.spacingLarge),
                    Expanded(child: LandingGearCard(data: data)),
                  ],
                ),

                const SizedBox(height: AppThemeData.spacingLarge),

                // 图表网格
                LayoutBuilder(
                  builder: (context, constraints) {
                    bool isThreeColumn = constraints.maxWidth > 900;

                    if (isThreeColumn) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildChartCard(
                              theme,
                              '重力监控 (G-Force)',
                              '${data.gForce?.toStringAsFixed(2) ?? "1.00"} G',
                              _gForceSpots,
                              Colors.orangeAccent,
                              0,
                              2,
                            ),
                          ),
                          const SizedBox(width: AppThemeData.spacingLarge),
                          Expanded(
                            child: _buildChartCard(
                              theme,
                              '高度趋势 (Altitude)',
                              '${data.altitude?.toStringAsFixed(0) ?? "0"} FT',
                              _altitudeSpots,
                              theme.colorScheme.primary,
                              // 为高度设置动态缓冲区：最小值和最大值之间至少保持 100ft 的差距
                              _calculateMinY(
                                _altitudeSpots,
                                100,
                                defaultVal: 0,
                              ),
                              _calculateMaxY(
                                _altitudeSpots,
                                100,
                                defaultVal: 100,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppThemeData.spacingLarge),
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
                          const SizedBox(height: AppThemeData.spacingLarge),
                          _buildChartCard(
                            theme,
                            '高度趋势 (Altitude)',
                            '${data.altitude?.toStringAsFixed(0) ?? "0"} FT',
                            _altitudeSpots,
                            theme.colorScheme.primary,
                            null,
                            null,
                          ),
                          const SizedBox(height: AppThemeData.spacingLarge),
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

  Widget _buildSystemsStatusCard(ThemeData theme, SimulatorData data) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppThemeData.spacingLarge),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(AppThemeData.borderRadiusLarge),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '飞行系统状态 (Systems Status)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 16),
          _buildStatusRow(
            '停机刹车 (Parking Brake)',
            data.parkingBrake == true ? 'SET' : 'RELEASED',
            isHighlight: data.parkingBrake == true,
          ),
          const Divider(height: 20),
          _buildStatusRow(
            '襟翼位置 (Flaps)',
            data.flapsLabel ?? 'UP',
            isHighlight: (data.flapsDeployRatio ?? 0) > 0.05,
          ),
          const Divider(height: 20),
          _buildStatusRow(
            '减速板 (Speed Brake)',
            data.speedBrake == true ? 'DEPLOYED' : 'RETRACTED',
            isHighlight: data.speedBrake == true,
          ),
          const Divider(height: 20),
          _buildStatusRow(
            '自动刹车 (Auto Brake)',
            data.autoBrakeLevel != null
                ? 'LEVEL ${data.autoBrakeLevel}'
                : 'OFF',
            isHighlight: data.autoBrakeLevel != null,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(
    String label,
    String value, {
    bool isHighlight = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color:
                Theme.of(
                  context,
                ).textTheme.bodySmall?.color?.withValues(alpha: 0.7) ??
                Colors.grey,
            fontSize: 13,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: (isHighlight ? Colors.orangeAccent : Colors.blueAccent)
                .withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            value,
            style: TextStyle(
              color: isHighlight ? Colors.orangeAccent : Colors.blueAccent,
              fontWeight: FontWeight.bold,
              fontSize: 13,
              fontFamily: 'Monospace',
            ),
          ),
        ),
      ],
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
      clipBehavior: Clip.antiAlias,
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
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: theme.hintColor,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
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
          const SizedBox(height: 16),
          Expanded(
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

  double _calculateMinY(
    List<FlSpot> spots,
    double minRange, {
    double defaultVal = 0,
  }) {
    if (spots.isEmpty) return defaultVal;
    double min = spots.map((e) => e.y).reduce(math.min);
    double max = spots.map((e) => e.y).reduce(math.max);
    if (max - min < minRange) {
      return min - (minRange - (max - min)) / 2;
    }
    return min - (minRange * 0.1);
  }

  double _calculateMaxY(
    List<FlSpot> spots,
    double minRange, {
    double defaultVal = 100,
  }) {
    if (spots.isEmpty) return defaultVal;
    double min = spots.map((e) => e.y).reduce(math.min);
    double max = spots.map((e) => e.y).reduce(math.max);
    if (max - min < minRange) {
      return max + (minRange - (max - min)) / 2;
    }
    return max + (minRange * 0.1);
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

class LandingGearCard extends StatelessWidget {
  final SimulatorData data;

  const LandingGearCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Dark panel background similar to the cockpit
    final panelColor = const Color(0xFF2A2A2A);
    final panelBorderColor = const Color(0xFF1A1A1A);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppThemeData.spacingLarge),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(AppThemeData.borderRadiusLarge),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '起落架状态 (Landing Gear)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 20),
          Center(
            child: Container(
              width: 280,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: panelColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: panelBorderColor, width: 4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Indicator Lights Area
                  _buildIndicators(data),
                  const SizedBox(height: 24),
                  // Gear Handle Area
                  _buildGearHandle(
                    context,
                    data.gearHandlePosition ?? 0,
                  ), // Default to DN
                  const SizedBox(height: 16),
                  // Limit Text (Decorative)
                  _buildLimitText(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIndicators(SimulatorData data) {
    // Status logic: 0=Off/Up, 1=Red/Transit, 2=Green/Down

    // Logic refinement for "High Simulation":
    // 1. Nose Gear
    // 2. Left Gear
    // 3. Right Gear
    // Each has two lights: Top (Red/Transit) and Bottom (Green/Down).

    final handle = data.gearHandlePosition ?? 0; // Default Down
    final isHandleDown = handle == 0;
    final isHandleUp = handle == 2;

    // Helper to determine status
    // Returns: 0=Off, 1=Red, 2=Green
    int getStatus(bool? isGearDownBool) {
      bool gearDown = isGearDownBool ?? false;

      if (isHandleDown) {
        return gearDown
            ? 2
            : 1; // Handle DN: Gear Down -> Green. Not Down -> Red (Transit).
      } else if (isHandleUp) {
        return gearDown
            ? 1
            : 0; // Handle UP: Gear Down -> Red (Unsafe). Gear Up -> Off.
      } else {
        // OFF position (1)
        // Used for depressurization.
        // If gear is locked down, it stays Green.
        // If gear is locked up, it stays Off.
        // If in transit... usually Red.
        return gearDown ? 2 : 0;
      }
    }

    return Column(
      children: [
        // Nose Gear (Top Center)
        _buildLightBox("NOSE\nGEAR", getStatus(data.noseGearDown)),
        const SizedBox(height: 12),
        // Main Gears (Row)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLightBox("LEFT\nGEAR", getStatus(data.leftGearDown)),
            const SizedBox(width: 24),
            _buildLightBox("RIGHT\nGEAR", getStatus(data.rightGearDown)),
          ],
        ),
      ],
    );
  }

  Widget _buildLightBox(String text, int status) {
    // status: 0=Off, 1=Red (Transit), 2=Green (Down)
    final bool isRedLit = status == 1; // Top Light
    final bool isGreenLit = status == 2; // Bottom Light

    return Column(
      children: [
        // Red Light Box (Top) - Indicates Transit/Unsafe
        _buildSingleLight(text, Colors.redAccent, isRedLit),
        const SizedBox(height: 4),
        // Green Light Box (Bottom) - Indicates Down & Locked
        _buildSingleLight(text, const Color(0xFF4CAF50), isGreenLit),
      ],
    );
  }

  Widget _buildSingleLight(String text, Color color, bool isLit) {
    return Container(
      width: 60,
      height: 40,
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border.all(color: Colors.grey[800]!, width: 2),
        borderRadius: BorderRadius.circular(4),
        boxShadow: isLit
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.6),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          // If lit, use the color. If not lit, use a very dim text color (simulating text etched on glass)
          color: isLit ? color : Colors.grey.withValues(alpha: 0.3),
          fontSize: 10,
          fontWeight: FontWeight.bold,
          height: 1.1,
          fontFamily:
              'monospace', // Use a monospaced-like font if available, or default
        ),
      ),
    );
  }

  Widget _buildGearHandle(BuildContext context, int position) {
    // Position: 2=UP, 1=OFF, 0=DN
    double sliderValue = 0;
    if (position == 2) sliderValue = -1; // Top
    if (position == 1) sliderValue = 0; // Middle
    if (position == 0) sliderValue = 1; // Bottom

    return SizedBox(
      height: 200,
      width: 80,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background Track
          Container(
            width: 40,
            height: 180,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey[800]!, width: 2),
            ),
          ),
          // Labels
          const Positioned(
            top: 10,
            left: 0,
            child: Text(
              "UP",
              style: TextStyle(color: Colors.white70, fontSize: 10),
            ),
          ),
          const Positioned(
            top: 85,
            left: 0,
            child: Text(
              "OFF",
              style: TextStyle(color: Colors.white70, fontSize: 10),
            ),
          ),
          const Positioned(
            bottom: 10,
            left: 0,
            child: Text(
              "DN",
              style: TextStyle(color: Colors.white70, fontSize: 10),
            ),
          ),

          // The Handle (Animated)
          AnimatedAlign(
            duration: const Duration(milliseconds: 300),
            alignment: Alignment(0, sliderValue),
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey[300],
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black54,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.white, Colors.grey[400]!],
                ),
              ),
              child: Center(
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle, // Wheel shape?
                    color: Colors.transparent,
                    border: Border.all(color: Colors.grey[600]!, width: 2),
                  ),
                  child: const Icon(Icons.circle, color: Colors.grey, size: 30),
                ),
              ),
            ),
          ),

          // Gear text label vertical
          const Positioned(
            left: -25,
            top: 50,
            child: RotatedBox(
              quarterTurns: 3,
              child: Text(
                "LANDING GEAR",
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 10,
                  letterSpacing: 2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLimitText() {
    return Column(
      children: const [
        Text(
          "LANDING GEAR LIMIT (IAS)",
          style: TextStyle(
            color: Colors.grey,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 4),
        Text(
          "OPERATING EXTEND 270K - 82M\nRETRACT 235K\nEXTENDED 320K - 82M",
          style: TextStyle(
            color: Colors.grey,
            fontSize: 8,
            fontFamily: 'Monospace',
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
