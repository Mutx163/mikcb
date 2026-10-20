import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../domain/month_view_logic.dart';
import '../l10n/app_localizations.dart';
import '../models/timetable_settings.dart';
import '../providers/timetable_provider.dart';
import '../ui/hyperos/hyperos.dart';
import '../ui/hyperos/hyperos_motion.dart';
import '../utils/home_page_background.dart';
import '../widgets/timetable/month_view/month_day_agenda.dart';
import '../widgets/timetable/month_view/month_grid.dart';
import 'add_course_screen.dart';
import 'add_exam_screen.dart';
import 'add_schedule_item_screen.dart';

/// 月视图页：整月概览 + 选中日议程。
///
/// ## 为什么不用 [HyperosSubpage]
///
/// 用户口径（2026-10-20）：「月视图的整体样式应该要跟周视图、日视图保持一致
/// 风格，现在差太远了，就像是一个设置里面的二级页面一样。」
///
/// [HyperosSubpage] 是**设置类二级页**的外壳（纯色页 + 磨砂标题栏），跟首页
/// 那套「壁纸 + 玻璃卡片」完全不是一个语言。所以本页照日视图的做法自建：
/// 壁纸铺底（[resolveHomePageRegionBackground]）→ 内容浮在上面 → 卡片一律
/// 走 [CourseSurface]（[dayViewContentCardSurfaceStyle]，与课程卡同档），
/// 墨色用 [contentCardInkOverWallpaper] 按卡面实际亮度判。
///
/// 与日视图的唯一差别：日视图是首页的一个内嵌面板（由首页 State 驱动转场与
/// 亮度带），本页是可从菜单/底栏打开的独立页面，所以壁纸亮度需要自己采样
/// （见 [_MonthViewScreenState._sampleWallpaperLuminance]）。
///
/// ## 数据
///
/// 全部来自 [MonthViewLogic]（纯 Dart 域逻辑，`test/domain/` 覆盖），
/// 本页只做：取 provider 数据 → 调域逻辑 → 画 → 转发点击。
class MonthViewScreen extends StatefulWidget {
  const MonthViewScreen({super.key});

  @override
  State<MonthViewScreen> createState() => _MonthViewScreenState();
}

class _MonthViewScreenState extends State<MonthViewScreen> {
  /// 翻月 pager 的页号基准：page = (year - baseYear) * 12 + (month - 1)。
  ///
  /// 取 2000-01 作基准，页号恒为正且足够大，用户不可能翻到边界。
  static const int _baseYear = 2000;
  static const int _pageCount = 200 * 12;

  PageController? _pager;

  /// 当前聚焦月（年、月），由 pager 页号推导。
  late int _focusedYear;
  late int _focusedMonth;

  /// 选中日；null = 没选（议程区收起）。翻月不自动选中，避免「翻个月
  /// 就被塞一个没看过的日程列表」。
  DateTime? _selectedDate;

  /// 壁纸主体亮度（首页同款三带里的 body 带）。null = 还没采到 / 没壁纸，
  /// 判墨回落主题色。
  double? _wallpaperLuminance;
  String? _luminanceKey;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedYear = now.year;
    _focusedMonth = now.month;
    _pager = PageController(initialPage: _pageFor(_focusedYear, _focusedMonth));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sampleWallpaperLuminance();
  }

  @override
  void dispose() {
    _pager?.dispose();
    super.dispose();
  }

  /// 采样壁纸 body 带的亮度，用于判墨。
  ///
  /// 首页由 `WallpaperLuminanceController` 在 State 层统一采样（含首帧预热、
  /// 去抖、失败闸门）；本页是独立页面、拿不到那份状态，所以按同一套口径
  /// 自己采一次：以「壁纸路径 + 对齐/缩放 + 视口」为键，键不变就不重采。
  Future<void> _sampleWallpaperLuminance() async {
    final settings = context.read<TimetableProvider>().settings;
    final path = homePageBackdropKey(settings);
    if (path == null || path.isEmpty) {
      if (_wallpaperLuminance != null || _luminanceKey != null) {
        setState(() {
          _wallpaperLuminance = null;
          _luminanceKey = null;
        });
      }
      return;
    }
    final viewport = MediaQuery.sizeOf(context);
    final key =
        '$path|${settings.homePageWallpaperAlignX}|'
        '${settings.homePageWallpaperAlignY}|${settings.homePageWallpaperScale}|'
        '${viewport.width}x${viewport.height}';
    if (key == _luminanceKey) {
      return;
    }
    final bands = await sampleHomePageWallpaperLuminanceBands(
      path,
      viewportSize: viewport,
      alignX: settings.homePageWallpaperAlignX,
      alignY: settings.homePageWallpaperAlignY,
      scale: settings.homePageWallpaperScale,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _luminanceKey = key;
      _wallpaperLuminance = bands?.body;
    });
  }

  static int _pageFor(int year, int month) =>
      (year - _baseYear) * 12 + (month - 1);

  static (int year, int month) _monthForPage(int page) {
    final zeroBased = page.clamp(0, _pageCount - 1);
    return (_baseYear + zeroBased ~/ 12, zeroBased % 12 + 1);
  }

  void _shiftMonth(int delta) {
    final target = _pageFor(_focusedYear, _focusedMonth) + delta;
    if (target < 0 || target >= _pageCount) {
      return;
    }
    _pager?.animateToPage(
      target,
      duration: 260.scaledMs,
      curve: Curves.easeOutCubic,
    );
  }

  void _backToCurrentMonth() {
    final now = DateTime.now();
    setState(() {
      _focusedYear = now.year;
      _focusedMonth = now.month;
    });
    _pager?.animateToPage(
      _pageFor(now.year, now.month),
      duration: 260.scaledMs,
      curve: Curves.easeOutCubic,
    );
  }

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _focusedYear == now.year && _focusedMonth == now.month;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.watch<TimetableProvider>();
    final settings = provider.settings;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // 与首页同一套壁纸底：有壁纸铺壁纸，没有就是主题底色（不透明）。
    final backgroundVisual = resolveHomePageRegionBackground(
      settings: settings,
      isDark: isDark,
      darkFallback: colorScheme.surface,
      region: HomePageBackgroundScope.timetable,
    );
    final hasBackdrop = backgroundVisual.hasImage;
    // 卡片判墨：按卡面实际亮度（卡底色压壁纸），与日视图摘要卡同一函数。
    final ink = contentCardInkOverWallpaper(
      cardFill: isDark
          ? colorScheme.surface
          : colorScheme.surfaceContainerHighest,
      washAlpha: 0.42,
      configuredHex: null,
      defaultHex: '#000000',
      themeFallback: colorScheme.onSurface,
      hasBackdrop: hasBackdrop,
      wallpaperLuminance: _wallpaperLuminance,
    );

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: homePageBackgroundLayer(
        visual: backgroundVisual,
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _buildTopBar(
                context: context,
                l10n: l10n,
                ink: ink,
                showBackToMonth: !_isCurrentMonth,
                onBackToMonth: _backToCurrentMonth,
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pager,
                  itemCount: _pageCount,
                  // 翻月只更新存储值；重建会带走「选中日」语义
                  // （翻到别的月再翻回来，选中日该还在）。
                  onPageChanged: (page) {
                    final (year, month) = _monthForPage(page);
                    if (year == _focusedYear && month == _focusedMonth) {
                      return;
                    }
                    setState(() {
                      _focusedYear = year;
                      _focusedMonth = month;
                    });
                  },
                  itemBuilder: (context, page) {
                    final (year, month) = _monthForPage(page);
                    return _buildMonthPage(
                      context: context,
                      provider: provider,
                      settings: settings,
                      year: year,
                      month: month,
                      l10n: l10n,
                      ink: ink,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 顶栏：返回 + 年月标题 +（非本月时）回到本月。
  ///
  /// 不用 [HyperosSubpage] 的磨砂大标题——那是设置页的语言。这里照首页顶栏的
  /// 做法：透明底、内容浮在壁纸上、墨色按壁纸亮度判（[ink]）。
  Widget _buildTopBar({
    required BuildContext context,
    required AppLocalizations l10n,
    required Color ink,
    required bool showBackToMonth,
    required VoidCallback onBackToMonth,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_rounded),
            color: ink,
            tooltip: l10n.backToWeekViewAction,
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: () => _shiftMonth(-1),
                  icon: const Icon(Icons.chevron_left_rounded),
                  color: ink.withValues(alpha: 0.8),
                  tooltip: l10n.monthViewPreviousMonth,
                  visualDensity: VisualDensity.compact,
                ),
                Text(
                  l10n.monthViewHeaderTitle(_focusedYear, _focusedMonth),
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: ink,
                  ),
                ),
                IconButton(
                  onPressed: () => _shiftMonth(1),
                  icon: const Icon(Icons.chevron_right_rounded),
                  color: ink.withValues(alpha: 0.8),
                  tooltip: l10n.monthViewNextMonth,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          if (showBackToMonth)
            IconButton(
              onPressed: onBackToMonth,
              icon: const Icon(Icons.today_rounded),
              color: ink,
              tooltip: l10n.monthViewBackToCurrentMonth,
            )
          else
            const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildMonthPage({
    required BuildContext context,
    required TimetableProvider provider,
    required TimetableSettings settings,
    required int year,
    required int month,
    required AppLocalizations l10n,
    required Color ink,
  }) {
    final now = DateTime.now();
    final grid = MonthViewLogic.buildMonthGrid(
      year: year,
      month: month,
      now: now,
      courses: provider.courses,
      scheduleItems: provider.scheduleItems,
      exams: provider.exams,
      settings: settings,
      holidayData: provider.holidayData,
    );
    final selected = _selectedDate;
    final selectedInThisMonth =
        selected != null && selected.year == year && selected.month == month;

    return LayoutBuilder(
      builder: (context, constraints) {
        // 可用高度里先给议程区留底，剩下全给月网格按行均分：月历是主体，
        // 不许缩成半屏、底下留一大片白（真机截图第一轮就是这个毛病）。
        //
        // 这是「预算」不是「硬约束」：议程更长时整页可滚动兜底，
        // 预算偏小只让网格高一点，不会截断议程。
        const viewportPadding = kMonthPageVerticalPadding;
        final agendaMinHeight =
            selectedInThisMonth ? kMonthAgendaMinHeight : kMonthEmptyHintHeight;
        final gridBudget =
            constraints.maxHeight -
            viewportPadding * 2 -
            agendaMinHeight -
            MonthGrid.headerHeight;
        final rowHeight = (gridBudget / 6).clamp(
          MonthGrid.minRowHeight,
          MonthGrid.maxRowHeight,
        );

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            10,
            viewportPadding,
            10,
            // 玻璃坞内嵌宿主的底部余量：滚动到底时议程才不会被药丸压住。
            viewportPadding + GlassDockScrollReliefScope.insetOf(context),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MonthGrid(
                grid: grid,
                settings: settings,
                selectedDate: selectedInThisMonth ? selected : null,
                rowHeight: rowHeight,
                inkColor: ink,
                onDayTap: (date) {
                  setState(() {
                    // 再点同一天 = 收起议程（与「点同一档 Tab 收起」同口径）。
                    _selectedDate = selectedInThisMonth && _selectedDate == date
                        ? null
                        : date;
                  });
                },
              ),
              if (selectedInThisMonth)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: MonthDayAgenda(
                    date: selected,
                    settings: settings,
                    inkColor: ink,
                    rows: MonthViewLogic.buildDayAgenda(
                      date: selected,
                      courses: provider.courses,
                      scheduleItems: provider.scheduleItems,
                      exams: provider.exams,
                      settings: settings,
                      sections: _sectionsFor(provider, settings),
                      now: now,
                    ),
                    onRowTap: (row) => _openAgendaRow(context, row),
                  ),
                )
              else
                MonthAgendaPlaceholder(inkColor: ink),
            ],
          ),
        );
      },
    );
  }

  /// 课程节次 → 作息时间要用的节次表：与日视图同口径（当前生效的时间
  /// 模板优先，缺失回落设置里那份）。
  List<SectionTime> _sectionsFor(
    TimetableProvider provider,
    TimetableSettings settings,
  ) {
    final schemeSections = provider.activeTimeScheme?.sections;
    if (schemeSections != null && schemeSections.isNotEmpty) {
      return schemeSections;
    }
    return settings.sections;
  }

  /// 议程行点击 → 对应编辑/详情去处（与日视图议程卡的去处一致）。
  Future<void> _openAgendaRow(BuildContext context, MonthAgendaRow row) async {
    switch (row.kind) {
      case MonthAgendaRowKind.exam:
        await Navigator.of(context).push<void>(
          HyperosPageRoute<void>(
            builder: (_) => AddExamScreen(exam: row.exam),
          ),
        );
      case MonthAgendaRowKind.schedule:
        final instance = row.schedule;
        if (instance == null) {
          return;
        }
        // 与日视图议程卡同一口径（`day_view_schedule_agenda_card`）：
        // 直接把实例的源条目交给表单，表单自己按 isRecurring / seriesId
        // 判定「编辑整系列还是单次」。
        await Navigator.of(context).push<void>(
          HyperosPageRoute<void>(
            builder: (_) => AddScheduleItemScreen(
              scheduleItem: instance.item,
              occurrenceDate: instance.occurrenceDate,
            ),
          ),
        );
      case MonthAgendaRowKind.course:
        final course = row.course;
        if (course == null) {
          return;
        }
        await Navigator.of(context).push<void>(
          HyperosPageRoute<void>(
            builder: (_) => AddCourseScreen(course: course),
          ),
        );
    }
  }

  /// 页面上下内边距（与首页课程网格的留白接近）。
  static const double kMonthPageVerticalPadding = 8;

  /// 选中日时议程区的预留高度（约两条议程行）。
  static const double kMonthAgendaMinHeight = 108;

  /// 未选中日时底部提示的预留高度。
  static const double kMonthEmptyHintHeight = 40;
}
