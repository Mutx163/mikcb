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
    extends State<_TimetablePageSettingsScreen> {
  late final TimetableProvider _timetableProvider;
  late TimetableSettings _draft;
  Timer? _autoSaveTimer;
  Future<void> _saveQueue = Future<void>.value();

  static const List<String> _backgroundColors = [
    '#F8FAFC',
    '#F7F7F5',
    '#FDF6EC',
    '#F2F7FF',
    '#F5F3FF',
    '#ECFDF5',
  ];

  @override
  void initState() {
    super.initState();
    _timetableProvider = context.read<TimetableProvider>();
    _draft = _timetableProvider.settings;
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
              itemBuilder: (context, index) => _buildSection(context, index),
            ),
          ),
        ],
      ),
    );
  }

  static const _sectionCount = 8;

  Widget _buildSection(BuildContext context, int index) {
    final l10n = AppLocalizations.of(context)!;
    return switch (index) {
      // 行列与密度：格子本身有多大、时间列怎么显示。
      0 => HyperosSectionLabel(text: l10n.timetablePageSectionDensity),
      1 => HyperosListGroup(
        children: [
          HyperosListTile(
            icon: Icons.schedule_rounded,
            iconAccent: HyperosIconColors.teal,
            // 与设置首页「时间模板」同名同页，避免「两套时间系统」心智。
            title: l10n.timeSchemeEntryTitle,
            details:
                _timetableProvider.activeTimeScheme?.name ??
                l10n.timeSchemeEntrySubtitleNoneSelected,
            onTap: () {
              HyperosNavigation.push(
                context,
                settings: const RouteSettings(name: '/settings/time-schemes'),
                builder: (_) => const TimeSchemeManagementScreen(),
              );
            },
          ),
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
            min: 0,
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
              HyperosSelectTile<BackToCurrentWeekButtonStyle>(
                label: l10n.layoutBackToCurrentWeekButtonStyleLabel,
                items: {
                  for (final v in BackToCurrentWeekButtonStyle.values)
                    _backToCurrentWeekButtonStyleLabel(l10n, v): v,
                },
                value: _draft.timetableBackToCurrentWeekButtonStyle,
                onChanged: (value) {
                  _updateDraft(
                    _draft.copyWith(
                      timetableBackToCurrentWeekButtonStyle: value,
                    ),
                  );
                },
              ),
              if (_draft.timetableBackToCurrentWeekButtonStyle ==
                  BackToCurrentWeekButtonStyle.floating)
                HyperosSliderTile(
                  title: l10n.layoutBackToCurrentWeekButtonOpacityTitle,
                  value: _draft.timetableFloatingBackToCurrentWeekButtonOpacity,
                  min: 0.55,
                  max: 1.0,
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
                onPick: _pickHomePageBackdropImage,
                onClear: () {
                  evictHomePageImageCache(
                    resolveHomePageBackdropImagePath(_draft),
                  );
                  PreblurredWallpaperCache.instance.evict(
                    resolveHomePageBackdropImagePath(_draft),
                  );
                  _updateDraft(
                    _draft.copyWith(
                      clearHomePageWallpaperPath: true,
                      clearHomePageBackgroundImagePath: true,
                    ),
                  );
                },
              ),
              HyperosSwitchTile(
                title: l10n.homePageBackdropFollowsWeekPagerTitle,
                value: _draft.homePageBackdropFollowsWeekPager,
                onChanged: (value) {
                  _updateDraft(
                    _draft.copyWith(homePageBackdropFollowsWeekPager: value),
                  );
                },
              ),
              HyperosSwitchTile(
                title: l10n.homePageBackgroundScopeStatusBar,
                value: HomePageBackgroundScope.includes(
                  _draft.homePageBackgroundScope,
                  HomePageBackgroundScope.statusBar,
                ),
                onChanged: (value) => _toggleBackgroundScope(
                  HomePageBackgroundScope.statusBar,
                  value,
                ),
              ),
              HyperosSwitchTile(
                title: l10n.homePageBackgroundScopeHeader,
                value: HomePageBackgroundScope.includes(
                  _draft.homePageBackgroundScope,
                  HomePageBackgroundScope.header,
                ),
                onChanged: (value) => _toggleBackgroundScope(
                  HomePageBackgroundScope.header,
                  value,
                ),
              ),
              HyperosSwitchTile(
                title: l10n.homePageBackgroundScopeWeekdayBar,
                value: HomePageBackgroundScope.includes(
                  _draft.homePageBackgroundScope,
                  HomePageBackgroundScope.weekdayBar,
                ),
                onChanged: (value) => _toggleBackgroundScope(
                  HomePageBackgroundScope.weekdayBar,
                  value,
                ),
              ),
              HyperosSwitchTile(
                title: l10n.homePageBackgroundScopeTimetable,
                value: HomePageBackgroundScope.includes(
                  _draft.homePageBackgroundScope,
                  HomePageBackgroundScope.timetable,
                ),
                onChanged: (value) => _toggleBackgroundScope(
                  HomePageBackgroundScope.timetable,
                  value,
                ),
              ),
              HyperosSwitchTile(
                title: l10n.homePageHeaderBlurTitle,
                value: _draft.homePageHeaderBlurEnabled,
                onChanged: (value) {
                  _updateDraft(
                    _draft.copyWith(homePageHeaderBlurEnabled: value),
                  );
                },
              ),
              HyperosSwitchTile(
                title: l10n.homePageWeekdayBarBlurTitle,
                value: _draft.homePageWeekdayBarBlurEnabled,
                onChanged: (value) {
                  _updateDraft(
                    _draft.copyWith(homePageWeekdayBarBlurEnabled: value),
                  );
                },
              ),
            ],
          ),
        ],
      ),
      // 课卡的字色不在这——它跟着课卡走，在「课程卡片」页。
      6 => TimetableTextColorSettings(
        settings: _draft,
        scope: TextColorScope.page,
        onChanged: (next) => _updateDraft(next),
      ),
      7 => _SettingsResetTile(
        scope: SettingsResetScope.timetablePage,
        onReset: _updateDraft,
      ),
      _ => const SizedBox.shrink(),
    };
  }

  void _toggleBackgroundScope(int scope, bool enabled) {
    _updateDraft(
      _draft.copyWith(
        homePageBackgroundScope: HomePageBackgroundScope.toggle(
          _draft.homePageBackgroundScope,
          scope,
          enabled: enabled,
        ),
      ),
    );
  }

  String _backToCurrentWeekButtonStyleLabel(
    AppLocalizations l10n,
    BackToCurrentWeekButtonStyle style,
  ) {
    return switch (style) {
      BackToCurrentWeekButtonStyle.inline =>
        l10n.layoutBackToCurrentWeekButtonStyleInline,
      BackToCurrentWeekButtonStyle.floating =>
        l10n.layoutBackToCurrentWeekButtonStyleFloating,
    };
  }

  Widget _buildHomePageImageTile(
    BuildContext context, {
    required AppLocalizations l10n,
    required String title,
    required String? path,
    required Future<void> Function() onPick,
    required VoidCallback onClear,
  }) {
    final fileName = path == null || path.isEmpty
        ? l10n.homePageImageNotSelected
        : path.split(Platform.pathSeparator).last;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: HyperosTypography.listTitle(context)),
          const SizedBox(height: 4),
          Text(fileName, style: HyperosTypography.listDetail(context)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: HyperosButton(
                  label: l10n.homePagePickImageAction,
                  onPressed: () => unawaited(onPick()),
                ),
              ),
              if (path != null && path.isNotEmpty) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: HyperosButton(
                    label: l10n.homePageClearImageAction,
                    variant: HyperosButtonVariant.secondary,
                    onPressed: onClear,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickHomePageBackdropImage() async {
    final targetPath = await pickAndStoreManagedImage(
      directoryName: 'home_page_wallpaper',
      filePrefix: 'wallpaper',
    );
    if (!mounted || targetPath == null) {
      return;
    }
    evictHomePageImageCache(resolveHomePageBackdropImagePath(_draft));
    PreblurredWallpaperCache.instance.evict(
      resolveHomePageBackdropImagePath(_draft),
    );
    _updateDraft(
      _draft.copyWith(
        homePageWallpaperPath: targetPath,
        clearHomePageBackgroundImagePath: true,
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
      return;
    }
  }
}
