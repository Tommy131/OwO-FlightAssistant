// 本机机场配置区块
//
// 负责单一职责：让用户搜索并设置"本机机场"（Home Airport）。
// 包含：
// - ICAO 输入框（大写自动转换，实时防抖搜索）
// - 下拉搜索建议列表（加载中转圈 / 结果列表）
// - 当前已保存机场显示
// - 保存 / 清除操作按钮
// - 后端不可达时的毛玻璃遮罩提示
import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../core/services/localization_service.dart';
import '../../../../../core/theme/app_theme_data.dart';
import '../../../../../core/widgets/common/snack_bar.dart';
import '../../../../common/providers/common_provider.dart';
import '../../../localization/map_localization_keys.dart';
import '../../../models/map_models.dart';
import '../../../providers/map_provider.dart';
import 'map_settings_section_card.dart';

/// 本机机场设置区块
///
/// 这是一个完全自治的 StatefulWidget，内部管理：
/// - 搜索输入状态（防抖 / Token 竞态防止 / 候选结果列表）
/// - 保存/清除的 loading 状态
///
/// 通过 [Provider.of] / [context.read] 操作 [MapProvider] 和 [HomeProvider]，
/// 不向父组件暴露任何内部状态。
class MapHomeAirportSection extends StatefulWidget {
  const MapHomeAirportSection({super.key});

  @override
  State<MapHomeAirportSection> createState() => _MapHomeAirportSectionState();
}

class _MapHomeAirportSectionState extends State<MapHomeAirportSection> {
  /// ICAO 输入框控制器
  final TextEditingController _icaoController = TextEditingController();

  /// 搜索防抖计时器
  Timer? _searchDebounce;

  /// 当前搜索候选机场列表
  List<MapAirportMarker> _suggestions = const [];

  /// 是否正在保存
  bool _isSaving = false;

  /// 是否正在搜索（显示转圈）
  bool _isSearching = false;

  /// 竞态防止 token（每次新搜索递增，旧回调发现不匹配则丢弃结果）
  int _searchToken = 0;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _icaoController.dispose();
    super.dispose();
  }

  // ── 内部逻辑 ──────────────────────────────────────────────────────────────

  /// 当输入框内容变化时触发防抖搜索
  void _onInputChanged(String value) {
    _searchDebounce?.cancel();
    final query = value.trim();
    if (query.isEmpty) {
      setState(() {
        _suggestions = const [];
        _isSearching = false;
      });
      return;
    }
    setState(() => _isSearching = true);
    final token = ++_searchToken;
    _searchDebounce = Timer(const Duration(milliseconds: 260), () {
      unawaited(_fetchSuggestions(query, token));
    });
  }

  /// 从 [MapProvider] 拉取搜索候选，去重后按前缀优先排序
  Future<void> _fetchSuggestions(String query, int token) async {
    final mapProvider = context.read<MapProvider?>();
    if (mapProvider == null) {
      if (!mounted || token != _searchToken) return;
      setState(() {
        _suggestions = const [];
        _isSearching = false;
      });
      return;
    }
    final results = await mapProvider.searchAirports(query);
    if (!mounted || token != _searchToken) return;
    final normalizedQuery = query.toUpperCase();
    final deduped = <String, MapAirportMarker>{};
    for (final airport in results) {
      final key = airport.code.trim().toUpperCase();
      if (key.isEmpty || deduped.containsKey(key)) continue;
      deduped[key] = airport;
    }
    final sorted = deduped.values.toList()
      ..sort((a, b) {
        final aCode = a.code.trim().toUpperCase();
        final bCode = b.code.trim().toUpperCase();
        final aPrefix = aCode.startsWith(normalizedQuery);
        final bPrefix = bCode.startsWith(normalizedQuery);
        if (aPrefix != bPrefix) return aPrefix ? -1 : 1;
        return aCode.compareTo(bCode);
      });
    setState(() {
      _suggestions = sorted.take(8).toList();
      _isSearching = false;
    });
  }

  /// 点击候选条目，填入输入框并收起列表
  void _selectSuggestion(MapAirportMarker airport) {
    final code = airport.code.trim().toUpperCase();
    _searchDebounce?.cancel();
    _searchToken += 1;
    setState(() {
      _icaoController.text = code;
      _icaoController.selection = TextSelection.collapsed(offset: code.length);
      _suggestions = const [];
      _isSearching = false;
    });
  }

  /// 保存本机机场：搜索精确匹配 → 写入 [MapProvider]
  Future<void> _save(BuildContext context) async {
    final mapProvider = context.read<MapProvider?>();
    final homeProvider = context.read<HomeProvider?>();
    if (mapProvider == null) return;
    if (homeProvider?.isBackendReachable != true) return;
    final icao = _icaoController.text.trim().toUpperCase();
    if (icao.isEmpty) {
      SnackBarHelper.showError(
        context,
        MapLocalizationKeys.homeAirportNotFound.tr(context),
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      final result = await mapProvider.searchAirports(icao);
      MapAirportMarker? target;
      for (final airport in result) {
        if (airport.code.toUpperCase() == icao) {
          target = airport;
          break;
        }
      }
      target ??= result.isNotEmpty ? result.first : null;
      if (target == null) {
        if (!mounted) return;
        SnackBarHelper.showError(
          context,
          MapLocalizationKeys.homeAirportNotFound.tr(context),
        );
        return;
      }
      await mapProvider.setHomeAirport(target);
      if (!mounted) return;
      setState(() => _icaoController.text = target!.code);
      SnackBarHelper.showSuccess(
        context,
        MapLocalizationKeys.homeAirportSaved.tr(context),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// 清除本机机场设置
  Future<void> _clear(BuildContext context) async {
    final mapProvider = context.read<MapProvider?>();
    final homeProvider = context.read<HomeProvider?>();
    if (mapProvider == null) return;
    if (homeProvider?.isBackendReachable != true) return;
    await mapProvider.clearHomeAirport();
    if (!mounted) return;
    setState(() {
      _icaoController.clear();
      _suggestions = const [];
      _isSearching = false;
    });
    SnackBarHelper.showSuccess(
      context,
      MapLocalizationKeys.homeAirportCleared.tr(context),
    );
  }

  // ── UI 构建 ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Consumer2<MapProvider, HomeProvider>(
      builder: (context, mapProvider, homeProvider, _) {
        // 初始时将已保存的机场代码填入输入框
        if (_icaoController.text.trim().isEmpty &&
            mapProvider.homeAirport != null) {
          _icaoController.text = mapProvider.homeAirport!.code;
        }
        final canConfigure = homeProvider.isBackendReachable;
        final homeAirport = mapProvider.homeAirport;
        final homeAirportDisplay = homeAirport == null
            ? '-'
            : '${homeAirport.code} (${homeAirport.position.latitude.toStringAsFixed(4)}, ${homeAirport.position.longitude.toStringAsFixed(4)})';
        final showSuggestions =
            canConfigure &&
            _icaoController.text.trim().isNotEmpty &&
            (_isSearching || _suggestions.isNotEmpty);

        return Stack(
          children: [
            SettingsSectionCard(
              icon: Icons.home_work_outlined,
              title: MapLocalizationKeys.homeAirportSectionTitle.tr(context),
              subtitle: MapLocalizationKeys.homeAirportSectionDesc.tr(context),
              child: _buildContent(
                context,
                canConfigure: canConfigure,
                homeAirport: homeAirport,
                homeAirportDisplay: homeAirportDisplay,
                showSuggestions: showSuggestions,
              ),
            ),
            // 后端不可达时的毛玻璃遮罩
            if (!canConfigure) _BackendUnavailableOverlay(),
          ],
        );
      },
    );
  }

  /// 区块内容：输入框 + 建议列表 + 当前机场 + 操作按钮
  Widget _buildContent(
    BuildContext context, {
    required bool canConfigure,
    required MapAirportMarker? homeAirport,
    required String homeAirportDisplay,
    required bool showSuggestions,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ICAO 输入框
        TextField(
          controller: _icaoController,
          enabled: canConfigure && !_isSaving,
          textCapitalization: TextCapitalization.characters,
          maxLength: 6,
          decoration: InputDecoration(
            labelText: MapLocalizationKeys.homeAirportIcaoLabel.tr(context),
            hintText: MapLocalizationKeys.homeAirportIcaoHint.tr(context),
            prefixIcon: const Icon(Icons.flight_land_rounded),
            counterText: '',
          ),
          onChanged: _onInputChanged,
        ),
        // 搜索建议下拉列表
        if (showSuggestions) ...[
          const SizedBox(height: AppThemeData.spacingSmall),
          _SuggestionDropdown(
            isSearching: _isSearching,
            suggestions: _suggestions,
            onSelect: _selectSuggestion,
          ),
        ],
        const SizedBox(height: AppThemeData.spacingSmall),
        // 当前已保存机场显示
        Text(
          MapLocalizationKeys.homeAirportCurrent
              .tr(context)
              .replaceFirst('{value}', homeAirportDisplay),
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: AppThemeData.spacingMedium),
        // 保存 / 清除按钮行
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: !canConfigure || _isSaving
                    ? null
                    : () => _save(context),
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined, size: 18),
                label: Text(
                  _isSaving
                      ? MapLocalizationKeys.saving.tr(context)
                      : MapLocalizationKeys.saveButton.tr(context),
                ),
              ),
            ),
            const SizedBox(width: AppThemeData.spacingSmall),
            OutlinedButton.icon(
              onPressed: !canConfigure || homeAirport == null || _isSaving
                  ? null
                  : () => _clear(context),
              icon: const Icon(Icons.clear_rounded, size: 18),
              label: Text(MapLocalizationKeys.clearButton.tr(context)),
            ),
          ],
        ),
      ],
    );
  }
}

// ── 内部私有子组件 ─────────────────────────────────────────────────────────

/// 搜索建议下拉列表
///
/// 仅负责渲染：加载中转圈 或 候选机场列表。
class _SuggestionDropdown extends StatelessWidget {
  final bool isSearching;
  final List<MapAirportMarker> suggestions;
  final ValueChanged<MapAirportMarker> onSelect;

  const _SuggestionDropdown({
    required this.isSearching,
    required this.suggestions,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(maxHeight: 220),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppThemeData.borderRadiusSmall),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.22),
        ),
      ),
      child: isSearching
          ? const Padding(
              padding: EdgeInsets.all(14),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          : ListView.separated(
              shrinkWrap: true,
              itemCount: suggestions.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final airport = suggestions[index];
                return ListTile(
                  dense: true,
                  title: Text(
                    airport.code,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    airport.name ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Text(
                    '${airport.position.latitude.toStringAsFixed(2)}, '
                    '${airport.position.longitude.toStringAsFixed(2)}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  onTap: () => onSelect(airport),
                );
              },
            ),
    );
  }
}

/// 后端服务不可达时的毛玻璃遮罩
///
/// 覆盖在整个卡片上方，显示"服务不可用"提示标签和说明文字。
class _BackendUnavailableOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Positioned.fill(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppThemeData.borderRadiusMedium),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            color: theme.colorScheme.surface.withValues(alpha: 0.72),
            padding: const EdgeInsets.all(AppThemeData.spacingMedium),
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 红色"服务不可用"胶囊标签
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.error,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    MapLocalizationKeys.homeAirportServiceUnavailableTag.tr(
                      context,
                    ),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onError,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: AppThemeData.spacingSmall),
                // 说明文字
                Text(
                  MapLocalizationKeys.homeAirportServiceUnavailableHint.tr(
                    context,
                  ),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
