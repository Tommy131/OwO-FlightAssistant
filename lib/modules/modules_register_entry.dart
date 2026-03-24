import '../core/module_registry/module_registry.dart';
import '../core/settings_pages/about_page.dart';

// 导入所有业务模块
import 'briefing/briefing_module.dart';
import 'airport_search/airport_search_module.dart';
import 'checklist/checklist_module.dart';
import 'flight_logs/flight_logs_module.dart';
import 'http/http_module.dart';
import 'map/map_module.dart';
import 'monitor/monitor_module.dart';
import 'common/common_module.dart';
import 'toolbox/toolbox_module.dart';
import 'home/home_module.dart';

/// 模块集中注册入口
/// 负责在应用启动时注册所有业务模块，以及处理全局清理逻辑
class ModulesRegisterEntry {
  static void registerAll() {
    final registry = ModuleRegistry();
    if (registry.isInitialized) {
      return;
    }

    // 0. 注册基础核心组件的默认内容
    AboutPage.registerDefaults();

    // 1. 注册核心业务模块
    registry.registerModule(CommonModule());
    registry.registerModule(HomeModule());
    registry.registerModule(ChecklistModule());
    registry.registerModule(MapModule());
    registry.registerModule(AirportSearchModule());
    registry.registerModule(MonitorModule());
    registry.registerModule(BriefingModule());
    registry.registerModule(FlightLogsModule());
    registry.registerModule(ToolboxModule());
    registry.registerModule(HttpModule());
    // 如果有其他模块，在此处继续注册...

    // 2. 初始化所有已注册模块
    registry.initializeAll();

    // 4. 注册全局清理回调
    _registerGlobalCleanup(registry);
  }

  /// 注册应用退出时的全局清理逻辑
  static void _registerGlobalCleanup(ModuleRegistry registry) {
    // 示例代码
    /* registry.registerCleanup(() async {
      debugPrint('[Cleanup] 正在清理资源...');
    }); */
  }
}
