import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/services/localization_service.dart';
import '../../../../core/theme/app_theme_data.dart';
import '../../localization/briefing_localization_keys.dart';
import '../../providers/briefing_provider.dart';

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

  void _generateBriefing() {
    if (!_formKey.currentState!.validate()) return;
    final provider = context.read<BriefingProvider>();
    provider.generateBriefing(
      departure: _departureController.text.trim().toUpperCase(),
      arrival: _arrivalController.text.trim().toUpperCase(),
      alternate: _alternateController.text.trim().toUpperCase(),
      flightNumber: _flightNumberController.text.trim(),
      route: _routeController.text.trim(),
      cruiseAltitude: int.tryParse(_cruiseAltitudeController.text.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
            _buildField(
              context,
              controller: _departureController,
              label: BriefingLocalizationKeys.fieldDeparture.tr(context),
            ),
            const SizedBox(height: 12),
            _buildField(
              context,
              controller: _arrivalController,
              label: BriefingLocalizationKeys.fieldArrival.tr(context),
            ),
            const SizedBox(height: 12),
            _buildField(
              context,
              controller: _alternateController,
              label: BriefingLocalizationKeys.fieldAlternate.tr(context),
            ),
            const SizedBox(height: 12),
            _buildField(
              context,
              controller: _flightNumberController,
              label: BriefingLocalizationKeys.fieldFlightNumber.tr(context),
            ),
            const SizedBox(height: 12),
            _buildField(
              context,
              controller: _routeController,
              label: BriefingLocalizationKeys.fieldRoute.tr(context),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            _buildField(
              context,
              controller: _cruiseAltitudeController,
              label: BriefingLocalizationKeys.fieldCruiseAltitude.tr(context),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: _generateBriefing,
                icon: const Icon(Icons.auto_awesome),
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
    required TextEditingController controller,
    required String label,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
