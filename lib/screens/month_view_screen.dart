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
import '../widgets/timetable/month_view/month_grid_handle.dart';
import '../widgets/timetable/month_view/month_panel_drag_area.dart';
import '../widgets/timetable/month_view/month_panel_top_curve.dart';
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

  /// 条目面板的滚动控制器。
  ///
  /// 面板要在**任意位置**上下拖动收放表格（用户 2026-10-21 晚口径），而列表
  /// 自己也要滚 —— 两者靠「列表到边界后把剩余位移交给收放」分工，那需要读列表
  /// 的滚动位置，所以控制器提到 State 上。
  final ScrollController _panelScroll = ScrollController();

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
    // 视口先喂给采样器：采样键里带视口段，与首页 chrome 那份**逐字相同**才
    // 可能命中共享缓存（命中 = 首帧就有正确极性 = 不闪）。
    final size = MediaQuery.maybeSizeOf(context);
    if (size != null && size.width > 0 && size.height > 0) {
      _luminance.setViewport(size);
    }
    // 键没变时是一次字符串比较，可以放心每帧依赖变更都调。
    _luminance.pull(context.read<TimetableProvider>().settings, () {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _panelScroll.dispose();
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
        // 标题跟着手指连续滑动：滑到一半能看到两个月份各露一半，
        // 而不是"松手才换"（2026-10-21 重新设计）。
        pageListenable: _pager,
        pageOf: () {
          // ⚠️ `PageController.page` 在 PageView 尚未构建时会**断言失败**
          //（"PageController.page cannot be accessed before a PageView is built
          // with it"）。工具行比网格先构建，所以这里必须先判 hasClients ——
          // 否则进页面直接崩（本仓 2026-10-21 实测）。
          final pager = _pager;
          if (pager == null || !pager.hasClients) {
            return _pageFor(_focusedYear, _focusedMonth).toDouble();
          }
          return pager.page ?? _pageFor(_focusedYear, _focusedMonth).toDouble();
        },
        monthOfPage: (page) {
          final (year, month) = _monthForPage(page);
          return (year: year, month: month);
        },
      ),
      // 卡片相对屏幕一动，预糊纹理就必须重取景（否则玻璃里那层背景跟着卡片
      // 走，读起来是"玻璃内部背景不动"）。这里有**两条**运动源，必须都接：
      // 横向翻月（PageController）+ 纵向收起/展开（网格动画控制器）。
      // 只接翻页那条就是 2026-10-21 用户实测到的 bug：左右滑玻璃正常、
      // 上下收放时玻璃内部背景纹丝不动。
      pagingRepaint: Listenable.merge([_pager, _gridExpand]),
      // ⚠️ 这里**不能**再包一层 PageView。
      //
      // 用户 2026-10-21 实测：「我在日期表格的拉杆下面，还能左右滑动，刚刚都说了
      // 这里只能上下滑动」。根因就是 body 原本是一个包住整页的横向 PageView ——
      // 它把拉杆与下方条目面板一起罩在横向手势里，于是「横向翻月」在整个下半屏
      // 都生效。内层网格那层 PageView 只是第二层，删掉外层才真的只让表格能翻月。
      //
      // 现在 body 只构建**当前聚焦的那一页**；横向翻月由网格自己那层 PageView
      // 负责（它只包住网格那一段高度，拉杆与面板都在它外面）。
      body: _buildMonthPage(
        context: context,
        provider: provider,
        settings: settings,
        year: _focusedYear,
        month: _focusedMonth,
        l10n: l10n,
        bodyLuminance: luminance?.body,
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

    // ⚠️ 本次重构的核心：**不再是「一个滚动视图把网格和议程串起来」**，
    // 而是「网格在上、面板在下」两段式。用户口径（2026-10-21 截图）：
    //   上滑 → 上面几行向上收起、下面几行被下面的东西盖起来、底部出现拉杆；
    //   条目视图不支持左右滑、只支持上下滑（上下滑就是收放网格）；
    //   月份网格支持左右滑（翻月）和上下滑（收放）。
    // ⚠️ AnimatedBuilder 必须包在 LayoutBuilder **外面**：版面（网格窗口高、
    // 面板高）都由展开进度 `_gridExpand` 推出来，只把网格包在 builder 里的话，
    // 窗口高度不会跟着动画变 —— 上滑时格子被裁、面板却不动，读起来是"卡住"。
    return AnimatedBuilder(
      animation: _gridExpand,
      builder: (context, _) => LayoutBuilder(
        builder: (context, constraints) {
          final dates = [for (final day in grid.days) day.date];
          final keptRow = monthGridRowToKeep(
            dates: dates,
            year: year,
            month: month,
            selectedDate: selectedInThisMonth ? selected : null,
            today: grid.today,
          );
          // 版面三件套（网格窗口高 / 面板高 / 内容位移）必须同源算 ——
          // 分开算就会出现「面板盖到哪儿」与「网格顶到哪儿」各说各话，
          // 症状正是收起后仍露出半格。
          final layout = monthGridLayout(
            t: _gridExpand.value,
            availableHeight: constraints.maxHeight,
            headerHeight: MonthGrid.headerHeight,
            horizontalPadding: MonthGrid.horizontalPadding,
            availableWidth: constraints.maxWidth,
            // 与 `MonthGrid` 内部同一判据：学期没配置时周次列根本不占位。
            weekNumberColumnVisible: settings.semesterStartDate != null,
            weekLabelWidth: MonthGrid.weekLabelWidth,
            minRowHeight: MonthGrid.minRowHeight,
            maxRowHeight: MonthGrid.maxRowHeight,
            keptRow: keptRow,
            // 把手夹在网格与面板之间，必须从可用高度里扣掉 —— 否则面板会被
            // 挤出屏幕（Expanded 只吃剩下的空间）。
            handleHeight: MonthGridHandle.extent,
            // 网格外面那层 Padding 的上边距也算进窗口高度，否则内容溢出 8px。
            topPadding: kMonthPageVerticalPadding,
          );
          // 拖拽行程按行高折算（1:1 跟手）；字段是因为手势回调拿不到局部量。
          _gridRowHeight = layout.rowHeight;

          return Column(
            children: [
              // ── 上半：月份网格（左右翻月 + 上下收放）──
              //
              // ⚠️ 必须给 PageView 一个**明确高度**：它在 Column 里没有约束，
              // 而高度正是「收起」要动的东西（layout.gridHeight 随进度从
              // 「表头+6 行」缩到「表头+1 行」）。
              //
              // 纵向手势由网格自己接（它只包住网格，不包面板）；横向交给 PageView。
              // 两者方向正交，同一手势里不会互相抢。
              SizedBox(
                height: layout.gridHeight,
                child: GestureDetector(
                  behavior: HitTestBehavior.deferToChild,
                  onVerticalDragStart: (_) => _beginGridDrag(),
                  onVerticalDragUpdate: _updateGridDrag,
                  onVerticalDragEnd: _endGridDrag,
                  child: PageView.builder(
                    controller: _pager,
                    itemCount: _pageCount,
                    onPageChanged: (page) {
                      final (y, m) = _monthForPage(page);
                      if (y == _focusedYear && m == _focusedMonth) {
                        return;
                      }
                      setState(() {
                        _focusedYear = y;
                        _focusedMonth = m;
                      });
                    },
                    itemBuilder: (context, page) {
                      final (y, m) = _monthForPage(page);
                      return _buildGridPage(
                        context: context,
                        provider: provider,
                        settings: settings,
                        year: y,
                        month: m,
                        bodyLuminance: bodyLuminance,
                        constraints: constraints,
                      );
                    },
                  ),
                ),
              ),
              // ── 中间：表格的把手（属于上面那张表格，不属于下面那个面板）──
              //
              // 归属很重要（用户 2026-10-21 修正）：这根横条被拖动时收放的是
              // **上面的日期表格**，所以它画在表格下沿、在面板容器**之外**。
              // 放进面板里就会读成"底部弹窗的拖拽把手"（iOS bottom sheet 的
              // 既有心智）—— 那把手势归属讲反了。
              MonthGridHandle(
                inkColor: ink,
                onDragStart: _beginGridDrag,
                onDragUpdate: _updateGridDrag,
                onDragEnd: _endGridDrag,
              ),
              // ── 下半：条目面板（自身只纵向滚动，不参与收放）──
              Expanded(
                child: _buildAgendaPanel(
                  context: context,
                  provider: provider,
                  settings: settings,
                  // ⚠️ 这里**不能**传上面那个按壁纸亮度判出来的 `ink`。
                  //
                  // 那个 ink 回答的是「字压在**壁纸**上该用黑还是白」。面板是
                  // 一块**不透明白底**，壁纸在它下面根本看不见 —— 拿壁纸的
                  // 明暗去判面板里的字，暗壁纸会算出白字，于是「10月22日」
                  // 这行标题白字压白底、直接消失（用户 2026-10-21 截图实测）。
                  //
                  // 面板内的字一律跟主题走（`colorScheme.onSurface`）。
                  now: now,
                  selectedInThisMonth: selectedInThisMonth,
                  selected: selected,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 上半那一页的网格（不含面板）。
  ///
  /// ⚠️ **版面必须按这一页自己的保留行算**，不能用外层那份 `layout`：外层那份是
  /// 按「当前聚焦月」的保留行算出来的，横向翻到相邻月时（PageView 会同时构建
  /// 左右页）保留行不同 —— 复用会让相邻页的行数与上移量都错位，滑动过程中看见
  /// 「另一页的格子高度不对」。
  Widget _buildGridPage({
    required BuildContext context,
    required TimetableProvider provider,
    required TimetableSettings settings,
    required int year,
    required int month,
    required double? bodyLuminance,
    required BoxConstraints constraints,
  }) {
    final grid = _cache.grid(
      year: year,
      month: month,
      now: DateTime.now(),
      courses: provider.courses,
      scheduleItems: provider.scheduleItems,
      exams: provider.exams,
      settings: settings,
      holidayData: provider.holidayData,
    );
    final ink = monthPageInkOverWallpaper(
      context: context,
      settings: settings,
      wallpaperBodyLuminance: bodyLuminance,
    );
    final selected = _selectedDate;
    final selectedInThisMonth =
        selected != null && selected.year == year && selected.month == month;
    final dates = [for (final day in grid.days) day.date];
    final keptRow = monthGridRowToKeep(
      dates: dates,
      year: year,
      month: month,
      selectedDate: selectedInThisMonth ? selected : null,
      today: grid.today,
    );
    // 本页自己的版面（与外层同一套判据，只是保留行取本页的）。
    final layout = monthGridLayout(
      t: _gridExpand.value,
      availableHeight: constraints.maxHeight,
      headerHeight: MonthGrid.headerHeight,
      horizontalPadding: MonthGrid.horizontalPadding,
      availableWidth: constraints.maxWidth,
      weekNumberColumnVisible: settings.semesterStartDate != null,
      weekLabelWidth: MonthGrid.weekLabelWidth,
      minRowHeight: MonthGrid.minRowHeight,
      maxRowHeight: MonthGrid.maxRowHeight,
      keptRow: keptRow,
      handleHeight: MonthGridHandle.extent,
      topPadding: kMonthPageVerticalPadding,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        MonthGrid.horizontalPadding,
        kMonthPageVerticalPadding,
        MonthGrid.horizontalPadding,
        0,
      ),
      child: MonthGrid(
        grid: grid,
        settings: settings,
        selectedDate: selectedInThisMonth ? selected : null,
        rowHeight: layout.rowHeight,
        inkColor: ink,
        collapseProgress: _gridExpand.value,
        keptRowIndex: keptRow,
        onDayTap: (date) {
          setState(() {
            // 再点同一天 = 取消选中（与「点同一档 Tab 收起」同口径）。
            _selectedDate = selectedInThisMonth && _selectedDate == date
                ? null
                : date;
          });
        },
      ),
    );
  }

  /// 下半的条目面板：一块实底平面 + 可纵向滚动的列表。
  ///
  /// **不持有拉杆**：那是上面那张日期表格的把手（见调用处的 `MonthGridHandle`）。
  /// 面板在这里的职责只有两件 —— 盖住网格下方的行、以及自己纵向滚动。
  Widget _buildAgendaPanel({
    required BuildContext context,
    required TimetableProvider provider,
    required TimetableSettings settings,
    required DateTime now,
    required bool selectedInThisMonth,
    required DateTime? selected,
  }) {
    // 面板是实底白卡，字跟**主题**走（不跟壁纸）。
    // 详见调用处那段注释：拿壁纸明暗判面板内的字，暗壁纸会判出白字 → 白底上看不见。
    final ink = Theme.of(context).colorScheme.onSurface;
    final rows = selectedInThisMonth && selected != null
        ? MonthViewLogic.buildDayAgenda(
            date: selected,
            courses: provider.courses,
            scheduleItems: provider.scheduleItems,
            exams: provider.exams,
            settings: settings,
            sections: _sectionsFor(provider, settings),
            now: now,
          )
        : const <MonthAgendaRow>[];

    // ⚠️ 上沿那圈弧属于**上面的表格**，不属于这块面板。
    //
    // 用户口径（2026-10-21）：「整个拉杆区域，左右不是有那个圆角吗，他应该是
    // 向上弯的，容器应该是上面的表格，而不是的信息区域」。
    //
    // 首版写的是 `BorderRadius.vertical(top: 16)` —— 那是"下面这块板子从下面
    // 升上来、自己有圆角"的语言（bottom sheet 的心智）。改成用
    // [MonthPanelTopCurveClipper] 画一段**向上凸**的弧：白底从表格下沿开始、
    // 两角向外张开兜住表格，读起来是"表格的白色托底"。
    return ClipPath(
      clipper: const MonthPanelTopCurveClipper(cornerRadius: 28),
      child: ColoredBox(
        // 面板是**实底**：它要把网格下方的行盖住（用户口径「下面两行往上逐渐
        // 被下面的东西盖起来」）。用透明就盖不住。
        color: Theme.of(context).colorScheme.surface,
        // ── 整个面板任意位置都能上下拖动来收放日期表格 ──
        //
        // 用户口径（2026-10-21 晚）：「底部信息区域，应该支持在任意位置上下滑动，
        // 可以操作日期表格的上下收起展开」。
        //
        // 列表自己也要纵向滚动、两者同向，**不能靠手势竞技场分工**（只会有一个
        // 赢家：要么列表永远滚不动、要么面板永远收不起来）。这里改成单一手势源
        // + 分流：纵向拖拽全由 [MonthPanelDragArea] 接管，列表还能滚就喂列表、
        // 到边界后同一次手势里无缝接着收放表格。详见该组件的类注释。
        child: MonthPanelDragArea(
          scrollController: _panelScroll,
          onCollapseStart: _beginGridDrag,
          // 面板里的位移是**原始 dy**（正 = 向下 = 展开）。网格那套
          // `_updateGridDrag` 吃的是同一个方向约定，直接转发。
          onCollapseUpdate: _updateGridDragDy,
          onCollapseEnd: _endGridDrag,
          // 列表照常滚（Scrollable 自己处理）；Listener 只是旁观指针流，
          // 在它滚不动时把剩余位移接过来收放表格 —— 两者不争手势。
          child: SingleChildScrollView(
            controller: _panelScroll,
            physics: const ClampingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              6,
              0,
              6,
              // 玻璃坞内嵌宿主的底部余量：滚到底时列表不被药丸压住。
              8 + GlassDockScrollReliefScope.insetOf(context),
            ),
            child: selectedInThisMonth
                ? MonthDayAgenda(
                    date: selected!,
                    settings: settings,
                    inkColor: ink,
                    rows: rows,
                    onRowTap: (row) => _openAgendaRow(context, row),
                  )
                : MonthAgendaPlaceholder(inkColor: ink),
          ),
        ),
      ),
    );
  }

  /// 开始拖拽：停掉吸附动画，记下起点（判「翻面还是弹回」要用）。
  void _beginGridDrag() {
    _gridExpand.stop();
    _gridDragStartValue = _gridExpand.value;
  }

  /// 拖拽中：手指向上（dy < 0）= 收起 = 进度减小，1:1 跟手。
  void _updateGridDrag(DragUpdateDetails details) =>
      _updateGridDragDy(details.delta.dy);

  /// 同上，但直接吃原始位移（面板那边的分流结果是"一段 dy"，不是 DragUpdateDetails）。
  void _updateGridDragDy(double dy) {
    final extent =
        (kMonthGridRowCount - kMonthGridCollapsedRows) * _gridRowHeight;
    if (extent <= 0) {
      return;
    }
    _gridExpand.value = (_gridExpand.value + dy / extent).clamp(0.0, 1.0);
  }

  /// 松手：按判据吸附到两端。
  void _endGridDrag(DragEndDetails details) {
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
}
