import 'package:flutter/material.dart';
import '../../../core/theme/app_theme_data.dart';
import '../../settings/widgets/settings_widgets.dart';
import '../data/aviation_terms.dart';

class TermsTranslationTab extends StatefulWidget {
  const TermsTranslationTab({super.key});

  @override
  State<TermsTranslationTab> createState() => _TermsTranslationTabState();
}

class _TermsTranslationTabState extends State<TermsTranslationTab> {
  final TextEditingController _searchController = TextEditingController();
  List<AviationTerm> _searchResults = [];
  bool _isSearching = false;

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
    final theme = Theme.of(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppThemeData.spacingLarge),
          child: SettingsCard(
            title: '航空术语翻译',
            icon: Icons.language_rounded,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SettingsInputField(
                  label: '输入英文术语/简写/中文',
                  hint: '例如: V1, ILS, 气压...',
                  controller: _searchController,
                  icon: Icons.search_rounded,
                  onChanged: _onSearchChanged,
                ),
                if (!_isSearching) ...[
                  const SizedBox(height: 32),
                  Text('常见术语参考', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children:
                        [
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
                            ]
                            .map(
                              (k) => ActionChip(
                                label: Text(k),
                                onPressed: () {
                                  _searchController.text = k;
                                  _onSearchChanged(k);
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
                        const SizedBox(height: 16),
                        Text(
                          '未找到相关术语',
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
              const SizedBox(width: 12),
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
          const SizedBox(height: 4),
          Text(
            term.fullName,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              fontStyle: FontStyle.italic,
            ),
          ),
          if (term.description != null) ...[
            const SizedBox(height: 8),
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
