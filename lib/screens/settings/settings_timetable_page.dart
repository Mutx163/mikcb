part of '../timetable_settings_screen.dart';

/// 课表页面设置。
///
/// 收的是「课表这一页」的属性：行列密度、回到本周、页面背景（含壁纸与背景
/// 显示区域）、星期栏与时间轴的文字色。重构前这些分散在「课表显示」与
/// 「外观与主题」两页——背景区域那 8 项本是课表页的属性，却挂在应用外观下。
class _TimetablePageSettingsScreen extends StatefulWidget {
  const _TimetablePageSettingsScreen();

  @override
  State<_TimetablePageSettingsScreen> createState() =>
      _TimetablePageSettingsScreenState();
}

class _TimetablePageSettingsScreenState
    extends State<_TimetablePageSettingsScreen>
    with _HomeBackdropFlow<_TimetablePageSettingsScreen> {
  late final TimetableProvider _timetableProvider;
  late TimetableSettings _draft;
  Timer? _autoSaveTimer;
  Future<void> _saveQueue = Future<void>.value();

  // —— _HomeBackdropFlow 的宿主适配：壁纸流程本体在
  // settings_home_backdrop_flow.dart，本页只提供草稿读写与课表列表。

  @override
  TimetableSettings get backdropDraft => _draft;

  @override
  void applyBackdropDraft(TimetableSettings next) => _updateDraft(next);

  @override
  TimetableProvider get backdropProvider => _timetableProvider;

  static const List<String> _backgroundColors = [
    '#F8FAFC',
    '#F7F7F5',
    '#FDF6EC',
    '#F2F7FF',
    '#F5F3FF',
    '#ECFDF5',
  ];

  /// 截屏提示依赖 Android 14 的官方回调；不支持的平台不展示这个开关，
  /// 免得留给用户一个「点了没反应」的开关。
  bool _screenshotShareSupported = false;

  @override
  void initState() {
    super.initState();
    _timetableProvider = context.read<TimetableProvider>();
    _draft = _timetableProvider.settings;
    unawaited(_loadScreenshotShareSupport());
  }

  Future<void> _loadScreenshotShareSupport() async {
    final supported = await ScreenCaptureService.ensureSupported();
    if (!mounted || supported == _screenshotShareSupported) {
      return;
    }
    setState(() => _screenshotShareSupported = supported);
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.watch<TimetableProvider>();
    return HyperosSubpage(
      onBack: () => Navigator.pop(context),
      title: Text(l10n.timetablePageSettingsTitle),
      // Fixed week preview + lower editor list — same as course-card settings.
      collapsibleLargeTitle: false,
      child: Column(
        children: [
          Expanded(
            flex: 4,
            child: SingleChildScrollView(
              key: const PageStorageKey<String>(
                'timetable-page-settings-preview',
              ),
              child: HyperosBlurredBodyInset(
                child: FrostedAppearanceScope(
                  // Without this the preview reads the *saved* appearance —
                  // FrostedAppearanceScope.of() silently falls back to
                  // defaults — so glass / blur edits made here would not show
                  // up in it.
                  appearance: _draft.frostedAppearance,
                  child: TimetableWeekPreview(
                    provider: provider,
                    settings: _draft,
                    week: provider.currentWeek,
                    maxVisibleSections: _draft.sectionCount,
                    isSettingsPreview: true,
                    // 预览要跟首页周网格一致，天气源显式传入（见该部件的字段说明）。
                    weather: context.watch<WeatherProvider?>(),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 6,
            child: HyperosListView(
              includeHeaderInset: false,
              pageStorageKey: const PageStorageKey<String>(
                'timetable-page-settings-editor',
              ),
              itemCount: _sectionCount,
              itemBuilder: _buildSection,
            ),
          ),
        ],
      ),
    );
  }

  /// Sections: 0-1 行列与密度 · 3 回到本周 · 5 页面背景 · 7 玻璃 / 材质
  /// · 8 文字色 · 9 恢复默认（偶数索引是节间距）。
  static const _sectionCount = 10;

  Widget _buildSection(BuildContext context, int index) {
    final l10n = AppLocalizations.of(context)!;
    return switch (index) {
      // 行列与密度：格子本身有多大、时间列怎么显示。
      0 => HyperosSectionLabel(text: l10n.timetablePageSectionDensity),
      1 => HyperosListGroup(
        children: [
          HyperosSwitchTile(
            title: l10n.layoutAutoFitHeightTitle,
            value: _draft.timetableAutoFitSectionHeight,
            onChanged: (value) {
              _updateDraft(
                _draft.copyWith(timetableAutoFitSectionHeight: value),
              );
            },
          ),
          HyperosSwitchTile(
            title: l10n.layoutHideWeekendsTitle,
            value: _draft.timetableHideWeekends,
            onChanged: (value) {
              _updateDraft(_draft.copyWith(timetableHideWeekends: value));
            },
          ),
          HyperosSwitchTile(
            title: l10n.layoutShowOtherWeeksTitle,
            subtitle: l10n.layoutShowOtherWeeksSubtitle,
            value: _draft.timetableShowNonCurrentWeekCourses,
            onChanged: (value) {
              _updateDraft(
                _draft.copyWith(timetableShowNonCurrentWeekCourses: value),
              );
            },
          ),
          // 课表网格的交互行为，归课表页设置（用户口径 2026-09-15：
          // 不放通用设置）。
          HyperosSwitchTile(
            title: l10n.longPressEmptySlotToAddTitle,
            subtitle: l10n.longPressEmptySlotToAddSubtitle,
            value: _draft.longPressEmptySlotToAddCourseEnabled,
            onChanged: (value) {
              _updateDraft(
                _draft.copyWith(longPressEmptySlotToAddCourseEnabled: value),
              );
            },
          ),
          // 截屏提示同理：只在课表页生效，所以归这里。
          if (_screenshotShareSupported)
            HyperosSwitchTile(
              title: l10n.settingsScreenshotShareTitle,
              subtitle: l10n.settingsScreenshotShareSubtitle,
              value: _draft.screenshotSharePromptEnabled,
              onChanged: (value) {
                _updateDraft(
                  _draft.copyWith(screenshotSharePromptEnabled: value),
                );
              },
            ),
          HyperosSelectTile<SectionTimeDisplayMode>(
            label: l10n.layoutTimeColumnDisplayLabel,
            items: {
              for (final v in SectionTimeDisplayMode.values)
                sectionTimeDisplayModeLabel(l10n, v): v,
            },
            value: _draft.timetableSectionTimeDisplayMode,
            onChanged: (value) {
              _updateDraft(
                _draft.copyWith(timetableSectionTimeDisplayMode: value),
              );
            },
          ),
          HyperosSelectTile<TimetableTimeColumnWidthMode>(
            label: l10n.layoutTimeColumnWidthLabel,
            items: {
              for (final v in TimetableTimeColumnWidthMode.values)
                timetableTimeColumnWidthModeLabel(l10n, v): v,
            },
            value: _draft.timetableTimeColumnWidthMode,
            onChanged: (value) {
              _updateDraft(
                _draft.copyWith(timetableTimeColumnWidthMode: value),
              );
            },
          ),
          HyperosSliderTile(
            title: l10n.layoutSectionHeightTitle,
            value: _draft.sectionHeight,
            min: 48,
            max: 92,
            divisions: 11,
            enabled: !_draft.timetableAutoFitSectionHeight,
            valueLabel: _draft.sectionHeight.toStringAsFixed(0),
            onChanged: !_draft.timetableAutoFitSectionHeight
                ? (value) => _updateDraft(
                    _draft.copyWith(sectionHeight: value),
                    debounce: true,
                  )
                : null,
          ),
          HyperosSliderTile(
            title: l10n.layoutCourseCardGapTitle,
            value: _draft.timetableCourseCardGap,
            max: 3,
            divisions: 12,
            valueLabel: _draft.timetableCourseCardGap.toStringAsFixed(1),
            onChanged: (value) => _updateDraft(
              _draft.copyWith(timetableCourseCardGap: value),
              debounce: true,
            ),
          ),
        ],
      ),
      2 => const HyperosSectionGap(),
      // 回到本周：按钮样式与浮动态透明度。
      3 => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HyperosSectionLabel(text: l10n.timetablePageSectionBackToWeek),
          HyperosListGroup(
            children: [
              // 「回本周」已收敛为浮钮唯一入口，样式选择行随之移除；
              // 仅保留浮钮透明度调节。
              HyperosSliderTile(
                  title: l10n.layoutBackToCurrentWeekButtonOpacityTitle,
                  value: _draft.timetableFloatingBackToCurrentWeekButtonOpacity,
                  min: 0.55,
                  divisions: 9,
                  valueLabel:
                      '${(_draft.timetableFloatingBackToCurrentWeekButtonOpacity * 100).round()}%',
                  onChanged: (value) => _updateDraft(
                    _draft.copyWith(
                      timetableFloatingBackToCurrentWeekButtonOpacity: value,
                    ),
                    debounce: true,
                  ),
                ),
            ],
          ),
        ],
      ),
      4 => const HyperosSectionGap(),
      // 页面背景：底色、壁纸、壁纸铺到哪几块、以及两处模糊。
      5 => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HyperosSectionLabel(text: l10n.timetablePageSectionBackground),
          HyperosListGroup(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                child: Text(
                  l10n.timetableBackgroundColorSectionTitle,
                  style: HyperosTypography.listDetail(context),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: HyperosHexColorChipGroup(
                  colorHexes: _backgroundColors,
                  selectedHex: _draft.timetablePageBackgroundColor,
                  colorParser: _colorFromHex,
                  onSelectedHex: (color) {
                    _updateDraft(
                      _draft.copyWith(timetablePageBackgroundColor: color),
                    );
                  },
                ),
              ),
              _buildHomePageImageTile(
                context,
                l10n: l10n,
                title: l10n.homePageWallpaperTitle,
                path: resolveHomePageBackdropImagePath(_draft),
                // 与「外观编辑」页底部那颗「调整壁纸」打开的弹窗**同一套接线**
                //（见 settings_home_backdrop_flow.dart 的
                // [buildWallpaperSheetBody]）：选图永远先开相册、选完进位置页，
                // 只想调位置的走旁边那颗「调整位置」。
                onPick: _pickAndPositionHomePageBackdrop,
                onAdjustPosition: _editHomePageBackdropPosition,
                onClear: () {
                  final stalePath = resolveHomePageBackdropImagePath(_draft);
                  _evictBackdropCaches(stalePath);
                  // 文件不再被当前背景引用，但多半还在「最近使用」里：改由
                  // 历史淘汰（挤出上限 / 恢复默认）负责删除。若在这里直接删，
                  // 用户从历史切回时只会拿到一条死路径。
                  _updateDraft(
                    _draft.copyWith(
                      clearHomePageWallpaperPath: true,
                      clearHomePageBackgroundImagePath: true,
                    ),
                  );
                },
              ),
              _buildRecentWallpaperTile(context, l10n: l10n),
              HyperosSwitchTile(
                title: l10n.homePageBackdropFollowsWeekPagerTitle,
                value: _draft.homePageBackdropFollowsWeekPager,
                onChanged: (value) {
                  _updateDraft(
                    _draft.copyWith(homePageBackdropFollowsWeekPager: value),
                  );
                },
              ),
              // 「壁纸透出范围」与「顶栏玻璃」开关已下线（2026-09-12）：
              // 壁纸有就整体透出；顶栏玻璃改用材质五档（不想要玻璃选实体），
              // 入口在下面「玻璃 / 材质」区块里，此处不再保留重复入口。
            ],
          ),
        ],
      ),
      // 玻璃 / 材质（2026-09-19 从「外观与配色」整体迁来：玻璃档位改在课表
      // 页面调整，理由与页面背景同一条）。
      6 => const HyperosSectionGap(),
      7 => _buildGlassMaterialSection(context, l10n),
      // 课卡的字色不在这——它跟着课卡走，在「课程卡片」页。
      8 => TimetableTextColorSettings(
        settings: _draft,
        scope: TextColorScope.page,
        onChanged: _updateDraft,
      ),
      9 => _SettingsResetTile(
        scope: SettingsResetScope.timetablePage,
        onReset: _updateDraft,
      ),
      _ => const SizedBox.shrink(),
    };
  }

  /// 「玻璃 / 材质」区块：**外观编辑入口行**。
  ///
  /// 2026-09-19 第五轮：质感方案 / 玻璃模式 / 高斯滑杆 / 高级材质入口 /
  /// 首页顶栏玻璃 / 子页顶栏风格 / 各表面材质地图整体并入「外观编辑」页的
  /// 材质面板 —— 看着首页改材质，预览区就是页面本身。本区块只留保证一键可达
  /// 的入口行。材质轴的「恢复默认」仍归本页作用域：确认文案里的「与玻璃质感」
  /// 就是对这件事的承诺（见 settings_reset.dart 的材质轴注释）。
  Widget _buildGlassMaterialSection(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    return HyperosSettingsBlock(
      title: l10n.frostedSheetSectionTitle,
      child: HyperosListGroup(
        children: [
          // 首页右上角菜单里也有一个同名入口（`kHomeMenuCatalog` 的
          // `appearanceEditor`），但八宫格只有 8 格且排列是用户自己存的，
          // 新增条目不会自动出现；这一行才是**保证一键可达**的那条路。
          HyperosListTile(
            title: l10n.appearanceEditorTitle,
            details: l10n.appearanceEditorEntrySubtitle,
            onTap: () async {
              await HyperosNavigation.push(
                context,
                settings: const RouteSettings(
                  name: '/settings/appearance-editor',
                ),
                builder: (_) => const _AppearanceEditorScreen(),
              );
              if (!mounted) return;
              setState(() {
                _draft = context.read<TimetableProvider>().settings;
              });
            },
          ),
        ],
      ),
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
    final provider = _timetableProvider;
    try {
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
        reportSettingsPersistRejected(this, message);
        setState(() {
          _draft = provider.settings;
        });
        return;
      }
    } catch (_) {
      // 落盘失败：provider 已回滚内存与课表镜像并 rethrow，不接就没人提示。
      reportSettingsPersistFailure(this, resetDraft: () {
        setState(() {
          _draft = provider.settings;
        });
      });
    }
  }
}

/// 壁纸缩略图卡（「最近使用」条）：78 宽，选中态描边 + 高亮标签。
class _WallpaperThumbnailCard extends StatelessWidget {
  const _WallpaperThumbnailCard({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.thumbnail,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// 缩略图本体；调用方负责铺满（卡内已套 ClipRRect 圆角）。
  final Widget thumbnail;

  @override
  Widget build(BuildContext context) {
    final primary = HyperosColors.primary(context);
    return SizedBox(
      width: 78,
      child: MiuixPressable(
        onPressed: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected ? primary : Colors.transparent,
                    width: 2,
                  ),
                ),
                padding: const EdgeInsets.all(2),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: thumbnail,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                height: 1.2,
                color: selected
                    ? primary
                    : HyperosColors.secondaryText(context),
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
