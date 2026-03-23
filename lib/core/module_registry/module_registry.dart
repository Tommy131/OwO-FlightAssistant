import '../setup_wizard/wizard_step_registry.dart';
import 'app_bar/app_bar_action_registry.dart';
import 'module_registrar.dart';
import 'navigation/navigation_registry.dart';
import 'settings_page/settings_page_registry.dart';
import 'about_page/about_page_registry.dart';
import 'sidebar/sidebar_footer_registry.dart';
import 'sidebar/sidebar_mini_card_registry.dart';
import 'sidebar/sidebar_title_badge_registry.dart';
import 'sidebar/sidebar_title_registry.dart';
import 'provider/provider_registry.dart';

/// 模块注册管理器
class ModuleRegistry {
  static final ModuleRegistry _instance = ModuleRegistry._internal();
  factory ModuleRegistry() => _instance;
  ModuleRegistry._internal();

  final List<ModuleRegistrar> _modules = [];
  final List<Future<void> Function()> _cleanupCallbacks = [];
  bool _initialized = false;

  /// 注册模块
  void registerModule(ModuleRegistrar module) {
    if (_initialized) {
      throw StateError('Cannot register modules after initialization');
    }
    _modules.add(module);
  }

  /// 初始化所有模块
  void initializeAll() {
    if (_initialized) return;

    for (final module in _modules) {
      module.register();
    }

    _initialized = true;
  }

  /// 注册应用关闭时的清理回调
  void registerCleanup(Future<void> Function() callback) {
    _cleanupCallbacks.add(callback);
  }

  /// 执行所有已注册的清理操作
  Future<void> performCleanup() async {
    for (final callback in _cleanupCallbacks) {
      try {
        await callback();
      } catch (e) {
        // 捕获异常防止中断后续清理
      }
    }
  }

  /// 获取向导步骤注册表
  WizardStepRegistry get wizardSteps => WizardStepRegistry();

  /// 获取设置页面注册表
  SettingsPageRegistry get settingsPages => SettingsPageRegistry();

  /// 获取关于页面注册表
  AboutPageRegistry get aboutPages => AboutPageRegistry();

  /// 获取 App Bar 操作按钮注册表
  AppBarActionRegistry get appBarActions => AppBarActionRegistry();

  /// 获取导航项注册表
  NavigationRegistry get navigation => NavigationRegistry();

  /// 获取导航可用性注册表
  NavigationAvailabilityRegistry get navigationAvailability =>
      NavigationAvailabilityRegistry();

  /// 获取侧边栏页脚注册表
  SidebarFooterRegistry get sidebarFooters => SidebarFooterRegistry();

  /// 获取侧边栏迷你卡片注册表
  SidebarMiniCardRegistry get sidebarMiniCards => SidebarMiniCardRegistry();

  /// 获取侧边栏标题注册表
  SidebarTitleRegistry get sidebarTitle => SidebarTitleRegistry();

  /// 获取侧边栏标题状态标识注册表
  SidebarTitleBadgeRegistry get sidebarTitleBadge =>
      SidebarTitleBadgeRegistry();

  /// 获取 Provider 注册表
  ProviderRegistry get providers => ProviderRegistry();

  /// 清空所有注册（仅用于测试）
  void clear() {
    _modules.clear();
    _initialized = false;
    WizardStepRegistry().clear();
    AboutPageRegistry().clear();
    SettingsPageRegistry().clear();
    AppBarActionRegistry().clear();
    NavigationRegistry().clear();
    NavigationAvailabilityRegistry().clear();
    SidebarFooterRegistry().clear();
    SidebarMiniCardRegistry().clear();
    SidebarTitleRegistry().clear();
    SidebarTitleBadgeRegistry().clear();
    _cleanupCallbacks.clear();
  }
}
