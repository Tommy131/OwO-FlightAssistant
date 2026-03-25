import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/module_registry/navigation/navigation_registry.dart';
import '../../../core/services/localization_service.dart';
import '../../../core/theme/app_theme_data.dart';
import '../../../core/widgets/common/dialog.dart';
import '../../common/localization/common_localization.dart';
import '../../common/providers/common_provider.dart';
import '../localization/home_localization_keys.dart';
import 'widgets/cards/checklist_phase_card.dart';
import 'widgets/cards/flight_number_card.dart';
import 'widgets/cards/simulator_connection_card.dart';
import 'widgets/cards/welcome_card.dart';
import 'widgets/flight_data_dashboard.dart';
import 'widgets/mask/backend_offline_mask.dart';

/// 首页（主页面）
///
/// 负责整体布局编排及后端离线遮罩的显示逻辑。
/// 各卡片与面板均已拆分至独立的 Widget 文件：
/// - [WelcomeCard]
/// - [FlightNumberCard]
/// - [SimulatorConnectionCard]
/// - [ChecklistPhaseCard]
/// - [FlightDataDashboard]
/// - [BackendOfflineMask]
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  /// 记录后端对话框开关状态
  bool _backendDialogVisible = false;

  /// 遮罩层是否存在于树中
  bool _showGlassMask = true;

  /// 遮罩层是否显示帮助卡片
  bool _showConnectionHelpCard = false;

  /// 遮罩层当前透明度（0=不可见，1=完全显示）
  double _glassMaskOpacity = 1;

  /// 后端是否持续不可达
  bool _stickyBackendUnavailable = false;

  /// 当前是否正在重试后端连接
  bool _isRetryingBackend = false;

  /// 已处理的后端中断版本号（防止重复弹出对话框）
  int _handledBackendOutageVersion = 0;

  @override
  void initState() {
    super.initState();
    final provider = context.read<HomeProvider>();
    _handledBackendOutageVersion = provider.backendOutageVersion;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showGlassMask = true;
      if (_stickyBackendUnavailable) {
        _showConnectionHelpCard = true;
        _glassMaskOpacity = 1;
        setState(() {});
        return;
      }
      _showConnectionHelpCard = false;
      _glassMaskOpacity = 1;
      setState(() {});
      _checkBackendAvailability(showDialogWhenUnavailable: false);
    });
  }

  /// 检查后端可达性并更新遮罩状态
  Future<void> _checkBackendAvailability({
    required bool showDialogWhenUnavailable,
  }) async {
    if (_isRetryingBackend) return;
    setState(() => _isRetryingBackend = true);
    final reachable = await context.read<HomeProvider>().refreshBackendHealth();
    if (!mounted) return;
    if (reachable) {
      _stickyBackendUnavailable = false;
      _showGlassMask = true;
      _showConnectionHelpCard = false;
      _glassMaskOpacity = 0;
    } else {
      _stickyBackendUnavailable = true;
      _showGlassMask = true;
      _showConnectionHelpCard = true;
      _glassMaskOpacity = 1;
    }
    setState(() => _isRetryingBackend = false);
    if (!reachable && showDialogWhenUnavailable) {
      await _showBackendUnavailableDialog();
    }
  }

  /// 处理全局后端中断事件（从 provider 版本号判断是否为新中断）
  void _handleGlobalBackendOutage(HomeProvider provider) {
    if (provider.isBackendReachable) {
      _handledBackendOutageVersion = provider.backendOutageVersion;
      return;
    }
    final outageVersion = provider.backendOutageVersion;
    if (outageVersion <= _handledBackendOutageVersion) return;
    _handledBackendOutageVersion = outageVersion;
    _stickyBackendUnavailable = true;
    _showGlassMask = true;
    _showConnectionHelpCard = true;
    _glassMaskOpacity = 1;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {});
      _showBackendUnavailableDialog();
    });
  }

  /// 当模拟器已连接时自动隐藏遮罩
  void _syncMaskWithConnection(HomeProvider provider) {
    if (!provider.isConnected) return;
    if (!_stickyBackendUnavailable &&
        !_showConnectionHelpCard &&
        !_showGlassMask) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _stickyBackendUnavailable = false;
        _showConnectionHelpCard = false;
        _glassMaskOpacity = 0;
        _showGlassMask = false;
      });
    });
  }

  /// 显示后端不可达提示对话框，可选跳转到设置页
  Future<void> _showBackendUnavailableDialog() async {
    if (_backendDialogVisible || !mounted) return;
    _backendDialogVisible = true;
    final shouldOpenSettings = await showAdvancedConfirmDialog(
      context: context,
      style: ConfirmDialogStyle.material,
      title: CommonLocalizationKeys.backendUnavailableTitle.tr(context),
      content: CommonLocalizationKeys.backendUnavailableContent.tr(context),
      icon: Icons.cloud_off_rounded,
      confirmColor: Theme.of(context).colorScheme.primary,
      confirmText: CommonLocalizationKeys.goToSettings.tr(context),
      cancelText: HomeLocalizationKeys.flightNumberDialogCancel.tr(context),
    );
    _backendDialogVisible = false;
    if (shouldOpenSettings == true) {
      NavigationCommandBus().goTo('settings');
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LocalizationService>();
    final homeProvider = context.watch<HomeProvider>();
    _handleGlobalBackendOutage(homeProvider);
    _syncMaskWithConnection(homeProvider);

    final shouldBlockHomeInteraction =
        _showConnectionHelpCard || _glassMaskOpacity > 0.01;

    return Stack(
      children: [
        // 主体内容滚动区域
        Container(
          color: Theme.of(context).scaffoldBackgroundColor,
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
        ),

        // 后端离线遮罩层（按需显示）
        if (_showGlassMask)
          Positioned.fill(
            child: BackendOfflineMask(
              opacity: _glassMaskOpacity,
              showHelpCard: _showConnectionHelpCard,
              isRetrying: _isRetryingBackend,
              absorbPointer: shouldBlockHomeInteraction,
              onRetry: () =>
                  _checkBackendAvailability(showDialogWhenUnavailable: true),
              onFadeEnd: () {
                if (!mounted) return;
                if (_glassMaskOpacity == 0 && !_showConnectionHelpCard) {
                  setState(() {
                    _showGlassMask = false;
                  });
                }
              },
            ),
          ),
      ],
    );
  }
}

/// 首页状态行：模拟器连接卡片 + 检查单阶段卡片（等高并排）
class _HomeStatusRow extends StatelessWidget {
  const _HomeStatusRow();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 760;
        if (isCompact) {
          return const SimulatorConnectionCard();
        }
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
      },
    );
  }
}
