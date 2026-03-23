import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/services/localization_service.dart';
import '../../../../core/theme/app_theme_data.dart';
import '../../../airport_search/models/airport_search_models.dart';
import '../../../airport_search/services/airport_search_service.dart';
import '../../localization/briefing_localization_keys.dart';

/// 机场输入及校验组件
/// 包含 ICAO 输入、自动联想、跑道动态加载及校验逻辑
class BriefingAirportInput extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String hintText;
  final bool isRequired;
  final bool hasSubmitted;
  final ValueChanged<List<AirportRunwayData>> onRunwaysLoaded;
  final ValueChanged<String?> onRunwaySelected;
  final String? initialRunway;

  const BriefingAirportInput({
    super.key,
    required this.controller,
    required this.label,
    required this.hintText,
    this.isRequired = true,
    this.hasSubmitted = false,
    required this.onRunwaysLoaded,
    required this.onRunwaySelected,
    this.initialRunway,
  });

  @override
  State<BriefingAirportInput> createState() => _BriefingAirportInputState();
}

class _BriefingAirportInputState extends State<BriefingAirportInput> {
  final _airportService = AirportSearchService();
  final _icaoPattern = RegExp(r'^[A-Z0-9]{4}$');
  final _icaoPartialPattern = RegExp(r'^[A-Z0-9]{1,4}$');
  final _fieldKey = GlobalKey<FormFieldState<String>>();
  final _focusNode = FocusNode();

  Timer? _debounce;
  bool _isSuggesting = false;
  bool _isLoadingRunways = false;
  bool _isValid = false;
  String? _errorText;
  List<AirportSuggestionData> _suggestions = [];
  List<AirportRunwayData> _runways = [];
  String? _selectedRunway;

  @override
  void initState() {
    super.initState();
    _selectedRunway = widget.initialRunway;
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        _fieldKey.currentState?.validate();
      }
    });

    // 如果初始有值且符合 ICAO 格式，尝试加载跑道
    final text = widget.controller.text.trim().toUpperCase();
    if (_icaoPattern.hasMatch(text)) {
      _loadRunways(text);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ICAO 代码输入框
        TextFormField(
          key: _fieldKey,
          controller: widget.controller,
          focusNode: _focusNode,
          textCapitalization: TextCapitalization.characters,
          maxLength: 4,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
            LengthLimitingTextInputFormatter(4),
            TextInputFormatter.withFunction((old, newValue) {
              return newValue.copyWith(
                text: newValue.text.toUpperCase(),
                selection: TextSelection.collapsed(
                  offset: newValue.text.length,
                ),
              );
            }),
          ],
          decoration: InputDecoration(
            counterText: '',
            labelText: widget.label,
            hintText: widget.hintText,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            prefixIcon: const Icon(Icons.pin_drop_outlined, size: 20),
          ),
          onChanged: _handleTextChanged,
          validator: _validate,
          autovalidateMode: widget.hasSubmitted
              ? AutovalidateMode.always
              : AutovalidateMode.onUserInteraction,
        ),

        // 联想建议列表
        if (_isSuggesting || _suggestions.isNotEmpty) ...[
          const SizedBox(height: 8),
          _buildSuggestionPanel(),
        ],

        // 跑道选择下拉框 (仅在 ICAO 校验成功后显示)
        if (_isValid &&
            _icaoPattern.hasMatch(
              widget.controller.text.trim().toUpperCase(),
            )) ...[
          const SizedBox(height: 12),
          _buildRunwayDropdown(),
        ],
      ],
    );
  }

  Widget _buildSuggestionPanel() {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppThemeData.spacingSmall),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(AppThemeData.borderRadiusSmall),
      ),
      child: _isSuggesting
          ? const Center(
              child: SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _suggestions
                  .map(
                    (item) => ActionChip(
                      onPressed: () => _selectSuggestion(item),
                      avatar: const Icon(Icons.place_outlined, size: 16),
                      label: Text(
                        '${item.icao} · ${item.name ?? "-"}',
                        maxLines: 1,
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }

  Widget _buildRunwayDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _runways.any((r) => r.ident == _selectedRunway)
          ? _selectedRunway
          : '',
      isExpanded: true,
      decoration: InputDecoration(
        labelText:
            '${widget.label}${BriefingLocalizationKeys.fieldRunwayHint.tr(context)}',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        prefixIcon: const Icon(Icons.linear_scale_rounded, size: 20),
        suffixIcon: _isLoadingRunways
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : null,
      ),
      items: [
        DropdownMenuItem(
          value: '',
          child: Text(BriefingLocalizationKeys.runwayAutoOption.tr(context)),
        ),
        ..._runways.map(
          (r) => DropdownMenuItem(
            value: r.ident,
            child: Text(
              r.lengthM != null
                  ? '${r.ident} (${r.lengthM!.toStringAsFixed(0)}m)'
                  : r.ident,
            ),
          ),
        ),
      ],
      onChanged: _isLoadingRunways
          ? null
          : (val) {
              setState(() => _selectedRunway = val);
              widget.onRunwaySelected(val == '' ? null : val);
            },
    );
  }

  void _handleTextChanged(String value) {
    _debounce?.cancel();
    final normalized = value.trim().toUpperCase();

    if (normalized.isEmpty || !_icaoPartialPattern.hasMatch(normalized)) {
      _resetState();
      return;
    }

    setState(() => _isSuggesting = true);
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        final results = await _airportService.suggestAirports(normalized);
        if (!mounted) return;
        setState(() {
          _suggestions = results;
          _isSuggesting = false;
        });
        // 如果输入已满 4 位且符合 ICAO，尝试加载详情以获取跑道
        if (_icaoPattern.hasMatch(normalized)) {
          _loadRunways(normalized);
        }
      } catch (_) {
        if (!mounted) return;
        setState(() => _isSuggesting = false);
      }
    });
  }

  Future<void> _loadRunways(String icao) async {
    setState(() => _isLoadingRunways = true);
    try {
      final airport = await _airportService.fetchAirport(icao);
      if (!mounted || widget.controller.text.trim().toUpperCase() != icao) {
        return;
      }
      setState(() {
        _runways = airport.runways;
        _isValid = true;
        _errorText = null;
        _isLoadingRunways = false;
      });
      widget.onRunwaysLoaded(airport.runways);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isValid = false;
        _errorText = BriefingLocalizationKeys.airportValidateFailed
            .tr(context)
            .replaceAll('{}', widget.label);
        _isLoadingRunways = false;
        _runways = [];
      });
    }
  }

  void _selectSuggestion(AirportSuggestionData item) {
    widget.controller.text = item.icao;
    widget.controller.selection = TextSelection.collapsed(
      offset: item.icao.length,
    );
    setState(() {
      _suggestions = [];
      _isSuggesting = false;
    });
    _loadRunways(item.icao);
  }

  void _resetState() {
    setState(() {
      _isSuggesting = false;
      _suggestions = [];
      _isValid = false;
      _errorText = null;
      _runways = [];
      _selectedRunway = null;
    });
    widget.onRunwaysLoaded([]);
    widget.onRunwaySelected(null);
  }

  String? _validate(String? value) {
    if (widget.isRequired && (value == null || value.trim().isEmpty)) {
      return BriefingLocalizationKeys.requiredField
          .tr(context)
          .replaceAll('{}', widget.label);
    }
    if (!widget.isRequired && (value == null || value.trim().isEmpty)) {
      return null;
    }

    final normalized = value!.trim().toUpperCase();
    if (!_icaoPattern.hasMatch(normalized)) {
      return BriefingLocalizationKeys.invalidIcao
          .tr(context)
          .replaceAll('{}', widget.label);
    }
    return _errorText;
  }
}
