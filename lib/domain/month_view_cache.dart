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
/// ## 失效判据：三份 list 看「元素签名」，两个单对象看 identity
///
/// 键是 `(year, month, 日历日 now, courses, scheduleItems, exams, settings,
/// holidayData)`：
///
/// - **courses / scheduleItems / exams** 比的是 [_listSignature]（长度 + 逐元素
///   哈希），不是整个 list 的 identity；
/// - **settings / holidayData** 比的是 `identical()`；
/// - 年月直比，`now` 见下一节。
///
/// ### 为什么 list 不能比 identity
///
/// `TimetableProvider.courses` 是 `List.unmodifiable(_courses)`：**每次访问都
/// 现造一个新的包装表**，`identical()` 恒为 false。按 list 身份做键，翻月、
/// 点选日期、provider 任意无关通知都会「未命中」，缓存等于没加。日程与考试
/// 两个 getter 是同一个写法，所以三份都要走元素签名。
///
/// ### 为什么元素签名是对的等判据
///
/// `Course` / `Exam` / `ScheduleItem` 都是不可变模型（字段全 final，没有
/// 覆写 `operator ==` / `hashCode`，所以元素的哈希就是身份哈希），改内容一律
/// 换新实例（`copyWith` / 重建 list）。于是：
///
/// - **元素实例不变 ⇔ 内容没变**（模型不可变，同一个实例的字段改不了）；
/// - 包装表新旧无所谓——`List.unmodifiable(backing)` 换了包装，元素还是同一批；
/// - 既不会漏失效（元素换了，签名就变），也不会假失效（翻月/点选时元素是同一批）。
///
/// 反过来做**字段级**深比较（逐条比 `course.name` 之类）没有意义：模型不可变，
/// 字段相等必然同源，而逐字段遍历几十条 × 每次 setState 的开销比 42 格本身还贵。
///
/// **顺序参与签名**：`Object.hashAll` 天然吃顺序。议程区的行序、格子配色
/// `courseColorHexes` 的取色顺序都由 list 顺序决定，同一批元素换个顺序就是
/// 另一份展示结果，必须重算。
///
/// [TimetableSettings] 与 [HolidayData] 没有值相等语义、也不经包装表，仍然是
/// 单对象身份判据：provider 换设置时确实换实例。

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
  ///
  /// 三份 list 可以直接传 provider 那种每次现造的包装表（例如
  /// `List.unmodifiable(_courses)`）：判据看的是元素，不看包装表身份。
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

/// 一组元素的「身份签名」：回答的只有一件事——**是不是同一批元素、同一个顺序**。
///
/// 不用 `List.identityHashCode`（没有这个 API），也不用整个 list 的
/// `identityHashCode`：调用方可能每次现造包装表（provider 的
/// `List.unmodifiable` 就是），包装表身份不稳定但元素是同一批。
///
/// 三个被签名的模型（[Course] / [Exam] / [ScheduleItem]）都是不可变对象且没有
/// 覆写 `==` / `hashCode`，所以 `Object.hashAll` 逐元素取到的就是**身份哈希**：
/// 同一实例必同值，不同实例几乎必不同值。长度单独并进来，是为了让「追加/删除
/// 元素」在哈希层面也立刻分开（`hashAll` 本身也吃长度，这里显式并一次读起来
/// 更清楚，代价可忽略）。
int _listSignature<T>(List<T> items) =>
    Object.hash(items.length, Object.hashAll(items));

/// 缓存键：月份 + 日历日 + 三份 list 的元素签名 + 两个单对象的身份。
///
/// 单独成类而不是拼字符串：拼串要自己造分隔符与转义，且 `toString()` 相同的
/// 两个实例不代表同一份数据；用类 + 显式 `==` 才说得清「什么算同一份输入」。
///
/// **签名在构造时算一次、存成字段**：`==` 与 [hashCode] 都只读这几个 int，因此
/// 两处判据在结构上就是同源的——不存在「改了一处、忘了另一处，测试照样绿」
/// 的余地（这种漏改本仓真踩过一次：早先只在 `==` 里改判据，而 `hashCode`
/// 仍在按身份分桶，判据根本没被调用到）。
class _MonthGridKey {
  final int year;
  final int month;

  /// 已截断到日历日的「今天」。
  final DateTime today;

  /// 三份 list 的元素签名（见 [_listSignature]）。
  final int coursesSignature;
  final int scheduleItemsSignature;
  final int examsSignature;

  final TimetableSettings settings;
  final HolidayData? holidayData;

  _MonthGridKey({
    required this.year,
    required this.month,
    required this.today,
    required List<Course> courses,
    required List<ScheduleItem> scheduleItems,
    required List<Exam> exams,
    required this.settings,
    required this.holidayData,
  }) : coursesSignature = _listSignature(courses),
       scheduleItemsSignature = _listSignature(scheduleItems),
       examsSignature = _listSignature(exams);

  @override
  bool operator ==(Object other) {
    return other is _MonthGridKey &&
        other.year == year &&
        other.month == month &&
        other.today == today &&
        other.coursesSignature == coursesSignature &&
        other.scheduleItemsSignature == scheduleItemsSignature &&
        other.examsSignature == examsSignature &&
        identical(other.settings, settings) &&
        identical(other.holidayData, holidayData);
  }

  @override
  int get hashCode => Object.hash(
    year,
    month,
    today,
    coursesSignature,
    scheduleItemsSignature,
    examsSignature,
    identityHashCode(settings),
    identityHashCode(holidayData),
  );
}
