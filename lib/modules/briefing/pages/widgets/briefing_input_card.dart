import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../core/services/localization_service.dart';
import '../../../../core/theme/app_theme_data.dart';
import '../../../../core/widgets/common/snack_bar.dart';
import '../../../airport_search/models/airport_search_models.dart';
import '../../../airport_search/services/airport_search_service.dart';
import '../../localization/briefing_localization_keys.dart';
import '../../providers/briefing_provider.dart';

enum _AirportField { departure, arrival, alternate }

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
  final _airportService = AirportSearchService();
  final _icaoPattern = RegExp(r'^[A-Z0-9]{4}$');
  final _icaoPartialPattern = RegExp(r'^[A-Z0-9]{1,4}$');
  final _flightNumberPattern = RegExp(r'^[A-Z]{2,3}\d{1,4}[A-Z]?$');
  final _departureFieldKey = GlobalKey<FormFieldState<String>>();
  final _arrivalFieldKey = GlobalKey<FormFieldState<String>>();
  final _alternateFieldKey = GlobalKey<FormFieldState<String>>();
  final _flightNumberFieldKey = GlobalKey<FormFieldState<String>>();
  final _departureFocusNode = FocusNode();
  final _arrivalFocusNode = FocusNode();
  final _alternateFocusNode = FocusNode();
  final _flightNumberFocusNode = FocusNode();
  Timer? _departureDebounce;
  Timer? _arrivalDebounce;
  Timer? _alternateDebounce;
  bool _hasSubmitted = false;
  bool _isValidatingAirport = false;
  bool _isSuggestingDeparture = false;
  bool _isSuggestingArrival = false;
  bool _isSuggestingAlternate = false;
  bool _isLoadingDepartureRunways = false;
  bool _isLoadingArrivalRunways = false;
  bool _isLoadingAlternateRunways = false;
  List<AirportSuggestionData> _departureSuggestions = [];
  List<AirportSuggestionData> _arrivalSuggestions = [];
  List<AirportSuggestionData> _alternateSuggestions = [];
  List<AirportRunwayData> _departureRunways = [];
  List<AirportRunwayData> _arrivalRunways = [];
  List<AirportRunwayData> _alternateRunways = [];
  String? _selectedDepartureRunway;
  String? _selectedArrivalRunway;
  String? _selectedAlternateRunway;
  bool _departureAirportValid = false;
  bool _arrivalAirportValid = false;
  bool _alternateAirportValid = false;
  String? _departureAirportError;
  String? _arrivalAirportError;
  String? _alternateAirportError;

  @override
  void initState() {
    super.initState();
    _departureFocusNode.addListener(() {
      if (!_departureFocusNode.hasFocus) {
        _departureFieldKey.currentState?.validate();
      }
    });
    _arrivalFocusNode.addListener(() {
      if (!_arrivalFocusNode.hasFocus) {
        _arrivalFieldKey.currentState?.validate();
      }
    });
    _alternateFocusNode.addListener(() {
      if (!_alternateFocusNode.hasFocus) {
        _alternateFieldKey.currentState?.validate();
      }
    });
    _flightNumberFocusNode.addListener(() {
      if (!_flightNumberFocusNode.hasFocus) {
        _flightNumberFieldKey.currentState?.validate();
      }
    });
  }

  @override
  void dispose() {
    _departureDebounce?.cancel();
    _arrivalDebounce?.cancel();
    _alternateDebounce?.cancel();
    _departureController.dispose();
    _arrivalController.dispose();
    _alternateController.dispose();
    _flightNumberController.dispose();
    _routeController.dispose();
    _cruiseAltitudeController.dispose();
    _departureFocusNode.dispose();
    _arrivalFocusNode.dispose();
    _alternateFocusNode.dispose();
    _flightNumberFocusNode.dispose();
    super.dispose();
  }

  Future<void> _generateBriefing() async {
    setState(() {
      _hasSubmitted = true;
    });
    if (!_formKey.currentState!.validate()) {
      SnackBarHelper.showWarning(
        context,
        BriefingLocalizationKeys.requiredAllFields.tr(context),
      );
      return;
    }
    final departure = _departureController.text.trim().toUpperCase();
    final arrival = _arrivalController.text.trim().toUpperCase();
    final alternate = _alternateController.text.trim().toUpperCase();
    final departureLabel = BriefingLocalizationKeys.fieldDeparture.tr(context);
    final arrivalLabel = BriefingLocalizationKeys.fieldArrival.tr(context);
    final alternateLabel = BriefingLocalizationKeys.fieldAlternate.tr(context);
    setState(() {
      _isValidatingAirport = true;
    });
    try {
      final departureValid = await _loadRunwaysForField(
        _AirportField.departure,
        departure,
      );
      final arrivalValid = departureValid
          ? await _loadRunwaysForField(_AirportField.arrival, arrival)
          : false;
      final alternateValid = departureValid && arrivalValid
          ? (alternate.isEmpty
                ? true
                : await _loadRunwaysForField(
                    _AirportField.alternate,
                    alternate,
                  ))
          : false;
      if (!mounted) return;
      if (!departureValid || !arrivalValid || !alternateValid) {
        _formKey.currentState!.validate();
        if (!alternateValid && alternate.isNotEmpty) {
          SnackBarHelper.showError(
            context,
            BriefingLocalizationKeys.airportValidateFailed
                .tr(context)
                .replaceAll('{}', alternateLabel),
          );
        } else if (!arrivalValid) {
          SnackBarHelper.showError(
            context,
            BriefingLocalizationKeys.airportValidateFailed
                .tr(context)
                .replaceAll('{}', arrivalLabel),
          );
        } else if (!departureValid) {
          SnackBarHelper.showError(
            context,
            BriefingLocalizationKeys.airportValidateFailed
                .tr(context)
                .replaceAll('{}', departureLabel),
          );
        }
        return;
      }
      final provider = context.read<BriefingProvider>();
      await provider.generateBriefing(
        departure: departure,
        arrival: arrival,
        alternate: alternate,
        flightNumber: _flightNumberController.text.trim(),
        route: _routeController.text.trim(),
        cruiseAltitude: int.tryParse(_cruiseAltitudeController.text.trim()),
        departureRunway: _selectedDepartureRunway,
        arrivalRunway: _selectedArrivalRunway,
        alternateRunway: _selectedAlternateRunway,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isValidatingAirport = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isGenerating =
        context.watch<BriefingProvider>().isLoading || _isValidatingAirport;

    return Container(
      padding: const EdgeInsets.all(AppThemeData.spacingMedium),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              BriefingLocalizationKeys.inputTitle.tr(context),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildIcaoField(
              context,
              controller: _departureController,
              field: _AirportField.departure,
              fieldKey: _departureFieldKey,
              focusNode: _departureFocusNode,
              label: BriefingLocalizationKeys.fieldDeparture.tr(context),
              hintText: BriefingLocalizationKeys.fieldIcaoHint.tr(context),
            ),
            if (_shouldShowRunwayField(_AirportField.departure)) ...[
              const SizedBox(height: 12),
              _buildRunwayField(
                context,
                field: _AirportField.departure,
                label: BriefingLocalizationKeys.fieldDepartureRunway.tr(
                  context,
                ),
              ),
            ],
            const SizedBox(height: 12),
            _buildIcaoField(
              context,
              controller: _arrivalController,
              field: _AirportField.arrival,
              fieldKey: _arrivalFieldKey,
              focusNode: _arrivalFocusNode,
              label: BriefingLocalizationKeys.fieldArrival.tr(context),
              hintText: BriefingLocalizationKeys.fieldIcaoHint.tr(context),
            ),
            if (_shouldShowRunwayField(_AirportField.arrival)) ...[
              const SizedBox(height: 12),
              _buildRunwayField(
                context,
                field: _AirportField.arrival,
                label: BriefingLocalizationKeys.fieldArrivalRunway.tr(context),
              ),
            ],
            const SizedBox(height: 12),
            _buildIcaoField(
              context,
              controller: _alternateController,
              field: _AirportField.alternate,
              fieldKey: _alternateFieldKey,
              focusNode: _alternateFocusNode,
              label: BriefingLocalizationKeys.fieldAlternate.tr(context),
              hintText: BriefingLocalizationKeys.fieldIcaoHint.tr(context),
              required: false,
            ),
            if (_shouldShowRunwayField(_AirportField.alternate)) ...[
              const SizedBox(height: 12),
              _buildRunwayField(
                context,
                field: _AirportField.alternate,
                label: BriefingLocalizationKeys.fieldAlternateRunway.tr(
                  context,
                ),
              ),
            ],
            const SizedBox(height: 12),
            _buildField(
              context,
              fieldKey: _flightNumberFieldKey,
              focusNode: _flightNumberFocusNode,
              controller: _flightNumberController,
              label: BriefingLocalizationKeys.fieldFlightNumber.tr(context),
              hintText: BriefingLocalizationKeys.fieldFlightNumberHint.tr(
                context,
              ),
              textCapitalization: TextCapitalization.characters,
              maxLength: 8,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                LengthLimitingTextInputFormatter(8),
                TextInputFormatter.withFunction((oldValue, newValue) {
                  return newValue.copyWith(
                    text: newValue.text.toUpperCase(),
                    selection: TextSelection.collapsed(
                      offset: newValue.text.length,
                    ),
                  );
                }),
              ],
              validator: (value) =>
                  _requiredValidator(
                    label: BriefingLocalizationKeys.fieldFlightNumber.tr(
                      context,
                    ),
                    value: value,
                  ) ??
                  _flightNumberValidator(value),
            ),
            const SizedBox(height: 12),
            _buildField(
              context,
              controller: _routeController,
              label: BriefingLocalizationKeys.fieldRoute.tr(context),
              hintText: BriefingLocalizationKeys.fieldRouteHint.tr(context),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            _buildField(
              context,
              controller: _cruiseAltitudeController,
              label: BriefingLocalizationKeys.fieldCruiseAltitude.tr(context),
              hintText: BriefingLocalizationKeys.fieldCruiseAltitudeHint.tr(
                context,
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                final required = _requiredValidator(
                  label: BriefingLocalizationKeys.fieldCruiseAltitude.tr(
                    context,
                  ),
                  value: value,
                );
                if (required != null) return required;
                final altitude = int.tryParse(value!.trim());
                if (altitude == null || altitude <= 0) {
                  return BriefingLocalizationKeys.invalidCruiseAltitude.tr(
                    context,
                  );
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: isGenerating ? null : _generateBriefing,
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
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(
    BuildContext context, {
    GlobalKey<FormFieldState<String>>? fieldKey,
    FocusNode? focusNode,
    required TextEditingController controller,
    required String label,
    String? hintText,
    int maxLines = 1,
    int? maxLength,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      key: fieldKey,
      controller: controller,
      focusNode: focusNode,
      maxLines: maxLines,
      maxLength: maxLength,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      inputFormatters: inputFormatters,
      validator: validator,
      autovalidateMode: _hasSubmitted
          ? AutovalidateMode.always
          : AutovalidateMode.onUserInteraction,
      onTapOutside: (_) => fieldKey?.currentState?.validate(),
      decoration: InputDecoration(
        counterText: maxLength == null ? null : '',
        labelText: label,
        hintText: hintText,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildIcaoField(
    BuildContext context, {
    required GlobalKey<FormFieldState<String>> fieldKey,
    required FocusNode focusNode,
    required TextEditingController controller,
    required _AirportField field,
    required String label,
    required String hintText,
    bool required = true,
  }) {
    final isSuggesting = _isSuggestingForField(field);
    final suggestions = _suggestionsForField(field);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          key: fieldKey,
          controller: controller,
          focusNode: focusNode,
          textCapitalization: TextCapitalization.characters,
          maxLength: 4,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
            LengthLimitingTextInputFormatter(4),
            TextInputFormatter.withFunction((oldValue, newValue) {
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
            labelText: label,
            hintText: hintText,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onChanged: (value) => _onIcaoChanged(field, value),
          autovalidateMode: _hasSubmitted
              ? AutovalidateMode.always
              : AutovalidateMode.onUserInteraction,
          onTapOutside: (_) => fieldKey.currentState?.validate(),
          validator: (value) {
            final requiredError = _requiredValidator(
              label: label,
              value: value,
            );
            if (required && requiredError != null) {
              return requiredError;
            }
            if (!required && (value == null || value.trim().isEmpty)) {
              return null;
            }
            final normalized = value!.trim().toUpperCase();
            if (!_icaoPattern.hasMatch(normalized)) {
              return BriefingLocalizationKeys.invalidIcao
                  .tr(context)
                  .replaceAll('{}', label);
            }
            final airportError = _airportErrorForField(field);
            if (airportError != null) {
              return airportError;
            }
            return null;
          },
        ),
        if (isSuggesting || suggestions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _buildSuggestionList(
              context,
              suggestions: suggestions,
              isSuggesting: isSuggesting,
              onSelect: (item) => _selectSuggestion(field, item),
            ),
          ),
      ],
    );
  }

  Widget _buildRunwayField(
    BuildContext context, {
    required _AirportField field,
    required String label,
  }) {
    final theme = Theme.of(context);
    final runways = _runwaysForField(field);
    final selected = _selectedRunwayForField(field);
    final isLoading = _isRunwayLoadingForField(field);
    return DropdownButtonFormField<String>(
      key: ValueKey(
        '${field.name}-${_controllerForField(field).text}-${runways.length}-${selected ?? ''}',
      ),
      initialValue: runways.any((item) => item.ident == selected)
          ? selected
          : '',
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        hintText: BriefingLocalizationKeys.fieldRunwayHint.tr(context),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        suffixIcon: isLoading
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
        DropdownMenuItem<String>(
          value: '',
          child: Text(BriefingLocalizationKeys.runwayAutoOption.tr(context)),
        ),
        ...runways.map(
          (runway) => DropdownMenuItem<String>(
            value: runway.ident,
            child: Text(
              runway.lengthM != null
                  ? '${runway.ident} (${runway.lengthM!.toStringAsFixed(0)}m)'
                  : runway.ident,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ),
      ],
      onChanged: isLoading
          ? null
          : (value) {
              setState(() {
                _setSelectedRunwayForField(field, value);
              });
            },
    );
  }

  Widget _buildSuggestionList(
    BuildContext context, {
    required List<AirportSuggestionData> suggestions,
    required bool isSuggesting,
    required ValueChanged<AirportSuggestionData> onSelect,
  }) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppThemeData.spacingSmall),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(AppThemeData.borderRadiusSmall),
      ),
      child: isSuggesting
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Wrap(
              spacing: 8,
              runSpacing: 8,
              children: suggestions
                  .map(
                    (item) => ActionChip(
                      onPressed: () => onSelect(item),
                      avatar: const Icon(Icons.place_outlined, size: 16),
                      label: Text(
                        '${item.icao} · ${item.name ?? '-'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }

  void _onIcaoChanged(_AirportField field, String input) {
    _debounceForField(field)?.cancel();
    final normalized = input.trim().toUpperCase();
    if (normalized.isEmpty || !_icaoPartialPattern.hasMatch(normalized)) {
      setState(() {
        _assignSuggesting(field, false);
        _setSuggestions(field, []);
        _setAirportValidityForField(field, false);
        _setAirportErrorForField(field, null);
        _clearRunwayStateIfNeeded(field);
      });
      return;
    }
    if (!_icaoPattern.hasMatch(normalized)) {
      setState(() {
        _setAirportValidityForField(field, false);
        _setAirportErrorForField(field, null);
        _clearRunwayStateIfNeeded(field);
      });
    }
    setState(() {
      _assignSuggesting(field, true);
    });
    _setDebounceForField(
      field,
      Timer(const Duration(milliseconds: 260), () async {
        final activeController = _controllerForField(field);
        final currentQuery = activeController.text.trim().toUpperCase();
        if (currentQuery.isEmpty ||
            !_icaoPartialPattern.hasMatch(currentQuery)) {
          if (!mounted) return;
          setState(() {
            _assignSuggesting(field, false);
            _setSuggestions(field, []);
          });
          return;
        }
        try {
          final suggestions = await _airportService.suggestAirports(
            currentQuery,
          );
          if (!mounted) return;
          if (_controllerForField(field).text.trim().toUpperCase() !=
              currentQuery) {
            return;
          }
          setState(() {
            _setSuggestions(field, suggestions);
            _assignSuggesting(field, false);
          });
          if (_icaoPattern.hasMatch(currentQuery)) {
            await _loadRunwaysForField(field, currentQuery);
            if (mounted) {
              _fieldKeyForField(field).currentState?.validate();
            }
          }
        } catch (_) {
          if (!mounted) return;
          setState(() {
            _setSuggestions(field, []);
            _assignSuggesting(field, false);
          });
        }
      }),
    );
  }

  void _selectSuggestion(
    _AirportField field,
    AirportSuggestionData suggestion,
  ) {
    final controller = _controllerForField(field);
    controller.text = suggestion.icao;
    controller.selection = TextSelection.collapsed(
      offset: controller.text.length,
    );
    setState(() {
      _setSuggestions(field, []);
      _assignSuggesting(field, false);
    });
    _loadRunwaysForField(field, suggestion.icao);
  }

  TextEditingController _controllerForField(_AirportField field) {
    switch (field) {
      case _AirportField.departure:
        return _departureController;
      case _AirportField.arrival:
        return _arrivalController;
      case _AirportField.alternate:
        return _alternateController;
    }
  }

  Timer? _debounceForField(_AirportField field) {
    switch (field) {
      case _AirportField.departure:
        return _departureDebounce;
      case _AirportField.arrival:
        return _arrivalDebounce;
      case _AirportField.alternate:
        return _alternateDebounce;
    }
  }

  List<AirportSuggestionData> _suggestionsForField(_AirportField field) {
    switch (field) {
      case _AirportField.departure:
        return _departureSuggestions;
      case _AirportField.arrival:
        return _arrivalSuggestions;
      case _AirportField.alternate:
        return _alternateSuggestions;
    }
  }

  bool _isSuggestingForField(_AirportField field) {
    switch (field) {
      case _AirportField.departure:
        return _isSuggestingDeparture;
      case _AirportField.arrival:
        return _isSuggestingArrival;
      case _AirportField.alternate:
        return _isSuggestingAlternate;
    }
  }

  void _setDebounceForField(_AirportField field, Timer timer) {
    switch (field) {
      case _AirportField.departure:
        _departureDebounce = timer;
        break;
      case _AirportField.arrival:
        _arrivalDebounce = timer;
        break;
      case _AirportField.alternate:
        _alternateDebounce = timer;
        break;
    }
  }

  void _setSuggestions(_AirportField field, List<AirportSuggestionData> value) {
    switch (field) {
      case _AirportField.departure:
        _departureSuggestions = value;
        break;
      case _AirportField.arrival:
        _arrivalSuggestions = value;
        break;
      case _AirportField.alternate:
        _alternateSuggestions = value;
        break;
    }
  }

  void _assignSuggesting(_AirportField field, bool value) {
    switch (field) {
      case _AirportField.departure:
        _isSuggestingDeparture = value;
        break;
      case _AirportField.arrival:
        _isSuggestingArrival = value;
        break;
      case _AirportField.alternate:
        _isSuggestingAlternate = value;
        break;
    }
  }

  Future<bool> _loadRunwaysForField(_AirportField field, String icao) async {
    if (!_icaoPattern.hasMatch(icao)) {
      if (!mounted) return false;
      setState(() {
        _setAirportValidityForField(field, false);
        _setAirportErrorForField(field, null);
        _clearRunwayStateIfNeeded(field);
      });
      return false;
    }
    if (!mounted) return false;
    setState(() {
      _setRunwayLoadingForField(field, true);
    });
    try {
      final airport = await _airportService.fetchAirport(icao);
      final current = _controllerForField(field).text.trim().toUpperCase();
      if (!mounted || current != icao) return false;
      setState(() {
        _setAirportValidityForField(field, true);
        _setAirportErrorForField(field, null);
        _setRunwaysForField(field, airport.runways);
        final selected = _selectedRunwayForField(field);
        final exists = airport.runways.any((item) => item.ident == selected);
        if (!exists) {
          _setSelectedRunwayForField(field, '');
        }
      });
      return true;
    } catch (_) {
      if (!mounted) return false;
      setState(() {
        _setAirportValidityForField(field, false);
        _setAirportErrorForField(
          field,
          BriefingLocalizationKeys.airportValidateFailed
              .tr(context)
              .replaceAll('{}', _labelForField(field)),
        );
        _clearRunwayStateIfNeeded(field);
      });
      return false;
    } finally {
      if (mounted) {
        setState(() {
          _setRunwayLoadingForField(field, false);
        });
      }
    }
  }

  bool _isRunwayLoadingForField(_AirportField field) {
    switch (field) {
      case _AirportField.departure:
        return _isLoadingDepartureRunways;
      case _AirportField.arrival:
        return _isLoadingArrivalRunways;
      case _AirportField.alternate:
        return _isLoadingAlternateRunways;
    }
  }

  void _setRunwayLoadingForField(_AirportField field, bool value) {
    switch (field) {
      case _AirportField.departure:
        _isLoadingDepartureRunways = value;
        break;
      case _AirportField.arrival:
        _isLoadingArrivalRunways = value;
        break;
      case _AirportField.alternate:
        _isLoadingAlternateRunways = value;
        break;
    }
  }

  List<AirportRunwayData> _runwaysForField(_AirportField field) {
    switch (field) {
      case _AirportField.departure:
        return _departureRunways;
      case _AirportField.arrival:
        return _arrivalRunways;
      case _AirportField.alternate:
        return _alternateRunways;
    }
  }

  void _setRunwaysForField(_AirportField field, List<AirportRunwayData> value) {
    switch (field) {
      case _AirportField.departure:
        _departureRunways = value;
        break;
      case _AirportField.arrival:
        _arrivalRunways = value;
        break;
      case _AirportField.alternate:
        _alternateRunways = value;
        break;
    }
  }

  String? _selectedRunwayForField(_AirportField field) {
    switch (field) {
      case _AirportField.departure:
        return _selectedDepartureRunway;
      case _AirportField.arrival:
        return _selectedArrivalRunway;
      case _AirportField.alternate:
        return _selectedAlternateRunway;
    }
  }

  void _setSelectedRunwayForField(_AirportField field, String? value) {
    final normalized = value == null || value.isEmpty ? null : value;
    switch (field) {
      case _AirportField.departure:
        _selectedDepartureRunway = normalized;
        break;
      case _AirportField.arrival:
        _selectedArrivalRunway = normalized;
        break;
      case _AirportField.alternate:
        _selectedAlternateRunway = normalized;
        break;
    }
  }

  void _clearRunwayStateIfNeeded(_AirportField field) {
    _setRunwaysForField(field, []);
    _setSelectedRunwayForField(field, null);
  }

  GlobalKey<FormFieldState<String>> _fieldKeyForField(_AirportField field) {
    switch (field) {
      case _AirportField.departure:
        return _departureFieldKey;
      case _AirportField.arrival:
        return _arrivalFieldKey;
      case _AirportField.alternate:
        return _alternateFieldKey;
    }
  }

  bool _shouldShowRunwayField(_AirportField field) {
    final normalized = _controllerForField(field).text.trim().toUpperCase();
    return _icaoPattern.hasMatch(normalized) && _isAirportValidForField(field);
  }

  bool _isAirportValidForField(_AirportField field) {
    switch (field) {
      case _AirportField.departure:
        return _departureAirportValid;
      case _AirportField.arrival:
        return _arrivalAirportValid;
      case _AirportField.alternate:
        return _alternateAirportValid;
    }
  }

  void _setAirportValidityForField(_AirportField field, bool value) {
    switch (field) {
      case _AirportField.departure:
        _departureAirportValid = value;
        break;
      case _AirportField.arrival:
        _arrivalAirportValid = value;
        break;
      case _AirportField.alternate:
        _alternateAirportValid = value;
        break;
    }
  }

  String? _airportErrorForField(_AirportField field) {
    switch (field) {
      case _AirportField.departure:
        return _departureAirportError;
      case _AirportField.arrival:
        return _arrivalAirportError;
      case _AirportField.alternate:
        return _alternateAirportError;
    }
  }

  void _setAirportErrorForField(_AirportField field, String? value) {
    switch (field) {
      case _AirportField.departure:
        _departureAirportError = value;
        break;
      case _AirportField.arrival:
        _arrivalAirportError = value;
        break;
      case _AirportField.alternate:
        _alternateAirportError = value;
        break;
    }
  }

  String _labelForField(_AirportField field) {
    switch (field) {
      case _AirportField.departure:
        return BriefingLocalizationKeys.fieldDeparture.tr(context);
      case _AirportField.arrival:
        return BriefingLocalizationKeys.fieldArrival.tr(context);
      case _AirportField.alternate:
        return BriefingLocalizationKeys.fieldAlternate.tr(context);
    }
  }

  String? _flightNumberValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    final normalized = value.trim().toUpperCase();
    if (_flightNumberPattern.hasMatch(normalized)) {
      return null;
    }
    return BriefingLocalizationKeys.invalidFlightNumber.tr(context);
  }

  String? _requiredValidator({required String label, required String? value}) {
    if (value == null || value.trim().isEmpty) {
      return BriefingLocalizationKeys.requiredField
          .tr(context)
          .replaceAll('{}', label);
    }
    return null;
  }
}
