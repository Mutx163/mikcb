part of '../timetable_settings_screen.dart';

/// 「首页与导航」二级页：从「外观」迁出的结构性设置（设置 IA 重构）。
///
/// 迁入条目：首页导航形态、玻璃坞内容布局与避让高度、日/周 Tab 开关、
/// 首页标题样式。本轮产品决策删除的条目不再出现：设置 Tab 开关、
/// 加号钮开关与圆钮功能选择、右上角菜单形态（homeMenuStyle）。
class _HomeNavigationSettingsScreen extends StatefulWidget {
  const _HomeNavigationSettingsScreen();

  @override
  State<_HomeNavigationSettingsScreen> createState() =>
      _HomeNavigationSettingsScreenState();
}

class _HomeNavigationSettingsScreenState
    extends State<_HomeNavigationSettingsScreen> {
  /// Visual groups on this page (not one card per control).
  /// 0 nav form · 1 dock tabs ＋ grid-menu customize · 2 home title · 3 reset.
  static const _homeNavigationSectionCount = 4;

  late final TimetableProvider _timetableProvider;
  late TimetableSettings _draft;
  Timer? _autoSaveTimer;
  Future<void> _saveQueue = Future<void>.value();

  @override
  void initState() {
    super.initState();
    _timetableProvider = context.read<TimetableProvider>();
    _draft = _timetableProvider.settings;
  }

  @override
  void dispose() {
    if (_autoSaveTimer?.isActive ?? false) {
      _autoSaveTimer?.cancel();
      _enqueuePersist(_draft);
    } else {
      _autoSaveTimer?.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return HyperosSubpage(
      onBack: () => Navigator.pop(context),
      title: Text(l10n.homeNavigationTitle),
      child: HyperosListView(
        itemCount: _homeNavigationSectionCount,
        itemBuilder: _buildHomeNavigationSection,
      ),
    );
  }

  Widget _buildHomeNavigationSection(BuildContext context, int index) {
    final l10n = AppLocalizations.of(context)!;
    final isGlassDock =
        _draft.homeNavigationForm == HomeNavigationForm.glassDock;

    return switch (index) {
      // 导航形态：经典 / 玻璃坞；玻璃坞下追加内容布局与避让高度。
      0 => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HyperosSettingsBlock(
            title: l10n.homeNavigationFormLabel,
            child: HyperosListGroup(
              children: [
                HyperosSelectTile<HomeNavigationForm>(
                  label: l10n.homeNavigationFormLabel,
                  subtitle: switch (_draft.homeNavigationForm) {
                    HomeNavigationForm.classic =>
                      l10n.homeNavigationFormClassicSubtitle,
                    HomeNavigationForm.glassDock =>
                      l10n.homeNavigationFormGlassDockSubtitle,
                  },
                  items: {
                    l10n.homeNavigationFormClassic: HomeNavigationForm.classic,
                    l10n.homeNavigationFormGlassDock:
                        HomeNavigationForm.glassDock,
                  },
                  value: _draft.homeNavigationForm,
                  onChanged: (value) {
                    _updateDraft(_draft.copyWith(homeNavigationForm: value));
                  },
                ),
                // 玻璃坞已固定满屏悬浮（93bed6b 移除「内容避让」布局），
                // 布局选择与避让高度设置随之不存在。
              ],
            ),
          ),
        ],
      ),
      // 底栏（仅玻璃坞）：最多 5 个按钮自由编排（含 日/周 视图切换与
      // 目录全部条目）；＋ 右上角「⋮」八宫格菜单自定义入口（常显）。
      1 => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isGlassDock) ...[
            const HyperosSectionGap(),
            HyperosSettingsBlock(
              title: l10n.glassDockCustomizeSectionTitle,
              child: HyperosListGroup(
                children: [
                  HyperosListTile(
                    title: l10n.glassDockCustomizeTitle,
                    details: l10n.homeGridCustomizeDetails(
                      resolveGlassDockActionIds(_draft).length,
                      HomeDockMenu.maxSlots,
                    ),
                    onTap: () async {
                      await HyperosNavigation.push(
                        context,
                        settings: const RouteSettings(
                          name: '/settings/glass-dock',
                        ),
                        builder: (_) => _GlassDockEditorScreen(
                          initialIds: resolveGlassDockActionIds(_draft),
                          onChanged: (ids) {
                            _updateDraft(
                              _draft.copyWith(glassDockActions: ids),
                            );
                          },
                        ),
                      );
                      if (!mounted) return;
                      setState(() {
                        _draft = context.read<TimetableProvider>().settings;
                      });
                    },
                  ),
                  HyperosSelectTile<String>(
                    label: l10n.glassDockRoundActionLabel,
                    items: {
                      l10n.homeMenuAddCourseTitle: 'addCourse',
                      for (final entry in kHomeMenuCatalog)
                        if (entry.visible()) entry.title(l10n): entry.id,
                    },
                    value: _draft.glassDockButtonEntryId.isEmpty
                        ? 'addCourse'
                        : _draft.glassDockButtonEntryId,
                    onChanged: (value) {
                      _updateDraft(
                        _draft.copyWith(glassDockButtonEntryId: value),
                      );
                    },
                  ),
                  HyperosListTile(
                    title: l10n.glassDockButtonIconTitle,
                    details:
                        _draft.glassDockButtonIconName ??
                        l10n.glassDockButtonIconDefault,
                    onTap: () async {
                      await HyperosNavigation.push(
                        context,
                        settings: const RouteSettings(
                          name: '/settings/glass-dock-icon',
                        ),
                        builder: (_) => _GlassDockIconPickerScreen(
                          initialName: _draft.glassDockButtonIconName,
                          onChanged: (name) {
                            _updateDraft(
                              _draft.copyWith(glassDockButtonIconName: name),
                            );
                          },
                        ),
                      );
                      if (!mounted) return;
                      setState(() {
                        _draft = context.read<TimetableProvider>().settings;
                      });
                    },
                  ),
                ],
              ),
            ),
          ],
          const HyperosSectionGap(),
          HyperosSettingsBlock(
            title: l10n.homeMenuCustomizeSectionTitle,
            child: HyperosListGroup(
              children: [
                HyperosListTile(
                  title: l10n.homeGridCustomizeTitle,
                  details: l10n.homeGridCustomizeDetails(
                    resolveHomeGridMenuEntries(_draft).length,
                    HomeGridMenu.maxSlots,
                  ),
                  onTap: () async {
                    await HyperosNavigation.push(
                      context,
                      settings: const RouteSettings(
                        name: '/settings/home-menu',
                      ),
                      builder: (_) => _HomeGridMenuEditorScreen(
                        initialIds: [
                          for (final entry in resolveHomeGridMenuEntries(
                            _draft,
                          ))
                            entry.id,
                        ],
                        onChanged: (ids) {
                          _updateDraft(
                            _draft.copyWith(homeGridMenuActions: ids),
                          );
                        },
                      ),
                    );
                    if (!mounted) return;
                    setState(() {
                      _draft = context.read<TimetableProvider>().settings;
                    });
                  },
                ),
              ],
            ),
          ),
        ],
      ),
      // 首页标题样式：预览 + 选择，自外观页原样迁入。
      2 => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const HyperosSectionGap(),
          HyperosSettingsBlock(
            title: l10n.homeTitleSectionTitle,
            child: HyperosListGroup(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: _HomeTitleStylePreview(style: _draft.homeTitleStyle),
                ),
                HyperosSelectTile<HomeTitleStyle>(
                  label: l10n.homeTitleStyleLabel,
                  items: {
                    for (final v in HomeTitleStyle.values)
                      homeTitleStyleLabel(l10n, v): v,
                  },
                  value: _draft.homeTitleStyle,
                  onChanged: (value) {
                    _updateDraft(_draft.copyWith(homeTitleStyle: value));
                  },
                ),
              ],
            ),
          ),
        ],
      ),
      3 => _SettingsResetTile(
        scope: SettingsResetScope.homeNavigation,
        onReset: _updateDraft,
      ),
      _ => const SizedBox.shrink(),
    };
  }

  void _updateDraft(TimetableSettings next, {bool debounce = false}) {
    setState(() {
      _draft = next;
    });
    _autoSaveTimer?.cancel();
    if (debounce) {
      _autoSaveTimer = Timer(
        const Duration(milliseconds: 250),
        () => _enqueuePersist(next),
      );
      return;
    }
    _enqueuePersist(next);
  }

  void _enqueuePersist(TimetableSettings next) {
    _saveQueue = _saveQueue.catchError((_) {}).then((_) => _persistDraft(next));
  }

  Future<void> _persistDraft(TimetableSettings next) async {
    if (next.liveMiuiIslandExpandedIconMode ==
            MiuiIslandExpandedIconMode.customImage &&
        (next.liveMiuiIslandExpandedIconPath == null ||
            next.liveMiuiIslandExpandedIconPath!.isEmpty)) {
      return;
    }
    // Use the cached provider — dispose may fire after the Element is unmounted.
    final provider = _timetableProvider;
    final message = await provider.updateTimetableSettings(next);
    if (!mounted) {
      return;
    }
    if (message != null) {
      showAppToast(context, message: message);
      setState(() {
        _draft = provider.settings;
      });
    }
  }
}
