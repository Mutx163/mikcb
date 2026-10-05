import '../models/holiday_entry.dart';
import 'week_calculator.dart';

/// 节假日展示判定领域服务（纯 Dart，无 Flutter / IO 依赖）。
///
/// 展示策略（解耦阶段 1 自 `TimetableProvider.isHoliday` 收口）：
/// 1. 调休上班日优先级最高——即使是假期覆盖模式也要显示课程；
/// 2. 假期覆盖模式开启时，所有假期都隐藏课程；
/// 3. 假期标记关闭时不隐藏；
/// 4. 其余按 [HolidayData] 判定；数据缺失视为无假期。
class HolidayResolver {
  HolidayResolver._();

  /// [date] 是否为假期（应隐藏课程）。
  static bool isHoliday(
    DateTime date, {
    required HolidayData? data,
    required bool overrideEnabled,
    required bool markingEnabled,
  }) {
    if (data?.isAdjustedWorkday(date) ?? false) return false;
    if (overrideEnabled) return true;
    if (!markingEnabled) return false;
    return data?.isHoliday(date) ?? false;
  }

  /// [date] 是否为调休上班日（需要显示课程）。
  static bool isAdjustedWorkday(DateTime date, {required HolidayData? data}) {
    return data?.isAdjustedWorkday(date) ?? false;
  }
}

/// 把一组假期日期先按日期升序，再切成"连续段"。
///
/// 远程接口**不保证**按日期升序返回。旧实现直接在原顺序上判断
/// `_isConsecutive(current.last, date)`，乱序时一段七天假会被拆成好几组：
/// banner 名字取错组、`groupId` 被分散，之后"调休上班挂到最近的一组"也跟着错
/// （它按 group.first / group.last 算距离，组被切碎后距离就不对了）。
/// 排序是这里正确性的前置条件，不是可选优化。
List<List<DateTime>> groupConsecutiveHolidayDates(List<DateTime> dates) {
  if (dates.isEmpty) return const [];
  // 先去重并归一到"当天 00:00"：远程响应里同一天可能重复出现（多源合并、接口
  // 重发），而重复值与前一天的天数差是 0，会被判成"不连续"从而**新起一组** ——
  // 一段假被拆成两组后，组名、groupId 以及"调休挂到最近的一组"全都会错。
  // 带时分秒的输入也在这里归一，避免同一天的两个时刻被当成两天。
  final byDay = <String, DateTime>{};
  for (final date in dates) {
    byDay.putIfAbsent(
      '${date.year}-${date.month}-${date.day}',
      () => DateTime(date.year, date.month, date.day),
    );
  }
  final sorted = byDay.values.toList()..sort((a, b) => a.compareTo(b));
  final groups = <List<DateTime>>[];
  List<DateTime>? current;
  for (final date in sorted) {
    final previous = current;
    if (previous != null &&
        WeekCalculator.daysBetween(previous.last, date) == 1) {
      previous.add(date);
    } else {
      if (previous != null) groups.add(previous);
      current = [date];
    }
  }
  final last = current;
  if (last != null) groups.add(last);
  return groups;
}

/// 该加载哪几年的节假日数据。
///
/// 判据只有一条：**当前这一周（周一起算）里出现过的年份都必须加载**。
/// 元旦、春节这类跨年假期在数据源里是整段挂在其中某一年的响应里的
/// （本仓库自己的 fixture 就把元旦写成 2026-12-31 / 2027-01-01 / 2027-01-02
/// 一段连续假期，`_nameForGroup` 还为它 special-case 过），所以 2027 年 1 月 1 日
/// 那一周的 12-28..12-31 属于 2026 年。只按 `now.year` 取时，这几天在界面上
/// 不是假期 —— 法定休息日照样排课、也不置灰；而 `refreshHolidayData` 同样只清
/// `now.year` 的缓存，用户手动刷新也自愈不了。
///
/// 同时保留既有意图：学期通常横跨两个学年，十一月之后就把下一年一并取回，
/// 这样往后翻几周也不缺假期数据。结果是旧规则的**超集**，新增的取数只发生在
/// 边界那一周，不会给平时多打一次请求。
Set<int> holidayYearsToLoad(DateTime now) {
  final weekStart = DateTime(
    now.year,
    now.month,
    now.day - (now.weekday - DateTime.monday),
  );
  final weekEnd = weekStart.add(const Duration(days: 6));
  final years = <int>{now.year, weekStart.year, weekEnd.year};
  if (now.month >= 11) {
    years.add(now.year + 1);
  }
  return years;
}

