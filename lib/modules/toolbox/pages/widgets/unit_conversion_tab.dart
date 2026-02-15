import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme_data.dart';
import '../../../../core/services/localization_service.dart';
import '../../data/unit_conversion_options.dart';
import '../../localization/toolbox_localization_keys.dart';
import 'toolbox_section_card.dart';

class UnitConversionTab extends StatefulWidget {
  const UnitConversionTab({super.key});

  @override
  State<UnitConversionTab> createState() => _UnitConversionTabState();
}

class _UnitConversionTabState extends State<UnitConversionTab> {
  final TextEditingController _unitController = TextEditingController();
  String _unitResult = '';
  UnitConversionOption _selectedOption = unitConversionOptions.first;

  @override
  void dispose() {
    _unitController.dispose();
    super.dispose();
  }

  void _convertUnit(BuildContext context) {
    final text = _unitController.text.trim();
    if (text.isEmpty) {
      if (_unitResult.isNotEmpty) {
        setState(() => _unitResult = '');
      }
      return;
    }
    final value = double.tryParse(text);
    if (value == null) {
      setState(
        () =>
            _unitResult = ToolboxLocalizationKeys.unitInvalidValue.tr(context),
      );
      return;
    }
    final result = _selectedOption.converter(value);
    setState(() {
      _unitResult =
          '${result.toStringAsFixed(2)} ${_selectedOption.resultUnit}';
    });
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LocalizationService>();
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppThemeData.spacingLarge),
      child: Column(
        children: [
          ToolboxSectionCard(
            title: ToolboxLocalizationKeys.unitSectionTitle.tr(context),
            icon: Icons.sync_alt_rounded,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<UnitConversionOption>(
                  key: ValueKey(_selectedOption.labelKey),
                  initialValue: _selectedOption,
                  decoration: InputDecoration(
                    labelText: ToolboxLocalizationKeys.unitTypeLabel.tr(
                      context,
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  items: unitConversionOptions
                      .map(
                        (option) => DropdownMenuItem(
                          value: option,
                          child: Text(option.labelKey.tr(context)),
                        ),
                      )
                      .toList(),
                  onChanged: (option) {
                    if (option == null) return;
                    setState(() => _selectedOption = option);
                    _convertUnit(context);
                  },
                ),
                const SizedBox(height: AppThemeData.spacingMedium),
                ToolboxTextField(
                  label: ToolboxLocalizationKeys.unitValueLabel.tr(context),
                  hint: ToolboxLocalizationKeys.unitValueHint.tr(context),
                  icon: Icons.edit_note_rounded,
                  controller: _unitController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (_) => _convertUnit(context),
                ),
                const SizedBox(height: AppThemeData.spacingMedium),
                ElevatedButton.icon(
                  onPressed: () => _convertUnit(context),
                  icon: const Icon(Icons.calculate),
                  label: Text(ToolboxLocalizationKeys.unitConvert.tr(context)),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
                if (_unitResult.isNotEmpty) ...[
                  const SizedBox(height: AppThemeData.spacingMedium),
                  Container(
                    padding: const EdgeInsets.all(AppThemeData.spacingMedium),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withValues(
                        alpha: 0.3,
                      ),
                      borderRadius: BorderRadius.circular(
                        AppThemeData.borderRadiusMedium,
                      ),
                      border: Border.all(
                        color: theme.colorScheme.primary.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          ToolboxLocalizationKeys.unitResult.tr(context),
                          style: theme.textTheme.labelSmall,
                        ),
                        const SizedBox(height: AppThemeData.spacingSmall),
                        SelectableText(
                          _unitResult,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
