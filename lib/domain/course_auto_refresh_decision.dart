/// 「课表自动更新」的**判定真源**：什么时机该不该去抓一次新课表。
///
/// 这里只有纯 Dart（不 import flutter），因为它要能被单元测试直接驱动：
/// 「上一次成功是什么时候 → 现在该不该跑」这类逻辑一旦写在页面里，就只能靠
/// 真机调时间验证，而这正是最容易写错、也最难复现的一类。
///
/// ## 三种时机
///
/// * [CourseAutoRefreshMode.everyLaunch]：每次打开软件都抓一次，但带
///   [kCourseAutoRefreshLaunchCooldown] 的冷却——用户切个应用回来不该再抓一遍。
/// * [CourseAutoRefreshMode.intervalHours]：距上次**成功**够 N 小时才抓。
///   「每隔一天」就是 N = 48，不必单开一种模式。
/// * [CourseAutoRefreshMode.dailyAt]：每天固定时刻（本地时间）之后抓一次。
///
/// ## 为什么判据是「上次成功」而不是「上次尝试」
///
/// 判据取「上次成功」+ 独立的失败冷却（[kCourseAutoRefreshRetryCooldown]）：
/// 只看尝试时间的话，一次网络抖动就把整个时间窗推后一整天；只看成功时间、不设
/// 失败冷却，则失败后每次切回前台都重试，教务那边会被反复登录。
library;

/// 自动更新的触发时机。
enum CourseAutoRefreshMode {
  /// 每次打开软件时。
  everyLaunch,

  /// 每隔 N 小时（距上次成功）。
  intervalHours,

  /// 每天固定时刻之后。
  dailyAt,
}

/// 「每次打开」模式的冷却：距上次成功不足这段时间就不再抓。
///
/// 用户开关应用、切前后台都属于「打开软件」；没有冷却的话一小时能抓十几次，
/// 每次都要走一遍教务网页登录，既慢又容易被教务判定异常。
const Duration kCourseAutoRefreshLaunchCooldown = Duration(minutes: 30);

/// 失败后的重试冷却。
///
/// 一次失败（教务维护、断网、需要手动登录）之后不能每次切回前台都重试：
/// 对用户是反复的提示打扰，对教务是反复的登录尝试。冷却期内一律安静等待。
const Duration kCourseAutoRefreshRetryCooldown = Duration(minutes: 30);

/// 间隔模式的小时上下限与默认值。
const int kCourseAutoRefreshMinIntervalHours = 1;
const int kCourseAutoRefreshMaxIntervalHours = 168;
const int kCourseAutoRefreshDefaultIntervalHours = 24;

/// 每天定时的默认时刻（分钟数，从 0 点起算）：07:30。
///
/// 取早上而不是半夜：教务一般在上班后才更新，半夜抓只会抓到昨天的数据；
/// 而大部分人在早上打开软件，7:30 之后第一次打开就能抓到当天的。
const int kCourseAutoRefreshDefaultDailyMinute = 7 * 60 + 30;

/// 把用户给的间隔小时夹进合法区间（存档损坏 / 手改 JSON 都走这里）。
int clampCourseAutoRefreshIntervalHours(int hours) =>
    hours.clamp(kCourseAutoRefreshMinIntervalHours, kCourseAutoRefreshMaxIntervalHours);

/// 把用户给的「一天中的第几分钟」归一成 0..1439。
int clampCourseAutoRefreshDailyMinute(int minuteOfDay) =>
    minuteOfDay.clamp(0, 24 * 60 - 1);

/// 判定结论。
enum CourseAutoRefreshDecision {
  /// 该抓了。
  run,

  /// 还没到点（或冷却中），本次跳过。
  wait,

  /// 用户没开这个功能。
  disabled,
}

/// 自动更新的一份配置（与存储解耦的值对象）。
class CourseAutoRefreshSchedule {
  const CourseAutoRefreshSchedule({
    this.enabled = false,
    this.mode = CourseAutoRefreshMode.everyLaunch,
    this.intervalHours = kCourseAutoRefreshDefaultIntervalHours,
    this.dailyMinuteOfDay = kCourseAutoRefreshDefaultDailyMinute,
  });

  final bool enabled;
  final CourseAutoRefreshMode mode;
  final int intervalHours;

  /// 每天定时的触发时刻，按「0 点起的分钟数」存（7:30 → 450）。
  ///
  /// 存分钟而不是 `"07:30"` 字符串：定时的比较是按时刻算的，字符串每次都要
  /// 解析，解析失败还得决定往哪边兜底。
  final int dailyMinuteOfDay;

  CourseAutoRefreshSchedule copyWith({
    bool? enabled,
    CourseAutoRefreshMode? mode,
    int? intervalHours,
    int? dailyMinuteOfDay,
  }) {
    return CourseAutoRefreshSchedule(
      enabled: enabled ?? this.enabled,
      mode: mode ?? this.mode,
      intervalHours: clampCourseAutoRefreshIntervalHours(
        intervalHours ?? this.intervalHours,
      ),
      dailyMinuteOfDay: clampCourseAutoRefreshDailyMinute(
        dailyMinuteOfDay ?? this.dailyMinuteOfDay,
      ),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'enabled': enabled,
    'mode': mode.name,
    'intervalHours': intervalHours,
    'dailyMinuteOfDay': dailyMinuteOfDay,
  };

  /// 容错解析：任何一项坏了都退回默认值，绝不让一条脏配置把整个功能变成
  /// 「永远不跑」或「每次打开都跑」。
  factory CourseAutoRefreshSchedule.fromJson(Object? raw) {
    if (raw is! Map) {
      return const CourseAutoRefreshSchedule();
    }
    final modeName = raw['mode'];
    final mode = CourseAutoRefreshMode.values.firstWhere(
      (item) => item.name == modeName,
      orElse: () => CourseAutoRefreshMode.everyLaunch,
    );
    final hours = raw['intervalHours'];
    final minute = raw['dailyMinuteOfDay'];
    return CourseAutoRefreshSchedule(
      enabled: raw['enabled'] == true,
      mode: mode,
      intervalHours: clampCourseAutoRefreshIntervalHours(
        hours is int ? hours : kCourseAutoRefreshDefaultIntervalHours,
      ),
      dailyMinuteOfDay: clampCourseAutoRefreshDailyMinute(
        minute is int ? minute : kCourseAutoRefreshDefaultDailyMinute,
      ),
    );
  }
}

/// 判定：现在该不该跑一次自动更新。
///
/// [now] / [lastSuccess] / [lastAttempt] 一律是**同一时区的本地时间**
/// （调用方传 `DateTime.now()` 与从毫秒时间戳还原的本地时间）。
CourseAutoRefreshDecision decideCourseAutoRefresh({
  required CourseAutoRefreshSchedule schedule,
  required DateTime now,
  required DateTime? lastSuccess,
  required DateTime? lastAttempt,
}) {
  if (!schedule.enabled) {
    return CourseAutoRefreshDecision.disabled;
  }

  // 上一次尝试失败（尝试晚于成功）：冷却期内不再打扰。
  final lastAttemptFailed =
      lastAttempt != null &&
      (lastSuccess == null || lastAttempt.isAfter(lastSuccess));
  if (lastAttemptFailed &&
      now.difference(lastAttempt) < kCourseAutoRefreshRetryCooldown) {
    return CourseAutoRefreshDecision.wait;
  }

  switch (schedule.mode) {
    case CourseAutoRefreshMode.everyLaunch:
      if (lastSuccess != null &&
          now.difference(lastSuccess) < kCourseAutoRefreshLaunchCooldown) {
        return CourseAutoRefreshDecision.wait;
      }
      return CourseAutoRefreshDecision.run;

    case CourseAutoRefreshMode.intervalHours:
      if (lastSuccess == null) {
        return CourseAutoRefreshDecision.run;
      }
      return now.difference(lastSuccess) <
              Duration(hours: schedule.intervalHours)
          ? CourseAutoRefreshDecision.wait
          : CourseAutoRefreshDecision.run;

    case CourseAutoRefreshMode.dailyAt:
      final target = mostRecentDailySlot(now, schedule.dailyMinuteOfDay);
      if (lastSuccess == null) {
        return CourseAutoRefreshDecision.run;
      }
      return lastSuccess.isBefore(target)
          ? CourseAutoRefreshDecision.run
          : CourseAutoRefreshDecision.wait;
  }
}

/// 最近一次已经过去的当日时刻（含今天这一档；今天还没到就用昨天那一档）。
///
/// 单独抽出来是因为它是「每天定时」唯一的易错点：跨零点后要用**昨天**的档
/// 去比上次成功，否则 0:00～7:29 这段时间里「今天那一档还没到」会被读成
/// 「已经跑过了」，一整天都不再更新。
DateTime mostRecentDailySlot(DateTime now, int minuteOfDay) {
  final startOfToday = DateTime(now.year, now.month, now.day);
  final todaySlot = startOfToday.add(Duration(minutes: minuteOfDay));
  if (now.isBefore(todaySlot)) {
    return todaySlot.subtract(const Duration(days: 1));
  }
  return todaySlot;
}
