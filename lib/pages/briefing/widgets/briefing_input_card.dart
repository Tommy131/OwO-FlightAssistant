import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../apps/providers/briefing_provider.dart';
import '../../../apps/providers/simulator/simulator_provider.dart';
import '../../../apps/models/airport_info.dart';
import '../../../apps/models/airport_detail_data.dart';
import '../../../apps/services/airport_detail_service.dart';
import '../../../core/theme/app_theme_data.dart';
import '../../../core/widgets/common/airport_search_field.dart';
import '../../../core/widgets/common/runway_selector.dart';
import '../../../core/utils/simulator_auto_fill_helper.dart';

/// 简报输入卡片组件
class BriefingInputCard extends StatefulWidget {
  const BriefingInputCard({super.key});

  @override
  State<BriefingInputCard> createState() => _BriefingInputCardState();
}

class _BriefingInputCardState extends State<BriefingInputCard> {
  final _formKey = GlobalKey<FormState>();
  final _departureController = TextEditingController();
  final _arrivalController = TextEditingController();
  final _alternateController = TextEditingController();
  final _flightNumberController = TextEditingController();
  final _routeController = TextEditingController();
  final _cruiseAltitudeController = TextEditingController(text: '35000');

  AirportInfo? _departureAirport;
  AirportInfo? _arrivalAirport;
  AirportInfo? _alternateAirport;
  bool _hasAutoFilled = false;

  // ICAO验证状态
  bool _isDepartureValid = false;
  bool _isArrivalValid = false;
  bool _isAlternateValid = true; // 备降机场可选，默认有效

  // 跑道选择
  String? _selectedDepartureRunway;
  String? _selectedArrivalRunway;
  AirportDetailData? _departureDetail;
  AirportDetailData? _arrivalDetail;
  bool _isLoadingRunways = false;

  @override
  void initState() {
    super.initState();
    // 延迟执行自动填充，确保Provider已初始化
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoFillFromSimulator();
    });
  }

  @override
  void dispose() {
    _departureController.dispose();
    _arrivalController.dispose();
    _alternateController.dispose();
    _flightNumberController.dispose();
    _routeController.dispose();
    _cruiseAltitudeController.dispose();
    super.dispose();
  }

  /// 从模拟器自动填充机场信息
  void _autoFillFromSimulator() {
    if (_hasAutoFilled) return;

    final simProvider = context.read<SimulatorProvider>();
    final result = SimulatorAutoFillHelper.autoFillAirports(simProvider);

    if (!result.hasData) return;

    bool hasFilledData = false;

    // 自动填充起飞机场（当前最近机场）
    if (result.departureAirport != null && _departureController.text.isEmpty) {
      _departureController.text = result.departureAirport!.icaoCode;
      _departureAirport = result.departureAirport;
      hasFilledData = true;
    }

    // 自动填充到达机场
    if (result.arrivalAirport != null && _arrivalController.text.isEmpty) {
      _arrivalController.text = result.arrivalAirport!.icaoCode;
      _arrivalAirport = result.arrivalAirport;
      hasFilledData = true;
    }

    // 自动填充备降机场
    if (result.alternateAirport != null && _alternateController.text.isEmpty) {
      _alternateController.text = result.alternateAirport!.icaoCode;
      _alternateAirport = result.alternateAirport;
      hasFilledData = true;
    }

    if (hasFilledData) {
      _hasAutoFilled = true;
      setState(() {});

      // 显示提示
      if (mounted) {
        SimulatorAutoFillHelper.showAutoFillSnackBar(context, result);
      }
    }
  }

  /// 手动刷新模拟器数据
  void _refreshFromSimulator() {
    _hasAutoFilled = false;
    _autoFillFromSimulator();
  }

  void _generateBriefing() {
    if (_formKey.currentState!.validate()) {
      final provider = context.read<BriefingProvider>();
      final simProvider = context.read<SimulatorProvider>();

      // 从模拟器获取重量数据（仅当连接时）
      int? simulatorTotalWeight;
      int? simulatorEmptyWeight;
      int? simulatorPayloadWeight;
      double? simulatorFuelWeight;

      if (simProvider.isConnected) {
        simulatorTotalWeight = simProvider.simulatorData.totalWeight?.round();
        simulatorEmptyWeight = simProvider.simulatorData.emptyWeight?.round();
        simulatorPayloadWeight = simProvider.simulatorData.payloadWeight
            ?.round();
        simulatorFuelWeight = simProvider.simulatorData.fuelQuantity;
      }

      provider.generateBriefing(
        departureIcao: _departureController.text.trim().toUpperCase(),
        arrivalIcao: _arrivalController.text.trim().toUpperCase(),
        alternateIcao: _alternateController.text.trim().isNotEmpty
            ? _alternateController.text.trim().toUpperCase()
            : null,
        flightNumber: _flightNumberController.text.trim().isNotEmpty
            ? _flightNumberController.text.trim()
            : null,
        route: _routeController.text.trim().isNotEmpty
            ? _routeController.text.trim()
            : null,
        cruiseAltitude: int.tryParse(_cruiseAltitudeController.text.trim()),
        departureRunway: _selectedDepartureRunway,
        arrivalRunway: _selectedArrivalRunway,
        // 传递模拟器重量数据
        simulatorTotalWeight: simulatorTotalWeight,
        simulatorEmptyWeight: simulatorEmptyWeight,
        simulatorPayloadWeight: simulatorPayloadWeight,
        simulatorFuelWeight: simulatorFuelWeight,
      );
    }
  }

  /// 加载机场跑道信息
  Future<void> _loadAirportRunways(String icaoCode, bool isDeparture) async {
    setState(() => _isLoadingRunways = true);

    try {
      final service = AirportDetailService();
      final detail = await service.fetchAirportDetail(icaoCode);

      if (detail != null && mounted) {
        setState(() {
          if (isDeparture) {
            _departureDetail = detail;
            _detectCurrentRunway(detail, true);
          } else {
            _arrivalDetail = detail;
          }
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingRunways = false);
      }
    }
  }

  /// 检测飞机当前所在跑道
  void _detectCurrentRunway(AirportDetailData airport, bool isDeparture) {
    final simProvider = context.read<SimulatorProvider>();
    if (!simProvider.isConnected) return;

    final lat = simProvider.simulatorData.latitude;
    final lon = simProvider.simulatorData.longitude;
    final onGround = simProvider.simulatorData.onGround ?? false;

    if (lat == null || lon == null || !onGround) return;

    // 检查飞机是否在某条跑道上
    for (final runway in airport.runways) {
      if (runway.isPointOnRunway(lat, lon)) {
        // 找到匹配的跑道，选择合适的端点
        String? selectedRunway;

        // 根据飞机朝向选择跑道端点
        final heading = simProvider.simulatorData.heading ?? 0;

        if (runway.leIdent != null && runway.heIdent != null) {
          // 解析跑道号
          final leNum = int.tryParse(
            runway.leIdent!.replaceAll(RegExp(r'[LRC]'), ''),
          );
          final heNum = int.tryParse(
            runway.heIdent!.replaceAll(RegExp(r'[LRC]'), ''),
          );

          if (leNum != null && heNum != null) {
            final leHeading = leNum * 10;
            final heHeading = heNum * 10;

            // 选择与飞机朝向最接近的端点
            final leDiff = (heading - leHeading).abs();
            final heDiff = (heading - heHeading).abs();

            selectedRunway = leDiff < heDiff ? runway.leIdent : runway.heIdent;
          }
        }

        if (selectedRunway == null) {
          // 如果没有详细端点信息，使用第一个
          final parts = runway.ident.split('/');
          selectedRunway = parts.isNotEmpty ? parts[0] : null;
        }

        if (selectedRunway != null && mounted) {
          setState(() {
            if (isDeparture) {
              _selectedDepartureRunway = selectedRunway;
            }
          });

          // 显示提示
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('检测到飞机位于跑道 $selectedRunway'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
        break;
      }
    }
  }

  /// 检查是否可以生成简报
  bool _canGenerateBriefing() {
    // 必须有起飞和到达机场，且都是有效的ICAO代码
    if (!_isDepartureValid || !_isArrivalValid) {
      return false;
    }

    // 如果填写了备降机场，必须是有效的ICAO代码
    if (!_isAlternateValid) {
      return false;
    }

    return true;
  }

  /// 获取验证提示信息
  String _getValidationMessage() {
    if (!_isDepartureValid) {
      return '请输入有效的起飞机场ICAO代码';
    }
    if (!_isArrivalValid) {
      return '请输入有效的到达机场ICAO代码';
    }
    if (!_isAlternateValid) {
      return '备降机场ICAO代码无效，请修正或清空';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<BriefingProvider>();
    final simProvider = context.watch<SimulatorProvider>();

    return Padding(
      padding: const EdgeInsets.all(AppThemeData.spacingMedium),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题和刷新按钮
            Row(
              children: [
                Expanded(
                  child: Text(
                    '航班信息',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (simProvider.isConnected)
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: '从模拟器刷新',
                    onPressed: _refreshFromSimulator,
                    iconSize: 20,
                  ),
              ],
            ),

            // 模拟器状态提示
            if (simProvider.isConnected) ...[
              const SizedBox(height: AppThemeData.spacingSmall),
              SimulatorAutoFillHelper.buildStatusBanner(context, simProvider),
            ],

            const SizedBox(height: AppThemeData.spacingMedium),

            // 航班号
            _buildFlightNumberField(),
            const SizedBox(height: AppThemeData.spacingMedium),

            // 起飞机场
            AirportSearchField(
              controller: _departureController,
              label: '起飞机场',
              hint: 'ICAO代码',
              icon: Icons.flight_takeoff,
              iconColor: Colors.green,
              required: true,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '请输入起飞机场';
                }
                if (!RegExp(r'^[A-Z]{4}$').hasMatch(value.trim())) {
                  return '请输入4位ICAO代码';
                }
                return null;
              },
              onAirportSelected: (airport) {
                setState(() {
                  _departureAirport = airport;
                  _departureDetail = null;
                  _selectedDepartureRunway = null;
                  _isDepartureValid = airport != null;
                });
                if (airport != null) {
                  _loadAirportRunways(airport.icaoCode, true);
                }
              },
            ),

            if (_departureAirport != null) ...[
              const SizedBox(height: 4),
              _buildAirportInfo(_departureAirport!, Colors.green),
            ],
            const SizedBox(height: AppThemeData.spacingMedium),

            // 起飞跑道选择
            if (_departureDetail != null) ...[
              RunwaySelector(
                runways: _departureDetail!.runways,
                selectedRunway: _selectedDepartureRunway,
                label: '起飞跑道',
                onChanged: (runway) {
                  setState(() => _selectedDepartureRunway = runway);
                },
                enabled: !provider.isLoading,
                isDeparture: true,
              ),
              const SizedBox(height: AppThemeData.spacingMedium),
            ] else if (_isLoadingRunways && _departureAirport != null) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: AppThemeData.spacingMedium),
            ],

            // 到达机场
            AirportSearchField(
              controller: _arrivalController,
              label: '到达机场',
              hint: 'ICAO代码',
              icon: Icons.flight_land,
              iconColor: Colors.orange,
              required: true,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '请输入到达机场';
                }
                if (!RegExp(r'^[A-Z]{4}$').hasMatch(value.trim())) {
                  return '请输入4位ICAO代码';
                }
                if (value.trim() == _departureController.text.trim()) {
                  return '到达机场不能与起飞机场相同';
                }
                return null;
              },
              onAirportSelected: (airport) {
                setState(() {
                  _arrivalAirport = airport;
                  _arrivalDetail = null;
                  _selectedArrivalRunway = null;
                  _isArrivalValid = airport != null;
                });
                if (airport != null) {
                  _loadAirportRunways(airport.icaoCode, false);
                }
              },
            ),

            if (_arrivalAirport != null) ...[
              const SizedBox(height: 4),
              _buildAirportInfo(_arrivalAirport!, Colors.orange),
            ],
            const SizedBox(height: AppThemeData.spacingMedium),

            // 到达跑道选择
            if (_arrivalDetail != null) ...[
              RunwaySelector(
                runways: _arrivalDetail!.runways,
                selectedRunway: _selectedArrivalRunway,
                label: '到达跑道',
                onChanged: (runway) {
                  setState(() => _selectedArrivalRunway = runway);
                },
                enabled: !provider.isLoading,
                isDeparture: false,
              ),
              const SizedBox(height: AppThemeData.spacingMedium),
            ] else if (_isLoadingRunways && _arrivalAirport != null) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: AppThemeData.spacingMedium),
            ],

            // 备降机场
            AirportSearchField(
              controller: _alternateController,
              label: '备降机场',
              hint: 'ICAO代码 (可选)',
              icon: Icons.alt_route,
              validator: (value) {
                if (value != null && value.trim().isNotEmpty) {
                  if (!RegExp(r'^[A-Z]{4}$').hasMatch(value.trim())) {
                    return '请输入4位ICAO代码';
                  }
                  if (value.trim() == _departureController.text.trim() ||
                      value.trim() == _arrivalController.text.trim()) {
                    return '备降机场不能与起飞/到达机场相同';
                  }
                }
                return null;
              },
              onAirportSelected: (airport) {
                setState(() {
                  _alternateAirport = airport;
                  // 如果有输入内容，则必须是有效的机场；如果没有输入，则视为有效（可选）
                  _isAlternateValid =
                      _alternateController.text.trim().isEmpty ||
                      airport != null;
                });
              },
            ),

            if (_alternateAirport != null) ...[
              const SizedBox(height: 4),
              _buildAirportInfo(_alternateAirport!, Colors.purple),
            ],
            const SizedBox(height: AppThemeData.spacingMedium),

            // 航路
            _buildRouteField(),
            const SizedBox(height: AppThemeData.spacingMedium),

            // 巡航高度
            _buildCruiseAltitudeField(),
            const SizedBox(height: AppThemeData.spacingLarge),

            // 生成按钮
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: (provider.isLoading || !_canGenerateBriefing())
                    ? null
                    : _generateBriefing,
                icon: provider.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.description),
                label: Text(provider.isLoading ? '生成中...' : '生成简报'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),

            // 验证提示
            if (!_canGenerateBriefing() && !provider.isLoading) ...[
              const SizedBox(height: AppThemeData.spacingSmall),
              Container(
                padding: const EdgeInsets.all(AppThemeData.spacingSmall),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.orange.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: Colors.orange,
                      size: 20,
                    ),
                    const SizedBox(width: AppThemeData.spacingSmall),
                    Expanded(
                      child: Text(
                        _getValidationMessage(),
                        style: const TextStyle(
                          color: Colors.orange,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // 错误信息
            if (provider.errorMessage != null) ...[
              const SizedBox(height: AppThemeData.spacingMedium),
              Container(
                padding: const EdgeInsets.all(AppThemeData.spacingMedium),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(width: AppThemeData.spacingSmall),
                    Expanded(
                      child: Text(
                        provider.errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFlightNumberField() {
    return TextFormField(
      controller: _flightNumberController,
      decoration: const InputDecoration(
        labelText: '航班号 (可选)',
        hintText: '例如: CA1234',
        prefixIcon: Icon(Icons.flight),
        border: OutlineInputBorder(),
      ),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[A-Z0-9]')),
        LengthLimitingTextInputFormatter(8),
      ],
      textCapitalization: TextCapitalization.characters,
      validator: (value) {
        if (value != null && value.trim().isNotEmpty) {
          // 航班号格式：2位航司代码 + 1-4位数字
          if (!RegExp(r'^[A-Z]{2}\d{1,4}$').hasMatch(value.trim())) {
            return '格式: 2位航司代码+数字 (如CA1234)';
          }
        }
        return null;
      },
      onChanged: (value) {
        final upperValue = value.toUpperCase();
        if (value != upperValue) {
          _flightNumberController.value = _flightNumberController.value
              .copyWith(
                text: upperValue,
                selection: TextSelection.collapsed(offset: upperValue.length),
              );
        }
      },
    );
  }

  Widget _buildRouteField() {
    return TextFormField(
      controller: _routeController,
      decoration: const InputDecoration(
        labelText: '航路 (可选)',
        hintText: '例如: DCT',
        prefixIcon: Icon(Icons.route),
        border: OutlineInputBorder(),
      ),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[A-Z0-9 ]')),
        LengthLimitingTextInputFormatter(50),
      ],
      textCapitalization: TextCapitalization.characters,
      onChanged: (value) {
        final upperValue = value.toUpperCase();
        if (value != upperValue) {
          _routeController.value = _routeController.value.copyWith(
            text: upperValue,
            selection: TextSelection.collapsed(offset: upperValue.length),
          );
        }
      },
    );
  }

  Widget _buildCruiseAltitudeField() {
    return TextFormField(
      controller: _cruiseAltitudeController,
      decoration: const InputDecoration(
        labelText: '巡航高度',
        hintText: 'feet',
        prefixIcon: Icon(Icons.height),
        border: OutlineInputBorder(),
      ),
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(5),
      ],
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return '请输入巡航高度';
        }
        final altitude = int.tryParse(value.trim());
        if (altitude == null) {
          return '请输入有效数字';
        }
        if (altitude < 1000 || altitude > 50000) {
          return '高度范围: 1000-50000';
        }
        return null;
      },
    );
  }

  Widget _buildAirportInfo(AirportInfo airport, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 40),
      child: Text(
        airport.nameChinese,
        style: TextStyle(
          fontSize: 12,
          color: Color.lerp(color, Colors.black, 0.3),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
