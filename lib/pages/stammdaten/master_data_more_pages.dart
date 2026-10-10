import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openaccounting/core/app_scope.dart';
import 'package:openaccounting/core/app_services.dart';
import 'package:openaccounting/core/localization.dart';
import 'package:openaccounting/design_system/components/app_card.dart';
import 'package:openaccounting/design_system/components/app_page.dart';
import 'package:openaccounting/design_system/components/app_page_header.dart';
import 'package:openaccounting/design_system/tokens/spacing.dart';
import 'package:openaccounting/l10n/l10n.dart';
import 'package:openaccounting/pages/stammdaten/artikel_repository.dart';
import 'package:openaccounting/pages/stammdaten/kategorien_repository.dart';
import 'package:openaccounting/pages/stammdaten/master_data_pages.dart';
import 'package:openaccounting/pages/stammdaten/master_data_workspaces.dart';
import 'package:openaccounting/pages/stammdaten/unternehmen_repository.dart';

/// Article and Settings master-data workspaces (group 3, groups 4-5 wiring).

AppServices _moreServicesOf(BuildContext context, WidgetRef ref) {
  return AppScope.maybeOf(context)?.services ?? ref.read(appServicesProvider);
}

List<Widget> _morePrimaryAction(BuildContext context, String label, IconData icon, VoidCallback? onPressed) {
  if (MediaQuery.sizeOf(context).width < 560) {
    return <Widget>[IconButton(icon: Icon(icon), tooltip: label, onPressed: onPressed)];
  }
  return <Widget>[FilledButton.icon(onPressed: onPressed, icon: Icon(icon), label: Text(label))];
}

class ArticlesWorkspaceView extends ConsumerStatefulWidget {
  const ArticlesWorkspaceView({super.key});

  @override
  ConsumerState<ArticlesWorkspaceView> createState() => _ArticlesWorkspaceViewState();
}

class _ArticlesWorkspaceViewState extends ConsumerState<ArticlesWorkspaceView> {
  final TextEditingController _searchController = TextEditingController();
  String _search = '';
  int _page = 1;
  int _reloadToken = 0;
  Object? _error;

  bool get _groups {
    try {
      return GoRouterState.of(context).uri.queryParameters['view'] == 'groups';
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = appLocalizationsOf(context);
    final bool groups = _groups;
    if (_error != null) {
      return AppPage(
        header: AppPageHeader(title: l10n.routeArticles, showFilterToolbar: false),
        child: MasterDataErrorView(
          onRetry: () => setState(() {
            _error = null;
            _reloadToken++;
          }),
        ),
      );
    }
    return AppPage(
      maxWidth: 1180,
      header: AppPageHeader(
        title: groups ? l10n.articlesViewGroups : l10n.routeArticles,
        searchController: _searchController,
        searchHint: '${l10n.routeArticles} ${l10n.actionSearch.toLowerCase()}…',
        onSearchChanged: (String value) => setState(() {
          _search = value;
          _page = 1;
        }),
        activeFilters: <String>[
          if (groups) l10n.articlesViewGroups else l10n.articlesViewItems,
          if (_search.trim().isNotEmpty) '${l10n.actionSearch}: ${_search.trim()}',
        ],
        onFilterRemoved: (_) => setState(() {
          _searchController.clear();
          _search = '';
          _page = 1;
        }),
        removeFilterLabel: l10n.actionRemoveFilter,
        tabs: <Widget>[
          Tab(text: l10n.articlesViewItems),
          Tab(text: l10n.articlesViewGroups),
        ],
        initialTabIndex: groups ? 1 : 0,
        onTabChanged: (int index) => context.go(index == 1 ? '/articles?view=groups' : '/articles'),
        actions: _morePrimaryAction(
          context,
          groups ? l10n.actionCreateGroup : l10n.actionCreateArticle,
          Icons.add,
          () => context.go(groups ? '/articles/new?kind=group' : '/articles/new?kind=item'),
        ),
      ),
      child: groups
          ? _ArticleGroupListBody(
              key: ValueKey<String>('groups_$_reloadToken'),
              search: _search,
              page: _page,
              onPageChanged: (int next) => setState(() => _page = next),
              onError: (Object error) => setState(() => _error = error),
            )
          : _ArticleListBody(
              key: ValueKey<String>('articles_$_reloadToken'),
              search: _search,
              page: _page,
              onPageChanged: (int next) => setState(() => _page = next),
              onError: (Object error) => setState(() => _error = error),
            ),
    );
  }
}

class _ArticleListBody extends ConsumerWidget {
  const _ArticleListBody({
    required this.search,
    required this.page,
    required this.onPageChanged,
    required this.onError,
    super.key,
  });

  final String search;
  final int page;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<Object> onError;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = appLocalizationsOf(context);
    final AppServices services = _moreServicesOf(context, ref);
    return FutureBuilder<ArticlePage>(
      future: services.articleWorkspace.query(search: search, page: page),
      builder: (BuildContext context, AsyncSnapshot<ArticlePage> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          WidgetsBinding.instance.addPostFrameCallback((_) => onError(snapshot.error!));
          return const SizedBox.shrink();
        }
        final ArticlePage result = snapshot.data!;
        if (result.items.isEmpty) {
          return MasterDataEmptyView(
            icon: Icons.inventory_2_outlined,
            createLabel: l10n.actionCreateArticle,
            onCreate: () => context.go('/articles/new?kind=item'),
          );
        }
        return AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        '${result.totalCount} ${l10n.countArticles}',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    Text('${result.totalCount} ${l10n.countResults}', style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              const Divider(height: 1),
              for (int index = 0; index < result.items.length; index++) ...<Widget>[
                Material(
                  type: MaterialType.transparency,
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.inventory_2_outlined, size: 20)),
                    title: Text(result.items[index].bezeichnung),
                    subtitle: Text(result.items[index].artikelnummer ?? ''),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.go('/articles/${result.items[index].id}?kind=item'),
                  ),
                ),
                if (index < result.items.length - 1) const Divider(height: 1, indent: 72),
              ],
              _morePagination(context, l10n, result.page, result.totalCount, result.hasMore, onPageChanged),
            ],
          ),
        );
      },
    );
  }
}

class _ArticleGroupListBody extends ConsumerWidget {
  const _ArticleGroupListBody({
    required this.search,
    required this.page,
    required this.onPageChanged,
    required this.onError,
    super.key,
  });

  final String search;
  final int page;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<Object> onError;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = appLocalizationsOf(context);
    final AppServices services = _moreServicesOf(context, ref);
    return FutureBuilder<ArticleGroupPage>(
      future: services.articleGroupWorkspace.query(search: search, page: page),
      builder: (BuildContext context, AsyncSnapshot<ArticleGroupPage> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          WidgetsBinding.instance.addPostFrameCallback((_) => onError(snapshot.error!));
          return const SizedBox.shrink();
        }
        final ArticleGroupPage result = snapshot.data!;
        if (result.items.isEmpty) {
          return MasterDataEmptyView(
            icon: Icons.folder_outlined,
            createLabel: l10n.actionCreateGroup,
            onCreate: () => context.go('/articles/new?kind=group'),
          );
        }
        return AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        '${result.totalCount} ${l10n.countGroups}',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    Text('${result.totalCount} ${l10n.countResults}', style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              const Divider(height: 1),
              for (int index = 0; index < result.items.length; index++) ...<Widget>[
                Material(
                  type: MaterialType.transparency,
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.folder_outlined, size: 20)),
                    title: Text(result.items[index].name),
                    subtitle: Text(result.items[index].beschreibung ?? ''),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.go('/articles/${result.items[index].id}?kind=group'),
                  ),
                ),
                if (index < result.items.length - 1) const Divider(height: 1, indent: 72),
              ],
              _morePagination(context, l10n, result.page, result.totalCount, result.hasMore, onPageChanged),
            ],
          ),
        );
      },
    );
  }
}

Widget _morePagination(
  BuildContext context,
  AppLocalizations l10n,
  int page,
  int totalCount,
  bool hasMore,
  ValueChanged<int> onPageChanged,
) {
  const int limit = 25;
  final int pageCount = totalCount == 0 ? 1 : ((totalCount - 1) ~/ limit) + 1;
  if (pageCount <= 1 && !hasMore) return const SizedBox.shrink();
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        IconButton(
          tooltip: l10n.filterPreviousPage,
          onPressed: page > 1 ? () => onPageChanged(page - 1) : null,
          icon: const Icon(Icons.chevron_left),
        ),
        Text(l10n.filterPageCount(page, pageCount)),
        IconButton(
          tooltip: l10n.filterNextPage,
          onPressed: page < pageCount ? () => onPageChanged(page + 1) : null,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    ),
  );
}

/// Kind-discriminated article detail: group IDs resolve through the group
/// service, never through the article lookup.
class ArticleRecordView extends ConsumerWidget {
  const ArticleRecordView({required this.id, super.key});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = appLocalizationsOf(context);
    final Uri uri = GoRouterState.of(context).uri;
    final String? kind = uri.queryParameters['kind'];
    if (kind != 'item' && kind != 'group') {
      return MasterDataTypeSelectionView(
        requestedId: id,
        title: l10n.articleTypeSelectionTitle,
        message: l10n.articleTypeSelectionMessage,
        firstLabel: l10n.articlesViewItems,
        secondLabel: l10n.articlesViewGroups,
        onSelectFirst: () => context.go('${uri.path}?kind=item'),
        onSelectSecond: () => context.go('${uri.path}?kind=group'),
      );
    }
    final int? recordId = int.tryParse(id);
    if (recordId == null) {
      return AppPage(
        header: AppPageHeader(title: l10n.notFound, showFilterToolbar: false),
        child: AppCard(child: Text(l10n.errorRecordNotFound(id))),
      );
    }
    if (kind == 'group') {
      return _ArticleGroupRecordBody(id: recordId);
    }
    return _ArticleRecordBody(id: recordId);
  }
}

class _ArticleRecordBody extends ConsumerWidget {
  const _ArticleRecordBody({required this.id});

  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = appLocalizationsOf(context);
    final AppServices services = _moreServicesOf(context, ref);
    return FutureBuilder<Artikel?>(
      future: services.articleDetail.itemById(id),
      builder: (BuildContext context, AsyncSnapshot<Artikel?> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return AppPage(
            header: AppPageHeader(title: l10n.routeArticles, showFilterToolbar: false),
            child: const Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return AppPage(
            header: AppPageHeader(title: l10n.routeArticles, showFilterToolbar: false),
            child: MasterDataErrorView(onRetry: () => context.go('/articles')),
          );
        }
        final Artikel? article = snapshot.data;
        if (article == null) {
          return AppPage(
            header: AppPageHeader(
              title: l10n.notFound,
              showFilterToolbar: false,
              leading: IconButton(
                onPressed: () => context.go('/articles'),
                icon: const Icon(Icons.arrow_back),
                tooltip: l10n.actionBack,
              ),
            ),
            child: AppCard(child: Text(l10n.errorRecordNotFound('$id'))),
          );
        }
        return AppPage(
          maxWidth: 860,
          header: AppPageHeader(
            title: article.bezeichnung,
            showFilterToolbar: false,
            leading: IconButton(
              onPressed: () => context.go('/articles'),
              icon: const Icon(Icons.arrow_back),
              tooltip: l10n.actionBack,
            ),
          ),
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _moreDetailRow(l10n.formName, article.bezeichnung),
                _moreDetailRow('Artikel-Nr.', article.artikelnummer ?? '—'),
                _moreDetailRow('Typ', article.typ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ArticleGroupRecordBody extends ConsumerWidget {
  const _ArticleGroupRecordBody({required this.id});

  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = appLocalizationsOf(context);
    final AppServices services = _moreServicesOf(context, ref);
    return FutureBuilder<ArtikelGruppe?>(
      future: services.articleDetail.groupById(id),
      builder: (BuildContext context, AsyncSnapshot<ArtikelGruppe?> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return AppPage(
            header: AppPageHeader(title: l10n.articlesViewGroups, showFilterToolbar: false),
            child: const Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return AppPage(
            header: AppPageHeader(title: l10n.articlesViewGroups, showFilterToolbar: false),
            child: MasterDataErrorView(onRetry: () => context.go('/articles?view=groups')),
          );
        }
        final ArtikelGruppe? group = snapshot.data;
        if (group == null) {
          return AppPage(
            header: AppPageHeader(
              title: l10n.notFound,
              showFilterToolbar: false,
              leading: IconButton(
                onPressed: () => context.go('/articles?view=groups'),
                icon: const Icon(Icons.arrow_back),
                tooltip: l10n.actionBack,
              ),
            ),
            child: AppCard(child: Text(l10n.errorRecordNotFound('$id'))),
          );
        }
        return AppPage(
          maxWidth: 860,
          header: AppPageHeader(
            title: group.name,
            showFilterToolbar: false,
            leading: IconButton(
              onPressed: () => context.go('/articles?view=groups'),
              icon: const Icon(Icons.arrow_back),
              tooltip: l10n.actionBack,
            ),
          ),
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _moreDetailRow(l10n.formName, group.name),
                _moreDetailRow(l10n.formDescription, group.beschreibung ?? '—'),
              ],
            ),
          ),
        );
      },
    );
  }
}

Widget _moreDetailRow(String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 160,
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
        Expanded(child: Text(value)),
      ],
    ),
  );
}

/// Article/group create form. Missing/invalid kind offers the item/group choice.
class ArticleFormView extends ConsumerStatefulWidget {
  const ArticleFormView({super.key});

  @override
  ConsumerState<ArticleFormView> createState() => _ArticleFormViewState();
}

class _ArticleFormViewState extends ConsumerState<ArticleFormView> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _description = TextEditingController();
  bool _saving = false;

  String? get _kind {
    try {
      return GoRouterState.of(context).uri.queryParameters['kind'];
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false) || _saving) return;
    final String? kind = _kind;
    if (kind != 'item' && kind != 'group') return;
    setState(() => _saving = true);
    try {
      final AppServices services = _moreServicesOf(context, ref);
      if (kind == 'group') {
        final ArtikelGruppe group = await services.articleGroupWorkspace.create(
          name: _name.text.trim(),
          beschreibung: _description.text.trim().isEmpty ? null : _description.text.trim(),
        );
        if (mounted) context.go('/articles/${group.id}?kind=group');
      } else {
        final ArtikelRepository repository = services.artikel;
        final Artikel article = await repository.create(
          bezeichnung: _name.text.trim(),
          beschreibung: _description.text.trim().isEmpty ? null : _description.text.trim(),
          vkBrutto: 0,
        );
        if (mounted) context.go('/articles/${article.id}?kind=item');
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('${appLocalizationsOf(context).saveFailed}: $error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = appLocalizationsOf(context);
    final String? kind = _kind;
    if (kind != 'item' && kind != 'group') {
      return MasterDataTypeSelectionView(
        requestedId: 'neu',
        title: l10n.articleTypeSelectionTitle,
        message: l10n.articleTypeSelectionMessage,
        firstLabel: l10n.articlesViewItems,
        secondLabel: l10n.articlesViewGroups,
        onSelectFirst: () => context.go('/articles/new?kind=item'),
        onSelectSecond: () => context.go('/articles/new?kind=group'),
      );
    }
    final bool group = kind == 'group';
    return AppPage(
      maxWidth: 860,
      header: AppPageHeader(
        title: group ? l10n.actionCreateGroup : l10n.actionCreateArticle,
        showFilterToolbar: false,
        leading: IconButton(
          onPressed: _saving ? null : () => context.go(group ? '/articles?view=groups' : '/articles'),
          icon: const Icon(Icons.arrow_back),
          tooltip: l10n.actionBack,
        ),
      ),
      child: Form(
        key: _formKey,
        child: ListView(
          children: <Widget>[
            TextFormField(
              controller: _name,
              decoration: InputDecoration(labelText: '${l10n.formName} *'),
              validator: (String? value) => value == null || value.trim().isEmpty ? l10n.formRequiredField : null,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _description,
              decoration: InputDecoration(labelText: l10n.formDescription),
            ),
            const SizedBox(height: AppSpacing.xxl),
            Row(
              children: <Widget>[
                OutlinedButton(
                  onPressed: _saving ? null : () => context.go(group ? '/articles?view=groups' : '/articles'),
                  child: Text(l10n.actionCancel),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.save_outlined),
                  label: Text(_saving ? l10n.actionSaving : l10n.actionSave),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Singleton company workspace: setup-needed state when absent, retry on failure.
class CompanySettingsView extends ConsumerStatefulWidget {
  const CompanySettingsView({super.key});

  @override
  ConsumerState<CompanySettingsView> createState() => _CompanySettingsViewState();
}

class _CompanySettingsViewState extends ConsumerState<CompanySettingsView> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  bool _saving = false;
  int _reloadToken = 0;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = appLocalizationsOf(context);
    final AppServices services = _moreServicesOf(context, ref);
    return AppPage(
      maxWidth: 860,
      header: AppPageHeader(
        title: l10n.settingsCompany,
        showFilterToolbar: false,
        leading: IconButton(
          onPressed: () => context.go('/settings'),
          icon: const Icon(Icons.arrow_back),
          tooltip: l10n.actionBack,
        ),
      ),
      child: FutureBuilder<Unternehmen>(
        key: ValueKey<String>('company_$_reloadToken'),
        future: services.companySettings.load(),
        builder: (BuildContext context, AsyncSnapshot<Unternehmen> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return MasterDataErrorView(onRetry: () => setState(() => _reloadToken++));
          }
          final Unternehmen company = snapshot.data!;
          if (_name.text.isEmpty && (company.name?.isNotEmpty ?? false)) {
            _name.text = company.name!;
          }
          if (company.name == null || company.name!.trim().isEmpty || company.name == 'Meine Firma') {
            return AppCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(l10n.companySetupNeeded),
                  const SizedBox(height: AppSpacing.lg),
                  _companyForm(context, l10n, services),
                ],
              ),
            );
          }
          return _companyForm(context, l10n, services);
        },
      ),
    );
  }

  Widget _companyForm(BuildContext context, AppLocalizations l10n, AppServices services) {
    return Form(
      key: _formKey,
      child: Column(
        children: <Widget>[
          TextFormField(
            controller: _name,
            decoration: InputDecoration(labelText: '${l10n.formCompany} *'),
            validator: (String? value) => value == null || value.trim().isEmpty ? l10n.formRequiredField : null,
          ),
          const SizedBox(height: AppSpacing.xxl),
          Row(
            children: <Widget>[
              const Spacer(),
              FilledButton.icon(
                onPressed: _saving
                    ? null
                    : () async {
                        if (!(_formKey.currentState?.validate() ?? false)) return;
                        setState(() => _saving = true);
                        try {
                          await services.companySettings.update(<String, dynamic>{'name': _name.text.trim()});
                          if (context.mounted) setState(() => _reloadToken++);
                        } catch (error) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context)
                                .showSnackBar(SnackBar(content: Text('${l10n.saveFailed}: $error')));
                          }
                        } finally {
                          if (mounted) setState(() => _saving = false);
                        }
                      },
                icon: _saving
                    ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.save_outlined),
                label: Text(_saving ? l10n.actionSaving : l10n.actionSave),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class CategoriesView extends ConsumerStatefulWidget {
  const CategoriesView({super.key});

  @override
  ConsumerState<CategoriesView> createState() => _CategoriesViewState();
}

class _CategoriesViewState extends ConsumerState<CategoriesView> {
  int _reloadToken = 0;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = appLocalizationsOf(context);
    final AppServices services = _moreServicesOf(context, ref);
    return AppPage(
      maxWidth: 860,
      header: AppPageHeader(
        title: l10n.settingsCategories,
        showFilterToolbar: false,
        leading: IconButton(
          onPressed: () => context.go('/settings'),
          icon: const Icon(Icons.arrow_back),
          tooltip: l10n.actionBack,
        ),
        actions: _morePrimaryAction(
          context,
          l10n.actionCreateCategory,
          Icons.add,
          () => unawaited(_create(context, services)),
        ),
      ),
      child: FutureBuilder<List<Kategorie>>(
        key: ValueKey<String>('categories_$_reloadToken'),
        future: services.categoryWorkspace.list(),
        builder: (BuildContext context, AsyncSnapshot<List<Kategorie>> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return MasterDataErrorView(onRetry: () => setState(() => _reloadToken++));
          }
          final List<Kategorie> rows = snapshot.data!;
          if (rows.isEmpty) {
            return MasterDataEmptyView(
              icon: Icons.category_outlined,
              createLabel: l10n.actionCreateCategory,
              onCreate: () => unawaited(_create(context, services)),
            );
          }
          return AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: <Widget>[
                for (int index = 0; index < rows.length; index++) ...<Widget>[
                  Material(
                    type: MaterialType.transparency,
                    child: ListTile(
                      title: Text(rows[index].bezeichnung),
                      subtitle: Text(rows[index].beschreibung ?? ''),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: l10n.actionDelete,
                        onPressed: () => unawaited(_delete(context, services, rows[index].id)),
                      ),
                    ),
                  ),
                  if (index < rows.length - 1) const Divider(height: 1, indent: 72),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _create(BuildContext context, AppServices services) async {
    final AppLocalizations l10n = appLocalizationsOf(context);
    final TextEditingController controller = TextEditingController();
    final String? name = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(l10n.actionCreateCategory),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(labelText: l10n.formName),
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: Text(l10n.actionCancel)),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()),
            child: Text(l10n.actionCreate),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty || !context.mounted) return;
    try {
      await services.categoryWorkspace.create(bezeichnung: name);
      if (mounted) setState(() => _reloadToken++);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${l10n.saveFailed}: $error')));
      }
    }
  }

  Future<void> _delete(BuildContext context, AppServices services, int id) async {
    final AppLocalizations l10n = appLocalizationsOf(context);
    try {
      await services.categoryWorkspace.delete(id);
      if (mounted) setState(() => _reloadToken++);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${l10n.saveFailed}: $error')));
      }
    }
  }
}

class BankAccountsView extends ConsumerStatefulWidget {
  const BankAccountsView({super.key});

  @override
  ConsumerState<BankAccountsView> createState() => _BankAccountsViewState();
}

class _BankAccountsViewState extends ConsumerState<BankAccountsView> {
  int _reloadToken = 0;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = appLocalizationsOf(context);
    final AppServices services = _moreServicesOf(context, ref);
    return AppPage(
      maxWidth: 860,
      header: AppPageHeader(
        title: l10n.settingsAccounts,
        showFilterToolbar: false,
        leading: IconButton(
          onPressed: () => context.go('/settings'),
          icon: const Icon(Icons.arrow_back),
          tooltip: l10n.actionBack,
        ),
        actions: _morePrimaryAction(
          context,
          l10n.actionCreateAccount,
          Icons.add,
          () => unawaited(_create(context, services)),
        ),
      ),
      child: FutureBuilder<List<BankAccount>>(
        key: ValueKey<String>('accounts_$_reloadToken'),
        future: services.bankAccounts.list(),
        builder: (BuildContext context, AsyncSnapshot<List<BankAccount>> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return MasterDataErrorView(onRetry: () => setState(() => _reloadToken++));
          }
          final List<BankAccount> rows = snapshot.data!;
          if (rows.isEmpty) {
            return MasterDataEmptyView(
              icon: Icons.account_balance_outlined,
              createLabel: l10n.actionCreateAccount,
              onCreate: () => unawaited(_create(context, services)),
            );
          }
          return AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: <Widget>[
                for (int index = 0; index < rows.length; index++) ...<Widget>[
                  Material(
                    type: MaterialType.transparency,
                    child: ListTile(
                      title: Text(rows[index].name),
                      subtitle: Text(rows[index].iban ?? ''),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: l10n.actionDelete,
                        onPressed: () => unawaited(_delete(context, services, rows[index].id)),
                      ),
                    ),
                  ),
                  if (index < rows.length - 1) const Divider(height: 1, indent: 72),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _create(BuildContext context, AppServices services) async {
    final AppLocalizations l10n = appLocalizationsOf(context);
    final TextEditingController name = TextEditingController();
    final TextEditingController iban = TextEditingController();
    final bool? saved = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(l10n.actionCreateAccount),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: name,
              decoration: InputDecoration(labelText: l10n.formName),
            ),
            TextField(
              controller: iban,
              decoration: InputDecoration(labelText: l10n.formIban),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text(l10n.actionCancel)),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: Text(l10n.actionCreate)),
        ],
      ),
    );
    final String accountName = name.text.trim();
    final String accountIban = iban.text.trim();
    name.dispose();
    iban.dispose();
    if (saved != true || accountName.isEmpty || !context.mounted) return;
    try {
      await services.bankAccounts.create(name: accountName, iban: accountIban.isEmpty ? null : accountIban);
      if (mounted) setState(() => _reloadToken++);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${l10n.saveFailed}: $error')));
      }
    }
  }

  Future<void> _delete(BuildContext context, AppServices services, int id) async {
    final AppLocalizations l10n = appLocalizationsOf(context);
    try {
      await services.bankAccounts.delete(id);
      if (mounted) setState(() => _reloadToken++);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${l10n.saveFailed}: $error')));
      }
    }
  }
}

class TaxRatesView extends ConsumerStatefulWidget {
  const TaxRatesView({super.key});

  @override
  ConsumerState<TaxRatesView> createState() => _TaxRatesViewState();
}

class _TaxRatesViewState extends ConsumerState<TaxRatesView> {
  int _reloadToken = 0;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = appLocalizationsOf(context);
    final AppServices services = _moreServicesOf(context, ref);
    return AppPage(
      maxWidth: 860,
      header: AppPageHeader(
        title: l10n.settingsTaxRates,
        showFilterToolbar: false,
        leading: IconButton(
          onPressed: () => context.go('/settings'),
          icon: const Icon(Icons.arrow_back),
          tooltip: l10n.actionBack,
        ),
        actions: _morePrimaryAction(
          context,
          l10n.actionCreateTaxRate,
          Icons.add,
          () => unawaited(_create(context, services)),
        ),
      ),
      child: FutureBuilder<List<TaxRate>>(
        key: ValueKey<String>('taxrates_$_reloadToken'),
        future: services.taxRates.list(),
        builder: (BuildContext context, AsyncSnapshot<List<TaxRate>> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return MasterDataErrorView(onRetry: () => setState(() => _reloadToken++));
          }
          final List<TaxRate> rows = snapshot.data!;
          if (rows.isEmpty) {
            return MasterDataEmptyView(
              icon: Icons.percent,
              createLabel: l10n.actionCreateTaxRate,
              onCreate: () => unawaited(_create(context, services)),
            );
          }
          return AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: <Widget>[
                for (int index = 0; index < rows.length; index++) ...<Widget>[
                  Material(
                    type: MaterialType.transparency,
                    child: ListTile(
                      title: Text(rows[index].bezeichnung),
                      subtitle: Text('${rows[index].satz} %'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: l10n.actionDelete,
                        onPressed: () => unawaited(_delete(context, services, rows[index].id)),
                      ),
                    ),
                  ),
                  if (index < rows.length - 1) const Divider(height: 1, indent: 72),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _create(BuildContext context, AppServices services) async {
    final AppLocalizations l10n = appLocalizationsOf(context);
    final TextEditingController name = TextEditingController();
    final TextEditingController rate = TextEditingController();
    final bool? saved = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(l10n.actionCreateTaxRate),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: name,
              decoration: InputDecoration(labelText: l10n.formName),
            ),
            TextField(
              controller: rate,
              decoration: const InputDecoration(labelText: 'Satz %'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text(l10n.actionCancel)),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: Text(l10n.actionCreate)),
        ],
      ),
    );
    final String label = name.text.trim();
    final num? satz = num.tryParse(rate.text.trim().replaceAll(',', '.'));
    name.dispose();
    rate.dispose();
    if (saved != true || label.isEmpty || satz == null || !context.mounted) return;
    try {
      await services.taxRates.create(satz: satz, bezeichnung: label);
      if (mounted) setState(() => _reloadToken++);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${l10n.saveFailed}: $error')));
      }
    }
  }

  Future<void> _delete(BuildContext context, AppServices services, int id) async {
    final AppLocalizations l10n = appLocalizationsOf(context);
    try {
      await services.taxRates.delete(id);
      if (mounted) setState(() => _reloadToken++);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${l10n.saveFailed}: $error')));
      }
    }
  }
}

class NumberRangesView extends ConsumerStatefulWidget {
  const NumberRangesView({super.key});

  @override
  ConsumerState<NumberRangesView> createState() => _NumberRangesViewState();
}

class _NumberRangesViewState extends ConsumerState<NumberRangesView> {
  int _reloadToken = 0;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = appLocalizationsOf(context);
    final AppServices services = _moreServicesOf(context, ref);
    return AppPage(
      maxWidth: 860,
      header: AppPageHeader(
        title: l10n.settingsNumberRanges,
        showFilterToolbar: false,
        leading: IconButton(
          onPressed: () => context.go('/settings'),
          icon: const Icon(Icons.arrow_back),
          tooltip: l10n.actionBack,
        ),
      ),
      child: FutureBuilder<List<NumberRange>>(
        key: ValueKey<String>('ranges_$_reloadToken'),
        future: services.numberRanges.list(),
        builder: (BuildContext context, AsyncSnapshot<List<NumberRange>> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return MasterDataErrorView(onRetry: () => setState(() => _reloadToken++));
          }
          final List<NumberRange> rows = snapshot.data!;
          if (rows.isEmpty) {
            return MasterDataEmptyView(
              icon: Icons.format_list_numbered,
              createLabel: l10n.actionCreateNumberRange,
              onCreate: () => context.go('/settings'),
            );
          }
          return AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: <Widget>[
                for (int index = 0; index < rows.length; index++) ...<Widget>[
                  Material(
                    type: MaterialType.transparency,
                    child: ListTile(
                      title: Text(rows[index].typ),
                      subtitle: Text('${rows[index].format} · ${l10n.numberRangeNextLabel}: ${rows[index].nextNumber}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        tooltip: l10n.actionEdit,
                        onPressed: () => unawaited(_edit(context, services, rows[index])),
                      ),
                    ),
                  ),
                  if (index < rows.length - 1) const Divider(height: 1, indent: 72),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _edit(BuildContext context, AppServices services, NumberRange range) async {
    final AppLocalizations l10n = appLocalizationsOf(context);
    final TextEditingController next = TextEditingController(text: '${range.nextNumber}');
    final bool? saved = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(range.typ),
        content: TextField(
          controller: next,
          decoration: InputDecoration(labelText: l10n.numberRangeNextLabel),
          keyboardType: TextInputType.number,
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text(l10n.actionCancel)),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: Text(l10n.actionSave)),
        ],
      ),
    );
    final int? nextNumber = int.tryParse(next.text.trim());
    next.dispose();
    if (saved != true || nextNumber == null || !context.mounted) return;
    try {
      await services.numberRanges.update(range.typ, nextNumber);
      if (mounted) setState(() => _reloadToken++);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${l10n.saveFailed}: $error')));
      }
    }
  }
}

/// Grouped master-data section for the Settings page: company, categories,
/// accounts, tax rates, number ranges, and articles.
class MasterDataSettingsSection extends StatelessWidget {
  const MasterDataSettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = appLocalizationsOf(context);
    final List<({String title, IconData icon, String route})> entries = <({String title, IconData icon, String route})>[
      (title: l10n.settingsCompany, icon: Icons.business_outlined, route: '/settings/company'),
      (title: l10n.settingsCategories, icon: Icons.category_outlined, route: '/settings/categories'),
      (title: l10n.settingsAccounts, icon: Icons.account_balance_outlined, route: '/settings/accounts'),
      (title: l10n.settingsTaxRates, icon: Icons.percent, route: '/settings/tax-rates'),
      (title: l10n.settingsNumberRanges, icon: Icons.format_list_numbered, route: '/settings/number-ranges'),
      (title: l10n.routeArticles, icon: Icons.inventory_2_outlined, route: '/articles'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(l10n.settingsMasterData, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: <Widget>[
              for (int index = 0; index < entries.length; index++) ...<Widget>[
                Material(
                  type: MaterialType.transparency,
                  child: ListTile(
                    leading: Icon(entries[index].icon),
                    title: Text(entries[index].title),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.go(entries[index].route),
                  ),
                ),
                if (index < entries.length - 1) const Divider(height: 1, indent: 72),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
