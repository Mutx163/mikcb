import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../domain/month_grid_collapse.dart';
import '../domain/month_view_cache.dart';
import '../domain/month_view_logic.dart';
import '../l10n/app_localizations.dart';
import '../models/timetable_settings.dart';
import '../providers/timetable_provider.dart';
import '../ui/hyperos/hyperos.dart';
import '../ui/hyperos/hyperos_motion.dart';
import '../utils/page_wallpaper_luminance.dart';
import '../widgets/timetable/month_view/month_day_agenda.dart';
import '../widgets/timetable/month_view/month_day_cell.dart';
import '../widgets/timetable/month_view/month_grid.dart';
import '../widgets/timetable/month_view/month_view_toolbar.dart';
import '../widgets/timetable/timetable_page_chrome_shell.dart';
import 'add_course_screen.dart';
import 'add_exam_screen.dart';
import 'add_schedule_item_screen.dart';

/// 月视图页：整月概览 + 选中日议程。
///
/// ## 与周视图 / 日视图同一套观感（用户口径）
///
/// 用户两轮口径：①「你自己评价一下这个页面的观感」；②「月视图的整体样式应该要
/// 跟周视图、日视图保持一致风格，现在差太远了，就像是一个设置里面的二级页面」。
///
/// 所以本页**不再自建外壳**，整页交给 [TimetablePageChromeShell]：
/// 壁纸铺底（真壁纸，不是纯色）、顶栏是首页那套「软件名字 + 右上角玻璃球菜单」、
/// 连续玻璃带盖住标题行与工具行、卡片走 `CourseSurface`（与课程卡同档）。
///
/// 首版曾用 `HyperosSubpage`（设置类二级页外壳：纯色页 + 磨砂大标题），那是
/// 观感跑偏的根因 —— 无论细节怎么调，它读起来都是「设置里的一个页面」。
///
/// ## 性能：三个热点，都在这页身上
///
/// 1. **每帧 42 次全屏 backdrop 抓取**。42 个格子各一张玻璃卡，玻璃档在
///    `CourseSurface` 里是 `BackdropFilter.grouped`；没有 `BackdropGroup` 祖先时
///    每个 filter 各自抓一份全屏（Flutter 的共享是 opt-in）。外壳补上了那个组，
///    并且给了 `PreblurredWallpaperScope` —— 卡片于是改走「贴一张糊好的位图」，
///    连实时模糊都不跑。
/// 2. **每次 setState 重算整月**。翻月、点选日期、provider 任何通知都会让
///    `itemBuilder` 重跑 `buildMonthGrid`（42 格 × 课程全表扫 + 考试全量解析 +
///    84 次假期判定）。现在走 [MonthViewDataCache]：同一份数据只算一次，
///    只算当前页与前后的各一页、且只留三页。
/// 3. **整页宽度刷新**。翻月时 `onPageChanged` 只更新存储值，但 `itemBuilder`
///    每帧仍为相邻页构造 widget —— 网格数据有缓存就只剩「画」，没有就每帧重算。
///
/// ## 数据
///
/// 全部来自 [MonthViewLogic]（纯 Dart 域逻辑，`test/domain/` 覆盖），本页只做：
/// 取 provider 数据 → 调域逻辑 → 画 → 转发点击。
class MonthViewScreen extends StatefulWidget {
  const MonthViewScreen({super.key});

  @override
  State<MonthViewScreen> createState() => _MonthViewScreenState();
}

class _MonthViewScreenState extends State<MonthViewScreen>
    with SingleTickerProviderStateMixin {
  /// 翻月 pager 的页号基准：page = (year - baseYear) * 12 + (month - 1)。
  ///
  /// 取 2000-01 作基准，页号恒为正且足够大，用户不可能翻到边界。
  static const int _baseYear = 2000;
  static const int _pageCount = 200 * 12;

  /// 月网格数据缓存（纯 Dart，见 `month_view_cache.dart`）。
  ///
  /// 挂在 State 上而不是全局：页面销毁就该丢，换配置档重进也从头来（那是新数据，
  /// 缓存本来也会因元素签名变化而全部失效）。
  final MonthViewDataCache _cache = MonthViewDataCache();

  PageController? _pager;

  /// 壁纸亮度采样器（独立页面拿不到首页那份，自己采一次）。
  final PageWallpaperLuminanceSampler _luminance =
      PageWallpaperLuminanceSampler();

  /// 当前聚焦月（年、月），由 pager 页号推导。
  late int _focusedYear;
  late int _focusedMonth;

  /// 选中日；null = 没选（议程区收起）。翻月不自动选中，避免「翻个月
  /// 就被塞一个没看过的日程列表」。
  DateTime? _selectedDate;

  /// 网格展开进度（1 = 全展开、0 = 只留一周），拖拽与吸附共用这一个控制器。
  ///
  /// 长命控制器走 [HyperosMotionPlatform.bindController]：用户中途改「页面
  /// 转场速度」时它能跟着重设时长（否则要杀进程才生效，与日视图展开同一坑）。
  /// 初始 1.0 = 展开（用户没要求记住收起态，进页面看整月是默认预期）。
  late final AnimationController _gridExpand =
      HyperosMotionPlatform.bindController(
        AnimationController(vsync: this, value: 1),
        _kGridCollapseBaseMs,
      );

  /// 拖拽起始进度：松手判「翻面还是弹回」的基准（判据在
  /// `monthGridSettleTarget`）。
  double _gridDragStartValue = 1;

  /// 最近一次布局算出的行高：拖拽行程按「收起的总高度」折算成 1:1 跟手。
  double _gridRowHeight = MonthGrid.minRowHeight;

  /// 收起 / 展开吸附动画的基础时长（毫秒）。
  static const int _kGridCollapseBaseMs = 260;

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
    // 键没变时是一次字符串比较，可以放心每帧依赖变更都调。
    _luminance.pull(context.read<TimetableProvider>().settings, () {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _gridExpand.dispose();
    _luminance.dispose();
    _pager?.dispose();
    super.dispose();
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
    // 整包订阅 provider：本页要读的字段太多（settings + 三份集合 + 活跃时间
    // 模板 + 假期数据），逐个 `context.select` 反而更脆 —— 漏一个就静默不刷新。
    // 真正的开销在「每次通知都重算 42 格」，那已经由 `MonthViewDataCache` 挡掉：
    // 数据没变时取数是纯比较，不重建网格。
    final provider = context.watch<TimetableProvider>();
    final settings = provider.settings;
    final luminance = _luminance.value;

    return TimetablePageChromeShell(
      topLuminance: luminance?.top,
      bodyLuminance: luminance?.body,
      toolbarHeight: kMonthViewToolbarHeight,
      // 工具行做成**独立 widget**（而不是页面里的一个方法）：它的墨色来自
      // `HomePageChromeInk` 作用域（外壳按壁纸亮度判好的极性），只有在外壳
      // 内部 build 才读得到；在页面 build 里读只会拿到 null 并回落主题色，
      // 深色壁纸上就成了看不见的字。
      toolbar: MonthViewToolbar(
        year: _focusedYear,
        month: _focusedMonth,
        isCurrentMonth: _isCurrentMonth,
        onPreviousMonth: () => _shiftMonth(-1),
        onNextMonth: () => _shiftMonth(1),
        onBackToCurrentMonth: _backToCurrentMonth,
      ),
      // 翻月时卡片在动、壁纸钉在屏幕上：预糊纹理必须每帧重取景，
      // 否则玻璃被整块搬走（半边磨砂半边透明）。
      pagingRepaint: _pager,
      body: PageView.builder(
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
            bodyLuminance: luminance?.body,
          );
        },
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
    required double? bodyLuminance,
  }) {
    final now = DateTime.now();
    // 缓存：同一份数据只算一次。键里的三份集合用**元素签名**判失效
    // （provider 的包装表每次都是新实例，按 list 身份判会恒不命中）。
    final grid = _cache.grid(
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

    // 卡片判墨：按**卡面实际亮度**（卡底色压壁纸），与日视图摘要卡同一函数。
    final ink = monthPageInkOverWallpaper(
      context: context,
      settings: settings,
      wallpaperBodyLuminance: bodyLuminance,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // 可用高度里先给议程区留底，剩下全给月网格按行均分：月历是主体，
        // 不许缩成半屏、底下留一大片白（真机截图第一轮就是这个毛病）。
        //
        // 这是「预算」不是「硬约束」：议程更长时整页可滚动兜底，
        // 预算偏小只让网格高一点，不会截断议程。
        const viewportPadding = kMonthPageVerticalPadding;
        final agendaMinHeight = selectedInThisMonth
            ? kMonthAgendaMinHeight
            : kMonthEmptyHintHeight;
        final gridBudget =
            constraints.maxHeight -
            viewportPadding * 2 -
            agendaMinHeight -
            MonthGrid.headerHeight;
        final rowHeight = (gridBudget / 6).clamp(
          MonthGrid.minRowHeight,
          MonthGrid.maxRowHeight,
        );
        // 拖拽行程按这个行高折算（1:1 跟手）；存字段是因为手势回调拿不到
        // LayoutBuilder 的局部量。
        _gridRowHeight = rowHeight;

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
              // 上滑收起 / 下拉展开（用户口径 2026-10-20）：拖拽 1:1 跟手，
              // 松手按 `monthGridSettleTarget` 吸附。手势包在网格上——它与
              // 外层 SingleChildScrollView 的纵向拖拽在同一竞技场，子检测器
              // 先入局获胜 ⇒ 在格子上拖 = 收放，在议程上拖 = 滚动，互不打架。
              // AnimatedBuilder 让动画帧只重建网格这一小块，不牵动整页。
              AnimatedBuilder(
                animation: _gridExpand,
                builder: (context, _) {
                  final dates = [for (final day in grid.days) day.date];
                  return GestureDetector(
                    behavior: HitTestBehavior.deferToChild,
                    onVerticalDragStart: (_) {
                      _gridExpand.stop();
                      _gridDragStartValue = _gridExpand.value;
                    },
                    onVerticalDragUpdate: (details) {
                      final extent =
                          (kMonthGridRowCount - kMonthGridCollapsedRows) *
                          _gridRowHeight;
                      if (extent <= 0) {
                        return;
                      }
                      // 手指向上（dy < 0）= 收起 = 进度减小。
                      _gridExpand.value =
                          (_gridExpand.value + details.delta.dy / extent).clamp(
                            0.0,
                            1.0,
                          );
                    },
                    onVerticalDragEnd: (details) {
                      final target = monthGridSettleTarget(
                        startValue: _gridDragStartValue,
                        currentValue: _gridExpand.value,
                        velocityDy: details.velocity.pixelsPerSecond.dy,
                      );
                      _gridExpand.animateTo(
                        target,
                        duration: _kGridCollapseBaseMs.scaledMs,
                        curve: Curves.easeOutCubic,
                      );
                    },
                    child: MonthGrid(
                      grid: grid,
                      settings: settings,
                      selectedDate: selectedInThisMonth ? selected : null,
                      rowHeight: rowHeight,
                      inkColor: ink,
                      collapseProgress: _gridExpand.value,
                      keptRowIndex: monthGridRowToKeep(
                        dates: dates,
                        year: year,
                        month: month,
                        selectedDate: selectedInThisMonth ? selected : null,
                        today: grid.today,
                      ),
                      onDayTap: (date) {
                        setState(() {
                          // 再点同一天 = 收起议程（与「点同一档 Tab 收起」同口径）。
                          _selectedDate =
                              selectedInThisMonth && _selectedDate == date
                              ? null
                              : date;
                        });
                      },
                    ),
                  );
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
          HyperosPageRoute<void>(builder: (_) => AddExamScreen(exam: row.exam)),
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
