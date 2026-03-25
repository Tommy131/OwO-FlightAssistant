import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../constants/app_constants.dart';
import '../theme/app_theme_data.dart';
import '../utils/url_launcher_helper.dart';
import '../localization/localization_keys.dart';
import '../services/localization_service.dart';
import '../widgets/common/overflow_marquee_text.dart';

import '../module_registry/module_registry.dart';
import '../module_registry/about_page/about_page_item.dart';

/// 关于应用页面
class AboutPage extends StatelessWidget {
  final VoidCallback? onBack;

  const AboutPage({super.key, this.onBack});

  /// 注册默认的关于页面卡片
  static void registerDefaults() {
    final registry = ModuleRegistry().aboutPages;

    registry.register(
      AboutPageItem(
        id: 'app_icon',
        priority: 10,
        builder: (_) => const _AppIconCard(),
      ),
    );

    registry.register(
      AboutPageItem(
        id: 'app_info',
        priority: 20,
        builder: (_) => const _AppInfoCard(),
      ),
    );

    registry.register(
      AboutPageItem(
        id: 'developer',
        priority: 30,
        builder: (_) => const _DeveloperCard(),
      ),
    );

    registry.register(
      AboutPageItem(
        id: 'discord_community',
        priority: 35,
        builder: (_) => const _DiscordCommunityCard(),
      ),
    );

    registry.register(
      AboutPageItem(
        id: 'contributors',
        priority: 38,
        builder: (_) => const _ContributorsCard(),
      ),
    );

    registry.register(
      AboutPageItem(
        id: 'open_source',
        priority: 40,
        builder: (_) => const _OpenSourceCard(),
      ),
    );

    registry.register(
      AboutPageItem(
        id: 'copyright',
        priority: 100,
        builder: (_) => const _CopyrightCard(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LocalizationService>();
    final theme = Theme.of(context);
    final items = ModuleRegistry().aboutPages.getAllItems();

    return Scaffold(
      body: ListView.separated(
        padding: const EdgeInsets.all(AppThemeData.spacingMedium),
        itemCount: items.length + 1, // +1 for the header
        separatorBuilder: (context, index) =>
            const SizedBox(height: AppThemeData.spacingMedium),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Row(
              children: [
                if (onBack != null)
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    tooltip: LocalizationKeys.back.tr(context),
                    onPressed: onBack,
                  ),
                const SizedBox(width: AppThemeData.spacingSmall),
                Text(
                  LocalizationKeys.aboutApp.tr(context),
                  style: theme.textTheme.headlineMedium,
                ),
              ],
            );
          }
          final item = items[index - 1];
          return item.builder(context);
        },
      ),
    );
  }
}

class _AppIconCard extends StatefulWidget {
  const _AppIconCard();

  @override
  State<_AppIconCard> createState() => _AppIconCardState();
}

class _AppIconCardState extends State<_AppIconCard> {
  final GlobalKey _logoKey = GlobalKey();
  int _tapCount = 0;
  DateTime? _lastTapTime;
  Timer? _tapResetTimer;
  OverlayEntry? _effectEntry;

  @override
  void dispose() {
    _tapResetTimer?.cancel();
    _removeEffect();
    super.dispose();
  }

  void _handleLogoTap() {
    final now = DateTime.now();
    if (_lastTapTime == null ||
        now.difference(_lastTapTime!) > const Duration(milliseconds: 1000)) {
      _tapCount = 0;
    }
    _lastTapTime = now;
    _tapCount += 1;
    _tapResetTimer?.cancel();
    _tapResetTimer = Timer(const Duration(milliseconds: 1400), () {
      _tapCount = 0;
    });
    if (_tapCount < 10) {
      return;
    }
    _tapCount = 0;
    _triggerEasterEgg();
  }

  void _triggerEasterEgg() {
    final context = _logoKey.currentContext;
    if (context == null) {
      return;
    }
    final renderBox = context.findRenderObject();
    if (renderBox is! RenderBox || !renderBox.hasSize) {
      return;
    }
    final origin = renderBox.localToGlobal(
      Offset(renderBox.size.width / 2, renderBox.size.height + 12),
    );
    final overlay = Overlay.of(context, rootOverlay: true);
    _removeEffect();
    SystemSound.play(SystemSoundType.alert);
    Timer(
      const Duration(milliseconds: 140),
      () => SystemSound.play(SystemSoundType.click),
    );
    Timer(
      const Duration(milliseconds: 280),
      () => SystemSound.play(SystemSoundType.click),
    );
    _effectEntry = OverlayEntry(
      builder: (_) =>
          _LogoRibbonOverlay(origin: origin, onFinished: _removeEffect),
    );
    overlay.insert(_effectEntry!);
  }

  void _removeEffect() {
    _effectEntry?.remove();
    _effectEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: _handleLogoTap,
            behavior: HitTestBehavior.opaque,
            child: Container(
              key: _logoKey,
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).primaryColor,
                    Theme.of(context).colorScheme.secondary,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(
                      context,
                    ).primaryColor.withValues(alpha: 0.3),
                    blurRadius: 20,
                    spreadRadius: 5,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: Semantics(
                  image: true,
                  label: LocalizationKeys.appLogo.tr(context),
                  child: ExcludeSemantics(
                    child: Image.asset(
                      AppConstants.assetIconPath,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.dashboard_rounded,
                        size: 60,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppThemeData.spacingMedium),
          Text(
            AppConstants.appName,
            style: Theme.of(context).textTheme.displaySmall,
          ),
          Text(
            'Version ${AppConstants.appVersion}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _LogoRibbonOverlay extends StatefulWidget {
  final Offset origin;
  final VoidCallback onFinished;

  const _LogoRibbonOverlay({required this.origin, required this.onFinished});

  @override
  State<_LogoRibbonOverlay> createState() => _LogoRibbonOverlayState();
}

class _LogoRibbonOverlayState extends State<_LogoRibbonOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_RibbonParticle> _particles;

  @override
  void initState() {
    super.initState();
    _particles = _buildParticles();
    _controller =
        AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 3600),
          )
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) {
              widget.onFinished();
            }
          })
          ..forward();
  }

  List<_RibbonParticle> _buildParticles() {
    final random = math.Random();
    const palette = <Color>[
      Color(0xFFFF5D73),
      Color(0xFFFFC14D),
      Color(0xFF6EE7B7),
      Color(0xFF6EA8FF),
      Color(0xFFB794F4),
      Color(0xFF4ECDC4),
      Color(0xFFFF7F50),
      Color(0xFFE056FD),
    ];
    return List<_RibbonParticle>.generate(170, (index) {
      final speedX = (random.nextDouble() - 0.5) * 240;
      final speedY = 120 + random.nextDouble() * 260;
      final delay = random.nextDouble() * 0.9;
      final life = 1.8 + random.nextDouble() * 1.2;
      final rotationSpeed = (random.nextDouble() - 0.5) * 7.2;
      final width = 4.0 + random.nextDouble() * 4;
      final height = 9.0 + random.nextDouble() * 13;
      final color = palette[random.nextInt(palette.length)];
      final baseRotation = random.nextDouble() * math.pi;
      return _RibbonParticle(
        velocity: Offset(speedX, speedY),
        delaySec: delay,
        lifeSec: life,
        rotationSpeed: rotationSpeed,
        width: width,
        height: height,
        color: color,
        baseRotation: baseRotation,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final safePadding = MediaQuery.of(context).padding;
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            size: size,
            painter: _RibbonPainter(
              particles: _particles,
              progress: _controller.value,
              origin: widget.origin,
              settleY: size.height - safePadding.bottom - 84,
            ),
          );
        },
      ),
    );
  }
}

class _RibbonParticle {
  final Offset velocity;
  final double delaySec;
  final double lifeSec;
  final double rotationSpeed;
  final double width;
  final double height;
  final Color color;
  final double baseRotation;

  const _RibbonParticle({
    required this.velocity,
    required this.delaySec,
    required this.lifeSec,
    required this.rotationSpeed,
    required this.width,
    required this.height,
    required this.color,
    required this.baseRotation,
  });
}

class _RibbonPainter extends CustomPainter {
  final List<_RibbonParticle> particles;
  final double progress;
  final Offset origin;
  final double settleY;

  const _RibbonPainter({
    required this.particles,
    required this.progress,
    required this.origin,
    required this.settleY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final totalSec = 3.6;
    final nowSec = progress * totalSec;
    final fadeGlobal = progress > 0.76 ? 1 - ((progress - 0.76) / 0.24) : 1.0;
    for (final particle in particles) {
      final age = nowSec - particle.delaySec;
      if (age <= 0 || age >= particle.lifeSec) {
        continue;
      }
      final lifeT = age / particle.lifeSec;
      var px = origin.dx + particle.velocity.dx * age;
      var py = origin.dy + particle.velocity.dy * age + 220 * age * age;
      final settleClamp = settleY - (particle.height * 0.5);
      if (py > settleClamp) {
        py = settleClamp;
      }
      if (px < -40 || px > size.width + 40) {
        continue;
      }
      final alpha = (1.0 - math.max(0, lifeT - 0.72) / 0.28) * fadeGlobal;
      if (alpha <= 0) {
        continue;
      }
      final paint = Paint()
        ..color = particle.color.withValues(alpha: alpha.clamp(0, 1));
      final angle = particle.baseRotation + particle.rotationSpeed * age;
      canvas.save();
      canvas.translate(px, py);
      canvas.rotate(angle);
      final rect = Rect.fromCenter(
        center: Offset.zero,
        width: particle.width,
        height: particle.height,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(2)),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _RibbonPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.origin != origin ||
        oldDelegate.settleY != settleY ||
        oldDelegate.particles != particles;
  }
}

class _AppInfoCard extends StatelessWidget {
  const _AppInfoCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppThemeData.spacingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CardHeader(
              icon: Icons.info_outline,
              title: LocalizationKeys.appInfo.tr(context),
            ),
            const Divider(height: 24),
            _ClickableInfoRow(
              label: LocalizationKeys.appNameLabel.tr(context),
              value: AppConstants.appName,
              icon: Icons.apps_rounded,
            ),
            const SizedBox(height: 12),
            _ClickableInfoRow(
              label: LocalizationKeys.packageNameLabel.tr(context),
              value: AppConstants.appPackageName,
              icon: Icons.api_rounded,
            ),
            const SizedBox(height: 12),
            _ClickableInfoRow(
              label: LocalizationKeys.versionLabel.tr(context),
              value:
                  '${AppConstants.appVersion} (${AppConstants.appBuildVersion})',
              icon: Icons.history_rounded,
            ),
          ],
        ),
      ),
    );
  }
}

class _DeveloperCard extends StatelessWidget {
  const _DeveloperCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppThemeData.spacingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CardHeader(
              icon: Icons.code_rounded,
              title: LocalizationKeys.developerInfo.tr(context),
            ),
            const Divider(height: 24),
            _ClickableInfoRow(
              label: LocalizationKeys.developerLabel.tr(context),
              value: AppConstants.developerName,
              icon: Icons.person_rounded,
            ),
            const SizedBox(height: 12),
            _ClickableInfoRow(
              label: LocalizationKeys.emailLabel.tr(context),
              value: AppConstants.developerEmail,
              icon: Icons.email_rounded,
              onTap: () => UrlLauncherHelper.launchURL(
                'mailto:${AppConstants.developerEmail}',
              ),
            ),
            const SizedBox(height: 12),
            _ClickableInfoRow(
              label: 'GitHub',
              value: AppConstants.githubUsername,
              icon: Icons.link_rounded,
              onTap: () => UrlLauncherHelper.launchURL(AppConstants.githubUrl),
            ),
          ],
        ),
      ),
    );
  }
}

class _OpenSourceCard extends StatelessWidget {
  const _OpenSourceCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppThemeData.spacingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CardHeader(
              icon: Icons.description_outlined,
              title: LocalizationKeys.openSourceLicense.tr(context),
            ),
            const Divider(height: 24),
            _ClickableInfoRow(
              label: LocalizationKeys.licenseLabel.tr(context),
              value: AppConstants.license,
              icon: Icons.gavel_rounded,
            ),
            const SizedBox(height: 12),
            _ClickableInfoRow(
              label: LocalizationKeys.projectSourceCode.tr(context),
              value: 'GitHub',
              icon: Icons.code_rounded,
              onTap: () =>
                  UrlLauncherHelper.launchURL(AppConstants.githubRepoUrl),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiscordCommunityCard extends StatelessWidget {
  const _DiscordCommunityCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppThemeData.spacingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF5865F2).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(
                      AppThemeData.borderRadiusSmall,
                    ),
                  ),
                  child: const Icon(
                    Icons.forum_outlined,
                    color: Color(0xFF5865F2),
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppThemeData.spacingSmall),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        LocalizationKeys.community.tr(context),
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        LocalizationKeys.discordCommunityDesc.tr(context),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppThemeData.spacingMedium),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () =>
                    UrlLauncherHelper.launchURL(AppConstants.discordInviteUrl),
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: Text(LocalizationKeys.joinDiscord.tr(context)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CopyrightCard extends StatelessWidget {
  const _CopyrightCard();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: AppThemeData.spacingSmall),
        Text(
          AppConstants.copyright,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(
              context,
            ).textTheme.bodySmall?.color?.withValues(alpha: 0.6),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppThemeData.spacingLarge),
      ],
    );
  }
}

class _ContributorsCard extends StatelessWidget {
  const _ContributorsCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final contributors = <_ContributorEntry>[
      const _ContributorEntry(
        name: 'HanskiJay (Tommy131)',
        contribution: '最肝的开发者',
      ),
      const _ContributorEntry(name: 'Flynn Zhang', contribution: '功能提议&测试反馈'),
      const _ContributorEntry(name: '狗狗星星', contribution: '测试反馈'),
      const _ContributorEntry(name: '小哈朋友', contribution: '功能提议&测试反馈'),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppThemeData.spacingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CardHeader(
              icon: Icons.groups_rounded,
              title: LocalizationKeys.contributors.tr(context),
            ),
            const SizedBox(height: 8),
            Text(
              LocalizationKeys.contributorsDesc.tr(context),
              style: theme.textTheme.bodySmall,
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    LocalizationKeys.contributors.tr(context),
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    '事件',
                    style: theme.textTheme.titleSmall,
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...contributors.asMap().entries.expand(
              (entry) => [
                _ContributorRow(item: entry.value),
                if (entry.key != contributors.length - 1)
                  const Divider(height: 14),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ContributorRow extends StatelessWidget {
  final _ContributorEntry item;

  const _ContributorRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: OverflowMarqueeText(
              text: item.name,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: OverflowMarqueeText(
              text: item.contribution,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodyMedium,
              alignment: Alignment.centerRight,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContributorEntry {
  final String name;
  final String contribution;

  const _ContributorEntry({required this.name, required this.contribution});
}

class _CardHeader extends StatelessWidget {
  final IconData icon;
  final String title;

  const _CardHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).primaryColor),
        const SizedBox(width: 8),
        Expanded(
          child: OverflowMarqueeText(
            text: title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

class _ClickableInfoRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;

  const _ClickableInfoRow({
    required this.label,
    required this.value,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      label: '$label: $value',
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppThemeData.borderRadiusSmall),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: OverflowMarqueeText(
                    text: label,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 4,
                  child: OverflowMarqueeText(
                    text: value,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: onTap != null
                          ? Theme.of(context).primaryColor
                          : null,
                    ),
                    textAlign: TextAlign.right,
                    alignment: Alignment.centerRight,
                  ),
                ),
                if (onTap != null) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: Theme.of(context).primaryColor,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
