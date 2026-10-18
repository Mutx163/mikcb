/// 桌面小组件的「周末文案」档位判定（纯 Dart，不依赖 Flutter / IO）。
///
/// 为什么**不**把周末算成假期：假期态会连带清空当天的课程列表
/// （`TimetableProvider.isHoliday` 为真时 `_liveBuildHomeWidgetSnapshot` 把
/// `todayCourses` 整个置空），周末有课的人会被抹掉课程。所以这里只做一件事：
/// 在「今天确实一节课都没排」的空位上，把文案换成周末文案，**绝不参与课程过滤**。
///
/// 与安卓侧的对应实现：`WidgetHolidayLogic.kt` 的 `widgetResolveWeekendMood`。
/// 两份必须逐条同口径——App 活着时由 Flutter 算好推给卡片，App 被杀后卡片按
/// SharedPreferences 自己重算，判定不一致会出现「重启后文案变了」。
library;

/// 周末文案档位。
enum WeekendMood {
  /// 不显示周末文案：工作日、周末有课、当天是法定假期。
  none,

  /// 周六/周日且当天一节课都没排 → 「周末愉快」。
  rest,

  /// 周五且今天不再有课、明天是周六/日 → 「周末要开始了」。
  ahead,
}

extension WeekendMoodX on WeekendMood {
  /// 写进快照 JSON 的取值，也是安卓侧解析的同一个字符串。
  String get value => switch (this) {
    WeekendMood.none => 'none',
    WeekendMood.rest => 'rest',
    WeekendMood.ahead => 'ahead',
  };

  /// 从快照 JSON 读回档位；未知值（含老版本快照）一律回落 [WeekendMood.none]。
  static WeekendMood fromValue(String? raw) => switch (raw) {
    'rest' => WeekendMood.rest,
    'ahead' => WeekendMood.ahead,
    _ => WeekendMood.none,
  };
}

/// 判定今天该显示哪档周末文案。
///
/// 参数全部由调用方给死（不在这里查课表、不查假期数据），这样它是个纯函数，
/// 单测可以逐个钉死边界场景，安卓侧也能照着一条条搬过去。
///
/// - [hasAnyCourseToday]：当天**排了**课（含已停课、含本周不上的）。
///   停课也算「排了课」——那种日子卡片照旧走课程呈现（显示「已结束」），
///   不冒充周末。
/// - [hasRemainingCourseToday]：今天还有正在上或还没开始的课。
///   周五的课还没上完时绝不抢屏显示周末文案。
/// - [isHolidayToday]：当天是法定假期/调休休息。假期有自己的文案（假期名），
///   周末文案不叠加。
/// - [isAdjustedWorkdayToday] / [isAdjustedWorkdayTomorrow]：调休补班日。
///   补班的周六日要上班，说「周末愉快」是误导。
WeekendMood resolveWeekendMood({
  required DateTime now,
  required bool hasAnyCourseToday,
  required bool hasRemainingCourseToday,
  required bool isHolidayToday,
  required bool isAdjustedWorkdayToday,
  required bool isAdjustedWorkdayTomorrow,
}) {
  // 法定假期优先：假期态的文案（假期名）比周末文案更具体，不叠加。
  if (isHolidayToday) return WeekendMood.none;

  if (now.weekday >= DateTime.saturday) {
    if (isAdjustedWorkdayToday) return WeekendMood.none;
    // 当天排了课就一律走课程呈现：有课→课，课都停了→「今日已结束」。
    if (hasAnyCourseToday) return WeekendMood.none;
    return WeekendMood.rest;
  }

  // 周五：明天必然是周六或周日（星期是跨月跨年连续的），所以只看明天是不是补班。
  if (now.weekday == DateTime.friday) {
    if (isAdjustedWorkdayTomorrow) return WeekendMood.none;
    if (hasRemainingCourseToday) return WeekendMood.none;
    return WeekendMood.ahead;
  }

  return WeekendMood.none;
}
