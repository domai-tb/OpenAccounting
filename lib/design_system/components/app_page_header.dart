import 'package:flutter/material.dart';
import 'package:openaccounting/core/theme/app_theme.dart';

/// Consistent page header per DESIGN §5.
/// Minimal for 1.2: title + optional subtitle + actions.
/// Full tabs/filter toolbar deferred to 3.2.
class AppPageHeader extends StatelessWidget implements PreferredSizeWidget {
  const AppPageHeader({
    required this.title,
    this.subtitle,
    this.actions,
    this.primaryAction,
    this.primaryActionLabel,
    this.onPrimaryAction,
    this.tabs,
    this.tabController,
    this.initialTabIndex = 0,
    this.onTabChanged,
    this.searchController,
    this.onSearchChanged,
    this.showFilterToolbar = true,
    this.searchLabel = 'Suchen',
    this.searchHint = 'Suchen…',
    this.filterButtonLabel = 'Filter',
    this.onFilterPressed,
    this.activeFilters = const <String>[],
    this.onFilterRemoved,
    this.removeFilterLabel = 'Filter entfernen',
    this.resultCount,
    this.resultCountLabelBuilder,
    this.resetFiltersLabel = 'Filter zurücksetzen',
    this.onResetFilters,
    this.tabsLabel = 'Ansichten',
    super.key,
  });

  final String title;
  final String? subtitle;
  final List<Widget>? actions;

  /// Custom primary action. If omitted, [primaryActionLabel] creates a [FilledButton].
  final Widget? primaryAction;
  final String? primaryActionLabel;
  final VoidCallback? onPrimaryAction;

  /// Tab widgets rendered below the title. A local [DefaultTabController] is provided when needed.
  final List<Widget>? tabs;
  final TabController? tabController;
  final int initialTabIndex;
  final ValueChanged<int>? onTabChanged;

  final TextEditingController? searchController;
  final ValueChanged<String>? onSearchChanged;
  final bool showFilterToolbar;
  final String searchLabel;
  final String? searchHint;
  final String filterButtonLabel;
  final VoidCallback? onFilterPressed;
  final List<String> activeFilters;
  final ValueChanged<String>? onFilterRemoved;
  final String removeFilterLabel;
  final int? resultCount;
  final String Function(int count)? resultCountLabelBuilder;
  final String resetFiltersLabel;
  final VoidCallback? onResetFilters;
  final String tabsLabel;

  static const double _subtitleHeight = AppSpacing.xl;
  static const double _toolbarHeight = AppSpacing.xxxl + AppSpacing.sm;
  static const double _filterSummaryHeight = AppSpacing.xxxl;

  bool get _hasTabs => tabs?.isNotEmpty ?? false;

  bool get _hasFilterSummary =>
      showFilterToolbar && (activeFilters.isNotEmpty || resultCount != null || onResetFilters != null);

  double get _bottomHeight {
    double height = showFilterToolbar ? _toolbarHeight : 0;
    if (subtitle != null) {
      height += _subtitleHeight;
    }
    if (_hasTabs) {
      height += kTextTabBarHeight;
    }
    if (_hasFilterSummary) {
      height += _filterSummaryHeight;
    }
    return height;
  }

  Widget? get _resolvedPrimaryAction {
    if (primaryAction != null) {
      return primaryAction;
    }

    final String? label = primaryActionLabel;
    if (label == null) {
      return null;
    }

    return FilledButton(
      onPressed: onPrimaryAction,
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.control)),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      ),
      child: Text(label),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Widget? resolvedPrimaryAction = _resolvedPrimaryAction;
    final List<Widget> resolvedActions = <Widget>[
      ...?actions,
      if (resolvedPrimaryAction != null)
        Padding(
          padding: const EdgeInsets.only(left: AppSpacing.sm),
          child: resolvedPrimaryAction,
        ),
    ];

    return AppBar(
      toolbarHeight: kToolbarHeight,
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      actions: resolvedActions.isEmpty ? null : resolvedActions,
      bottom: PreferredSize(
        preferredSize: Size.fromHeight(_bottomHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (subtitle != null) _buildSubtitle(),
            if (_hasTabs) _buildTabs(),
            if (showFilterToolbar) _buildToolbar(),
            if (_hasFilterSummary) _buildFilterSummary(),
          ],
        ),
      ),
    );
  }

  Widget _buildSubtitle() {
    return SizedBox(
      height: _subtitleHeight,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
          child: Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, softWrap: false),
        ),
      ),
    );
  }

  int _safeInitialTabIndex(int tabCount) {
    if (initialTabIndex < 0) {
      return 0;
    }

    final int lastTabIndex = tabCount - 1;
    return initialTabIndex > lastTabIndex ? lastTabIndex : initialTabIndex;
  }

  Widget _buildTabs() {
    final List<Widget> tabWidgets = tabs!;
    final Widget tabBar = Semantics(
      container: true,
      label: tabsLabel,
      child: SizedBox(
        height: kTextTabBarHeight,
        child: TabBar(
          controller: tabController,
          isScrollable: true,
          labelPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          onTap: onTabChanged,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          tabs: tabWidgets,
        ),
      ),
    );

    if (tabController != null) {
      return tabBar;
    }

    return DefaultTabController(
      length: tabWidgets.length,
      initialIndex: _safeInitialTabIndex(tabWidgets.length),
      child: tabBar,
    );
  }

  Widget _buildToolbar() {
    return SizedBox(
      height: _toolbarHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Semantics(
                label: searchLabel,
                textField: true,
                child: TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.control)),
                    hintText: searchHint,
                    labelText: searchLabel,
                    prefixIcon: const Icon(Icons.search),
                  ),
                  onChanged: onSearchChanged,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: onFilterPressed,
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.control)),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              ),
              icon: const Icon(Icons.filter_list),
              label: Text(filterButtonLabel),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterSummary() {
    final List<Widget> children = <Widget>[
      for (final String filter in activeFilters)
        Padding(
          padding: const EdgeInsets.only(right: AppSpacing.sm),
          child: _buildFilterChip(filter),
        ),
      if (activeFilters.isNotEmpty && resultCount != null) const SizedBox(width: AppSpacing.sm),
      if (resultCount != null)
        Semantics(container: true, label: _resultCountText, liveRegion: true, child: Text(_resultCountText)),
      if (onResetFilters != null)
        Padding(
          padding: const EdgeInsets.only(left: AppSpacing.sm),
          child: TextButton(
            onPressed: onResetFilters,
            style: TextButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.control)),
            ),
            child: Text(resetFiltersLabel),
          ),
        ),
    ];

    return SizedBox(
      height: _filterSummaryHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(mainAxisSize: MainAxisSize.min, children: children),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String filter) {
    final String semanticLabel = '$removeFilterLabel: $filter';
    final ValueChanged<String>? removeFilter = onFilterRemoved;

    return Semantics(
      container: true,
      hint: removeFilterLabel,
      label: filter,
      child: FilterChip(
        deleteButtonTooltipMessage: removeFilterLabel,
        deleteIcon: Semantics(button: true, label: semanticLabel, child: const Icon(Icons.close)),
        label: Text(filter),
        onDeleted: removeFilter == null ? null : () => removeFilter(filter),
        onSelected: removeFilter == null ? null : (bool _) => removeFilter(filter),
        selected: true,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.control)),
      ),
    );
  }

  String get _resultCountText {
    final int count = resultCount!;
    final String? localizedText = resultCountLabelBuilder?.call(count);
    if (localizedText != null) {
      return localizedText;
    }

    final String noun = count == 1 ? 'Ergebnis' : 'Ergebnisse';
    return '$count $noun';
  }

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight + _bottomHeight);
}
