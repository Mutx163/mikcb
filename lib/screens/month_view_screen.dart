import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../domain/month_grid_collapse.dart';
import '../domain/month_view_cache.dart';
import '../domain/month_view_logic.dart';
import '../domain/week_calculator.dart';
import '../l10n/app_localizations.dart';
import '../models/timetable_settings.dart';
import '../providers/timetable_provider.dart';
import '../ui/hyperos/hyperos.dart';
import '../ui/hyperos/hyperos_motion.dart';
import '../utils/page_wallpaper_luminance.dart';
import '../widgets/timetable/month_view/month_calendar_card.dart';
import '../widgets/timetable/month_view/month_day_agenda.dart';
import '../widgets/timetable/month_view/month_grid.dart';
import '../widgets/timetable/month_view/month_metrics.dart';
import '../widgets/timetable/month_view/month_panel_drag_area.dart';
import '../widgets/timetable/month_view/month_panel_overview.dart';
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

  /// **测试专用**：下一个建出来的页面直接采用这份壁纸读数（跳过解码）。
  ///
  /// 为什么必须有这个口子：测试宿主机没有壁纸文件，`PageWallpaperLuminanceSampler`
  /// 采不到剖面 ⇒ 「页面把逐行亮度传给网格」这条链路在测试里根本走不到，
  /// 于是删掉那行转发测试也不会红（本仓对参数透传类改动有过 43 条用例全绿的
  /// 前车之鉴，见 AGENTS.md）。
  ///
  /// 用例在 `tearDown` 里必须把它清回 null，否则会漏到下一条用例。
  @visibleForTesting
  static PageWallpaperLuminance? debugSeedLuminance;

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

  /// 聚焦月实际要画的行数（4~6）：拖拽行程必须按**这一页**的行数折算。
  ///
  /// 旧实现把行程写死成 `(6 - 1) × 行高`：4/5 行月横竖只缩了 3/4 行，
  /// 手指却要走 5 行 —— 于是"手指动、格子先停"。见 `_updateGridDragDy`。
  int _gridRowCount = kMonthGridRowCount;

  /// 收起 / 展开吸附动画的基础时长（毫秒）。
  static const int _kGridCollapseBaseMs = 260;

  /// 条目面板的滚动控制器。
  ///
  /// 面板要在**任意位置**上下拖动收放表格（用户 2026-10-21 晚口径），而列表
  /// 自己也要滚 —— 两者靠「先收网格、收到底再滚列表」分工，那需要读列表
  /// 的滚动位置，所以控制器提到 State 上。
  final ScrollController _panelScroll = ScrollController();

  /// 面板与列表共享的拖拽状态（谁吃这段位移、回调是谁）。
  ///
  /// 它与传给列表的 [MonthPanelScrollPhysics] **必须是同一个实例**：physics
  /// 的类型恒定、状态全在这个对象里，于是中途改判据不会重建
  /// `ScrollPosition`、正在进行的拖动不会断（理由见该文件的类注释）。
  ///
  /// 判据与实现在 `initState` 里一次性接线，见 [MonthPanelDragState]。
  final MonthPanelDragState _panelDrag = MonthPanelDragState();

  /// 翻月控制器与收放动画的**合并监听**，给预糊位图逐帧重取景用。
  ///
  /// ⚠️ **必须在 State 上建一次**，不能写在 `build` 里。`Listenable.merge`
  /// **没有值相等语义**（Flutter 的 `_MergingListenable` 只包一层 children），
  /// 而 `PreblurredWallpaperScope` 是按 `identical` 判「监听源换了没」的 ——
  /// 每帧新建一个实例就等于每帧判定「换了」，于是 42 个玻璃填充位每帧都在
  /// 拆挂监听器、每帧都 markNeedsPaint（2026-10-21 实测）。
  ///
  /// `_gridExpand` 是延迟初始化的 late final，所以这里也延迟到 [initState]
  /// 第一次读它时再建。
  late final Listenable _pagingRepaint;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedYear = now.year;
    _focusedMonth = now.month;
    _pager = PageController(initialPage: _pageFor(_focusedYear, _focusedMonth));
    // 两条运动源都要接：横向翻月（PageController）+ 纵向收起/展开（动画控制器）。
    // 只接翻页那条，上下收放时玻璃内部背景会纹丝不动（2026-10-21 用户实测）。
    _pagingRepaint = Listenable.merge([_pager, _gridExpand]);
    // 测试专用读数（见 [MonthViewScreen.debugSeedLuminance]）：正常运行时恒为 null。
    final seeded = MonthViewScreen.debugSeedLuminance;
    if (seeded != null) {
      _luminance.seedForTest(seeded);
    }
    // 面板列表与网格收放共用同一套判据与回调：接一次线，之后无论怎么重建
    // 都是同一份（physics 里拿到的就是这个对象，不必每帧新建）。
    _panelDrag
      ..gridCanAbsorb = _gridCanAbsorb
      ..onCollapseStart = _beginGridDrag
      ..onCollapseUpdate = _updateGridDragDy
      ..onCollapseEnd = _endGridDrag;
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
      // ⚠️ toolbar 传 null（月度导航 2026-10-23 已移进日历卡）。
      //
      // 用户口径：「顶部的 2026年10月，左右按钮，回今日区域，看看这些能不能和
      // 下面的日期做一下整体化」。导航原先住在满宽玻璃带里、与下面那张
      // 8dp 外沿 / 24 圆角的日历白卡之间隔着一圈壁纸 —— 而它控制的正是那张卡。
      // 现在它是**卡顶的一行**（见 `MonthCalendarCard.navigator`）。
      //
      // 玻璃带因此回到它本职：只盖"软件名 + 右上角菜单"那一行，
      // 竖向左沿由四条（0/6/8/22）收成一条（22）。
      toolbarHeight: 0,
      // 卡片相对屏幕一动，预糊纹理就必须重取景（否则玻璃里那层背景跟着卡片
      // 走，读起来是"玻璃内部背景不动"）。这里有**两条**运动源，必须都接：
      // 横向翻月（PageController）+ 纵向收起/展开（网格动画控制器）。
      // 只接翻页那条就是 2026-10-21 用户实测到的 bug：左右滑玻璃正常、
      // 上下收放时玻璃内部背景纹丝不动。
      //
      // ⚠️ 用 State 上那份合并实例，不在这里 `Listenable.merge(...)`：
      // 每帧新建会让 scope 每帧判定「监听源换了」，42 个玻璃填充位跟着拆挂
      // 监听器（见 `_pagingRepaint` 的注释）。
      pagingRepaint: _pagingRepaint,
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

    // ⚠️ 本次重构的核心：**不再是「一个滚动视图把网格和议程串起来」**，
    // 而是「网格在上、面板在下」两段式。用户口径（2026-10-21 截图）：
    //   上滑 → 上面几行向上收起、下面几行被下面的东西盖起来、底部出现拉杆；
    //   条目视图不支持左右滑、只支持上下滑（上下滑就是收放网格）；
    //   月份网格支持左右滑（翻月）和上下滑（收放）。
    //
    // ⚠️ **层次顺序（2026-10-21 改）**：`LayoutBuilder` 在外、`AnimatedBuilder`
    // 在内，且动画那块带 `child`。
    //
    // 改前是反的（动画在外、LayoutBuilder 在内、没有 child），于是动画每一帧
    // 都把「LayoutBuilder + PageView + 42 个日期格 + 整个条目面板」重新构建
    // 一遍 —— 真机实测 914 次 build/帧、42 格/帧，而日视图与周视图同一时刻
    // 只有 1 次。用户读到的就是"这页有点卡"。
    //
    // 现在约束（可用宽高）与动画无关，所以 LayoutBuilder 放外层、只跑一次；
    // 里面只有「网格窗口高度」这一个值随动画变，其余（PageView 子树、拉杆、
    // 面板）全部作为 `child` 传进动画块，**不参与逐帧重建**。面板是 `Expanded`，
    // 高度由 Column 自动吃掉剩余空间，不需要跟着动画重建。
    return LayoutBuilder(
      builder: (context, constraints) {
        final dates = [for (final day in grid.days) day.date];
        final keptRow = monthGridRowToKeep(
          dates: dates,
          year: year,
          month: month,
          selectedDate: selectedInThisMonth ? selected : null,
          today: grid.today,
        );
        // 先按展开态算一次，只为拿与动画无关的行高：`monthGridLayout` 的
        // rowHeight 完全不参与 t 的插值（它按「始终 6 行」的可用空间算），
        // 所以展开态那份就是任何时刻那份。
        //
        // 拖拽行程按行高折算（1:1 跟手）；字段是因为手势回调拿不到局部量。
        _gridRowCount = grid.rowsInMonth;
        _gridRowHeight = _layoutFor(
          t: 1,
          constraints: constraints,
          settings: settings,
          keptRow: keptRow,
          rowCount: grid.rowsInMonth,
        ).rowHeight;

        // 卡顶导航行：**只建一次**，作为 `AnimatedBuilder` 之外的稳定节点。
        //
        // 它是 `MonthViewToolbar`（自己订阅 `_pager` 做连续滑动），不需要跟着
        // 网格收放动画重建 —— 每帧重建会让这条 40dp 的行参与那类无谓工作
        //（见类注释「为什么收的是动画」）。
        final navRow = MonthViewToolbar(
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
            // with it"）。导航行比网格先构建，所以这里必须先判 hasClients ——
            // 否则进页面直接崩（本仓 2026-10-21 实测）。
            final pager = _pager;
            if (pager == null || !pager.hasClients) {
              return _pageFor(_focusedYear, _focusedMonth).toDouble();
            }
            return pager.page ??
                _pageFor(_focusedYear, _focusedMonth).toDouble();
          },
          monthOfPage: (page) {
            final (year, month) = _monthForPage(page);
            return (year: year, month: month);
          },
        );

        return Column(
          children: [
            // ── 上半：日历白卡（左右翻月 + 上下收放 + 卡底拉杆）──
            //
            // 动画只改这一层的**高度**：`layout.gridHeight` 随进度从「表头+6 行」
            // 缩到「表头+1 行」。里面的 PageView 与 42 格是稳定 child，
            // 帧内不重建（这是这次提速的全部来源）。
            //
            // ⚠️ 必须给 PageView 一个**明确高度**：它在 Column 里没有约束，
            // 而高度正是「收起」要动的东西。
            //
            // 纵向手势由网格自己接（它只包住网格，不包信息区）；横向交给 PageView。
            // 两者方向正交，同一手势里不会互相抢。
            //
            // 2026-10-23：外面多了一层 `MonthCalendarCard`（白底圆角 + 卡底拉杆），
            // 用户口径是小米日历那种「表格是一张卡、拉杆在卡底」。
            //
            // ⚠️ **高度账**：卡片 = 表格窗口 + 卡底那条拉杆。所以 `SizedBox` 的
            // 高度是 `gridHeight + MonthCalendarCard.chromeHeight` —— 少了后面
            // 这一项，卡片内部的 Column 直接 `RenderFlex overflowed`
            //（2026-10-23 实测）。同一个常量也在 `_layoutFor` 的 handleHeight 里用。
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: MonthMetrics.cardInset,
              ),
              child: AnimatedBuilder(
                // ⚠️ 监听**合并**源（翻月 pager + 收放动画），不再只监听
                // `_gridExpand`：水平滑动途中相邻页会进来，卡片高度得跟着
                // 跨着的两页里较高的那份走，否则 6 行月挨着 5 行月时最后
                // 一行会被裁掉（2026-11 实测：2026-10 是 5 行、11 月是 6 行）。
                //
                // 用 State 上那份 `_pagingRepaint`（横竖两条运动源的合并实例）
                // 而不是在这里现 `Listenable.merge`：每帧新建会让依赖它的
                // 玻璃位图 scope 判定"监听源换了"（见 `_pagingRepaint` 注释）。
                // `child` 仍是整个 PageView 子树，动画帧里不重建它。
                animation: _pagingRepaint,
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
                        constraints: constraints,
                      );
                    },
                  ),
                ),
                builder: (context, child) {
                  // 卡片高度按**当前跨着的两页**里较多的行数算：静止时等于
                  // 聚焦月自己的行数（不留空白），滑动途中取大值（不裁行）。
                  // 判据在 `monthGridCardRowCount`（纯 Dart，test/domain 覆盖）。
                  final cardRowCount = _cardRowCount(
                    provider: provider,
                    settings: settings,
                  );
                  final layout = _layoutFor(
                    t: _gridExpand.value,
                    constraints: constraints,
                    settings: settings,
                    keptRow: keptRow,
                    rowCount: cardRowCount,
                  );
                  return SizedBox(
                    // 表格窗口 + 卡底拉杆 + 卡顶导航行（同一本账，见类注释）。
                    height: layout.gridHeight + MonthCalendarCard.cardChrome,
                    child: MonthCalendarCard(
                      navigator: navRow,
                      onDragStart: _beginGridDrag,
                      onDragUpdate: _updateGridDrag,
                      onDragEnd: _endGridDrag,
                      // 上边距用卡片默认值（`MonthMetrics.cardPadding` = 14）；
                      // 高度账那一侧由 `monthGridLayout(topPadding:)` 算同一段。
                      child: child!,
                    ),
                  );
                },
              ),
            ),
            // ── 下半：信息区（一列独立卡，直接浮在壁纸上）──
            //
            // 2026-10-23：不再是一整块通栏白板（用户口径「单独的卡片，而不是
            // 一个整体大卡片」）。卡片之间的缝里露出壁纸，与上半那张日历卡
            // 读作同一套。
            Expanded(
              child: _buildInfoArea(
                context: context,
                provider: provider,
                settings: settings,
                now: now,
                selectedInThisMonth: selectedInThisMonth,
                selected: selected,
                grid: grid,
              ),
            ),
          ],
        );
      },
    );
  }

  /// 某一份约束 + 某个展开进度下的版面。
  ///
  /// 抽成方法是为了让「展开态算一次拿行高」与「动画帧里算窗口高」走**同一个**
  /// 函数：两处各写一遍就会漂，而漂的症状是收起后仍露出半格（本仓踩过）。
  ///
  /// [rowCount] 是**这一页**实际要画的行数（`MonthGridData.rowsInMonth`，4~6）。
  /// 它必须跟着"哪一页"走：PageView 会同时构建相邻页，而相邻月的行数可能不同
  /// （5 行月挨着 6 行月），共用一份就会让其中一页的窗口高错一整行。
  MonthGridLayout _layoutFor({
    required double t,
    required BoxConstraints constraints,
    required TimetableSettings settings,
    required int keptRow,
    required int rowCount,
  }) {
    return monthGridLayout(
      t: t,
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
      // 本页真实行数：尾部整行都是邻月补位格时不画那一行，行高与窗口高
      // 都按真实行数分摊（2026-10-25，见 `MonthGridData.rowsInMonth`）。
      rowCount: rowCount,
      // 卡内**非表格**的开销（导航行 + 分隔线 + 卡底拉杆）要一次性全扣掉，
      // 否则网格 6 行放不下、溢出。
      //
      // ⚠️ 用 `MonthCalendarCard.cardChrome` 这一个常量，**不要**在这里再拼
      // `navHeight + chromeHeight`：2026-10-23 导航搬进卡后只扣了拉杆那段，
      // 立刻在真机/测试里 `RenderFlex overflowed by 41 pixels`（40 + 1）。
      handleHeight: MonthCalendarCard.cardChrome,
      // 网格外面那层 Padding 的上边距也算进窗口高度，否则内容溢出。
      topPadding: kMonthPageVerticalPadding,
    );
  }

  /// 日历卡高度该按几行算（判据见 [monthGridCardRowCount]）。
  ///
  /// 取 PageView 当前**跨着的两页**里较多的行数：水平滑动途中两页共存，
  /// 只按聚焦月算会把更高那一页的最后一行裁掉（2026-10 是 5 行、
  /// 2026-11 是 6 行，翻过去时 11 月的最后一行被切掉）。停在整页时两页
  /// 相同 ⇒ 静止态严格等于聚焦月自己的行数，不会多留一行空白。
  int _cardRowCount({
    required TimetableProvider provider,
    required TimetableSettings settings,
  }) {
    final fallbackPage = _pageFor(_focusedYear, _focusedMonth).toDouble();
    final pager = _pager;
    // `PageController.page` 在 PageView 尚未构建时会断言失败（与导航行
    // 那处 pageOf 同一坑），所以必须先判 hasClients。
    final pageValue = pager != null && pager.hasClients
        ? (pager.page ?? fallbackPage)
        : fallbackPage;
    return monthGridCardRowCount(
      page: pageValue,
      rowsOfPage: (page) => _rowsInMonthForPage(page, provider, settings),
    );
  }

  /// 某个月页实际要画几行（与 `_buildGridPage` 走同一份缓存，不另算一遍）。
  int _rowsInMonthForPage(
    int page,
    TimetableProvider provider,
    TimetableSettings settings,
  ) {
    final (year, month) = _monthForPage(page);
    return _cache
        .grid(
          year: year,
          month: month,
          now: DateTime.now(),
          courses: provider.courses,
          scheduleItems: provider.scheduleItems,
          exams: provider.exams,
          settings: settings,
          holidayData: provider.holidayData,
        )
        .rowsInMonth;
  }

  /// 上半那一页的网格（不含信息区）。
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
    // 本页的行高：**与展开进度无关**（`monthGridLayout` 按「始终 6 行」的可用
    // 空间算行高，不参与 t 的插值），所以这里取展开态那份即可 —— 收放过程中
    // 格子高度不能变，否则读起来像"字放大了"。
    //
    // ⚠️ 只取 rowHeight，不取 gridHeight：窗口高度由页面那层随动画改的
    // `SizedBox` 负责，网格自己不参与收放。
    final layout = _layoutFor(
      t: 1,
      constraints: constraints,
      settings: settings,
      keptRow: keptRow,
      rowCount: grid.rowsInMonth,
    );

    // 网格自己的左右内边距由 `MonthCalendarCard` 那层负责（`gridInnerPadding`），
    // 这里**不要再加** —— 两层叠加会把格子挤窄，算出的"正方形行高"跟着偏。
    return MonthGrid(
      grid: grid,
      selectedDate: selectedInThisMonth ? selected : null,
      rowHeight: layout.rowHeight,
      // 传**动画**而不是当前值：网格内部自己订阅，42 格因此不参与逐帧重建
      // （这是这次提速的另一半，见 `MonthGrid` 的类注释）。
      progress: _gridExpand,
      keptRowIndex: keptRow,
      onDayTap: (date) {
        // ── 点到月份外的补位格：翻到那个月再选中它 ──
        //
        // 旧实现把 `_selectedDate` 设成邻月的日期，而下半屏的判据是
        // `selectedInThisMonth`（year/month 都要对上）—— 于是点下去
        // **什么都不发生**：下半屏仍是本月概览，格子也不高亮，看起来像
        // 点了个死按钮（2026-10-22 实测：点 9/28 → 议程 0、概览 1）。
        //
        // 用户的意图显然是「我想看那天」，所以现在把它翻过去：先切月，
        // 再选中。`_focusedYear/_focusedMonth` 由 `onPageChanged` 维护，
        // 这里提前设是为了让同一帧就算出正确的 `selectedInThisMonth`。
        if (date.year != year || date.month != month) {
          setState(() {
            _focusedYear = date.year;
            _focusedMonth = date.month;
            _selectedDate = date;
          });
          _pager?.animateToPage(
            _pageFor(date.year, date.month),
            duration: 260.scaledMs,
            curve: Curves.easeOutCubic,
          );
          return;
        }
        setState(() {
          // 再点同一天 = 取消选中（与「点同一档 Tab 收起」同口径）。
          _selectedDate = selectedInThisMonth && _selectedDate == date
              ? null
              : date;
        });
        _resetPanelScroll();
      },
    );
  }

  /// 下半的信息区：一列**独立的卡**，直接浮在壁纸上（2026-10-23）。
  ///
  /// ## 为什么不再是一块白板
  ///
  /// 用户口径：「下面的信息区域也改成这样，单独的卡片，而不是一个整体大卡片」，
  /// 并给了小米日历的截图 —— 那边信息区是一张张分开的白卡，卡与卡之间露出壁纸。
  ///
  /// 旧版式是一整块通栏白板（`ClipPath` + `ColoredBox` + 顶弧），卡都画在板**里
  /// 面**。它带来三个连锁问题：
  ///
  /// 1. 上半是 42 张碎卡、下半是一整块板 —— 两种语言；
  /// 2. 板内的卡必须 `forceSolid`（玻璃会透出屏级壁纸纹理，板拦不住）；
  /// 3. 板底还要一条渐隐带盖住被药丸切开的内容。
  ///
  /// 现在三条一起消失：卡片直接浮在壁纸上，靠 `itemGap` 的缝 + 圆角区分。
  ///
  /// ## ⚠️ 材质必须是**实底**（2026-10-23 第二轮修正）
  ///
  /// 上一版本轮内曾把 `forceSolid` 去掉（理由：卡浮在壁纸上，玻璃采到的正是
  /// 它该透的那层背景）。真机上那是一个错误 —— 用户的壁纸是高饱和彩色斜带，
  /// 半透明卡把壁纸透进来，读起来是"一块模糊的洞"而不是卡；下半因此和上半那张
  /// 实底日历卡成了两种材质。现在信息卡**一律实底**，与日历卡同一档。
  ///
  /// ## 手势：仍然「任意位置上下滑动 = 收放日历」
  ///
  /// 板没了，但 [MonthPanelDragArea] 还在 —— 它包住整个可滚动区域，纵向拖拽
  /// 先收日历、收到底再滚列表。用户 2026-10-21 晚的口径（「底部信息区域，应该
  /// 支持在任意位置上下滑动」）必须保留。
  Widget _buildInfoArea({
    required BuildContext context,
    required TimetableProvider provider,
    required TimetableSettings settings,
    required DateTime now,
    required bool selectedInThisMonth,
    required DateTime? selected,
    required MonthGridData grid,
  }) {
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

    // ⚠️ 这里**不再**需要「卡外文字」的墨色：2026-10-23 起信息区每张卡都自带
    // 标题，所有文字都在卡内，按卡面判墨（见 `monthInfoCardInk`）——
    // 直接压在壁纸上的散字已经没有了，那正是用户说"非常诡异"的一半原因。

    // 玻璃坞内嵌宿主的底部余量：滚到底时最后一张卡不被药丸压住。
    final bottomRelief =
        MonthMetrics.panelBottomInset + GlassDockScrollReliefScope.insetOf(context);

    // ⚠️ 议程卡**必须懒建**：`selected` 在"没选中任何一天"时是 null，而
    // `selected!` 会当场抛 `Null check operator used on a null value`
    //（2026-10-25 实测：概览态整页白屏）。所以这里是函数而不是实例。
    Widget buildAgenda() => MonthDayAgenda(
      date: selected!,
      settings: settings,
      rows: rows,
      onRowTap: (row) => _openAgendaRow(context, row),
      // 选中日什么都没有时，空态卡里给一个加课入口（带这天 +
      // 星期几进表单）：这正是用户最想"补点什么"的时刻。
      onAddCourse: () => _openAddCourseForDate(context, selected, settings),
    );

    final overview = MonthPanelOverview(
      grid: grid,
      settings: settings,
      // 「本月有安排的日子」从今天往后排（跨过月末回月首），
      // 排序口径见 `MonthViewLogic.scheduledDaysOfMonth`。
      upcoming: MonthViewLogic.scheduledDaysOfMonth(grid, today: now),
      // ⚠️ 填满模式：收起日历后信息区变高，列表要**跟着多列几行**，
      // 而不是把那块高度留成空白（旧实现固定 3 行，收起态实测空 304px
      // = 35.7% 屏高，用户看到的是"上面收起来了、下面什么也没多给我"）。
      fillHeight: true,
      onDayTap: (date) {
        setState(() => _selectedDate = date);
        _resetPanelScroll();
      },
    );

    return MonthPanelDragArea(
      scrollController: _panelScroll,
      dragState: _panelDrag,
      // ⚠️ 列表的**用户滚动必须关掉**（2026-10-21 第三轮的核心）。
      //
      // 让 Scrollable 自己滚，它会在"网格收起、列表变高"的瞬间把
      // maxScrollExtent 缩到 0，然后判定不可滚动、当场 goBallistic 结束
      // 整次拖动 —— 实测轨迹 61 → 36 → 11 → 0，同一帧发出 ScrollEndNotification，
      // 此后指针怎么动都不再被处理，网格停在半收起、抬手弹回全展开。
      // 这不是参数问题，是机制冲突。
      //
      // 现在位移由 MonthPanelDragArea 算好、jumpTo 落进来：一个指针源驱动
      // 两块内容，一体化是结构保证的（惯性由它在抬手时补）。
      child: LayoutBuilder(
        builder: (context, constraints) {
          // ── 概览态：内容**填满**可用高度，不做滚动 ──
          //
          // 概览态的内容是"概览卡 + 有安排的日子"，行数由可用高度反推
          // （见 `MonthPanelOverview.fillHeight`），所以它天然不会溢出，
          // 也就不需要滚动视图。包一层 `SizedBox` 把高度**明确**给下去 ——
          // 里面那个 `Expanded` 在无界高度下会直接抛。
          if (!selectedInThisMonth) {
            final inner = constraints.maxHeight -
                MonthMetrics.itemGap -
                bottomRelief;
            return Padding(
              padding: EdgeInsets.fromLTRB(
                MonthMetrics.cardInset,
                MonthMetrics.itemGap,
                MonthMetrics.cardInset,
                bottomRelief,
              ),
              child: SizedBox(
                height: inner < 0 ? 0 : inner,
                child: overview,
              ),
            );
          }

          // ── 议程态：自然高度 + 可滚动 ──
          //
          // 选中日可能有十几节课，高度是不可预知的，所以这一支保持滚动。
          // 它不能走"填满"那条路：把内容撑满反而会让短议程被拉出一堆空白。
          return SingleChildScrollView(
            controller: _panelScroll,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              // 左右内边距 = 卡片外沿，与上半那张日历卡同一条线（见 MonthMetrics）。
              MonthMetrics.cardInset,
              // 卡与日历卡之间那道缝：露出壁纸，"两张卡"才成立。
              MonthMetrics.itemGap,
              MonthMetrics.cardInset,
              bottomRelief,
            ),
            child: buildAgenda(),
          );
        },
      ),
    );
  }

  /// 选中日变化后，把下半信息区的列表**滚回顶部**。
  ///
  /// ## 为什么必须显式做（2026-10-22 实测）
  ///
  /// 面板是「同一个 `SingleChildScrollView` + 同一个 `ScrollController`，只换
  /// child」：概览态 → 议程态换的是 `MonthPanelOverview ⇄ MonthDayAgenda`。
  /// 于是**滚动位置会被带进新内容**：在概览里滚到 240dp 再点某一天，如果那天的
  /// 议程够长（实测 14 节课，max 663dp），面板就停在 240dp —— "10月22日"这个
  /// 标题已经在屏幕外，当天议程从半截开始，用户看到的是一堆不知道属于哪天的课。
  ///
  /// 内容变短时 Flutter 会把 offset 自动钳回 0，所以这个 bug **只在"新内容也够
  /// 长"时暴露** —— 平时点一个只有两节课的日子看不出来，容易漏。
  ///
  /// 放在 `setState` 之后、同一帧内执行：新 child 还没布局，直接 `jumpTo(0)`
  /// 会被随后的布局覆盖。`hasClients` 之外的 `position` 也可能还没建立，所以
  /// 用**下一帧**再落一次（`addPostFrameCallback`），两处都做是保守的：
  /// 有 clients 时当帧生效，没有时由下一帧兜住。
  void _resetPanelScroll() {
    if (_panelScroll.hasClients) {
      _panelScroll.jumpTo(0);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _panelScroll.hasClients && _panelScroll.offset != 0) {
        _panelScroll.jumpTo(0);
      }
    });
  }

  /// 网格还能不能继续往这个方向收放。
  ///
  /// 收起方向（dy < 0）只要还没完全收起就能继续；展开方向（dy > 0）只要
  /// 还没完全展开就能继续。到了边界就必须把位移交还给列表 —— 否则网格早已
  /// 停住、位移却被它吞掉，用户会觉得"手指在动、画面不动"。
  bool _gridCanAbsorb(double dy) {
    if (dy < 0) {
      return _gridExpand.value > 0;
    }
    if (dy > 0) {
      return _gridExpand.value < 1;
    }
    return false;
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
    // 行程 = 这一页真实要收掉的行数 × 行高。旧实现写死 `(6 - 1) × 行高`：
    // 4/5 行月实际只缩 3/4 行，手指却要走满 5 行 —— 表现为「手指还在动、
    // 格子已经停住」。行数由 `_buildMonthPage` 每页写入（`_gridRowCount`）。
    final extent = monthGridDragTravel(
      rowCount: _gridRowCount,
      rowHeight: _gridRowHeight,
    );
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

  /// 空态卡里的「加课」：带着那一天的星期与所在周进表单。
  ///
  /// 空态之所以值得给入口：这一天什么都没排，说完「这天没有安排」就断了 ——
  /// 而用户点进某一天、看见空，往往正是想说「这天要加一节课」。
  ///
  /// 参数口径与首页空格加课一致（`timetable_screen.dart` 那几处）：
  /// `initialDayOfWeek` 传那天的星期，`initialWeek` 传那天的真实周次 ——
  /// 只传星期不传周次的话，课程默认按第 1 周起排，用户从 10 月点进来却把课
  /// 排到了 9 月初（`initialWeek` 存在的全部理由就是这个）。
  /// 学期未配置 / 那天在开学前时 `initialWeek` 为 null，表单自己用默认值。
  ///
  /// ⚠️ [settings] 由调用方传入而**不在这里 `context.read`**：本仓有
  /// 「TimetableProvider 直接读取点只减不增」的架构守卫（基线 230 处），
  /// 多一处 `read` 就会让守卫变红。调用方本来就在 `_buildAgendaPanel` 里
  /// 握着同一个 settings 实例，顺手传下来没有任何额外成本。
  Future<void> _openAddCourseForDate(
    BuildContext context,
    DateTime date,
    TimetableSettings settings,
  ) async {
    final semesterStart = settings.semesterStartDate;
    final weekIndex = semesterStart == null
        ? null
        : WeekCalculator.getWeekIndex(date, semesterStart);
    await Navigator.of(context).push<void>(
      HyperosPageRoute<void>(
        builder: (_) => AddCourseScreen(
          initialDayOfWeek: date.weekday,
          initialWeek: weekIndex,
        ),
      ),
    );
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

  /// 日历卡**内部**的上边距（表头上方那一点呼吸）。
  ///
  /// 旧实现叫 `kMonthPageVerticalPadding = 8`，那是"网格直接铺在页面上"时的
  /// 页面内边距。现在它成了卡片内边距：8dp 在 24 圆角的白卡里等于表头贴着
  /// 卡顶，读起来像内容溢出（2026-10-23 真机截图）。取 14 与卡片左右内边距同值。
  ///
  /// ⚠️ 它与 `monthGridLayout(topPadding:)` 是**同一个数**（那笔账算的是
  /// 网格窗口高度里含多少上边距），两处必须一起改。
  static const double kMonthPageVerticalPadding = 14;
}
