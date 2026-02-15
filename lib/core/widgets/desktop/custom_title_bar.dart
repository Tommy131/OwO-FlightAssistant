import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import '../../localization/localization_keys.dart';
import '../../services/localization_service.dart';

class CustomTitleBar extends StatefulWidget {
  final double height;
  final Widget? leading;
  final Widget? title;
  final Color? backgroundColor;

  const CustomTitleBar({
    super.key,
    this.height = 40,
    this.leading,
    this.title,
    this.backgroundColor,
  });

  @override
  State<CustomTitleBar> createState() => _CustomTitleBarState();
}

class _CustomTitleBarState extends State<CustomTitleBar> with WindowListener {
  bool _isMaximized = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _updateMaximizedState();
  }

  Future<void> _updateMaximizedState() async {
    _isMaximized = await windowManager.isMaximized();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowMaximize() => _updateMaximizedState();

  @override
  void onWindowUnmaximize() => _updateMaximizedState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final minimizeLabel = LocalizationKeys.windowMinimize.tr(context);
    final maximizeLabel = LocalizationKeys.windowMaximize.tr(context);
    final restoreLabel = LocalizationKeys.windowRestore.tr(context);
    final closeLabel = LocalizationKeys.windowClose.tr(context);

    return SizedBox(
      height: widget.height,
      child: Material(
        color: widget.backgroundColor ?? theme.colorScheme.surface,
        child: Row(
          children: [
            // ===== 可拖拽区域 =====
            Expanded(
              child: DragToMoveArea(
                child: Row(
                  children: [
                    const SizedBox(width: 8),
                    if (widget.leading != null) widget.leading!,
                    if (widget.title != null) ...[
                      const SizedBox(width: 8),
                      DefaultTextStyle(
                        style: theme.textTheme.titleSmall!,
                        child: widget.title!,
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // ===== 窗口控制按钮 =====
            _WindowButton(
              icon: Icons.remove,
              tooltip: minimizeLabel,
              onPressed: () => windowManager.minimize(),
              hoverColor: Colors.grey,
            ),
            _WindowButton(
              icon: _isMaximized ? Icons.filter_none : Icons.crop_square,
              tooltip: _isMaximized ? restoreLabel : maximizeLabel,
              onPressed: () async {
                if (_isMaximized) {
                  await windowManager.unmaximize();
                } else {
                  await windowManager.maximize();
                }
                _updateMaximizedState();
              },
              hoverColor: Colors.blue,
            ),
            _WindowButton(
              icon: Icons.close,
              tooltip: closeLabel,
              hoverColor: Colors.red,
              onPressed: () async {
                bool isPreventClose = await windowManager.isPreventClose();
                if (isPreventClose) {
                  windowManager.close();
                } else {
                  windowManager.destroy();
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _WindowButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;
  final Color? hoverColor;

  const _WindowButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.hoverColor,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          hoverColor: hoverColor?.withValues(alpha: 0.5),
          onTap: onPressed,
          child: SizedBox(
            width: 46,
            height: double.infinity,
            child: ExcludeSemantics(child: Icon(icon, size: 14)),
          ),
        ),
      ),
    );
  }
}
