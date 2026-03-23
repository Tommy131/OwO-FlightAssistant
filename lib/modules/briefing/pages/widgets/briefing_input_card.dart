import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../core/services/localization_service.dart';
import '../../../../core/theme/app_theme_data.dart';
import '../../../../core/widgets/common/snack_bar.dart';
import '../../localization/briefing_localization_keys.dart';
import '../../providers/briefing_provider.dart';
import 'briefing_airport_input.dart';

/// 飞行简报输入表单容器
/// 组合出发、到达、备降机场输入块以及航线、高度等航班基本信息
class BriefingInputCard extends StatefulWidget {
  const BriefingInputCard({super.key});

  @override
  State<BriefingInputCard> createState() => _BriefingInputCardState();
}

class _BriefingInputCardState extends State<BriefingInputCard> {
  final _formKey = GlobalKey<FormState>();

  // 各核心字段控制器
  final _departureController = TextEditingController();
  final _arrivalController = TextEditingController();
  final _alternateController = TextEditingController();
  final _flightNumberController = TextEditingController();
  final _routeController = TextEditingController();
  final _cruiseAltitudeController = TextEditingController(text: '35000');

  String? _selectedDepRunway;
  String? _selectedArrRunway;
  String? _selectedAltRunway;

  bool _hasSubmitted = false;

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<BriefingProvider>();
    final isGenerating = provider.isLoading;

    return Container(
      padding: const EdgeInsets.all(AppThemeData.spacingMedium),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 表单标题
            Text(
              BriefingLocalizationKeys.inputTitle.tr(context),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            // 模块 1: 起降与备降机场
            BriefingAirportInput(
              controller: _departureController,
              label: BriefingLocalizationKeys.fieldDeparture.tr(context),
              hintText: BriefingLocalizationKeys.fieldIcaoHint.tr(context),
              hasSubmitted: _hasSubmitted,
              onRunwaysLoaded: (_) {},
              onRunwaySelected: (val) => _selectedDepRunway = val,
            ),
            const SizedBox(height: 12),
            BriefingAirportInput(
              controller: _arrivalController,
              label: BriefingLocalizationKeys.fieldArrival.tr(context),
              hintText: BriefingLocalizationKeys.fieldIcaoHint.tr(context),
              hasSubmitted: _hasSubmitted,
              onRunwaysLoaded: (_) {},
              onRunwaySelected: (val) => _selectedArrRunway = val,
            ),
            const SizedBox(height: 12),
            BriefingAirportInput(
              controller: _alternateController,
              label: BriefingLocalizationKeys.fieldAlternate.tr(context),
              hintText: BriefingLocalizationKeys.fieldIcaoHint.tr(context),
              isRequired: false,
              hasSubmitted: _hasSubmitted,
              onRunwaysLoaded: (_) {},
              onRunwaySelected: (val) => _selectedAltRunway = val,
            ),
            const SizedBox(height: 12),

            // 模块 2: 航班及航路详情
            _buildFlightDetailsSection(),
            const SizedBox(height: 16),

            // 提交按钮
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: isGenerating ? null : _handleGenerate,
                icon: isGenerating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome),
                label: Text(
                  BriefingLocalizationKeys.generateAction.tr(context),
                ),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(120, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      AppThemeData.borderRadiusSmall,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建航班基础信息编辑区域
  Widget _buildFlightDetailsSection() {
    return Column(
      children: [
        // 航班号输入
        _buildTextField(
          controller: _flightNumberController,
          label: BriefingLocalizationKeys.fieldFlightNumber.tr(context),
          hintText: 'e.g. CA1234',
          textCapitalization: TextCapitalization.characters,
          maxLength: 8,
          prefixIcon: Icons.flight_takeoff_rounded,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
            TextInputFormatter.withFunction(
              (old, newVal) => newVal.copyWith(
                text: newVal.text.toUpperCase(),
                selection: TextSelection.collapsed(offset: newVal.text.length),
              ),
            ),
          ],
          validator: (val) {
            if (val == null || val.trim().isEmpty) {
              return BriefingLocalizationKeys.requiredField
                  .tr(context)
                  .replaceAll(
                    '{}',
                    BriefingLocalizationKeys.fieldFlightNumber.tr(context),
                  );
            }
            if (!RegExp(r'^[A-Z]{2,3}\d{1,4}[A-Z]?$').hasMatch(val.trim())) {
              return BriefingLocalizationKeys.invalidFlightNumber.tr(context);
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        // 航路输入
        _buildTextField(
          controller: _routeController,
          label: BriefingLocalizationKeys.fieldRoute.tr(context),
          hintText: BriefingLocalizationKeys.fieldRouteHint.tr(context),
          maxLines: 2,
          prefixIcon: Icons.map_outlined,
        ),
        const SizedBox(height: 12),
        // 巡航高度输入
        _buildTextField(
          controller: _cruiseAltitudeController,
          label: BriefingLocalizationKeys.fieldCruiseAltitude.tr(context),
          hintText: 'e.g. 35000',
          keyboardType: TextInputType.number,
          prefixIcon: Icons.trending_up_rounded,
          validator: (val) {
            if (val == null || val.trim().isEmpty) {
              return BriefingLocalizationKeys.requiredField
                  .tr(context)
                  .replaceAll(
                    '{}',
                    BriefingLocalizationKeys.fieldCruiseAltitude.tr(context),
                  );
            }
            final alt = int.tryParse(val.trim());
            if (alt == null || alt <= 0) {
              return BriefingLocalizationKeys.invalidCruiseAltitude.tr(context);
            }
            return null;
          },
        ),
      ],
    );
  }

  /// 内部封装的通用文本框组件
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hintText,
    IconData? prefixIcon,
    int maxLines = 1,
    int? maxLength,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      inputFormatters: inputFormatters,
      validator: validator,
      autovalidateMode: _hasSubmitted
          ? AutovalidateMode.always
          : AutovalidateMode.onUserInteraction,
      decoration: InputDecoration(
        counterText: '',
        labelText: label,
        hintText: hintText,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 20) : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  /// 触发生成逻辑
  Future<void> _handleGenerate() async {
    setState(() => _hasSubmitted = true);
    if (!_formKey.currentState!.validate()) {
      SnackBarHelper.showWarning(
        context,
        BriefingLocalizationKeys.requiredAllFields.tr(context),
      );
      return;
    }

    final provider = context.read<BriefingProvider>();
    await provider.generateBriefing(
      departure: _departureController.text.trim(),
      arrival: _arrivalController.text.trim(),
      alternate: _alternateController.text.trim(),
      flightNumber: _flightNumberController.text.trim(),
      route: _routeController.text.trim(),
      cruiseAltitude: int.tryParse(_cruiseAltitudeController.text.trim()),
      departureRunway: _selectedDepRunway,
      arrivalRunway: _selectedArrRunway,
      alternateRunway: _selectedAltRunway,
    );
  }
}
