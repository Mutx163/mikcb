part of '../timetable_settings_screen.dart';

class _AppearanceSettingsScreen extends StatefulWidget {
  const _AppearanceSettingsScreen();

  @override
  State<_AppearanceSettingsScreen> createState() =>
      _AppearanceSettingsScreenState();
}

class _AppearanceSettingsScreenState extends State<_AppearanceSettingsScreen> {
  /// Visual groups on this page (not one card per control).
  /// 0 preview · 1 app display · 2 home title · 3 theme manage + seed · 4 frosted.
  ///
  /// 页面背景、壁纸与背景区域已移到「课表页面」，统一课卡颜色已移到
  /// 「课程卡片」：它们染的不是应用，而是课表页和课卡。
  static const _appearanceSectionCount = 6;

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

    return FrostedAppearanceScope(
      appearance: _draft.frostedAppearance,
      child: HyperosSubpage(
        onBack: () => Navigator.pop(context),
        title: Text(l10n.appearanceTitle),
        child: HyperosListView(
          itemCount: _appearanceSectionCount,
          itemBuilder: _buildAppearanceSection,
        ),
      ),
    );
  }

  Widget _buildAppearanceSection(BuildContext context, int index) {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.watch<TimetableProvider>();
    final themePreviewColor = _colorFromHex(_draft.themeSeedColor);
    final isDarkPreview = Theme.of(context).brightness == Brightness.dark;

    final Widget section = switch (index) {
      0 => HyperosCard(
        padding: EdgeInsets.zero,
        child: ColoredBox(
          color: isDarkPreview
              ? HyperosColors.surfaceContainerHighest(context)
              : HyperosColors.surface(context),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.previewTitle,
                  style: HyperosTypography.title(context),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: HyperosColors.surfaceContainer(
                      context,
                    ).withValues(alpha: 0.82),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 72,
                          decoration: BoxDecoration(
                            color: themePreviewColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                appThemeModeLabel(l10n, _draft.appThemeMode),
                                style: TextStyle(
                                  color: HyperosColors.onPrimary(context),
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              Text(
                                appFontModeLabel(l10n, _draft.appFontMode),
                                style: TextStyle(color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          height: 72,
                          decoration: BoxDecoration(
                            color: HyperosColors.surface(
                              context,
                            ).withValues(alpha: 0.72),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            l10n.frostedSheetSectionTitle,
                            style: HyperosTypography.listDetail(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      // 主题 / 字体 / 首页导航形态 — 应用级外观（语言与转场已迁到「通用」）。
      // 本组原是页面中段唯一无标题的裸组，与下方 2/3/4 组样式不一致
      // （IA 规范 §3「不许无名分组」），补齐区块标题。
      1 => HyperosSettingsBlock(
        title: l10n.appearanceThemeDisplaySectionTitle,
        child: HyperosListGroup(
          children: [
            HyperosSelectTile<AppThemeMode>(
              label: l10n.themeModeLabel,
              subtitle: l10n.displayModeSubtitle,
              items: {
                for (final v in AppThemeMode.values)
                  appThemeModeLabel(l10n, v): v,
              },
              value: _draft.appThemeMode,
              onChanged: (value) {
                _updateDraft(_draft.copyWith(appThemeMode: value));
              },
            ),
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
                l10n.homeNavigationFormGlassDock: HomeNavigationForm.glassDock,
              },
              value: _draft.homeNavigationForm,
              onChanged: (value) {
                _updateDraft(_draft.copyWith(homeNavigationForm: value));
              },
            ),
            // 右上角「更多」菜单形态：列表弹窗（当前设计）或八宫格瓷贴
            // （v2.0.5.5 已发布样式）。八宫格下追加按钮自定义入口。
            HyperosSelectTile<HomeMenuStyle>(
              label: l10n.homeMenuStyleLabel,
              subtitle: switch (_draft.homeMenuStyle) {
                HomeMenuStyle.list => l10n.homeMenuStyleListSubtitle,
                HomeMenuStyle.grid => l10n.homeMenuStyleGridSubtitle,
              },
              items: {
                l10n.homeMenuStyleList: HomeMenuStyle.list,
                l10n.homeMenuStyleGrid: HomeMenuStyle.grid,
              },
              value: _draft.homeMenuStyle,
              onChanged: (value) {
                _updateDraft(_draft.copyWith(homeMenuStyle: value));
              },
            ),
            if (_draft.homeMenuStyle == HomeMenuStyle.grid)
              HyperosListTile(
                icon: Icons.grid_view_outlined,
                iconAccent: HyperosIconColors.blue,
                title: l10n.homeGridCustomizeTitle,
                details: l10n.homeGridCustomizeDetails(
                  resolveHomeGridMenuActions(_draft).length,
                  HomeGridMenu.maxSlots,
                ),
                onTap: () async {
                  await HyperosNavigation.push(
                    context,
                    settings: const RouteSettings(name: '/settings/home-menu'),
                    builder: (_) => _HomeGridMenuEditorScreen(
                      initialActions: resolveHomeGridMenuActions(_draft),
                      onChanged: (actions) {
                        _updateDraft(
                          _draft.copyWith(
                            homeGridMenuActions: [
                              for (final action in actions) action.id,
                            ],
                          ),
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
            if (_draft.homeNavigationForm == HomeNavigationForm.glassDock)
              HyperosSelectTile<GlassDockLayout>(
                label: l10n.glassDockLayoutLabel,
                subtitle: switch (_draft.glassDockLayout) {
                  GlassDockLayout.overlay =>
                    l10n.glassDockLayoutOverlaySubtitle,
                  GlassDockLayout.inset => l10n.glassDockLayoutInsetSubtitle,
                },
                items: {
                  l10n.glassDockLayoutOverlay: GlassDockLayout.overlay,
                  l10n.glassDockLayoutInset: GlassDockLayout.inset,
                },
                value: _draft.glassDockLayout,
                onChanged: (value) {
                  _updateDraft(_draft.copyWith(glassDockLayout: value));
                },
              ),
            if (_draft.homeNavigationForm == HomeNavigationForm.glassDock &&
                _draft.glassDockLayout == GlassDockLayout.inset)
              HyperosSliderTile(
                title: l10n.glassDockInsetClearanceLabel,
                value: _draft.glassDockInsetClearance,
                min: glassDockInsetClearanceMin,
                max: glassDockInsetClearanceMax,
                divisions:
                    (glassDockInsetClearanceMax - glassDockInsetClearanceMin)
                        .round(),
                valueLabel:
                    '${_draft.glassDockInsetClearance.toStringAsFixed(0)}px',
                onChanged: (value) {
                  _updateDraft(
                    _draft.copyWith(glassDockInsetClearance: value),
                    debounce: true,
                  );
                },
              ),
            if (_draft.homeNavigationForm == HomeNavigationForm.glassDock) ...[
              // 底栏入口开关：日课表 / 设置两个 Tab 可分别隐藏；
              // 加号按钮是独立圆形入口（GlassTabBar 的 extraButton）。
              // 约束：至少保留一个 Tab 入口——关掉另一个时本开关锁定。
              HyperosSwitchTile(
                title: l10n.glassDockShowDayTabTitle,
                value: _draft.glassDockShowDayTab,
                onChanged: _draft.glassDockShowSettingsTab
                    ? (value) {
                        _updateDraft(
                          _draft.copyWith(glassDockShowDayTab: value),
                        );
                      }
                    : null,
              ),
              HyperosSwitchTile(
                title: l10n.glassDockShowSettingsTabTitle,
                value: _draft.glassDockShowSettingsTab,
                onChanged: _draft.glassDockShowDayTab
                    ? (value) {
                        _updateDraft(
                          _draft.copyWith(glassDockShowSettingsTab: value),
                        );
                      }
                    : null,
              ),
              HyperosSwitchTile(
                title: l10n.glassDockShowAddButtonTitle,
                subtitle: l10n.glassDockShowAddButtonSubtitle,
                value: _draft.glassDockShowAddButton,
                onChanged: (value) {
                  _updateDraft(_draft.copyWith(glassDockShowAddButton: value));
                },
              ),
            ],
            HyperosSelectTile<AppFontMode>(
              label: l10n.fontModeLabel,
              useSheetForPopup: true,
              items: {
                for (final v in AppFontMode.values)
                  appFontModeLabel(l10n, v): v,
              },
              value: _draft.appFontMode,
              onChanged: (value) {
                _updateDraft(_draft.copyWith(appFontMode: value));
              },
              itemTitleStyleBuilder: (mode) {
                final spec = mode.fontSpec;
                if (spec.fontFamily == null || spec.fontFamily!.isEmpty) {
                  return null;
                }
                return TextStyle(
                  fontFamily: spec.fontFamily,
                  fontFamilyFallback: spec.fontFamilyFallback,
                );
              },
            ),
          ],
        ),
      ),
      2 => HyperosSettingsBlock(
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
      // 主题管理并入主题色卡，避免单行孤岛。
      3 => HyperosSettingsBlock(
        title: l10n.themeSeedSectionTitle,
        child: HyperosListGroup(
          children: [
            HyperosListTile(
              icon: Icons.style_outlined,
              iconAccent: HyperosIconColors.purple,
              title: l10n.themeManageTitle,
              details: l10n.themeManageSubtitle,
              onTap: () {
                HyperosNavigation.push(
                  context,
                  settings: const RouteSettings(name: '/settings/theme'),
                  builder: (_) => const _ThemeManageScreen(),
                );
              },
            ),
            HyperosSelectTile<ForuiTheme>(
              label: l10n.themePreset,
              subtitle: l10n.themeSeedSectionSubtitle,
              items: {
                for (final v in ForuiTheme.values) _foruiThemeLabel(v): v,
              },
              value: _draft.foruiTheme,
              onChanged: (value) {
                _updateDraft(
                  _draft.copyWith(
                    foruiTheme: value,
                    themeSeedColor: value.seedHex,
                  ),
                );
              },
            ),
          ],
        ),
      ),
      4 => HyperosSettingsBlock(
        title: l10n.frostedSheetSectionTitle,
        child: HyperosListGroup(
          children: [
            HyperosSelectTile<FrostedGlassMode>(
              label: l10n.frostedGlassModeLabel,
              items: {
                for (final mode in FrostedGlassMode.values)
                  frostedGlassModeLabel(l10n, mode): mode,
              },
              value: _draft.frostedGlassMode,
              onChanged: (value) {
                _updateDraft(_draft.copyWith(frostedGlassMode: value));
              },
            ),
            HyperosSwitchTile(
              title: l10n.frostedBlurEnabledTitle,
              value: _draft.frostedBlurEnabled,
              onChanged: (value) {
                _updateDraft(_draft.copyWith(frostedBlurEnabled: value));
              },
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: FrostedSheetSettingsPreview(
                provider: provider,
                settings: _draft,
                week: provider.currentWeek,
                blurSigma: _draft.frostedSheetBlurSigma,
                tintAlpha: _draft.frostedSheetTintAlpha,
                barrierAlpha: _draft.frostedSheetBarrierAlpha,
                blurEnabled: _draft.frostedBlurEnabled,
                glassMode: _draft.frostedGlassMode,
                liquidGlassTuning: _draft.liquidGlassTuning,
                onOpenDemoSheet: () => showFrostedSheetSettingsDemo(context),
              ),
            ),
            if (_draft.frostedGlassMode == FrostedGlassMode.liquidGlass)
              HyperosListTile(
                icon: Icons.auto_awesome_outlined,
                iconAccent: HyperosIconColors.purple,
                title: l10n.advancedMaterialTitle,
                details: l10n.advancedMaterialEntrySubtitle,
                onTap: () async {
                  await HyperosNavigation.push(
                    context,
                    settings: const RouteSettings(
                      name: '/settings/advanced-material',
                    ),
                    builder: (_) => const AdvancedMaterialSettingsScreen(),
                  );
                  if (!mounted) return;
                  setState(() {
                    _draft = context.read<TimetableProvider>().settings;
                  });
                },
              ),
            if (_draft.frostedGlassMode == FrostedGlassMode.gaussian) ...[
              HyperosSliderTile(
                title: l10n.frostedSheetBlurLabel,
                value: _draft.frostedSheetBlurSigma,
                min: 0,
                max: 24,
                divisions: 24,
                valueLabel: _draft.frostedSheetBlurSigma.toStringAsFixed(0),
                onChanged: (value) {
                  _updateDraft(
                    _draft.copyWith(frostedSheetBlurSigma: value),
                    debounce: true,
                  );
                },
              ),
              HyperosSliderTile(
                title: l10n.frostedSheetTintLabel,
                value: _draft.frostedSheetTintAlpha,
                min: 0,
                max: 0.75,
                divisions: 75,
                valueLabel: '${(_draft.frostedSheetTintAlpha * 100).round()}%',
                onChanged: (value) {
                  _updateDraft(
                    _draft.copyWith(frostedSheetTintAlpha: value),
                    debounce: true,
                  );
                },
              ),
            ],
          ],
        ),
      ),
      5 => _SettingsResetTile(
        scope: SettingsResetScope.appearance,
        onReset: _updateDraft,
      ),
      _ => const SizedBox.shrink(),
    };

    if (index == 0) {
      return section;
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [const HyperosSectionGap(), section],
    );
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

String _foruiThemeLabel(ForuiTheme theme) {
  final name = theme.name;
  return name[0].toUpperCase() + name.substring(1);
}

Map<String, String> buildLocaleMenuMap(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  final seen = <String>{''};
  final map = <String, String>{l10n.languageModeSystem: ''};
  for (final locale in AppLocalizations.supportedLocales) {
    final tag = locale.countryCode?.isNotEmpty == true
        ? '${locale.languageCode}_${locale.countryCode}'
        : locale.languageCode;
    if (!seen.add(tag)) {
      continue;
    }
    map[nativeNameFor(locale)] = tag;
  }
  return map;
}

class _ThemeManageScreen extends StatefulWidget {
  const _ThemeManageScreen();

  @override
  State<_ThemeManageScreen> createState() => _ThemeManageScreenState();
}

class _ThemeManageScreenState extends State<_ThemeManageScreen> {
  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return HyperosSubpage(
      onBack: () => Navigator.pop(context),
      title: Text(l10n.themeManageTitle),
      child: HyperosListView(
        itemCount: _themeSectionCount,
        itemBuilder: _buildThemeSection,
      ),
    );
  }

  static const _themeSectionCount = 4;

  Widget _buildThemeSection(BuildContext context, int index) {
    final l10n = AppLocalizations.of(context)!;
    return switch (index) {
      0 => Consumer<TimetableProvider>(
        builder: (context, provider, child) {
          final settings = provider.settings;
          final checkpointName = settings.themeCheckpointName;
          final hasModifications = settings.hasThemeModifications;

          if (checkpointName == null) return const SizedBox.shrink();

          return HyperosControlCard(
            title: l10n.themeCurrentTheme,
            subtitle: hasModifications
                ? l10n.themeBasedOnModified(checkpointName)
                : checkpointName,
            child: hasModifications
                ? HyperosControlCardInset(
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        HyperosButton(
                          label: l10n.themeResetToPreset,
                          variant: HyperosButtonVariant.secondary,
                          onPressed: () {
                            if (settings.themeCheckpointConfig != null) {
                              _applyThemeWithUndo(
                                context,
                                settings.themeCheckpointConfig!,
                                themeName: checkpointName,
                              );
                            }
                          },
                        ),
                        HyperosButton(
                          label: l10n.themeSaveCurrent,
                          variant: HyperosButtonVariant.secondary,
                          onPressed: () => _showSaveThemeDialog(context),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          );
        },
      ),
      1 => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const HyperosSectionGap(),
          HyperosSectionLabel(text: l10n.themeManageSubtitle),
          HyperosChoiceGroup(
            children: [
              HyperosActionTile(
                icon: Icons.ios_share_outlined,
                title: l10n.themeExport,
                onTap: () => _exportTheme(context),
                showDivider: true,
              ),
              HyperosActionTile(
                icon: Icons.download_outlined,
                title: l10n.themeImport,
                onTap: () => _importTheme(context),
                showDivider: true,
              ),
              HyperosActionTile(
                icon: Icons.bookmark_add_outlined,
                title: l10n.themeSaveCurrent,
                onTap: () => _showSaveThemeDialog(context),
              ),
            ],
          ),
        ],
      ),
      2 => Consumer<TimetableProvider>(
        builder: (context, provider, child) {
          final current = provider.settings.foruiTheme;
          final themes = ForuiTheme.values;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const HyperosSectionGap(),
              HyperosSectionLabel(text: l10n.themePreset),
              HyperosChoiceGroup(
                children: [
                  for (var i = 0; i < themes.length; i++)
                    HyperosChoiceTile(
                      prefix: HyperosColorDot(
                        color: _colorFromHex(themes[i].seedHex),
                      ),
                      title: _foruiThemeLabel(themes[i]),
                      selected: current == themes[i],
                      showDivider: i < themes.length - 1,
                      onTap: () => _applyForuiTheme(context, themes[i]),
                    ),
                ],
              ),
            ],
          );
        },
      ),
      3 => Consumer<TimetableProvider>(
        builder: (context, provider, child) {
          final savedThemes = provider.settings.savedThemes;
          if (savedThemes.isEmpty) return const SizedBox.shrink();
          final settings = provider.settings;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const HyperosSectionGap(),
              HyperosSectionLabel(text: l10n.themeSaved),
              HyperosChoiceGroup(
                children: [
                  for (var i = 0; i < savedThemes.length; i++)
                    HyperosChoiceTile(
                      prefix: HyperosColorDot(
                        color: _colorFromHex(savedThemeSeedHex(savedThemes[i])),
                      ),
                      title: savedThemes[i].name,
                      subtitle: ThemePreviewDots(
                        colors: savedThemes[i].config.previewColors,
                      ),
                      selected: isSavedThemeSelected(settings, savedThemes[i]),
                      trailing: IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                        icon: Icon(
                          Icons.more_horiz_rounded,
                          color: HyperosColors.secondaryText(context),
                        ),
                        tooltip: l10n.themeMoreActions,
                        onPressed: () =>
                            _showSavedThemeActions(context, savedThemes[i]),
                      ),
                      showDivider: i < savedThemes.length - 1,
                      dividerIndent: 44,
                      onTap: () =>
                          _showSavedThemePreview(context, savedThemes[i]),
                    ),
                ],
              ),
            ],
          );
        },
      ),
      _ => const SizedBox.shrink(),
    };
  }

  // --- theme actions below ---

  Future<void> _showSavedThemePreview(BuildContext context, SavedTheme theme) {
    return showSavedThemePreviewSheet(
      context,
      name: theme.name,
      config: theme.config,
      onApply: () => _applySavedTheme(context, theme),
    );
  }

  Future<void> _showSavedThemeActions(BuildContext context, SavedTheme theme) {
    return showSavedThemeActionSheet(
      context,
      theme: theme,
      onRename: () => _showRenameDialog(context, theme),
      onDuplicate: () => _duplicateTheme(context, theme),
      onDelete: () => _deleteSavedTheme(context, theme),
    );
  }

  Future<bool> _applySavedTheme(BuildContext context, SavedTheme theme) async {
    final canApply = await confirmApplyThemeWithUnsavedCheck(
      context,
      onSaveRequested: () => _showSaveThemeDialog(context),
    );
    if (!canApply || !context.mounted) {
      return false;
    }
    _applyThemeWithUndo(context, theme.config, themeName: theme.name);
    return true;
  }

  Future<void> _deleteSavedTheme(BuildContext context, SavedTheme theme) async {
    final confirmed = await showThemeDeleteConfirmDialog(
      context,
      name: theme.name,
    );
    if (!confirmed || !context.mounted) {
      return;
    }
    context.read<TimetableProvider>().deleteTheme(theme.id);
  }

  void _applyThemeWithUndo(
    BuildContext context,
    ThemeConfig config, {
    String? themeName,
  }) {
    final provider = Provider.of<TimetableProvider>(context, listen: false);
    final l10n = AppLocalizations.of(context)!;

    final newSettings = config.applyToSettings(provider.settings);
    provider.applyThemeWithUndo(
      newSettings.copyWith(
        themeCheckpointName: themeName,
        themeCheckpointConfig: config,
      ),
      themeName: themeName,
    );

    showThemeFeedbackToast(
      context,
      message: l10n.themeChanged(themeName ?? l10n.themeManageTitle),
      onUndo: provider.undoThemeChange,
    );
  }

  void _applyForuiTheme(BuildContext context, ForuiTheme theme) {
    final provider = Provider.of<TimetableProvider>(context, listen: false);
    final l10n = AppLocalizations.of(context)!;
    final name = _foruiThemeLabel(theme);
    provider.applyThemeWithUndo(
      provider.settings.copyWith(
        foruiTheme: theme,
        themeSeedColor: theme.seedHex,
        clearThemeCheckpoint: true,
      ),
      themeName: name,
    );
    showThemeFeedbackToast(
      context,
      message: l10n.themeChanged(name),
      onUndo: provider.undoThemeChange,
    );
  }

  void _showSaveThemeDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showThemeNameDialog(
      context,
      title: l10n.themeSaveCurrent,
      initialName: '',
      onSubmit: (name) {
        final provider = Provider.of<TimetableProvider>(context, listen: false);
        final themeConfig = ThemeConfig.fromSettings(provider.settings);
        provider.saveTheme(name, themeConfig.toJson());
      },
    );
  }

  void _showRenameDialog(BuildContext context, SavedTheme theme) {
    final l10n = AppLocalizations.of(context)!;
    showThemeNameDialog(
      context,
      title: l10n.themeRename,
      initialName: theme.name,
      onSubmit: (newName) {
        context.read<TimetableProvider>().renameTheme(theme.id, newName);
      },
    );
  }

  void _duplicateTheme(BuildContext context, SavedTheme theme) {
    final l10n = AppLocalizations.of(context)!;
    final provider = Provider.of<TimetableProvider>(context, listen: false);
    provider.saveTheme(
      l10n.themeDuplicateCopyName(theme.name),
      theme.themeData,
    );
  }

  void _exportTheme(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = Provider.of<TimetableProvider>(context, listen: false);
    final themeConfig = ThemeConfig.fromSettings(provider.settings);
    Clipboard.setData(ClipboardData(text: jsonEncode(themeConfig.toJson())));
    showThemeFeedbackToast(
      context,
      message: l10n.themeExportSuccess,
      kind: AppToastKind.success,
    );
  }

  void _importTheme(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final data = await Clipboard.getData('text/plain');
    if (!context.mounted) return;
    if (data?.text == null) {
      showThemeFeedbackToast(
        context,
        message: l10n.themeImportFailed,
        kind: AppToastKind.error,
      );
      return;
    }
    try {
      final json = jsonDecode(data!.text!) as Map<String, dynamic>;
      final config = ThemeConfig.fromJson(json);

      if (config.version == 2 &&
          (config.seedColor == null ||
              config.courseCardTitleColorLight == null)) {
        throw FormatException('missing required fields');
      }

      _applyThemeWithUndo(context, config, themeName: l10n.themeImport);
    } catch (_) {
      if (context.mounted) {
        showThemeFeedbackToast(
          context,
          message: l10n.themeImportFailed,
          kind: AppToastKind.error,
        );
      }
    }
  }
}

class _HomeTitleStylePreview extends StatelessWidget {
  final HomeTitleStyle style;

  const _HomeTitleStylePreview({required this.style});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    Widget child;
    switch (style) {
      case HomeTitleStyle.classic:
        child = Text(
          AppLocalizations.of(context)!.appTitle,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w400,
          ),
        );
      case HomeTitleStyle.brand:
        child = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              AppLocalizations.of(context)!.appTitle,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w400,
                height: 1.0,
              ),
            ),
            Text(
              AppLocalizations.of(context)!.defaultTimetablePreviewName,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: HyperosColors.surfaceContainer(context).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Align(alignment: Alignment.center, child: child),
    );
  }
}

/// Public factory for debug deep-link navigation (debug builds only).
