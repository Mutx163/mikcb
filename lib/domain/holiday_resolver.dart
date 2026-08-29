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
