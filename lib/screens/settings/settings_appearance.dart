part of '../timetable_settings_screen.dart';

class _AppearanceSettingsScreen extends StatefulWidget {
  const _AppearanceSettingsScreen();

  @override
  State<_AppearanceSettingsScreen> createState() =>
      _AppearanceSettingsScreenState();
}

class _AppearanceSettingsScreenState extends State<_AppearanceSettingsScreen> {
  /// Visual groups on this page (not one card per control).
  /// 0 preview · 1 appearance editor entry · 2 app display ·
  /// 3 theme manage + seed · 4 reset.
  ///
  /// 页面背景、壁纸与背景区域已移到「课表页面」，统一课卡颜色已移到
  /// 「课程卡片」：它们染的不是应用，而是课表页和课卡。导航形态 /
  /// 玻璃坞 / 首页标题等结构性设置已迁到「首页与导航」。
  ///
  /// 材质（质感方案 / 玻璃模式 / 高斯滑杆 / 高级材质入口 / 首页顶栏
  /// 材质 / 子页顶栏风格 / 各表面材质地图）2026-09-19 迁「课表页面」、同日
  /// 第五轮再并入「外观编辑」页的材质面板——预览区就是微缩首页本身。
  static const _appearanceSectionCount = 5;

  late final TimetableProvider _timetableProvider;
  late TimetableSettings _draft;
  Timer? _autoSaveTimer;
  Future<void> _saveQueue = Future<void>.value();

  @override
  void initState() {
    super.initState();
    _timetableProvider = context.read<TimetableProvider>();
    _draft = _timetableProvider.settings;
    // 订阅 provider：主题管理页/撤销等其他入口直接改 provider.settings 时，
    // 本页草稿立即跟随，避免本页 snapshot 在 dispose 时把旧主题整体回写
    // （曾导致「主题管理页切换主题无效且与外面不同步」）。
    _timetableProvider.addListener(_onTimetableChanged);
  }

  /// 「字体选择」弹层首帧要为每个候选字族做一次系统字体解析 + 文本布局（真机
  /// 实测主线程 38.7~188ms 的尖峰）。在本页打开后按帧摊开预热掉，见
  /// [prewarmAppFontSpecs]。
  ///
  /// 放在 didChangeDependencies 而不是 initState：样例句走 l10n（弹层里渲染的
  /// 也是本地化文字），而 initState 里还读不到 [AppLocalizations]。
  bool _fontPrewarmStarted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_fontPrewarmStarted) {
      return;
    }
    _fontPrewarmStarted = true;
    prewarmAppFontSpecs(AppLocalizations.of(context)!.fontPreviewSample);
  }

  void _onTimetableChanged() {
    if (!mounted) return;
    setState(() {
      _draft = _timetableProvider.settings;
    });
  }

  @override
  void dispose() {
    _timetableProvider.removeListener(_onTimetableChanged);
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
                                style: const TextStyle(color: Colors.white70),
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
      // 「外观编辑」的**固定入口**（2026-09-22 用户要求）。
      //
      // 此前这一页没有任何进编辑页的路（「课表页面」页里那条是按「看着材质改」
      // 的场景放的）；而首页右上角菜单里那条目是用户自己配的八宫格，挪掉或
      // 换掉就找不回来。这里给一条不以用户配置为前提的入口，紧跟「预览」——
      // 两者说的是同一件事：上面的预览区是抽象色块，编辑页才是整页微缩图。
      //
      // 入口行只留标题，不挂行尾那句灰字描述（用户 2026-09-22：「灰字描述，
      // 不符合软件标准，去掉」）。「课表页面」页那条同名入口还带着旧的那句，
      // 属另一处，不在本次范围内。
      //
      // 不走 zoom 转场：那条是「从首页那颗按钮进来、首页整页缩进新页」专用
      // （[HyperosZoomPageRoute] 的动力来自首页自己的快照）。从设置页进来时
      // 首页在路由栈底下压着、没有可缩的对象，走通用推页。
      1 => HyperosListGroup(
        children: [
          HyperosListTile(
            title: l10n.appearanceEditorTitle,
            onTap: () {
              HyperosNavigation.push(
                context,
                settings: const RouteSettings(
                  name: '/settings/appearance-editor',
                ),
                builder: (_) => const _AppearanceEditorScreen(),
              );
            },
          ),
        ],
      ),
      // 主题 / 字体 — 应用级外观（语言与转场已迁到「通用」，导航形态与
      // 首页标题已迁到「首页与导航」）。本组原是页面中段唯一无标题的裸组，
      // 与后续分组样式不一致（IA 规范 §3「不许无名分组」），补齐区块标题。
      2 => HyperosSettingsBlock(
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
            // 全局字重 / 字号：对齐 Hyper-PiliPlus 的连续滑杆（w100–w900、
            // 0.85–1.6），默认 w400 / 1.0 时不覆盖 Theme 与系统 textScaler。
            HyperosSliderTile(
              title: l10n.fontWeightLabel,
              value: _draft.appFontWeight.toDouble(),
              min: kAppFontWeightMin.toDouble(),
              max: kAppFontWeightMax.toDouble(),
              divisions: kAppFontWeightDivisions,
              valueLabel: 'w${_draft.appFontWeight}',
              onChanged: (value) {
                _updateDraft(
                  _draft.copyWith(appFontWeight: value.toInt()),
                  debounce: true,
                );
              },
            ),
            HyperosSliderTile(
              title: l10n.fontSizeLabel,
              value: _draft.appTextScale,
              min: kAppTextScaleMin,
              max: kAppTextScaleMax,
              divisions: kAppTextScaleDivisions,
              valueLabel: _draft.appTextScale == kAppTextScaleDefault
                  ? l10n.fontSizeDefault
                  : _draft.appTextScale.toStringAsFixed(2),
              onChanged: (value) {
                _updateDraft(
                  _draft.copyWith(appTextScale: normalizeAppTextScale(value)),
                  debounce: true,
                );
              },
            ),
            // 实时预览：所见即所得地反馈字体族 + 字重 + 字号。
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Container(
                decoration: BoxDecoration(
                  color: HyperosColors.surfaceContainer(
                    context,
                  ).withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(12),
                width: double.infinity,
                child: Text(
                  l10n.fontPreviewSample,
                  style: _draft.appFontMode.fontSpec.applyTo(
                    TextStyle(
                      fontSize: 16 * _draft.appTextScale,
                      fontWeight: FontWeight(_draft.appFontWeight),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      // 主题管理并入主题色卡，避免单行孤岛。（首页标题分区已迁到
      // 「首页与导航」，含预览与样式选择。）
      3 => HyperosSettingsBlock(
        title: l10n.themeSeedSectionTitle,
        child: HyperosListGroup(
          children: [
            HyperosListTile(
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
                for (final v in ForuiTheme.values) foruiThemeLabel(l10n, v): v,
              },
              // 弹窗每项：色圆点 + 名称（小米风格选择器）。
              itemPrefixBuilder: (ForuiTheme v) =>
                  HyperosColorDot(color: _colorFromHex(v.seedHex)),
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
      4 => _SettingsResetTile(
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
                title: l10n.themeExport,
                onTap: () => _exportTheme(context),
                showDivider: true,
              ),
              HyperosActionTile(
                title: l10n.themeImport,
                onTap: () => _importTheme(context),
                showDivider: true,
              ),
              HyperosActionTile(
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
          const themes = ForuiTheme.values;
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
                      title: foruiThemeLabel(l10n, themes[i]),
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
    final name = foruiThemeLabel(l10n, theme);
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
        throw const FormatException('missing required fields');
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
          children: [
            Text(
              AppLocalizations.of(context)!.appTitle,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w400,
                height: 1,
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
      child: Align(child: child),
    );
  }
}

/// 「各表面当前材质」的展示文案。渐进 / 高斯、磨砂 / 液态复用既有选项名
/// （同物同名），只补「已关闭 / 实体 / 磨砂玻璃」三个状态词。
String _surfaceMaterialLabel(AppLocalizations l10n, SurfaceMaterial material) =>
    switch (material) {
      SurfaceMaterial.off => l10n.materialStateOff,
      SurfaceMaterial.solid => l10n.materialStateSolid,
      SurfaceMaterial.frost => l10n.materialStateFrost,
      SurfaceMaterial.frostProgressive => l10n.headerBlurStyleInspire,
      SurfaceMaterial.frostGaussian => l10n.headerBlurStyleGaussian,
      SurfaceMaterial.liquidGlass => l10n.frostedGlassModeLiquid,
    };

/// Public factory for debug deep-link navigation (debug builds only).
