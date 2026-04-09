import 'package:flutter/material.dart';

class ResponsiveSidebarShell extends StatelessWidget {
  const ResponsiveSidebarShell({
    super.key,
    required this.isCompact,
    required this.isExpanded,
    required this.compactWidth,
    required this.expandedWidth,
    required this.content,
    required this.buildPanel,
    required this.onCollapse,
  });

  final bool isCompact;
  final bool isExpanded;
  final double compactWidth;
  final double expandedWidth;
  final Widget content;
  final Widget Function({
    required bool useCompactNav,
    required bool showLabel,
    required bool isFloating,
  })
  buildPanel;
  final VoidCallback onCollapse;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              width: isCompact ? compactWidth : expandedWidth,
              child: buildPanel(
                useCompactNav: isCompact,
                showLabel: !isCompact,
                isFloating: false,
              ),
            ),
            Expanded(child: content),
          ],
        ),
        if (isCompact)
          Positioned(
            left: compactWidth,
            right: 0,
            top: 0,
            bottom: 0,
            child: IgnorePointer(
              ignoring: !isExpanded,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                opacity: isExpanded ? 1 : 0,
                child: GestureDetector(
                  onTap: onCollapse,
                  child: Container(color: Colors.black26),
                ),
              ),
            ),
          ),
        if (isCompact)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            left: isExpanded ? compactWidth : -expandedWidth,
            top: 0,
            bottom: 0,
            child: Material(
              elevation: 14,
              color: Colors.transparent,
              child: buildPanel(
                useCompactNav: true,
                showLabel: true,
                isFloating: true,
              ),
            ),
          ),
      ],
    );
  }
}

class SidebarPanelContainer extends StatelessWidget {
  const SidebarPanelContainer({
    super.key,
    required this.width,
    required this.isFloating,
    required this.children,
    this.topSlot,
    this.onBlankTap,
  });

  final double width;
  final bool isFloating;
  final Widget? topSlot;
  final List<Widget> children;
  final VoidCallback? onBlankTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (topSlot != null) topSlot!,
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 8),
            children: children,
          ),
        ),
      ],
    );

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: isFloating
            ? theme.cardColor
            : theme.cardColor.withValues(alpha: 0.5),
        border: Border(
          right: BorderSide(color: theme.dividerColor.withValues(alpha: 0.12)),
        ),
      ),
      child: onBlankTap == null
          ? body
          : Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onBlankTap,
                    child: const SizedBox.expand(),
                  ),
                ),
                body,
              ],
            ),
    );
  }
}

class SidebarToggleButton extends StatelessWidget {
  const SidebarToggleButton({
    super.key,
    required this.showLabel,
    required this.enabled,
    required this.isExpanded,
    required this.onPressed,
    this.expandedText = '收起菜单',
    this.collapsedText = '展开菜单',
  });

  final bool showLabel;
  final bool enabled;
  final bool isExpanded;
  final VoidCallback? onPressed;
  final String expandedText;
  final String collapsedText;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
      child: SizedBox(
        height: 46,
        child: TextButton(
          onPressed: enabled ? onPressed : null,
          style: TextButton.styleFrom(
            padding: EdgeInsets.symmetric(horizontal: showLabel ? 12 : 0),
            alignment: showLabel ? Alignment.centerLeft : Alignment.center,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final canShowLabel = showLabel && constraints.maxWidth >= 84;
              return Row(
                mainAxisAlignment: canShowLabel
                    ? MainAxisAlignment.start
                    : MainAxisAlignment.center,
                children: [
                  const Icon(Icons.menu_rounded, size: 20),
                  if (canShowLabel) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isExpanded ? expandedText : collapsedText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class SidebarNavItemTile extends StatelessWidget {
  const SidebarNavItemTile({
    super.key,
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.primaryColor,
    required this.showLabel,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color primaryColor;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 46),
          padding: EdgeInsets.symmetric(
            horizontal: showLabel ? 20 : 0,
            vertical: 15,
          ),
          decoration: BoxDecoration(
            border: Border(
              right: BorderSide(
                color: isSelected ? primaryColor : Colors.transparent,
                width: 3,
              ),
            ),
            color: isSelected
                ? primaryColor.withValues(alpha: 0.1)
                : Colors.transparent,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final canShowLabel = showLabel && constraints.maxWidth >= 84;
              return Row(
                mainAxisAlignment: canShowLabel
                    ? MainAxisAlignment.start
                    : MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 20,
                    color: isSelected
                        ? primaryColor
                        : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  if (canShowLabel) ...[
                    const SizedBox(width: 15),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isSelected
                              ? primaryColor
                              : theme.colorScheme.onSurface.withValues(
                                  alpha: 0.8,
                                ),
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
