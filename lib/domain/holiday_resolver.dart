import '../models/holiday_entry.dart';

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

