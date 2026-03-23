import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../localization/localization_keys.dart';
import '../../services/localization_service.dart';

class StoragePathTile extends StatelessWidget {
  final String? currentPath;
  final Function(String) onPathSelected;
  final String? title;
  final String? subtitle;
  final bool showHeader;
  final EdgeInsetsGeometry contentPadding;
  final bool enableTap;
  final bool showChangeButton;
  final String? changeButtonLabel;

  const StoragePathTile({
    super.key,
    required this.currentPath,
    required this.onPathSelected,
    this.title,
    this.subtitle,
    this.showHeader = true,
    this.contentPadding = const EdgeInsets.all(16),
    this.enableTap = true,
    this.showChangeButton = false,
    this.changeButtonLabel,
  });

  Future<void> _pickPath(BuildContext context) async {
    String? result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: LocalizationKeys.storagePathSelectionDialogTitle.tr(context),
    );
    if (result != null) {
      onPathSelected(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayTitle =
        title ?? LocalizationKeys.storagePathSelectionTitle.tr(context);
    final displaySubtitle =
        subtitle ?? LocalizationKeys.storagePathSelectionSubtitle.tr(context);
    final pathLabel =
        currentPath ?? LocalizationKeys.storagePathNotSelected.tr(context);
    final changeLabel =
        changeButtonLabel ??
        LocalizationKeys.storagePathChangeButton.tr(context);
    final tapLabel =
        '$displayTitle. $displaySubtitle. $pathLabel. $changeLabel';

    final content = Padding(
      padding: contentPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showHeader)
            Row(
              children: [
                Icon(
                  Icons.folder_open,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayTitle,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        displaySubtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
                if (enableTap)
                  Icon(
                    Icons.edit_location_alt_outlined,
                    size: 20,
                    color: Theme.of(context).colorScheme.outline,
                  ),
              ],
            ),
          if (showHeader) const SizedBox(height: 16),
          Semantics(
            label: pathLabel,
            child: ExcludeSemantics(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.outline.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        pathLabel,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                          color: currentPath != null
                              ? Theme.of(context).colorScheme.onSurface
                              : Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                    if (enableTap) ...[
                      const SizedBox(width: 8),
                      Icon(
                        Icons.edit_rounded,
                        size: 16,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          if (showChangeButton) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _pickPath(context),
                icon: const Icon(Icons.drive_folder_upload_rounded, size: 18),
                label: Text(changeLabel),
              ),
            ),
          ],
        ],
      ),
    );

    if (!showHeader && enableTap) {
      return Semantics(
        button: true,
        label: tapLabel,
        child: ExcludeSemantics(
          child: InkWell(onTap: () => _pickPath(context), child: content),
        ),
      );
    }

    if (showHeader && enableTap) {
      return Semantics(
        button: true,
        label: tapLabel,
        child: ExcludeSemantics(
          child: InkWell(
            onTap: () => _pickPath(context),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.outline.withValues(alpha: 0.3),
                ),
                borderRadius: BorderRadius.circular(12),
                color: Theme.of(context).colorScheme.surfaceContainerLow,
              ),
              child: content,
            ),
          ),
        ),
      );
    }

    if (showHeader) {
      return Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
          ),
          borderRadius: BorderRadius.circular(12),
          color: Theme.of(context).colorScheme.surfaceContainerLow,
        ),
        child: content,
      );
    }

    return content;
  }
}
