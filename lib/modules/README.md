# 模块化开发指南

## 概述

本项目采用模块化架构，所有模块都通过统一入口注册并由核心注册表分发到各功能模块（向导步骤、设置页面、导航、AppBar、侧边栏页脚、国际化等）。

## 当前目录结构

```tree
lib/
├── core/
│   ├── module_registry/
│   │   ├── module_registrar.dart
│   │   ├── module_registry.dart
│   │   ├── app_bar/
│   │   ├── navigation/
│   │   ├── settings_page/
│   │   ├── about_page/
│   │   └── sidebar/
│   └── setup_wizard/
│       ├── wizard_step.dart
│       └── wizard_step_registry.dart
└── modules/
    ├── example_module/
    │   ├── localization/
    │   ├── pages/
    │   ├── wizard/
    │   └── example_module.dart
    ├── modules_register_entry.dart
    └── README.md
```

## 模块开发流程

### 1. 创建模块类

实现 `ModuleRegistrar`，在 `register()` 中注册模块能力：

```dart
import 'package:flutter/material.dart';
import '../../core/module_registry/module_registrar.dart';
import '../../core/module_registry/module_registry.dart';
import '../../core/module_registry/navigation/navigation_item.dart';
import '../../core/module_registry/settings_page/settings_page_item.dart';
import '../../core/setup_wizard/wizard_step.dart';

class MyModule implements ModuleRegistrar {
  @override
  String get moduleName => 'my_module';

  @override
  void register() {
    final registry = ModuleRegistry();

    registry.navigation.register(
      (context) => NavigationItem(
        id: 'my_home',
        title: 'My Home',
        icon: Icons.home_outlined,
        page: const SizedBox.shrink(),
      ),
    );

    registry.wizardSteps.register('my_step', () => _MyWizardStep());
    registry.settingsPages.register('my_settings', () => _MySettingsPage());
    registry.aboutPages.register(AboutPageItem(
      id: 'my_card',
      builder: (context) => const Card(child: Text('My Custom About Card')),
      priority: 35,
    ));
  }
}

class _MyWizardStep extends WizardStep {
  @override
  String get id => 'my_step';

  @override
  String get title => 'My Step';

  @override
  int get priority => 50;

  @override
  bool canGoNext() => true;

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('My Step'));
  }
}

class _MySettingsPage extends SettingsPageItem {
  @override
  String get id => 'my_settings';

  @override
  String getTitle(BuildContext context) => 'My Settings';

  @override
  IconData get icon => Icons.settings;

  @override
  int get priority => 80;

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('My Settings'));
  }
}
```

### 2. 在统一入口注册模块

在 `lib/modules/modules_register_entry.dart` 中注册模块并初始化：

```dart
final registry = ModuleRegistry();
registry.registerModule(MyModule());
registry.initializeAll();
```

## 常用注册能力

- 向导步骤：`registry.wizardSteps.register(id, factory)`
- 设置页面：`registry.settingsPages.register(id, factory)`
- 关于页面卡片：`registry.aboutPages.register(item)`
- AppBar 操作：`registry.appBarActions.register(id, factory)`
- 侧边栏页脚：`registry.sidebarFooters.register(id, factory)`

## 国际化模块接入

模块可在 `register()` 内注册自己的翻译：

```dart
import '../../core/services/localization_service.dart';
import 'localization/my_translations.dart';

LocalizationService().registerModuleTranslations(myTranslations);
```

## 排序与优先级

- 向导步骤与设置页面均按 `priority` 升序排列
- 向导核心总结步骤固定为 `priority = 1000`，确保始终最后

## 注意事项

1. 所有注册项的 `id` 必须唯一
2. `modules_register_entry.dart` 是唯一注册入口
3. 模块注册必须发生在 `initializeAll()` 之前
