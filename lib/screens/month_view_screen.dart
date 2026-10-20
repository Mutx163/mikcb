import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../domain/month_view_logic.dart';
import '../l10n/app_localizations.dart';
import '../models/timetable_settings.dart';
import '../providers/timetable_provider.dart';
import '../ui/hyperos/hyperos.dart';
import '../widgets/timetable/month_view/month_day_agenda.dart';
import '../widgets/timetable/month_view/month_grid.dart';
import 'add_course_screen.dart';
import 'add_exam_screen.dart';
import 'add_schedule_item_screen.dart';

/// 月视图页：整月概览 + 选中日议程。
///
/// 定位见 `.agents/notes/proposed/feature/2026-10-20-month-view.md`：
/// 回答「这个月哪天有事」，不承担排课网格职责（那是周视图）。点格子 =
/// 在下方展开当日议程，不再跳走——「点月历格子 → 看当天日程列表」是
/// 用户从系统日历带来的肌肉记忆；Google 日历 2025 年动过这条路径引发
/// 大量抗议，用户的答案很明确。
///
/// 数据全部来自 [MonthViewLogic]（纯 Dart 域逻辑，已被 `test/domain/` 覆盖），
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

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedYear = now.year;
    _focusedMonth = now.month;
    _pager = PageController(initialPage: _pageFor(_focusedYear, _focusedMonth));
  }

  @override
  void dispose() {
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
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  void _backToCurrentMonth() {
    final now = DateTime.now();
    final target = _pageFor(now.year, now.month);
    setState(() {
      _focusedYear = now.year;
      _focusedMonth = now.month;
    });
    _pager?.animateToPage(
      target,
      duration: const Duration(milliseconds: 260),
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

    return HyperosSubpage(
      onBack: () => Navigator.pop(context),
      title: Text(l10n.monthViewTitle),
      suffixes: [
        if (!_isCurrentMonth)
          FHeaderAction(
            icon: const Icon(Icons.today_rounded),
            semanticsLabel: l10n.monthViewBackToCurrentMonth,
            onPress: _backToCurrentMonth,
          ),
      ],
      child: PageView.builder(
        controller: _pager,
        itemCount: _pageCount,
        // 翻月只更新存储值，不在 onPageChanged 里 setState 整页重建：
        // 重建会带走「选中日」语义（用户翻到别的月再翻回来，选中日该还在）。
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

    return ListView(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 8,
        // 玻璃坞内嵌宿主会把底部余量注入到 HyperosListView；本页用普通
        // ListView（网格不参与 ScrollReliefScope 的列表内边距提升），
        // 这里显式补上同一份余量，最后一行议程才不会被药丸压住。
        bottom: 24 + GlassDockScrollReliefScope.insetOf(context),
      ),
      children: [
        _buildMonthHeader(
          context: context,
          year: year,
          month: month,
          l10n: l10n,
          onPrevious: () => _shiftMonth(-1),
          onNext: () => _shiftMonth(1),
        ),
        const SizedBox(height: 6),
        MonthGrid(
          grid: grid,
          selectedDate: selectedInThisMonth ? selected : null,
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
          MonthDayAgenda(
            date: selected,
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
      ],
    );
  }

  Widget _buildMonthHeader({
    required BuildContext context,
    required int year,
    required int month,
    required AppLocalizations l10n,
    required VoidCallback onPrevious,
    required VoidCallback onNext,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        IconButton(
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left_rounded),
          tooltip: l10n.monthViewPreviousMonth,
          visualDensity: VisualDensity.compact,
        ),
        Expanded(
          child: Center(
            child: Text(
              l10n.monthViewHeaderTitle(year, month),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
            ),
          ),
        ),
        IconButton(
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right_rounded),
          tooltip: l10n.monthViewNextMonth,
          visualDensity: VisualDensity.compact,
        ),
      ],
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
        // 判定「编辑整系列还是单次」。这里不要再另造系列根类型。
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
}
