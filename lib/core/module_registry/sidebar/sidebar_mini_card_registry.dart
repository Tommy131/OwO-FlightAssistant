import '../../../modules/common/providers/home_provider.dart';
import 'sidebar_mini_card.dart';

class SidebarMiniCardRegistry {
  static final SidebarMiniCardRegistry _instance =
      SidebarMiniCardRegistry._internal();
  factory SidebarMiniCardRegistry() => _instance;
  SidebarMiniCardRegistry._internal();

  final Map<String, SidebarMiniCard Function()> _cardFactories = {};

  void register(String id, SidebarMiniCard Function() factory) {
    _cardFactories[id] = factory;
  }

  bool contains(String id) => _cardFactories.containsKey(id);

  SidebarMiniCard? resolve(HomeProvider? home) {
    final cards = _cardFactories.values.map((factory) => factory()).toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));
    for (final card in cards) {
      if (card.canDisplay(home)) {
        return card;
      }
    }
    return null;
  }

  void clear() {
    _cardFactories.clear();
  }
}
