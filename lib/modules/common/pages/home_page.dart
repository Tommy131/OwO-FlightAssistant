import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/services/localization_service.dart';
import '../../../core/theme/app_theme_data.dart';
import '../../../core/widgets/common/dialog.dart';
import '../../checklist/providers/checklist_provider.dart';
import '../localization/common_localization_keys.dart';
import '../models/home_models.dart';
import '../providers/home_provider.dart';
import 'widgets/flight_data_dashboard.dart';
import 'widgets/transponder_status_widget.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    context.watch<LocalizationService>();
    final theme = Theme.of(context);

    return Container(
      color: theme.scaffoldBackgroundColor,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppThemeData.spacingLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            WelcomeCard(),
            SizedBox(height: AppThemeData.spacingLarge),
            FlightNumberCard(),
            SizedBox(height: AppThemeData.spacingLarge),
            _HomeStatusRow(),
            SizedBox(height: AppThemeData.spacingLarge),
            FlightDataDashboard(),
          ],
        ),
      ),
    );
  }
}

class _HomeStatusRow extends StatelessWidget {
  const _HomeStatusRow();

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: const [
          Expanded(child: SimulatorConnectionCard()),
          SizedBox(width: AppThemeData.spacingMedium),
          Expanded(child: ChecklistPhaseCard()),
        ],
      ),
    );
  }
}

class WelcomeCard extends StatelessWidget {
  const WelcomeCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<HomeProvider>();

    final isConnected = provider.isConnected;
    final aircraftTitle = provider.aircraftTitle;
    final isPaused = provider.isPaused ?? false;
    final showTransponder =
        isConnected &&
        (provider.transponderState != null || provider.transponderCode != null);

    String title;
    String subtitle;
    Widget? statusIndicator;

    if (!isConnected) {
      title = CommonLocalizationKeys.welcomeNotConnectedTitle.tr(context);
      subtitle = CommonLocalizationKeys.welcomeNotConnectedSubtitle.tr(context);
    } else if (isPaused) {
      title = CommonLocalizationKeys.welcomePausedTitle.tr(context);
      subtitle = CommonLocalizationKeys.welcomePausedSubtitle
          .tr(context)
          .replaceAll('{aircraft}', aircraftTitle ?? '-');
      statusIndicator = Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.yellow.withValues(alpha: 0.2),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.pause_circle_filled,
          color: Colors.yellow,
          size: 32,
        ),
      );
    } else {
      title = CommonLocalizationKeys.welcomeReadyTitle.tr(context);
      subtitle = aircraftTitle != null
          ? CommonLocalizationKeys.welcomeReadySubtitle
                .tr(context)
                .replaceAll('{aircraft}', aircraftTitle)
          : CommonLocalizationKeys.welcomeReadySubtitleWaiting.tr(context);
      statusIndicator = Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.greenAccent.withValues(alpha: 0.2),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.check_circle,
          color: Colors.greenAccent,
          size: 32,
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppThemeData.spacingLarge),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppThemeData.borderRadiusLarge),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppThemeData.spacingSmall),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: AppThemeData.spacingLarge),
              Row(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    color: Colors.white.withValues(alpha: 0.8),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    CommonLocalizationKeys.welcomeSupportSims.tr(context),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              statusIndicator ?? const SizedBox.shrink(),
              if (showTransponder && statusIndicator != null)
                const SizedBox(height: 8),
              if (showTransponder)
                TransponderStatusWidget(
                  code: provider.transponderCode,
                  state: provider.transponderState,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class SimulatorConnectionCard extends StatelessWidget {
  const SimulatorConnectionCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<HomeProvider>();
    final isConnected = provider.isConnected;
    final simulatorType = provider.simulatorType;

    return Container(
      padding: const EdgeInsets.all(AppThemeData.spacingLarge),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppThemeData.borderRadiusMedium),
        border: Border.all(
          color: isConnected
              ? Colors.green.withValues(alpha: 0.5)
              : AppThemeData.getBorderColor(theme),
          width: isConnected ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isConnected ? Icons.link : Icons.link_off,
                color: isConnected ? Colors.green : Colors.grey,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  CommonLocalizationKeys.simTitle.tr(context),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isConnected
                ? CommonLocalizationKeys.simConnected
                      .tr(context)
                      .replaceAll('{sim}', _getSimulatorName(simulatorType))
                : CommonLocalizationKeys.simDisconnected.tr(context),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isConnected ? Colors.green : Colors.grey,
            ),
          ),
          const Spacer(),
          const SizedBox(height: 12),
          if (isConnected)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => provider.disconnect(),
                icon: const Icon(Icons.link_off, size: 16),
                label: Text(CommonLocalizationKeys.simDisconnect.tr(context)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                ),
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: PopupMenuButton<String>(
                onSelected: (value) {
                  final type = switch (value) {
                    'xplane' => HomeSimulatorType.xplane,
                    'msfs' => HomeSimulatorType.msfs,
                    _ => HomeSimulatorType.msfs,
                  };
                  _handleConnect(context, provider, type);
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'xplane',
                    child: Row(
                      children: [
                        const Icon(Icons.airplanemode_active, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          CommonLocalizationKeys.simConnectXplane.tr(context),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'msfs',
                    child: Row(
                      children: [
                        const Icon(Icons.flight, size: 18),
                        const SizedBox(width: 8),
                        Text(CommonLocalizationKeys.simConnectMsfs.tr(context)),
                      ],
                    ),
                  ),
                ],
                child: ElevatedButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.link, size: 16),
                  label: Text(CommonLocalizationKeys.simConnect.tr(context)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _getSimulatorName(HomeSimulatorType type) {
    return switch (type) {
      HomeSimulatorType.xplane => 'X-Plane 11/12',
      HomeSimulatorType.msfs => 'MSFS 2020/2024',
      HomeSimulatorType.none => 'N/A',
    };
  }

  Future<void> _handleConnect(
    BuildContext context,
    HomeProvider provider,
    HomeSimulatorType type,
  ) async {
    final theme = Theme.of(context);
    final name = _getSimulatorName(type);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 20),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 20),
                Text(
                  CommonLocalizationKeys.simConnectingTitle
                      .tr(context)
                      .replaceAll('{sim}', name),
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  CommonLocalizationKeys.simConnectingSubtitle.tr(context),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final success = await provider.connect(type);

    if (context.mounted) {
      Navigator.of(context).pop();
    }

    if (!success && context.mounted) {
      showAdvancedConfirmDialog(
        context: context,
        style: ConfirmDialogStyle.material,
        title: CommonLocalizationKeys.simConnectFailedTitle.tr(context),
        content:
            provider.errorMessage ??
            CommonLocalizationKeys.simConnectFailedContent.tr(context),
        icon: Icons.error_outline,
        confirmColor: Colors.red,
        confirmText: CommonLocalizationKeys.flightNumberDialogConfirm.tr(
          context,
        ),
        cancelText: '',
      );
    }
  }
}

class ChecklistPhaseCard extends StatelessWidget {
  const ChecklistPhaseCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final checklistProvider = context.watch<ChecklistProvider>();
    final checklistPhase = checklistProvider.currentPhase;
    final phase = HomeChecklistPhase(
      labelKey: checklistPhase.labelKey,
      icon: checklistPhase.icon,
    );
    final progress = checklistProvider.getPhaseProgress(checklistPhase);
    final showEmpty = checklistProvider.selectedAircraft == null;

    return Container(
      padding: const EdgeInsets.all(AppThemeData.spacingLarge),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppThemeData.borderRadiusMedium),
        border: Border.all(color: AppThemeData.getBorderColor(theme)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(phase.icon, color: theme.colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  CommonLocalizationKeys.checklistTitle.tr(context),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            showEmpty
                ? CommonLocalizationKeys.checklistEmpty.tr(context)
                : phase.labelKey.tr(context),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
          const Spacer(),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  value: showEmpty ? null : progress,
                  backgroundColor: theme.colorScheme.outline.withValues(
                    alpha: 0.1,
                  ),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    theme.colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                showEmpty ? '--' : '${(progress * 100).toInt()}%',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class FlightNumberCard extends StatelessWidget {
  const FlightNumberCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<HomeProvider>();

    return Container(
      padding: const EdgeInsets.all(AppThemeData.spacingMedium),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppThemeData.borderRadiusMedium),
        border: Border.all(
          color: AppThemeData.getBorderColor(theme).withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(
                AppThemeData.borderRadiusSmall,
              ),
            ),
            child: Icon(
              Icons.confirmation_number_outlined,
              color: theme.colorScheme.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: AppThemeData.spacingMedium),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  CommonLocalizationKeys.flightNumberTitle.tr(context),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  provider.hasFlightNumber
                      ? provider.flightNumber!
                      : CommonLocalizationKeys.flightNumberEmpty.tr(context),
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => _showEditDialog(context, provider),
            icon: const Icon(Icons.edit_note_rounded, size: 18),
            label: Text(
              provider.hasFlightNumber
                  ? CommonLocalizationKeys.flightNumberEdit.tr(context)
                  : CommonLocalizationKeys.flightNumberSet.tr(context),
            ),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditDialog(
    BuildContext context,
    HomeProvider provider,
  ) async {
    final controller = TextEditingController(text: provider.flightNumber);

    if (provider.hasFlightNumber) {
      final confirm = await showAdvancedConfirmDialog(
        context: context,
        title: CommonLocalizationKeys.flightNumberDialogEditTitle.tr(context),
        content: CommonLocalizationKeys.flightNumberDialogEditContent
            .tr(context)
            .replaceAll('{number}', provider.flightNumber ?? ''),
        icon: Icons.info_outline_rounded,
        confirmText: CommonLocalizationKeys.flightNumberDialogContinue.tr(
          context,
        ),
        cancelText: CommonLocalizationKeys.flightNumberDialogCancel.tr(context),
      );
      if (confirm != true) return;
    }

    if (!context.mounted) return;

    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        final formKey = GlobalKey<FormState>();
        return AlertDialog(
          title: Text(
            CommonLocalizationKeys.flightNumberDialogTitle.tr(context),
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(CommonLocalizationKeys.flightNumberDialogHint.tr(context)),
                Text(
                  CommonLocalizationKeys.flightNumberDialogFormat.tr(context),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: controller,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: CommonLocalizationKeys.flightNumberDialogInputHint
                        .tr(context),
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.flight_outlined),
                  ),
                  textCapitalization: TextCapitalization.characters,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return null;
                    if (!RegExp(
                      r'^[A-Z]{2,3}\d{1,4}[A-Z]?$',
                    ).hasMatch(value.trim().toUpperCase())) {
                      return CommonLocalizationKeys.flightNumberDialogInvalid
                          .tr(context);
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                CommonLocalizationKeys.flightNumberDialogCancel.tr(context),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(context, controller.text.trim());
                }
              },
              child: Text(
                CommonLocalizationKeys.flightNumberDialogConfirm.tr(context),
              ),
            ),
          ],
        );
      },
    );

    if (result != null) {
      await provider.setFlightNumber(result.isEmpty ? null : result);
    }
  }
}
