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
              itemBuilder: _buildSection,
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
              _buildBuiltInWallpaperTile(context, l10n: l10n),
              _buildHomePageImageTile(
                context,
                l10n: l10n,
                title: l10n.homePageWallpaperTitle,
                path: resolveHomePageBackdropImagePath(_draft),
                onPick:
                    (resolveHomePageBackdropImagePath(_draft)?.isNotEmpty ??
                        false)
                    ? _editHomePageBackdropPosition
                    : _pickHomePageBackdropImage,
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
              // 壁纸有就整体透出；顶栏玻璃归「外观与配色 → 首页顶栏玻璃」
              // 材质五档（不想要玻璃选实体），此处不再保留重复入口。
            ],
          ),
        ],
      ),
      // 课卡的字色不在这——它跟着课卡走，在「课程卡片」页。
      6 => TimetableTextColorSettings(
        settings: _draft,
        scope: TextColorScope.page,
        onChanged: _updateDraft,
      ),
      7 => _SettingsResetTile(
        scope: SettingsResetScope.timetablePage,
        onReset: _updateDraft,
      ),
      _ => const SizedBox.shrink(),
    };
  }

  /// 内置壁纸的全部选项（含「不使用」），顺序与设置页展示顺序一致。
  static List<(BuiltInWallpaper?, String)> _builtInWallpaperOptions(
    AppLocalizations l10n,
  ) => [
    (null, l10n.homePageBuiltInWallpaperNone),
    (BuiltInWallpaper.og, l10n.homePageBuiltInWallpaperOg),
    (BuiltInWallpaper.lavaDark, l10n.homePageBuiltInWallpaperLavaDark),
    (BuiltInWallpaper.lavaLight, l10n.homePageBuiltInWallpaperLavaLight),
    (BuiltInWallpaper.dark1, l10n.homePageBuiltInWallpaperDark1),
    (BuiltInWallpaper.light2, l10n.homePageBuiltInWallpaperLight2),
    (BuiltInWallpaper.light3, l10n.homePageBuiltInWallpaperLight3),
    (BuiltInWallpaper.emberTeal, l10n.homePageBuiltInWallpaperEmberTeal),
  ];

  /// 内置预设的本地化名称；null 为「不使用」。
  static String _builtInWallpaperLabel(
    AppLocalizations l10n,
    BuiltInWallpaper? wallpaper,
  ) {
    for (final (candidate, label) in _builtInWallpaperOptions(l10n)) {
      if (candidate == wallpaper) {
        return label;
      }
    }
    return '';
  }

  /// 失效一张背景的缓存：图片缓存、文件存在性 memo 与预模糊位图。
  ///
  /// [key] 是背景身份键（图片路径或 builtin:<预设>）；图片路径才会去动
  /// 图片缓存，内置键只清预模糊位图。null / 空串安全跳过（无背景）。
  void _evictBackdropCaches(String? key) {
    if (key == null || key.isEmpty) {
      return;
    }
    if (!key.startsWith(kBuiltInWallpaperKeyPrefix)) {
      evictHomePageImageCache(key);
      invalidateHomePageBackdropFileExists(key);
    }
    PreblurredWallpaperCache.instance.evict(key);
  }

  /// 当前生效背景对应的历史条目；没有背景时返回 null。
  ///
  /// 图片壁纸带上当前的对齐值（切回时要还原裁剪位置），内置壁纸没有裁剪
  /// 窗口，对齐固定 0。
  WallpaperHistoryEntry? _currentBackdropEntry() {
    final key = homePageBackdropKey(_draft);
    if (key == null) {
      return null;
    }
    final isBuiltIn = key.startsWith(kBuiltInWallpaperKeyPrefix);
    return WallpaperHistoryEntry(
      key: key,
      alignX: isBuiltIn ? 0 : _draft.homePageWallpaperAlignX,
      alignY: isBuiltIn ? 0 : _draft.homePageWallpaperAlignY,
    );
  }

  /// 把 [entries]（按「旧 → 新」顺序）补记进「最近使用」，返回带新历史的设置。
  ///
  /// 被挤出上限的图片文件已不再被任何历史条目引用，异步删除释放空间；
  /// 删除失败不阻断主流程（deleteManagedImage 自身吞掉异常）。
  TimetableSettings _rememberBackdrops(
    TimetableSettings next,
    List<WallpaperHistoryEntry> entries,
  ) {
    if (entries.isEmpty) {
      return next;
    }
    final result = rememberWallpaperHistoryBatch(
      history: next.wallpaperHistory,
      entries: entries,
    );
    unawaited(deleteEvictedWallpaperFiles(result.evictedPaths));
    return next.copyWith(wallpaperHistory: result.history);
  }

  /// 应用一次背景切换的收尾：缓存失效 + 补记「最近使用」+ 落盘。
  ///
  /// [next] 已带好背景字段（路径 / 内置预设 / 对齐）；[remembered] 是按
  /// 「旧 → 新」顺序要补记的条目。背景身份没变（只挪裁剪位置）时不动缓存：
  /// 预模糊位图只按路径缓存，与对齐无关。
  void _applyBackdropChange(
    TimetableSettings next, {
    List<WallpaperHistoryEntry> remembered = const [],
  }) {
    final previousKey = homePageBackdropKey(_draft);
    final nextKey = homePageBackdropKey(next);
    if (previousKey != nextKey) {
      _evictBackdropCaches(previousKey);
      _evictBackdropCaches(nextKey);
    }
    _updateDraft(_rememberBackdrops(next, remembered));
  }

  /// 选中一张内置预设；null 表示「不使用」。
  ///
  /// 内置壁纸与自选图片互斥：切到内置（或「不使用」）时一并清掉图片路径，
  /// 否则图片会一直压在壁纸上。被换下的那张图片不会被删除——它会留在
  /// 「最近使用」里，用户随时能切回去。
  void _selectBuiltInWallpaper(BuiltInWallpaper? wallpaper) {
    final previous = _currentBackdropEntry();
    _applyBackdropChange(
      _draft.copyWith(
        homePageBuiltInWallpaper: wallpaper?.value,
        clearHomePageBuiltInWallpaper: wallpaper == null,
        clearHomePageWallpaperPath: true,
        clearHomePageBackgroundImagePath: true,
        // 内置壁纸没有可拖动的裁剪窗口，位置固定居中。
        homePageWallpaperAlignX: 0,
        homePageWallpaperAlignY: 0,
      ),
      remembered: [
        ?previous,
        if (wallpaper != null)
          WallpaperHistoryEntry(key: builtInWallpaperKey(wallpaper)),
      ],
    );
  }

  /// 切回「最近使用」里的某一条背景。
  ///
  /// 图片条目恢复当时的裁剪位置；文件已丢失 / 预设已下线的条目不可用，
  /// 直接忽略（下一次重建时它也不会再出现在列表里）。
  void _selectBackdropEntry(WallpaperHistoryEntry entry) {
    final next = settingsWithWallpaperHistoryEntry(_draft, entry);
    if (next == null) {
      return;
    }
    final previous = _currentBackdropEntry();
    _applyBackdropChange(
      next,
      remembered: [
        ?previous,
        WallpaperHistoryEntry(
          key: entry.key,
          alignX: entry.alignX,
          alignY: entry.alignY,
        ),
      ],
    );
  }

  /// 「最近使用」缩略图条：可一键切回最近设置过的 10 张壁纸。
  ///
  /// 列表 = 已持久化的历史（最新在前）中当前可用者；历史还是空的老用户，
  /// 把当前生效的那一张补在最前，一进设置页就能看到自己正用着什么。
  Widget _buildRecentWallpaperTile(
    BuildContext context, {
    required AppLocalizations l10n,
  }) {
    final currentKey = homePageBackdropKey(_draft);
    final entries = <WallpaperHistoryEntry>[
      if (currentKey != null &&
          !_draft.wallpaperHistory.any((entry) => entry.key == currentKey))
        WallpaperHistoryEntry(
          key: currentKey,
          alignX: _draft.homePageWallpaperAlignX,
          alignY: _draft.homePageWallpaperAlignY,
        ),
      ...availableWallpaperHistory(_draft.wallpaperHistory),
    ];
    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }
    final selectedKey = currentKey;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.homePageWallpaperRecentTitle,
            style: HyperosTypography.listTitle(context),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.homePageWallpaperRecentSubtitle,
            style: HyperosTypography.listDetail(context),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 116,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: entries.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final entry = entries[index];
                final builtIn = builtInWallpaperOfHistoryEntry(entry);
                return _WallpaperThumbnailCard(
                  label: builtIn != null
                      ? _builtInWallpaperLabel(l10n, builtIn)
                      : l10n.homePageWallpaperRecentImageLabel,
                  selected: entry.key == selectedKey,
                  onTap: () => _selectBackdropEntry(entry),
                  thumbnail: builtIn != null
                      ? BokehLavaGradient(
                          wallpaper: builtIn,
                          // 同屏多张缩略图：静态首帧即可，避免多 Ticker。
                          animate: false,
                        )
                      : Image.file(
                          File(entry.key),
                          fit: BoxFit.cover,
                          cacheWidth: 240,
                          // 列表构建后文件被删/损坏时不崩帧。
                          errorBuilder: (context, error, stackTrace) =>
                              const SizedBox.shrink(),
                        ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 内置壁纸选择行：横向预设卡片 + 「不使用」。
  ///
  /// 内置壁纸是代码渲染的渐变底图（无文件、无网络），与自选图片共用同一套
  /// 渲染 / 亮度采样 / 预模糊玻璃管线；用户自选图片优先，清除图片后自动
  /// 回退到这里选中的预设。
  Widget _buildBuiltInWallpaperTile(
    BuildContext context, {
    required AppLocalizations l10n,
  }) {
    final selected = resolveBuiltInWallpaper(_draft);
    final options = _builtInWallpaperOptions(l10n);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.homePageBuiltInWallpaperTitle,
            style: HyperosTypography.listTitle(context),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 116,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: options.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final (wallpaper, label) = options[index];
                return _BuiltInWallpaperOption(
                  label: label,
                  wallpaper: wallpaper,
                  selected: selected == wallpaper,
                  onTap: () => _selectBuiltInWallpaper(wallpaper),
                );
              },
            ),
          ),
        ],
      ),
    );
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
    final hasWallpaper = path != null && path.isNotEmpty;
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
                  label: hasWallpaper
                      ? l10n.homePageSwitchImageAction
                      : l10n.homePagePickImageAction,
                  onPressed: () => unawaited(onPick()),
                ),
              ),
              if (hasWallpaper) ...[
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
      directoryName: kHomePageWallpaperDirectoryName,
      filePrefix: kHomePageWallpaperFilePrefix,
      // 「最近使用」要留住前几张壁纸，不能再沿用「选新图就删光本目录」
      // 的清理模式；淘汰交给历史上限（kMaxWallpaperHistoryEntries）。
      cleanupArtifacts: false,
    );
    if (!mounted || targetPath == null) {
      return;
    }
    final previous = _currentBackdropEntry();
    _applyBackdropChange(
      _draft.copyWith(
        homePageWallpaperPath: targetPath,
        clearHomePageBackgroundImagePath: true,
      ),
      remembered: [
        ?previous,
        WallpaperHistoryEntry(key: targetPath),
      ],
    );
  }

  /// 已存在壁纸时点击入口：直接进入位置编辑页，初始值取自上次保存的对齐。
  Future<void> _editHomePageBackdropPosition() async {
    final existingPath = resolveHomePageBackdropImagePath(_draft);
    if (existingPath == null || existingPath.isEmpty) {
      await _pickHomePageBackdropImage();
      return;
    }
    // 壁纸文件可能已丢失（重装/清除数据后设置被备份恢复、跨设备同步只带回
    // JSON 不带文件等）：此时进入位置编辑页会在读取图片时抛
    // PathNotFoundException。改为清掉失效路径，直接走重新选图流程。
    if (!File(existingPath).existsSync()) {
      _evictBackdropCaches(existingPath);
      if (!mounted) {
        return;
      }
      _updateDraft(
        _draft.copyWith(
          clearHomePageWallpaperPath: true,
          clearHomePageBackgroundImagePath: true,
        ),
      );
      await _pickHomePageBackdropImage();
      return;
    }
    if (!mounted) {
      return;
    }
    final result = await pushWallpaperPositionPickerPage(
      context,
      imagePath: existingPath,
      initialAlignX: _draft.homePageWallpaperAlignX,
      initialAlignY: _draft.homePageWallpaperAlignY,
      onPickNewImage: () => pickAndStoreManagedImage(
        directoryName: 'home_page_wallpaper',
        filePrefix: 'wallpaper',
        // 编辑页内换图：保留上一张，等确认后再清理。
        cleanupArtifacts: false,
      ),
    );
    if (!mounted || result == null) {
      return;
    }
    if (!result.confirmed) {
      // 用户取消：若在编辑页里换了图，清理那张未被采用的新文件。
      if (result.path != existingPath) {
        final newFile = File(result.path);
        if (newFile.existsSync()) {
          await newFile.delete();
        }
        invalidateHomePageBackdropFileExists(result.path);
      }
      return;
    }
    final previous = _currentBackdropEntry();
    _applyBackdropChange(
      _draft.copyWith(
        homePageWallpaperPath: result.path,
        homePageWallpaperAlignX: result.alignX,
        homePageWallpaperAlignY: result.alignY,
        clearHomePageBackgroundImagePath: true,
      ),
      remembered: [
        ?previous,
        WallpaperHistoryEntry(
          key: result.path,
          alignX: result.alignX,
          alignY: result.alignY,
        ),
      ],
    );
    // 被换下的旧图不再删除：它在「最近使用」里留档，用户可以随时切回，
    // 只有被挤出上限（或恢复默认）时才真正落盘删除。
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

/// 内置壁纸预览卡：选中态描边 + 勾选角标。
class _BuiltInWallpaperOption extends StatelessWidget {
  const _BuiltInWallpaperOption({
    required this.label,
    required this.wallpaper,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final BuiltInWallpaper? wallpaper;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final wallpaper = this.wallpaper;
    return _WallpaperThumbnailCard(
      label: label,
      selected: selected,
      onTap: onTap,
      thumbnail: wallpaper == null
          ? ColoredBox(
              color: HyperosColors.surfaceContainer(context),
              child: Icon(
                Icons.block_rounded,
                size: 22,
                color: HyperosColors.secondaryText(context),
              ),
            )
          : BokehLavaGradient(
              wallpaper: wallpaper,
              // 列表里多张缩略图同屏；静态首帧与首页动画同 seed，
              // 避免同时起多个 Ticker 耗电。
              animate: false,
            ),
    );
  }
}

/// 壁纸缩略图卡（内置预设与「最近使用」共用）：78 宽，选中态描边 + 高亮标签。
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
