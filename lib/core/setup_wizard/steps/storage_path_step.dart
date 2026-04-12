import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../wizard_step.dart';
import '../wizard_controller.dart';
import '../../widgets/common/storage_path_tile.dart';
import '../../localization/localization_keys.dart';
import '../../services/localization_service.dart';

/// 存储路径选择步骤
class StoragePathStep extends WizardStep {
  StoragePathStep();

  @override
  String get id => 'storage_path';

  @override
  String get title => LocalizationKeys.storagePathStep;

  @override
  int get priority => 10;

  @override
  bool canGoNext() {
    return true;
  }

  @override
  Map<String, String>? getSummary() {
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<WizardController>();

    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          StoragePathTile(
            currentPath: controller.previewPath,
            onPathSelected: (path) => controller.setSelectedPath(path),
          ),
          const SizedBox(height: 24),
          Text(
            LocalizationKeys.storagePathHint.tr(context),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
