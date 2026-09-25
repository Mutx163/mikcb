part of '../timetable_settings_screen.dart';

/// 课程卡片设置。
///
/// 重构前，课卡的属性散在两页三处：统一卡片色在「外观与主题」，表面样式、
/// 显示字段、对齐、冲突表现在「课表显示」，文字色又在「课表显示」页最底部。
/// 用户想改课卡上的任何东西都要先猜它归哪一页。这里按「作用对象」收成一页：
/// 凡是画在课卡上的，都在这。
///
/// **一个刻意的例外：天气**。课卡上的天气行（「周视图课卡」开关）与显示内容
/// （现象/温度/降水概率）都在「天气」页——天气有独立的数据开关、城市与数据来源
/// 署名，它的显示项跟那三件事是一套的；三个位置开关（日视图/周视图/详情弹窗）
/// 拆到两页反而更难找。本页顶部的实时预览仍会画出天气行（跟首页一致）。
class _CourseCardSettingsScreen extends StatefulWidget {
  const _CourseCardSettingsScreen();

  @override
  State<_CourseCardSettingsScreen> createState() =>
      _CourseCardSettingsScreenState();
}

class _CourseCardSettingsScreenState extends State<_CourseCardSettingsScreen> {
  late final TimetableProvider _timetableProvider;
  late TimetableSettings _draft;
  Timer? _autoSaveTimer;
  Future<void> _saveQueue = Future<void>.value();

  static const List<String> _cardColors = [
    '#2563EB',
    '#7C3AED',
    '#059669',
    '#DC2626',
    '#EA580C',
    '#0891B2',
    '#4F46E5',
    '#DB2777',
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
      title: Text(l10n.courseCardSettingsTitle),
      // Fixed week preview above a lower editor list — do not collapse the
      // large title from the editor scroll (preview is not under the bar).
      collapsibleLargeTitle: false,
      child: Column(
        children: [
          // 预览占 4 成、可调项占 6 成：小屏上 50:50 会让下半屏只剩三四行可见。
          Expanded(
            flex: 4,
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              key: const PageStorageKey<String>('course-card-settings-preview'),
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
                    // 本页就是来调卡片玻璃的：让预览里的卡片走真折射，拖下面的
                    // 形状类旋钮（折射/边光/色散）当场看得见（否则预览只有染色会动，
                    // 因为这张缩略图本来拿不到卡片位图）。
                    preblurredCardGlass: true,
                    // 预览要跟首页周网格一致，所以显式把天气源传进去
                    // （预览部件刻意不自己查 provider，导出分享图那条路会绕过它）。
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
                'course-card-settings-editor',
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
      // 显示字段：卡上「显示什么」，一组开关。
      0 => HyperosSectionLabel(text: l10n.courseCardSectionFields),
      1 => HyperosListGroup(
        children: [
          HyperosSwitchTile(
            title: l10n.showCourseNameTitle,
            value: _draft.courseCardShowName,
            onChanged: (value) {
              _updateDraft(_draft.copyWith(courseCardShowName: value));
            },
          ),
          HyperosSwitchTile(
            title: l10n.layoutShowTeacherTitle,
            value: _draft.courseCardShowTeacher,
            onChanged: (value) {
              _updateDraft(_draft.copyWith(courseCardShowTeacher: value));
            },
          ),
          HyperosSwitchTile(
            title: l10n.layoutShowClassroomTitle,
            value: _draft.courseCardShowLocation,
            onChanged: (value) {
              _updateDraft(_draft.copyWith(courseCardShowLocation: value));
            },
          ),
          HyperosSwitchTile(
            title: l10n.layoutShowTimeTitle,
            value: _draft.courseCardShowTime,
            onChanged: (value) {
              _updateDraft(_draft.copyWith(courseCardShowTime: value));
            },
          ),
          HyperosSwitchTile(
            title: l10n.layoutShowTimeLabelsTitle,
            value: _draft.courseCardShowTimeLabels,
            onChanged: _draft.courseCardShowTime
                ? (value) {
                    _updateDraft(
                      _draft.copyWith(courseCardShowTimeLabels: value),
                    );
                  }
                : null,
          ),
          HyperosSwitchTile(
            title: l10n.layoutShowWeeksTitle,
            value: _draft.courseCardShowWeeks,
            onChanged: (value) {
              _updateDraft(_draft.copyWith(courseCardShowWeeks: value));
            },
          ),
          HyperosSwitchTile(
            title: l10n.layoutShowDescriptionTitle,
            value: _draft.courseCardShowDescription,
            onChanged: (value) {
              _updateDraft(_draft.copyWith(courseCardShowDescription: value));
            },
          ),
        ],
      ),
      2 => const HyperosSectionGap(),
      // 排版与字号：卡上「怎么摆」。
      3 => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HyperosSectionLabel(text: l10n.courseCardSectionLayout),
          HyperosListGroup(
            children: [
              HyperosSelectTile<CourseCardSurfaceStyle>(
                // 表面样式副题原为复述标题的零信息文案，随文案治理删除。
                //
                // ⚠️ 选到「液态玻璃」之后的八根调参旋钮**不在这一页**（2026-09-22
                // 起）：它们搬到了「外观编辑 → 材质 → 课程卡片」页 —— 那边改成分页
                // 之后放得下，见 `settings_appearance_editor.dart` 的
                // `_buildCourseCardMaterialPage`。文案与档位仍同源。
                label: l10n.courseCardSurfaceStyleLabel,
                items: {
                  for (final style in CourseCardSurfaceStyle.values)
                    courseCardSurfaceStyleLabel(l10n, style): style,
                },
                value: _draft.courseCardSurfaceStyle,
                onChanged: (value) {
                  _updateDraft(_draft.copyWith(courseCardSurfaceStyle: value));
                },
              ),
              HyperosSelectTile<CourseCardVerticalAlign>(
                label: l10n.layoutVerticalAlignLabel,
                items: {
                  for (final v in CourseCardVerticalAlign.values)
                    courseCardVerticalAlignLabel(l10n, v): v,
                },
                value: _draft.courseCardVerticalAlign,
                onChanged: (value) {
                  _updateDraft(_draft.copyWith(courseCardVerticalAlign: value));
                },
              ),
              HyperosSelectTile<CourseCardHorizontalAlign>(
                label: l10n.layoutHorizontalAlignLabel,
                items: {
                  for (final v in CourseCardHorizontalAlign.values)
                    courseCardHorizontalAlignLabel(l10n, v): v,
                },
                value: _draft.courseCardHorizontalAlign,
                onChanged: (value) {
                  _updateDraft(
                    _draft.copyWith(courseCardHorizontalAlign: value),
                  );
                },
              ),
              HyperosSliderTile(
                title: l10n.layoutCourseCardFontSizeTitle,
                value: _draft.courseCardFontSize,
                min: 7,
                max: 12,
                divisions: 10,
                valueLabel: _draft.courseCardFontSize.toStringAsFixed(1),
                onChanged: (value) => _updateDraft(
                  _draft.copyWith(courseCardFontSize: value),
                  debounce: true,
                ),
              ),
              HyperosSliderTile(
                title: l10n.layoutCompactFontSizeTitle,
                value: _draft.compactFontSize,
                min: 7,
                max: 12,
                divisions: 10,
                valueLabel: _draft.compactFontSize.toStringAsFixed(1),
                onChanged: (value) => _updateDraft(
                  _draft.copyWith(compactFontSize: value),
                  debounce: true,
                ),
              ),
            ],
          ),
        ],
      ),
      4 => const HyperosSectionGap(),
      // 颜色与冲突表现：卡的底色与冲突角标/透明度（非本周课在「课表页面」）。
      5 => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HyperosSectionLabel(text: l10n.courseCardSectionColor),
          HyperosListGroup(
            children: [
              HyperosSwitchTile(
                title: l10n.unifiedCourseCardColorTitle,
                subtitle: l10n.unifiedCourseCardColorSubtitle,
                value: _draft.timetableUseUnifiedCardColor,
                onChanged: (value) {
                  _updateDraft(
                    _draft.copyWith(timetableUseUnifiedCardColor: value),
                  );
                },
              ),
              if (_draft.timetableUseUnifiedCardColor)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                  child: HyperosHexColorChipGroup(
                    colorHexes: _cardColors,
                    selectedHex: _draft.timetableUnifiedCardColor,
                    colorParser: _colorFromHex,
                    onSelectedHex: (color) {
                      _updateDraft(
                        _draft.copyWith(timetableUnifiedCardColor: color),
                      );
                    },
                  ),
                ),
              // 一键重刷全部课程随机配色（同名同色）；上方实时预览立即反映。
              HyperosNavTile(
                title: l10n.courseRecolorTileTitle,
                subtitle: l10n.courseRecolorTileSubtitle,
                onTap: () => showCourseRecolorSheet(context),
              ),
              HyperosSwitchTile(
                title: l10n.layoutShowConflictBadgeTitle,
                value: _draft.showConflictBadgeOnTimetable,
                onChanged: (value) {
                  _updateDraft(
                    _draft.copyWith(showConflictBadgeOnTimetable: value),
                  );
                },
              ),
              HyperosSliderTile(
                title: l10n.layoutConflictOpacityTitle,
                value: _draft.timetableConflictCourseOpacity,
                min: 0.2,
                divisions: 16,
                valueLabel:
                    '${(_draft.timetableConflictCourseOpacity * 100).round()}%',
                onChanged: (value) => _updateDraft(
                  _draft.copyWith(timetableConflictCourseOpacity: value),
                  debounce: true,
                ),
              ),
            ],
          ),
        ],
      ),
      6 => TimetableTextColorSettings(
        settings: _draft,
        scope: TextColorScope.courseCard,
        onChanged: _updateDraft,
      ),
      7 => _SettingsResetTile(
        scope: SettingsResetScope.courseCard,
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
