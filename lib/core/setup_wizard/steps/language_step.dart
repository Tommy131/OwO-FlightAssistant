import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../wizard_step.dart';
import '../wizard_controller.dart';
import '../../services/localization_service.dart';
import '../../widgets/common/overflow_marquee_text.dart';
import '../../localization/localization_keys.dart';

class LanguageStep extends WizardStep {
  @override
  String get id => 'language_selection';

  @override
  String get title => LocalizationKeys.languageStep;

  @override
  int get priority => 0;

  @override
  bool canGoNext() => true;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<WizardController>();
    final localizationService = context.watch<LocalizationService>();
    final languages = localizationService.supportedLanguages;

    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 32),
          Container(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              children: languages.map((lang) {
                final isSelected = controller.languageCode == lang['code'];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    onTap: () {
                      controller.setLanguageCode(lang['code']!);
                      // 立即更新应用的语言，以便用户看到变化
                      final parts = lang['code']!.split('_');
                      localizationService.setLocale(Locale(parts[0], parts[1]));
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.1)
                            : Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(
                                  context,
                                ).colorScheme.outline.withValues(alpha: 0.2),
                          width: 2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isSelected
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off,
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Colors.grey,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: OverflowMarqueeText(
                              text: lang['name']!,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          if (isSelected)
                            Icon(
                              Icons.check,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
