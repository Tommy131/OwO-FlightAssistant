import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme_data.dart';
import '../../../../core/services/localization_service.dart';
import '../../data/aviation_terms.dart';
import '../../models/toolbox_models.dart';
import '../../localization/toolbox_localization_keys.dart';
import 'toolbox_section_card.dart';

/// 工具箱 - 航空术语翻译分页
///
/// 提供航空专业术语的搜索、缩写查询、中文对照及详细解释。

class TermsTranslationTab extends StatefulWidget {
  const TermsTranslationTab({super.key});

  @override
  State<TermsTranslationTab> createState() => _TermsTranslationTabState();
}

class _TermsTranslationTabState extends State<TermsTranslationTab> {
  final TextEditingController _searchController = TextEditingController();
  List<AviationTerm> _searchResults = [];
  bool _isSearching = false;

  static const List<String> _suggestedTerms = [
    'V1',
    'VR',
    'V2',
    'Vref',
    'Vne',
    'ILS',
    'VOR',
    'QNH',
    'FL',
    'SID',
    'STAR',
    'METAR',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    setState(() {
      _isSearching = query.isNotEmpty;
      _searchResults = AviationTermsData.search(query);
    });
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LocalizationService>();
    final theme = Theme.of(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppThemeData.spacingLarge),
          child: ToolboxSectionCard(
            title: ToolboxLocalizationKeys.termsSectionTitle.tr(context),
            icon: Icons.language_rounded,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ToolboxTextField(
                  label: ToolboxLocalizationKeys.termsSearchLabel.tr(context),
                  hint: ToolboxLocalizationKeys.termsSearchHint.tr(context),
                  controller: _searchController,
                  icon: Icons.search_rounded,
                  onChanged: _onSearchChanged,
                ),
                if (!_isSearching) ...[
                  const SizedBox(height: AppThemeData.spacingLarge),
                  Text(
                    ToolboxLocalizationKeys.termsCommonTitle.tr(context),
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: AppThemeData.spacingSmall),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _suggestedTerms
                        .map(
                          (term) => ActionChip(
                            label: Text(term),
                            onPressed: () {
                              _searchController.text = term;
                              _onSearchChanged(term);
                            },
                          ),
                        )
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (_isSearching)
          Expanded(
            child: _searchResults.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 48,
                          color: theme.disabledColor,
                        ),
                        const SizedBox(height: AppThemeData.spacingSmall),
                        Text(
                          ToolboxLocalizationKeys.termsNotFound.tr(context),
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.disabledColor,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppThemeData.spacingLarge,
                    ),
                    itemCount: _searchResults.length,
                    separatorBuilder: (context, index) => Divider(
                      height: 1,
                      color: theme.dividerColor.withValues(alpha: 0.1),
                    ),
                    itemBuilder: (context, index) =>
                        _TermListItem(term: _searchResults[index]),
                  ),
          ),
      ],
    );
  }
}

class _TermListItem extends StatelessWidget {
  final AviationTerm term;

  const _TermListItem({required this.term});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  term.abbreviation,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: AppThemeData.spacingSmall),
              Expanded(
                child: Text(
                  term.chineseName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppThemeData.spacingSmall),
          Text(
            term.fullName,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              fontStyle: FontStyle.italic,
            ),
          ),
          if (term.description != null) ...[
            const SizedBox(height: AppThemeData.spacingSmall),
            Text(
              term.description!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
