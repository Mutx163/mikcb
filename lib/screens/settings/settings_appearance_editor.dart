part of '../timetable_settings_screen.dart';

/// 「外观编辑」页：**整页就是一张首页微缩图**，底部两颗按钮进弹窗改东西。
///
/// 用户口径（2026-09-19）：
/// * 微缩预览是「把整个首页原样缩小」，用一样的代码，保证观感一致；
/// * 可日 / 周视图切换，按钮放顶部；
/// * 顶部完成 / 取消；底部「调整壁纸」「材质」两个入口。
///
/// 实现取巧的地方只有一处：微缩用的是 [TimetableWeekPreview] —— 它本来就是
/// 首页那套「壁纸 + 连续玻璃带 + 星期栏 + 网格 + 课程卡」的**同一份渲染代码**
/// 缩到给定框里（设置页的课表预览、分享图都用它），所以材质、色调、玻璃形态
/// 与首页逐字同源。日视图预览是这套网格收成一天（见
/// [TimetableWeekPreview.onlyDayOfWeek]），**不是**首页那种「摘要卡 + 议程列表」
/// 的日视图 —— 那一套还长在 `timetable_screen` 里没抽出来。
///
/// 编辑语义：本页与别的设置页一样**即时落盘**（弹窗里改一下预览就变），
/// 「取消」= 用进页时的那份设置回滚，「完成」= 保留并返回。
class _AppearanceEditorScreen extends StatefulWidget {
  const _AppearanceEditorScreen();

  @override
  State<_AppearanceEditorScreen> createState() =>
      _AppearanceEditorScreenState();
}

class _AppearanceEditorScreenState extends State<_AppearanceEditorScreen>
    with _HomeBackdropFlow<_AppearanceEditorScreen> {
  late final TimetableProvider _timetableProvider;
  late TimetableSettings _draft;

  /// 进页时的快照：只服务「取消」回滚。
  late final TimetableSettings _openedWith;

  Timer? _autoSaveTimer;
  Future<void> _saveQueue = Future<void>.value();

  /// 预览看日课表还是周课表（只影响预览，不动首页真实状态）。
  bool _dayPreview = false;

  /// 日视图预览看哪一天（1 = 周一 … 7 = 周日）；进页时取今天。
  late int _previewDayOfWeek;

  // —— _HomeBackdropFlow 的宿主适配：壁纸流程本体在
  // settings_home_backdrop_flow.dart，本页只提供草稿读写与课表列表。

  @override
  TimetableSettings get backdropDraft => _draft;

  @override
  void applyBackdropDraft(TimetableSettings next) => _updateDraft(next);

  @override
  TimetableProvider get backdropProvider => _timetableProvider;

  @override
  void initState() {
    super.initState();
    _timetableProvider = context.read<TimetableProvider>();
    _draft = _timetableProvider.settings;
    _openedWith = _draft;
    _previewDayOfWeek = DateTime.now().weekday;
  }

  @override
  void dispose() {
    // 滑块 debounce 未到期时若直接返回，只 cancel 会丢最后一档草稿。
    if (_autoSaveTimer?.isActive ?? false) {
      _autoSaveTimer?.cancel();
      _enqueuePersist(_draft);
    } else {
      _autoSaveTimer?.cancel();
    }
    super.dispose();
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
    final provider = _timetableProvider;
    final message = await provider.updateTimetableSettings(
      next.copyWith(
        activeTimeSchemeId: provider.settings.activeTimeSchemeId,
        sections: List<SectionTime>.from(provider.settings.sections),
      ),
    );
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

  /// 完成：保留改动，返回。
  void _finish() {
    Navigator.pop(context);
  }

  /// 取消：把进页时的设置整份写回，再返回。
  ///
  /// 本页所有改动都是即时落盘的（弹窗里改一下，预览立刻变），所以「取消」不是
  /// 什么都不做，而是回滚 —— 否则按钮名与行为不符。回滚后仍走一次正常落盘。
  void _cancel() {
    if (_draft != _openedWith) {
      _updateDraft(_openedWith);
    }
    Navigator.pop(context);
  }

  Future<void> _openWallpaperSheet() async {
    final l10n = AppLocalizations.of(context)!;
    await showHomeHyperosSheet<void>(
      context: context,
      builder: (sheetContext) => HyperosSheetFrame(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: SingleChildScrollView(
          child: buildWallpaperSheetBody(sheetContext, l10n: l10n),
        ),
      ),
    );
  }

  Future<void> _openMaterialSheet() async {
    final l10n = AppLocalizations.of(context)!;
    await showHomeHyperosSheet<void>(
      context: context,
      builder: (sheetContext) => HyperosSheetFrame(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: StatefulBuilder(
          builder: (sheetContext, setSheetState) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.appearanceEditorMaterialAction,
                style: HyperosTypography.sheetTitle(sheetContext),
              ),
              const SizedBox(height: 16),
              HyperosListGroup(
                children: [
                  // 质感方案：一键写穿一组推荐的材质搭配。
                  HyperosSelectTile<TexturePreset?>(
                    label: l10n.texturePresetLabel,
                    subtitle: l10n.texturePresetSubtitle,
                    items: {
                      l10n.texturePresetClassicFrost:
                          TexturePreset.classicFrost,
                      l10n.texturePresetFullLiquid: TexturePreset.fullLiquid,
                      l10n.texturePresetSoftMist: TexturePreset.softMist,
                      l10n.texturePresetMinimalSolid:
                          TexturePreset.minimalSolid,
                      l10n.texturePresetCustom: null,
                    },
                    value: texturePresetOf(_draft),
                    onChanged: (preset) async {
                      if (preset == null) return;
                      final applied = await _confirmTexturePreset(preset);
                      if (!applied || !mounted) return;
                      setSheetState(() {});
                    },
                  ),
                  // 玻璃模式四档：与「课表页面」设置里那行同一映射。
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
                      setSheetState(() {});
                    },
                  ),
                  // 高级材质（柔光 / 液态）才需要进一步调校：档位与滑杆都在那页。
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
                        setSheetState(() {});
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 与「课表页面」那行同一个确认口径（写穿范围先讲清楚），返回是否应用。
  Future<bool> _confirmTexturePreset(TexturePreset preset) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showHyperosConfirmDialog(
      context: context,
      title: l10n.texturePresetApplyTitle,
      message: l10n.texturePresetApplyBody,
      cancelLabel: l10n.cancelAction,
      confirmLabel: l10n.confirmAction,
    );
    if (confirmed != true || !mounted) {
      return false;
    }
    _updateDraft(applyTexturePreset(_draft, preset));
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.watch<TimetableProvider>();
    return FrostedAppearanceScope(
      // 预览必须读**本页草稿**的外观，否则弹窗里刚改的材质不会反映到微缩图上
      // （FrostedAppearanceScope.of 会静默回落到默认值）。
      appearance: _draft.frostedAppearance,
      child: HyperosSubpage(
        onBack: _cancel,
        title: Text(l10n.appearanceEditorTitle),
        suffixes: [
          FHeaderAction(
            icon: const Icon(Icons.check_rounded),
            semanticsLabel: l10n.appearanceEditorDoneAction,
            onPress: _finish,
          ),
        ],
        headerExtension: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
          child: HyperosTabRow(
            tabs: [
              l10n.glassDockTabDay,
              l10n.glassDockTabWeek,
            ],
            selectedIndex: _dayPreview ? 0 : 1,
            onChanged: (index) => setState(() => _dayPreview = index == 0),
          ),
        ),
        bottomBar: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: HyperosButton(
                  label: l10n.appearanceEditorWallpaperAction,
                  variant: HyperosButtonVariant.secondary,
                  onPressed: _openWallpaperSheet,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: HyperosButton(
                  label: l10n.appearanceEditorMaterialAction,
                  onPressed: _openMaterialSheet,
                ),
              ),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: SingleChildScrollView(
              key: const PageStorageKey<String>('appearance-editor-preview'),
              child: TimetableWeekPreview(
                provider: provider,
                settings: _draft,
                week: provider.currentWeek,
                maxVisibleSections: _draft.sectionCount,
                includeAppHeader: true,
                onlyDayOfWeek: _dayPreview ? _previewDayOfWeek : null,
                showFloatingBackToCurrentWeek: false,
                // 天气与首页同源（该部件的字段说明要求显式传）。
                weather: context.watch<WeatherProvider?>(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
