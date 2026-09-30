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
                // [buildWallpaperSheetSelectionPage]，弹窗那侧 2026-09-28 起还分成了
                // 两页，第一页就是它）：选图永远先开相册、选完进位置页，
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
              // 「背景随周次滑动」与壁纸弹窗里那颗是**同一个开关**（同一个
              // builder、同一份设置，见 [_buildBackdropFollowsWeekPagerTile]）。
              _buildBackdropFollowsWeekPagerTile(context, l10n: l10n),
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

/// 「最近使用」整段：标题 + 缩略图条 + 移除确认条。
///
/// **确认按钮为什么画在条外面、而不是塞进卡里**（第一版塞进去过，被否掉）：
///
/// * **塞不进。** 78 宽的卡里平分两颗按钮只剩约 37 宽，要放到 24px 高才不至于
///   把卡片标签顶掉 —— 而 24×37 远小于最小点击区，真机上按不准。
/// * **几何必然出错。** 卡片的 `MiuixPressable` 会按自己的 14 圆角裁剪子树，
///   于是按钮自己的圆角和外侧被父级裁出来的圆角**对不上**：两颗按钮的外侧下角
///   是父级的 14、内侧与上侧是按钮自己的 8，看起来就是"某个角圆得不一样"。
/// * **画在条外面就没有这些约束**：两颗都是设置页其他地方同款的
///   [HyperosButton]（高度约 40、点得准、圆角与其他按钮一致），条只负责
///   "哪张被选中了"这一件事。
///
/// 确认态**不弹覆盖层**：这个流程有两个宿主，其中「外观编辑」页底部那颗
/// 「调整壁纸」是底部弹层；而弹层是根覆盖层自插条目，任何再往上的弹层都会被
/// 压在它背面（真机实锤，材质面板那边为同一件事做过 `_withHostSheetClosed`）。
/// 弹确认框在两个宿主里必然分叉，"确认条就地长在列表下面"则两边天然一致。
class _RecentWallpaperSection extends StatefulWidget {
  const _RecentWallpaperSection({
    required this.entries,
    required this.selectedKey,
    required this.l10n,
    required this.horizontalInset,
    required this.onSelect,
    required this.onBlockedRemove,
    required this.onConfirmRemove,
  });

  final List<WallpaperHistoryEntry> entries;

  /// 当前正在用的那张的键；它不可移除。
  final String? selectedKey;

  final AppLocalizations l10n;

  /// 宿主给的左右内缩（见 `_HomeBackdropFlow.backdropRowHorizontalInset`）：
  /// 设置页那一处是 16（卡片自己的行内缩），弹窗那一处是 0（面板已经给了 16）。
  final double horizontalInset;

  final ValueChanged<WallpaperHistoryEntry> onSelect;

  /// 「你按的那张正被使用、不能移除」的解释。角标不会出现在它上面，所以这条路
  /// 只可能来自长按 —— 那也正是唯一能让用户问出"为什么这张没有 ×"的时刻。
  final void Function(BuildContext context, WallpaperHistoryEntry entry)
  onBlockedRemove;

  final void Function(BuildContext context, WallpaperHistoryEntry entry)
  onConfirmRemove;

  @override
  State<_RecentWallpaperSection> createState() =>
      _RecentWallpaperSectionState();
}

class _RecentWallpaperSectionState extends State<_RecentWallpaperSection> {
  /// 已发起移除、正等确认的那一条的键；null = 没有。
  String? _armedKey;

  @override
  void didUpdateWidget(_RecentWallpaperSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 删掉之后（或历史被外部改动之后）不能让一个已经不存在的 key 继续挂着：
    // 那会留下一条永远按不掉、也永远删不掉的确认条。
    final key = _armedKey;
    if (key != null && !widget.entries.any((entry) => entry.key == key)) {
      _armedKey = null;
    }
  }

  void _disarm() {
    if (_armedKey == null) {
      return;
    }
    setState(() => _armedKey = null);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        widget.horizontalInset,
        14,
        widget.horizontalInset,
        14,
      ),
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
            height: _recentWallpaperStripHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: widget.entries.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final entry = widget.entries[index];
                final isCurrent = entry.key == widget.selectedKey;
                final armed = entry.key == _armedKey;
                return _WallpaperThumbnailCard(
                  // 按壁纸键给每张卡一个稳定的 key：确认态会让角标此消彼长
                  // （被选中的那张自己收起角标），几何测试只靠"第几个 ×"
                  // 根本指不准是哪一张。
                  key: ValueKey<String>('wallpaper-recent-card:${entry.key}'),
                  label: l10n.homePageWallpaperRecentImageLabel,
                  selected: isCurrent,
                  removable: !isCurrent,
                  armed: armed,
                  onTap: () {
                    // 已发起移除的那张，单击是**取消**而不是切壁纸：它此刻的
                    // 语义是"要不要删"，顺手把壁纸也换了就是一次操作两个后果。
                    if (armed) {
                      _disarm();
                      return;
                    }
                    widget.onSelect(entry);
                  },
                  onRequestRemove: () {
                    if (armed) {
                      _disarm();
                      return;
                    }
                    setState(() => _armedKey = entry.key);
                  },
                  // 不可移除的那张：长按只解释一句为什么不行（没有 × 角标）。
                  onBlockedRemove: () => widget.onBlockedRemove(context, entry),
                  thumbnail: Image.file(
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
          if (_armedKey != null) ...[
            const SizedBox(height: 14),
            Text(
              l10n.wallpaperHistoryRemoveConfirmHint,
              style: HyperosTypography.listDetail(context).copyWith(
                color: HyperosColors.error(context),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: HyperosButton(
                    label: l10n.deleteAction,
                    variant: HyperosButtonVariant.destructive,
                    onPressed: () {
                      final entry = _armedEntry();
                      _disarm();
                      if (entry != null) {
                        widget.onConfirmRemove(context, entry);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: HyperosButton(
                    label: l10n.cancelAction,
                    variant: HyperosButtonVariant.secondary,
                    onPressed: _disarm,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// 当前已发起移除的那一条（条目可能已经不在列表里 → null）。
  WallpaperHistoryEntry? _armedEntry() {
    final key = _armedKey;
    if (key == null) {
      return null;
    }
    for (final entry in widget.entries) {
      if (entry.key == key) {
        return entry;
      }
    }
    return null;
  }
}

/// 壁纸缩略图卡（「最近使用」条里的一张）：78 宽，选中态描边 + 高亮标签。
///
/// 两种附加形态（与常态互斥，见 [_RecentWallpaperSection]）：
/// * [armed]：已发起移除 —— 缩略图压暗 + 警示色描边、角标收起。此时单击与长按
///   都改走"取消"，确认改由条下面那条确认条承担；
/// * [removable] 为 false：正在用的那张，没有角标，长按只解释一句为什么不给删。
class _WallpaperThumbnailCard extends StatelessWidget {
  const _WallpaperThumbnailCard({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.thumbnail,
    this.removable = true,
    this.armed = false,
    this.onRequestRemove,
    this.onBlockedRemove,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget thumbnail;

  /// 是否允许移除。正在用的那张传 false（不给角标，也进不了确认态）。
  final bool removable;

  /// 本卡是否正处在"已发起移除、等确认"的状态。
  final bool armed;

  /// 请求移除（角标 / 长按都走它）。armed 时它变成"取消"。
  final VoidCallback? onRequestRemove;

  /// 不可移除时对"用户仍想删"的回应（解释为什么不行）。
  final VoidCallback? onBlockedRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final primary = HyperosColors.primary(context);
    final danger = HyperosColors.error(context);
    return SizedBox(
      width: 78,
      child: Stack(
        children: [
          MiuixPressable(
            onPressed: onTap,
            onLongPress: armed
                ? onRequestRemove
                : (removable ? onRequestRemove : onBlockedRemove),
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
                        color: armed
                            ? danger
                            : (selected ? primary : Colors.transparent),
                        width: 2,
                      ),
                    ),
                    padding: const EdgeInsets.all(2),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      // 已发起移除时在缩略图上压一层半透明黑：让"这张要被移除
                      // 了"在图本身也读得出来，而不只是靠那颗红边。
                      //
                      // 刻意用「叠一层」而不是 `Opacity` / `ColorFiltered`：
                      // `Opacity` 会把图往卡片底色上混（读作"发白"而不是"被压
                      // 暗"），`ColorFiltered(srcATop, 黑)` 则直接把不透明区域
                      // 涂成纯黑。
                      child: Stack(
                        key: const ValueKey<String>('wallpaper-card-thumbnail'),
                        fit: StackFit.expand,
                        children: [
                          thumbnail,
                          if (armed)
                            const ColoredBox(color: Color(0x99000000)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                // 标签位**定高**（= 两行 11px）：条高定死之后，卡内三段的分配
                // 才是确定的，缩略图不会因为标签一行 / 两行之差而每张各高一点。
                SizedBox(
                  height: _recentCardLabelHeight,
                  child: Center(
                    child: Text(
                      label,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.2,
                        color: armed
                            ? danger
                            : (selected
                                  ? primary
                                  : HyperosColors.secondaryText(context)),
                        fontWeight: selected || armed
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 角标画在按压区**之外**：压在卡内的话，点它会连带把壁纸切了。
          // armed 时收起 —— 确认条已经接管，它留着只会让人以为还能再点一次。
          if (removable && !armed)
            Positioned(
              top: 4,
              right: 4,
              child: _WallpaperRemoveBadge(
                onPressed: onRequestRemove,
                tooltip: l10n.wallpaperHistoryRemoveBadgeTooltip,
              ),
            ),
        ],
      ),
    );
  }
}

/// 缩略图右上角的「×」角标（小米相册那套「角标移除」）。
///
/// 刻意做成**看得见的入口**而不是只有长按：移除是不可逆的（图片文件一起删），
/// 藏在隐藏手势后面等于让用户自己发现 + 试错。
class _WallpaperRemoveBadge extends StatelessWidget {
  const _WallpaperRemoveBadge({required this.onPressed, this.tooltip});

  final VoidCallback? onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final badge = MiuixPressable(
      onPressed: onPressed,
      borderRadius: BorderRadius.circular(10),
      // 不加白底：压在照片上时白圆反而更抢眼，半透明黑 + 白 × 才是图库里
      // 那个"角标"该有的分量。
      child: Container(
        width: 22,
        height: 22,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF000000).withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(
          Icons.close_rounded,
          size: 15,
          color: Colors.white,
        ),
      ),
    );
    // 无障碍 / 悬停说明：角标本身只有一颗 15px 的 ×，不配一句说明读屏用户
    // 只能听出"按钮"。
    final label = tooltip;
    if (label == null || label.isEmpty) {
      return badge;
    }
    return Tooltip(message: label, child: badge);
  }
}
