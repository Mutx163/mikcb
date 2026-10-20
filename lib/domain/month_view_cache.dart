import '../models/course.dart';
import '../models/exam.dart';
import '../models/holiday_entry.dart';
import '../models/schedule_item.dart';
import '../models/timetable_settings.dart';
import 'month_view_logic.dart';

/// 月视图网格数据的进程内缓存（纯 Dart，无 Flutter / IO 依赖）。
///
/// ## 为什么要这一层
///
/// [MonthViewLogic.buildMonthGrid] 每次都要把可见页的固定 42 格逐日判一遍
/// （星期映射、周次、当天课程与配色、考试过期、日程展开、假期两层语义）。
/// 单次是微秒级，但月视图页的 `setState` 来源不止翻月：点选某天、provider
/// 任一通知（主题、假期、考试、日程……）都会重建整页，于是同一页在用户
/// 什么都没改的情况下被反复重算。缓存把「同一份输入只算一次」这件事钉在
/// 域层，渲染层不必自己判脏。
///
/// ## 失效判据：五份输入的 identity
///
/// 键是 `(year, month, 日历日 now, courses, scheduleItems, exams, settings,
/// holidayData)`，其中五份数据比的是**实例身份**而不是内容：
///
/// - provider 改数据时一律换 list 实例（`courses = [...]` / `List.from(...)`），
///   所以身份变了就等于内容可能变了，这是最省事的正确判据；
/// - 反过来做深比较要遍历全部课程/日程/考试，省下的那点算术还不如比较本身贵，
///   而且会把「内容恰好相同、但对象已换」当成命中——那等于在缓存里替上层
///   猜它想不想刷新，出错时极难查。
///
/// **调用方前提**：必须传稳定的 list 实例。像 `List.unmodifiable(_courses)`
/// 这样每次访问现造一个包装表（`TimetableProvider.courses` 就是这种写法），
/// 身份每次都变，缓存永远不命中——那不是缓存坏了，是键没稳定过。
///
/// [TimetableSettings] 与 [HolidayData] 本就没有值相等语义，身份的语义与
/// 内容变更天然对齐，直接用身份判。
///
/// ## `now` 只按日历日截断
///
/// 键里的 `now` 取 `DateTime(now.year, now.month, now.day)`：网格里唯一用到
/// 时刻的地方是「今天」高亮与考试过期判定，用户对它的预期精度是**天**，
/// 不是秒。
///
/// **由此放宽的口径（刻意，不是 bug）**：同一天里，上午 10 点算出的网格在
/// 晚上 9 点仍然直接复用，于是当天已结束的考试**当天仍显示圆点**，要到
/// 次日第一次取数才消失。若把 `now` 精确到分钟进键，一次 setState 跨过
/// 考试结束时刻就会重算整页——为了圆点晚几个小时消失而让翻月/点选回到卡顿，
/// 这笔交换不值。真要提前，调用 [clear] 即可。
///
/// ## 只留最近 3 个月
///
/// 翻月是连续动作：用户从 10 月翻到 12 月、再翻回来，上一页还得命中；但
/// 无限攒下去等于把走过的每个月的 42 格都留在内存里（一页 42 个
/// [MonthDayEntry]，单个不大，攒一年的量就没必要了）。3 个月够盖住
/// 「上一个月 / 当前月 / 下一个月」这一圈来回翻，且容量是常数。
class MonthViewDataCache {
  /// 最多同时缓存几个月的网格。见类注释「只留最近 3 个月」。
  static const int capacity = 3;

  /// 按「最近使用」排序的缓存表（Dart 的 Map 保持插入顺序）。
  /// 命中的条目在 [grid] 里移到尾部，于是头部恒为最久未用的一条。
  final Map<_MonthGridKey, MonthGridData> _entries =
      <_MonthGridKey, MonthGridData>{};

  /// 取 [year]/[month] 这一页的网格数据：命中返回上次算好的同一个实例，
  /// 未命中就转调 [MonthViewLogic.buildMonthGrid] 并把结果收进缓存。
  ///
  /// 参数含义与失效判据见类注释。返回的 [MonthGridData] 是**共享实例**，
  /// 调用方只读——`days` 已是不可变列表，不要就地改。
  MonthGridData grid({
    required int year,
    required int month,
    required DateTime now,
    required List<Course> courses,
    required List<ScheduleItem> scheduleItems,
    required List<Exam> exams,
    required TimetableSettings settings,
    required HolidayData? holidayData,
  }) {
    final today = DateTime(now.year, now.month, now.day);
    final key = _MonthGridKey(
      year: year,
      month: month,
      today: today,
      courses: courses,
      scheduleItems: scheduleItems,
      exams: exams,
      settings: settings,
      holidayData: holidayData,
    );
    final cached = _entries.remove(key);
    if (cached != null) {
      // 重新插到尾部 = 标记为最近使用；不重新插入的话，翻回来命中的那一页
      // 仍停在队首，下一次插入就会把它当最旧的一条丢掉。
      _entries[key] = cached;
      return cached;
    }
    final built = MonthViewLogic.buildMonthGrid(
      year: year,
      month: month,
      // 传原始 now（不截断）：过期判定按精确时刻算，缓存的放宽只发生在
      // 「同一天内复用旧结果」上，不能在构建时就把精度丢掉。
      now: now,
      courses: courses,
      scheduleItems: scheduleItems,
      exams: exams,
      settings: settings,
      holidayData: holidayData,
    );
    _entries[key] = built;
    while (_entries.length > capacity) {
      _entries.remove(_entries.keys.first);
    }
    return built;
  }

  /// 清空缓存（例如考试结束、跨天刷新等需要立刻重算的场合）。
  void clear() => _entries.clear();
}

/// 缓存键：月份 + 日历日 + 五份输入的身份。
///
/// 单独成类而不是拼字符串：拼串会丢掉「身份」语义（`toString()` 相同并不
/// 代表同一份数据），也挡不住两个不同实例被拼成同一个键。
class _MonthGridKey {
  final int year;
  final int month;

  /// 已截断到日历日的「今天」。
  final DateTime today;

  final List<Course> courses;
  final List<ScheduleItem> scheduleItems;
  final List<Exam> exams;
  final TimetableSettings settings;
  final HolidayData? holidayData;

  const _MonthGridKey({
    required this.year,
    required this.month,
    required this.today,
    required this.courses,
    required this.scheduleItems,
    required this.exams,
    required this.settings,
    required this.holidayData,
  });

  @override
  bool operator ==(Object other) {
    return other is _MonthGridKey &&
        other.year == year &&
        other.month == month &&
        other.today == today &&
        identical(other.courses, courses) &&
        identical(other.scheduleItems, scheduleItems) &&
        identical(other.exams, exams) &&
        identical(other.settings, settings) &&
        identical(other.holidayData, holidayData);
  }

  @override
  int get hashCode => Object.hash(
    year,
    month,
    today,
    identityHashCode(courses),
    identityHashCode(scheduleItems),
    identityHashCode(exams),
    identityHashCode(settings),
    identityHashCode(holidayData),
  );
}
