part of '../timetable_settings_screen.dart';

class _AppearanceSettingsScreen extends StatefulWidget {
  const _AppearanceSettingsScreen();

  @override
  State<_AppearanceSettingsScreen> createState() =>
      _AppearanceSettingsScreenState();
}

class _AppearanceSettingsScreenState extends State<_AppearanceSettingsScreen> {
  /// Visual groups on this page (not one card per control).
  /// 0 preview · 1 app display · 2 theme manage + seed · 3 frosted · 4 reset.
  ///
  /// 页面背景、壁纸与背景区域已移到「课表页面」，统一课卡颜色已移到
  /// 「课程卡片」：它们染的不是应用，而是课表页和课卡。导航形态 /
  /// 玻璃坞 / 首页标题等结构性设置已迁到「首页与导航」。
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
      // 主题 / 字体 — 应用级外观（语言与转场已迁到「通用」，导航形态与
      // 首页标题已迁到「首页与导航」）。本组原是页面中段唯一无标题的裸组，
      // 与后续分组样式不一致（IA 规范 §3「不许无名分组」），补齐区块标题。
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
      2 => HyperosSettingsBlock(
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
      3 => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          HyperosSettingsBlock(
            title: l10n.frostedSheetSectionTitle,
            child: HyperosListGroup(
              children: [
                // 「质感方案」：一键写穿一组推荐的材质搭配（2026-09-12）。
                // 纯增量层——只改既有字段、不锁定、不落盘新字段：当前命中
                // 哪个方案由 texturePresetOf 派生，应用后手动改任何一项即
                // 回落「自定义」。写穿前经确认弹层说明覆盖范围。
                HyperosSelectTile<TexturePreset?>(
                  label: l10n.texturePresetLabel,
                  subtitle: l10n.texturePresetSubtitle,
                  items: {
                    l10n.texturePresetClassicFrost: TexturePreset.classicFrost,
                    l10n.texturePresetFullLiquid: TexturePreset.fullLiquid,
                    l10n.texturePresetSoftMist: TexturePreset.softMist,
                    l10n.texturePresetMinimalSolid: TexturePreset.minimalSolid,
                    l10n.texturePresetCustom: null,
                  },
                  value: texturePresetOf(_draft),
                  onChanged: (preset) {
                    if (preset == null) return;
                    _applyTexturePreset(preset);
                  },
                ),
                // 玻璃模式三档，与引导页「视觉效果」同一映射（见
                // [glassModeChoiceOf] / [applyGlassModeChoice]）：此前
                // 经典磨砂/高斯模糊/半透明三档渲染链路完全相同，只有
                // 「高斯模糊」多露出两个滑杆，四个名字里三个长一个样，
                // 用户无从选起；独立的「启用模糊」开关并入「实体卡片」。
                HyperosSelectTile<GlassModeChoice>(
                  label: l10n.frostedGlassModeLabel,
                  items: {
                    l10n.frostedGlassModeSolid: GlassModeChoice.solid,
                    l10n.frostedGlassModeGaussian: GlassModeChoice.gaussian,
                    l10n.frostedGlassModeSoft: GlassModeChoice.softGlass,
                    l10n.frostedGlassModeLiquid: GlassModeChoice.liquidGlass,
                  },
                  value: glassModeChoiceOf(_draft),
                  onChanged: (value) {
                    _updateDraft(applyGlassModeChoice(_draft, value));
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
                    softGlassTuning:
                        _draft.softGlassTuning ?? SoftGlassTuning.defaults,
                    onOpenDemoSheet: () =>
                        showFrostedSheetSettingsDemo(context),
                  ),
                ),
                // 高级材质（柔光 / 液态）才需要进一步调校：液态有折射
                // 参数，两者共用同一组「作用范围」开关。
                if (isAdvancedGlassMode(_draft.frostedGlassMode))
                  HyperosListTile(
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
                // 高斯模糊档(开模糊 + 非液态)露出强度/亮度滑杆。按
                // 「开模糊且非液态/非柔光」判定而非 == gaussian：存量
                // frosted 默认档用户现在同样落在这一档，需要能看到滑杆。
                if (_draft.frostedBlurEnabled &&
                    _draft.frostedGlassMode != FrostedGlassMode.liquidGlass &&
                    _draft.frostedGlassMode != FrostedGlassMode.softGlass) ...[
                  HyperosSliderTile(
                    title: l10n.frostedSheetBlurLabel,
                    value: _draft.frostedSheetBlurSigma,
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
                    max: 0.75,
                    divisions: 75,
                    valueLabel:
                        '${(_draft.frostedSheetTintAlpha * 100).round()}%',
                    onChanged: (value) {
                      _updateDraft(
                        _draft.copyWith(frostedSheetTintAlpha: value),
                        debounce: true,
                      );
                    },
                  ),
                ],
                // 顶栏模糊风格两行（渐进 / 高斯）从「课表页面」迁入：材质
                // 选择归外观页，课表页面只留顶栏玻璃显示开关。两行恒常
                // 显示，不做任何条件隐藏（用户 2026-09-12 拍板：选项永远
                // 留在页面上）。磨砂与柔光下改了立即生效（柔光下风格决定
                // 雾面模糊的衰减形态）；全局液态 + 作用范围开时顶栏跟随
                // 液态而不看风格，只记住选择，切回即恢复，由提示语说明。
                HyperosSelectTile<HeaderBlurStyle>(
                  label: l10n.headerBlurStyleLabel,
                  subtitle: l10n.headerBlurStyleSubtitle,
                  items: {
                    l10n.headerBlurStyleInspire: HeaderBlurStyle.inspire,
                    l10n.headerBlurStyleGaussian: HeaderBlurStyle.gaussian,
                  },
                  value: _draft.headerBlurStyle,
                  onChanged: (value) {
                    _updateDraft(applyChromeBlurStyle(_draft, value));
                  },
                ),
                // 子页顶栏（设置等页）与首页玻璃带相互独立，各选各的风格。
                HyperosSelectTile<HeaderBlurStyle>(
                  label: l10n.subpageHeaderBlurStyleLabel,
                  items: {
                    l10n.headerBlurStyleInspire: HeaderBlurStyle.inspire,
                    l10n.headerBlurStyleGaussian: HeaderBlurStyle.gaussian,
                  },
                  value: _draft.subpageHeaderBlurStyle,
                  onChanged: (value) {
                    _updateDraft(applySubpageChromeBlurStyle(_draft, value));
                  },
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Text(
                    l10n.headerBlurStyleHint,
                    style: HyperosTypography.sectionDescription(context),
                  ),
                ),
              ],
            ),
          ),
          // 「各表面当前材质」地图：与渲染侧门控同口径的只读推导（2026-
          // 09-12），回答「哪个表面现在是什么材质、为什么」。行名复用作用
          // 范围开关的既有文案（同物同名），不含依设备实时状态定的系统降级。
          HyperosSettingsBlock(
            title: l10n.surfaceMaterialSectionTitle,
            child: HyperosListGroup(
              children: [
                _surfaceMaterialTile(
                  l10n.liquidGlassScopeHomeChromeTitle,
                  homeBandSurfaceMaterial(_draft),
                ),
                _surfaceMaterialTile(
                  l10n.surfaceSubpageHeader,
                  subpageHeaderSurfaceMaterial(_draft),
                ),
                _surfaceMaterialTile(
                  l10n.liquidGlassScopeDockTitle,
                  dockSurfaceMaterial(_draft),
                ),
                _surfaceMaterialTile(
                  l10n.liquidGlassScopeSheetDialogTitle,
                  sheetDialogSurfaceMaterial(_draft),
                ),
                _surfaceMaterialTile(
                  l10n.liquidGlassScopeSelectSheetTitle,
                  selectSheetSurfaceMaterial(_draft),
                ),
                _surfaceMaterialTile(
                  l10n.liquidGlassScopePopupTitle,
                  popupSurfaceMaterial(_draft),
                ),
                _surfaceMaterialTile(
                  l10n.liquidGlassScopePickerButtonsTitle,
                  pickerButtonsSurfaceMaterial(_draft),
                ),
                _surfaceMaterialTile(
                  l10n.surfaceCourseCard,
                  courseCardSurfaceMaterial(_draft),
                ),
              ],
            ),
          ),
        ],
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

  /// 「各表面当前材质」地图的只读行：左表面名（主题墨色）、右材质值（次级
  /// 墨色）。不用 [HyperosListTile]——它的 details 只在可点行渲染，纯展示
  /// 行会把标题打到 45% 透明度且不画值（2026-09-12 真机灰色卡回归）。
  Widget _surfaceMaterialTile(String title, SurfaceMaterial material) {
    final l10n = AppLocalizations.of(context)!;
    return hyperosListRowShell(
      padding: hyperosRowPadding(context),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: HyperosTypography.listTitle(context),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: HyperosTokens.rowContentGap),
          Text(
            _surfaceMaterialLabel(l10n, material),
            style: HyperosTypography.listDetail(context).copyWith(
              color: HyperosColors.secondaryText(context),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _applyTexturePreset(TexturePreset preset) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showHyperosConfirmDialog(
      context: context,
      title: l10n.texturePresetApplyTitle,
      message: l10n.texturePresetApplyBody,
      cancelLabel: l10n.cancelAction,
      confirmLabel: l10n.confirmAction,
    );
    if (confirmed != true || !mounted) {
      return;
    }
    _updateDraft(applyTexturePreset(_draft, preset));
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

/// 「各表面当前材质」的展示文案。渐进 / 高斯、柔光 / 液态复用既有选项名
/// （同物同名），只补「已关闭 / 实体 / 磨砂玻璃」三个状态词。
String _surfaceMaterialLabel(AppLocalizations l10n, SurfaceMaterial material) =>
    switch (material) {
      SurfaceMaterial.off => l10n.materialStateOff,
      SurfaceMaterial.solid => l10n.materialStateSolid,
      SurfaceMaterial.frost => l10n.materialStateFrost,
      SurfaceMaterial.frostProgressive => l10n.headerBlurStyleInspire,
      SurfaceMaterial.frostGaussian => l10n.headerBlurStyleGaussian,
      SurfaceMaterial.softGlass => l10n.frostedGlassModeSoft,
      SurfaceMaterial.liquidGlass => l10n.frostedGlassModeLiquid,
    };

/// Public factory for debug deep-link navigation (debug builds only).
