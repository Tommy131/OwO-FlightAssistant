import { ModuleRegistry } from '../core/module-registry/module-registry';
import { AirportSearchModule } from './airport_search/airport-search-module';
import { BriefingModule } from './briefing/briefing-module';
import { ChecklistModule } from './checklist/checklist-module';
import { CommonModule } from './common/common-module';
import { EfbModule } from './efb/efb-module';
import { FlightLogsModule } from './flight_logs/flight-logs-module';
import { HomeModule } from './home/home-module';
import { HttpModule } from './http/http-module';
import { LogViewerModule } from './log_viewer/log-viewer-module';
import { MapModule } from './map/map-module';
import { MonitorModule } from './monitor/monitor-module';
import { SettingsModule } from './settings/settings-module';
import { ToolboxModule } from './toolbox/toolbox-module';

/**
 * 模块集中注册入口
 *
 * 对应 Flutter 版 `lib/modules/modules_register_entry.dart`。
 * 在应用启动时注册所有业务模块，并处理全局清理逻辑。
 *
 * 注册顺序即 register() 调用顺序；导航项最终位置由各自的 priority 决定，
 * 与注册顺序无关（见 navigation-registry.ts）。
 */
export class ModulesRegisterEntry {
  static registerAll(): void {
    if (ModuleRegistry.isInitialized) return;

    // 1. 注册核心业务模块
    ModuleRegistry.registerModule(new CommonModule());
    ModuleRegistry.registerModule(new HomeModule());
    ModuleRegistry.registerModule(new EfbModule());
    ModuleRegistry.registerModule(new ChecklistModule());
    ModuleRegistry.registerModule(new ToolboxModule());
    ModuleRegistry.registerModule(new AirportSearchModule());
    ModuleRegistry.registerModule(new MapModule());
    ModuleRegistry.registerModule(new MonitorModule());
    ModuleRegistry.registerModule(new BriefingModule());
    ModuleRegistry.registerModule(new FlightLogsModule());
    ModuleRegistry.registerModule(new HttpModule());
    ModuleRegistry.registerModule(new LogViewerModule());
    ModuleRegistry.registerModule(new SettingsModule());
    // 后续模块在此继续注册...

    // 2. 初始化全部已注册模块
    ModuleRegistry.initializeAll();
  }
}
