/// 导航分组本地化 Key 定义
class NavigationLocalizationKeys {
  static const String navGroupGeneral = 'navigation.group.general';
  static const String navGroupFlight = 'navigation.group.flight';
  static const String navGroupTools = 'navigation.group.tools';
  static const String navGroupOthers = 'navigation.group.others';
}

/// 导航分组翻译内容
final Map<String, Map<String, String>> navigationModuleTranslations = {
  'zh_CN': {
    NavigationLocalizationKeys.navGroupGeneral: '概览',
    NavigationLocalizationKeys.navGroupFlight: '飞行',
    NavigationLocalizationKeys.navGroupTools: '工具',
    NavigationLocalizationKeys.navGroupOthers: '其他',
  },
  'en_US': {
    NavigationLocalizationKeys.navGroupGeneral: 'GENERAL',
    NavigationLocalizationKeys.navGroupFlight: 'FLIGHT',
    NavigationLocalizationKeys.navGroupTools: 'TOOLS',
    NavigationLocalizationKeys.navGroupOthers: 'OTHERS',
  },
};
