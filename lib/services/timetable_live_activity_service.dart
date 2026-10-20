import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../domain/clock_order.dart';
import '../domain/couple_timetable_logic.dart';
import '../domain/holiday_resolver.dart';
import '../domain/live_activity_logic.dart';
import '../domain/week_calculator.dart';
import '../models/course.dart';
import '../models/exam.dart';
import '../models/holiday_entry.dart';
import '../models/partner_timetable_binding.dart';
import '../models/timetable_profile.dart';
import '../models/timetable_settings.dart';
import 'home_widget_binding_service.dart';
import 'home_widget_service.dart';
import 'home_widget_snapshot_service.dart';
import 'miui_live_activities_service.dart';
import 'stats_widget_service.dart';

/// 超级岛 / 桌面小组件管线的宿主依赖面。
///
/// 由 `TimetableProvider` 侧实现：读课表数据与日期语义、拿原生面服务句柄、
/// 进出 live-surface 门、声明运行态桶。服务不碰 provider 私有字段，可用假端口
/// 单测。
abstract interface class TimetableLiveActivityPort {
  /// 运行态桶（心跳、去重签名、挂起窗口、自检覆盖层）。
  LiveActivityRuntimeState get liveRuntime;

  TimetableSettings get settings;
  List<Course> get courses;
  List<TimetableProfile> get profiles;
  HolidayData? get holidayData;
  String? get currentLiveCourseId;
  set currentLiveCourseId(String? value);
  bool get enableLiveActivitySync;

  TimetableProfile? get activeProfile;
  PartnerTimetableBinding? get partnerBinding;
  bool get hasPartnerBinding;
  TimetableProfile? get partnerProfile;
  int get currentWeek;
  int get currentDateWeek;
  int get currentDayOfWeek;
  Future<void> initialize();
  Future<bool> syncTemporalContext({DateTime? now});
  bool isHoliday(DateTime date);
  bool isAdjustedWorkday(DateTime date);
  HolidayEntry? getHolidayForDate(DateTime date);
  List<Course> getActiveCoursesForDay(int dayOfWeek, {int? week});
  List<Course> getCoursesForDay(int dayOfWeek, {int? week});
  Exam? getNextExam();
  Course resolveCourseDisplayName(Course course);
  int calculateCalendarWeekForDate(DateTime date, {int? fallbackWeek});
  bool isLiveTestingFixture(Course course);
  List<SectionTime>? resolveSectionsForCourse(
    Course course, {
    TimetableSettings? settings,
    DateTime? onDate,
  });
  Future<T> runLiveSurfaceExclusive<T>(Future<T> Function() action);
  void notifyStateChanged();

  MiuiLiveActivitiesService get liveActivitiesService;
  HomeWidgetService get homeWidgetService;
  HomeWidgetSnapshotService get homeWidgetSnapshotService;
  HomeWidgetBindingService get homeWidgetBindingService;
}

/// 超级岛 / 桌面小组件的运行态桶。
///
/// 这里全是「上一次推了什么」的去重状态与心跳句柄：只有本服务写，provider 只在
/// 生命周期边界（dispose、切档案、导入后重推）清。搬进显式对象而不是继续躺在
/// provider 的字段海里，端口就只需要暴露一个 getter。
class LiveActivityRuntimeState {
  /// 30 秒心跳（只在本服务里起停）。
  Timer? timer;

  /// 临时暂停实时同步的截止时间。
  DateTime? suspendedUntil;

  /// 最近一次已推给岛的活动阶段键，用于阶段切换去重。
  String? lastActivityStageKey;

  /// 最近一次成功推送的岛内容签名。
  String? lastLiveSnapshotSignature;

  /// 最近一次成功推送的今日小组件快照签名。
  String? lastHomeWidgetSnapshotSignature;

  /// 绑定卡片（appWidgetId → 专属快照内容签名）的推送去重。
  final Map<int, String> widgetSnapshotSignatures = <int, String>{};

  /// 自检预设课覆盖层：只注入超级岛选课与原生快照路径，绝不写入真实课表
  /// （内存态，重启即清）。
  List<Course> fixtureOverlayCourses = const [];
}

/// 超级岛（实时活动）/ 桌面小组件管线：选课、快照构建、去重推送、心跳与时序。
///
/// 2026-10-20 从 `TimetableProvider` 的 `live_activity_controller.dart` 分片搬出。
/// 写入纪律不变：所有原生面推送都在 [TimetableLiveActivityPort.runLiveSurfaceExclusive]
/// 里串行；“先发改内存去重签名、失败不回退”是刻意的——签名只是下次推送的
/// 比较基准，最坏情况是多推一次快照，而回退会让去重永久错位。
class TimetableLiveActivityService {
  const TimetableLiveActivityService._();

  /// 课末提醒窗口：岛在课结束前 10 分钟切到「即将结束」阶段。
  static const Duration _endReminderWindow = Duration(minutes: 10);


  static String resolveRealTime(
    TimetableLiveActivityPort host,
    Course course,
    bool isStart,
  ) {
    // Diagnostic fixtures intentionally carry temporary free-form clocks. They
    // must exercise the production selection path without mutating a user's
    // active time scheme.
    if (host.isLiveTestingFixture(course)) {
      return isStart ? course.startTime : course.endTime;
    }
    // Live always resolves against the calendar day being evaluated so date
    // rules (e.g. summer timetable) apply for today without being baked into
    // persisted Course clocks.
    final onDate = DateTime.now();
    return LiveActivityLogic.resolveRealTime(
      course,
      isStart,
      host.resolveSectionsForCourse(course, onDate: onDate),
    );
  }

  static DateTime _liveApplyTimeCorrection(TimetableLiveActivityPort host, DateTime dateTime) {
    final correctionSeconds = host.settings.liveTimeCorrectionSeconds;
    if (correctionSeconds == 0) {
      return dateTime;
    }
    return dateTime.add(Duration(seconds: correctionSeconds));
  }

  static DateTime? buildCorrectedCourseDateTime(
    TimetableLiveActivityPort host,
    DateTime date,
    String courseTime,
  ) {
    final base = LiveActivityLogic.buildCourseDateTime(date, courseTime);
    if (base == null) {
      return null;
    }
    return _liveApplyTimeCorrection(host, base);
  }

  static DateTime? _liveResolveBeforeClassBlockedUntil(
    TimetableLiveActivityPort host,
    List<Course> todayCourses,
    int courseIndex,
    DateTime referenceDate,
  ) {
    if (courseIndex <= 0 || courseIndex >= todayCourses.length) {
      return null;
    }

    final course = todayCourses[courseIndex];
    final courseStartTime = buildCorrectedCourseDateTime(
      host,
      referenceDate,
      resolveRealTime(host, course, true),
    );
    if (courseStartTime == null) {
      return null;
    }

    DateTime? blockedUntil;
    for (var i = 0; i < courseIndex; i++) {
      final previousCourse = todayCourses[i];
      final previousStartTime = buildCorrectedCourseDateTime(
        host,
        referenceDate,
        resolveRealTime(host, previousCourse, true),
      );
      final previousEndTime = buildCorrectedCourseDateTime(
        host,
        referenceDate,
        resolveRealTime(host, previousCourse, false),
      );
      if (previousStartTime == null || previousEndTime == null) {
        continue;
      }
      if (previousStartTime.isAfter(courseStartTime)) {
        continue;
      }
      if (blockedUntil == null || previousEndTime.isAfter(blockedUntil)) {
        blockedUntil = previousEndTime;
      }
    }

    return blockedUntil;
  }

  static List<String> _liveBuildHolidayDatesForSnapshot(TimetableLiveActivityPort host) {
    if (!host.settings.enableHolidayMarking || host.holidayData == null) {
      return const [];
    }
    // Full HolidayData.isHoliday semantics (custom makeup beats statutory hide).
    // Do not use TimetableProvider.isHoliday: holidayOverride is sent separately.
    return host.holidayData!.holidayDateKeysForSnapshot();
  }

  /// Makeup days that must punch through native [holidayOverrideEnabled].
  static List<String> _liveBuildAdjustedWorkdayDatesForSnapshot(TimetableLiveActivityPort host) {
    if (host.holidayData == null) {
      return const [];
    }
    return host.holidayData!.adjustedWorkdayDateKeysForSnapshot();
  }

  static void startActivityTick(TimetableLiveActivityPort host) {
    host.liveRuntime.timer?.cancel();
    unawaited(host.syncTemporalContext());
    unawaited(updateActivity(host));
    _liveScheduleActivityTick(host);
  }

  static Future<void> handleAppResumed(TimetableLiveActivityPort host) async {
    host.liveRuntime.timer?.cancel();
    // 续排必须放在 finally：本函数一开始就无条件摘掉了 30 秒心跳，而
    // `syncTemporalContext()` 与 `_runLiveSurfaceExclusive(...)` 都会外抛
    // （季节日期规则到点批量套用时 `schedule_date_rule_repository.dart:141-146`
    // 对 saveProfiles 是 catch→回滚→rethrow；`StorageService._setStringChecked`
    // 在 commit 返回 false 时抛 `StateError('storage_write_failed')`；原生通道
    // 调用也可能 MissingPluginException）。原先重排只写在 happy path 末句，
    // 一旦抛出就永久没有心跳 —— 而 `handleAppResumed`
    // （timetable_provider.dart:645-659）把异常吞进日志
    // `live_activity_resume_recovery_failed`，用户看不到任何提示。
    // 后果覆盖整个会话：跨日/跨周不再切周次、超级岛不再随课程边界切换、
    // 桌面卡片的刷新触发点不再补排，只能杀 App 恢复
    // （`_liveScheduleActivityTick` 全仓只有两个调用点：:161 与这里）。
    try {
      await host.syncTemporalContext();
      // Clear + push under one exclusive section so a concurrent WebDAV apply
      // cannot interleave a half-updated native snapshot.
      await host.runLiveSurfaceExclusive(() async {
        host.liveRuntime.lastLiveSnapshotSignature = null;
        host.currentLiveCourseId = null;
        await updateActivityBody(host);
      });
    } finally {
      _liveScheduleActivityTick(host);
    }
  }

  /// 测试缝：30 秒心跳当前是否挂着。
  ///
  /// 回归钉 `test/providers/live_activity_resume_tick_test.dart` —— 要钉的就是
  /// 「回前台链路抛错之后心跳仍在」，没有别的观察点（`_liveActivityTimer` 是私有字段，
  /// 而整页 pump 在本仓会挂死）。
  @visibleForTesting
  static bool hasLiveActivityTickForTesting(TimetableLiveActivityPort host) =>
      host.liveRuntime.timer?.isActive == true;

  static void _liveScheduleActivityTick(TimetableLiveActivityPort host) {
    // Timer 的回调跑在**创建它的那个 Zone**里，而写锁的"同一 Zone 可重入"
    // 判据读的正是 Zone 里的 token（sync_operation_gate.dart:19/24）。
    // 本函数有一条会被持锁 Zone 调到的路径：`_init()` 抛错时
    // `_initializationFuture` 被重置（timetable_provider.dart:576-578），
    // 于是下一次用户写入会在 `_runMutation` 内重跑 `_init` →
    // `_bootstrapHolidayAwareSurfaces` → `startActivityTick` → 这里。
    // 那样这个 30 秒 tick 就永久带着 token：它每次调的
    // `syncTemporalContext()`（内部走 `_runMutation`）命中
    // `isHeldByCurrentZone` → `Future.sync` 立即执行、完全不排队，
    // 跨日/跨周 tick 覆写 `_currentWeek` 与全量 profiles 时就能与
    // 真正持锁的写入交错 —— 丢写且没有任何报错。
    // 用 Zone.root 建表，回调落回无 token 的普通 Zone，门重新生效。
    host.liveRuntime.timer = Zone.root.run(
      () => Timer.periodic(const Duration(seconds: 30), (_) {
        unawaited(host.syncTemporalContext());
        checkActivityStageTransition(host);
      }),
    );
  }

  static void checkActivityStageTransition(TimetableLiveActivityPort host) {
    final selection = getActivityCourseSelection(host);
    final liveCourse = selection?.currentCourse;
    if (liveCourse == null || selection == null) {
      if (host.liveRuntime.lastActivityStageKey != null ||
          host.currentLiveCourseId != null) {
        host.liveRuntime.lastActivityStageKey = null;
        host.currentLiveCourseId = null;
        unawaited(updateActivity(host));
      }
      return;
    }

    final key = LiveActivityLogic.buildStageTransitionKey(selection);
    if (host.liveRuntime.lastActivityStageKey != null &&
        host.liveRuntime.lastActivityStageKey != key) {
      host.currentLiveCourseId = null;
      unawaited(updateActivity(host));
    }
    host.liveRuntime.lastActivityStageKey = key;
  }

  static void seedTrackingForTesting(
    TimetableLiveActivityPort host, {
    String? lastStageKey,
    String? currentCourseId,
  }) {
    host.liveRuntime.lastActivityStageKey = lastStageKey;
    host.currentLiveCourseId = currentCourseId;
  }

  static Future<void> updateActivityForTesting(
    TimetableLiveActivityPort host, {
    bool syncScheduleSnapshot = true,
  }) => updateActivity(host, syncScheduleSnapshot: syncScheduleSnapshot);

  /// Comparator that orders live candidates by their resolved (corrected) start
  /// time. Preset fixture courses carry free-form clocks, so section order alone
  /// is not chronological once the overlay is merged in.
  static int _liveCompareByResolvedStart(
    TimetableLiveActivityPort host,
    DateTime referenceDate,
    Course a,
    Course b,
  ) {
    final aStart = buildCorrectedCourseDateTime(
      host,
      referenceDate,
      resolveRealTime(host, a, true),
    );
    final bStart = buildCorrectedCourseDateTime(
      host,
      referenceDate,
      resolveRealTime(host, b, true),
    );
    if (aStart == null || bStart == null) {
      if (aStart == null && bStart == null) {
        return a.startSection.compareTo(b.startSection);
      }
      return aStart == null ? 1 : -1;
    }
    return aStart.compareTo(bStart);
  }

  static LiveActivityCourseSelection? getActivityCourseSelection(
    TimetableLiveActivityPort host, {
    DateTime? now,
    bool allowUpcomingFallback = false,
    int? week,
  }) {
    final currentTime = now ?? DateTime.now();
    // Selection must honor holiday semantics; do not rely solely on the stop
    // branch in updateActivityBody (tick/stage paths call selection first).
    if (host.isHoliday(currentTime)) {
      return null;
    }
    final targetWeek = week ?? host.calculateCalendarWeekForDate(currentTime);
    var todayCourses = host.getActiveCoursesForDay(
      currentTime.weekday,
      week: targetWeek,
    );
    final fixtureCourses = host.liveRuntime.fixtureOverlayCourses
        .where(
          (course) =>
              course.dayOfWeek == currentTime.weekday &&
              course.isActiveInWeek(targetWeek),
        )
        .toList(growable: false);
    if (fixtureCourses.isNotEmpty) {
      // 自检预设课与真实课同场竞争：按解析后的开始时间统一排序，真实课照常优先。
      todayCourses = [...todayCourses, ...fixtureCourses]
        ..sort((a, b) => _liveCompareByResolvedStart(host, currentTime, a, b));
    }
    if (todayCourses.isEmpty) {
      return null;
    }

    for (var i = 0; i < todayCourses.length; i++) {
      final course = todayCourses[i];
      final startTime = buildCorrectedCourseDateTime(
        host,
        currentTime,
        resolveRealTime(host, course, true),
      );
      final endTime = buildCorrectedCourseDateTime(
        host,
        currentTime,
        resolveRealTime(host, course, false),
      );
      if (startTime == null || endTime == null) {
        continue;
      }

      final aheadTime = startTime.subtract(
        Duration(minutes: host.settings.liveShowBeforeClassMinutes),
      );
      final blockedUntil = _liveResolveBeforeClassBlockedUntil(
        host,
        todayCourses,
        i,
        currentTime,
      );
      final effectiveAheadTime =
          blockedUntil != null && blockedUntil.isAfter(aheadTime)
          ? blockedUntil
          : aheadTime;
      final stage = LiveActivityLogic.resolveLiveActivityStage(
        currentTime: currentTime,
        startTime: startTime,
        endTime: endTime,
        aheadTime: effectiveAheadTime,
        settings: host.settings,
        endReminderWindow: _endReminderWindow,
      );
      if (stage != null) {
        final nextCourse = i + 1 < todayCourses.length
            ? todayCourses[i + 1]
            : null;
        return LiveActivityCourseSelection(
          currentCourse: host.resolveCourseDisplayName(course),
          nextCourse: nextCourse == null
              ? null
              : host.resolveCourseDisplayName(nextCourse),
          stage: stage,
        );
      }
    }

    if (!allowUpcomingFallback || !host.settings.liveEnableBeforeClass) {
      return null;
    }

    for (var i = 0; i < todayCourses.length; i++) {
      final course = todayCourses[i];
      final startTime = buildCorrectedCourseDateTime(
        host,
        currentTime,
        resolveRealTime(host, course, true),
      );
      if (startTime == null || !startTime.isAfter(currentTime)) {
        continue;
      }
      final blockedUntil = _liveResolveBeforeClassBlockedUntil(
        host,
        todayCourses,
        i,
        currentTime,
      );
      if (blockedUntil != null && currentTime.isBefore(blockedUntil)) {
        continue;
      }

      final nextCourse = i + 1 < todayCourses.length ? todayCourses[i + 1] : null;
      return LiveActivityCourseSelection(
        currentCourse: host.resolveCourseDisplayName(course),
        nextCourse: nextCourse == null
            ? null
            : host.resolveCourseDisplayName(nextCourse),
        stage: LiveActivityStage.beforeClass,
      );
    }

    return null;
  }

  static LiveActivityCourseSelection? getTestActivityCourseSelection(
    TimetableLiveActivityPort host, {
    DateTime? now,
  }) {
    final currentTime = now ?? DateTime.now();
    final targetWeek = host.calculateCalendarWeekForDate(currentTime);
    final immediateSelection = getActivityCourseSelection(host, 
      now: currentTime,
      allowUpcomingFallback: true,
      week: targetWeek,
    );
    if (immediateSelection != null) {
      return immediateSelection;
    }

    final today = DateTime(currentTime.year, currentTime.month, currentTime.day);
    final maxWeek = host.courses.isEmpty
        ? targetWeek
        : host.courses
              .map((course) => course.endWeek)
              .reduce((a, b) => a > b ? a : b);

    Course? bestCourse;
    DateTime? bestStartTime;
    int? bestWeek;

    for (final course in host.courses) {
      for (var week = targetWeek; week <= maxWeek; week++) {
        if (!course.isInWeek(week)) {
          continue;
        }

        final dayOffset =
            (week - targetWeek) * 7 + course.dayOfWeek - currentTime.weekday;
        if (dayOffset < 0) {
          continue;
        }

        final candidateDate = today.add(Duration(days: dayOffset));
        final candidateStart = buildCorrectedCourseDateTime(
          host,
          candidateDate,
          resolveRealTime(host, course, true),
        );
        if (candidateStart == null || !candidateStart.isAfter(currentTime)) {
          continue;
        }

        if (bestStartTime == null || candidateStart.isBefore(bestStartTime)) {
          bestCourse = course;
          bestStartTime = candidateStart;
          bestWeek = week;
        }
        break;
      }
    }

    final fallbackStage = LiveActivityLogic.preferredTestStage(host.settings);
    if (bestCourse == null || bestWeek == null || fallbackStage == null) {
      return null;
    }
    final resolvedWeek = bestWeek;

    final sameDayCourses =
        host.courses
            .where(
              (course) =>
                  course.dayOfWeek == bestCourse!.dayOfWeek &&
                  course.isInWeek(resolvedWeek),
            )
            .toList()
          ..sort((a, b) => a.startSection.compareTo(b.startSection));
    final currentIndex = sameDayCourses.indexWhere(
      (course) => course.id == bestCourse!.id,
    );
    final nextCourse =
        currentIndex != -1 && currentIndex + 1 < sameDayCourses.length
        ? sameDayCourses[currentIndex + 1]
        : null;

    return LiveActivityCourseSelection(
      currentCourse: host.resolveCourseDisplayName(bestCourse),
      nextCourse: nextCourse == null
          ? null
          : host.resolveCourseDisplayName(nextCourse),
      stage: fallbackStage,
    );
  }

  static HomeWidgetSnapshot? buildHomeWidgetSnapshot(
    TimetableLiveActivityPort host, {
    DateTime? now,
  }) {
    final profile = host.activeProfile;
    if (profile == null) {
      return null;
    }

    final currentTime = now ?? DateTime.now();
    // Must use calendar week (no semesterWeekCount clamp). Clamping to the last
    // teaching week after the term ends would revive endWeek=N courses forever.
    final targetWeek = host.calculateCalendarWeekForDate(currentTime);
    final originalTodayCount = host
        .getCoursesForDay(currentTime.weekday, week: targetWeek)
        .length;
    final todayIsHoliday = host.isHoliday(currentTime);
    final todayCourses = todayIsHoliday
        ? const <Course>[]
        : host
              .getActiveCoursesForDay(currentTime.weekday, week: targetWeek)
              .map(host.resolveCourseDisplayName)
              .toList(growable: false);

    final tomorrow = currentTime.add(const Duration(days: 1));
    final tomorrowWeek = host.calculateCalendarWeekForDate(tomorrow);
    final tomorrowIsHoliday = host.isHoliday(tomorrow);
    final tomorrowCourses = tomorrowIsHoliday
        ? const <Course>[]
        : host
              .getActiveCoursesForDay(tomorrow.weekday, week: tomorrowWeek)
              .map(host.resolveCourseDisplayName)
              .toList(growable: false);

    final holidayEntry = host.getHolidayForDate(currentTime);
    // 周末文案档位用：调休补班的周六日是上班日，卡片不能说「周末愉快」。
    final todayIsAdjustedWorkday = host.isAdjustedWorkday(currentTime);
    final tomorrowIsAdjustedWorkday = host.isAdjustedWorkday(tomorrow);

    return host.homeWidgetSnapshotService.build(
      profileId: profile.id,
      profileName: profile.name,
      currentWeek: targetWeek,
      settings: host.settings,
      todayCourses: todayCourses,
      now: currentTime,
      countdownLeadMinutes: host.settings.widgetCountdownLeadMinutes,
      countdownTextStyle: host.settings.widgetCountdownTextStyle.value,
      nextExam: host.getNextExam(),
      isHoliday: todayIsHoliday,
      holidayName: todayIsHoliday ? holidayEntry?.name : null,
      tomorrowCourses: tomorrowCourses,
      tomorrowWeek: tomorrowWeek,
      tomorrowDayOfWeek: tomorrow.weekday,
      showTomorrowCourses: host.settings.widgetShowTomorrowCourses,
      originalTodayCourseCount: todayIsHoliday ? 0 : originalTodayCount,
      isAdjustedWorkdayToday: todayIsAdjustedWorkday,
      isAdjustedWorkdayTomorrow: tomorrowIsAdjustedWorkday,
    );
  }

  /// 按任意课表（含 TA 课表）构建桌面卡片快照，与上面的 active 路径平行：
  /// 周次/课程/节假日开关/外观设置全部取自 [profile] 自身，而非当前课表。
  /// active 路径不能直接委托这里——active 的内存态课程可能尚未 flush 回
  /// profile 列表，两者的数据源语义不同。
  static HomeWidgetSnapshot? buildHomeWidgetSnapshotForProfile(
    TimetableLiveActivityPort host,
    TimetableProfile profile, {
    DateTime? now,
  }) {
    final currentTime = now ?? DateTime.now();
    final settings = profile.settings;
    // Must use calendar week (no semesterWeekCount clamp), same as active path.
    final targetWeek = WeekCalculator.calendarWeekForDate(
      currentTime,
      semesterStart: settings.semesterStartDate,
      fallback: profile.currentWeek,
    );
    List<Course> coursesForDay(int dayOfWeek, int week, {required bool activeOnly}) {
      return profile.courses
          .where(
            (course) =>
                course.dayOfWeek == dayOfWeek &&
                (activeOnly ? course.isActiveInWeek(week) : course.isInWeek(week)),
          )
          .toList()
        ..sort((a, b) => a.startSection.compareTo(b.startSection));
    }

    final originalTodayCount =
        coursesForDay(currentTime.weekday, targetWeek, activeOnly: false).length;
    final todayIsHoliday = HolidayResolver.isHoliday(
      currentTime,
      data: host.holidayData,
      overrideEnabled: settings.holidayOverrideEnabled,
      markingEnabled: settings.enableHolidayMarking,
    );
    final todayCourses = todayIsHoliday
        ? const <Course>[]
        : coursesForDay(currentTime.weekday, targetWeek, activeOnly: true);

    final tomorrow = currentTime.add(const Duration(days: 1));
    final tomorrowWeek = WeekCalculator.calendarWeekForDate(
      tomorrow,
      semesterStart: settings.semesterStartDate,
      fallback: profile.currentWeek,
    );
    final tomorrowIsHoliday = HolidayResolver.isHoliday(
      tomorrow,
      data: host.holidayData,
      overrideEnabled: settings.holidayOverrideEnabled,
      markingEnabled: settings.enableHolidayMarking,
    );
    final tomorrowCourses = tomorrowIsHoliday
        ? const <Course>[]
        : coursesForDay(tomorrow.weekday, tomorrowWeek, activeOnly: true);

    final holidayEntry = host.getHolidayForDate(currentTime);
    final upcomingExams = profile.exams.where((exam) => !exam.isExpired).toList()
      ..sort(Exam.compareByStart);
    final nextExam = upcomingExams.isEmpty ? null : upcomingExams.first;
    // 周末文案档位用（同上）：绑定课表走 profile 自己的节假日开关，
    // 但调休补班标记没有开关，只认全局假期数据。
    final todayIsAdjustedWorkday = HolidayResolver.isAdjustedWorkday(
      currentTime,
      data: host.holidayData,
    );
    final tomorrowIsAdjustedWorkday = HolidayResolver.isAdjustedWorkday(
      tomorrow,
      data: host.holidayData,
    );

    return host.homeWidgetSnapshotService.build(
      profileId: profile.id,
      profileName: profile.name,
      currentWeek: targetWeek,
      settings: settings,
      todayCourses: todayCourses,
      now: currentTime,
      countdownLeadMinutes: settings.widgetCountdownLeadMinutes,
      countdownTextStyle: settings.widgetCountdownTextStyle.value,
      nextExam: nextExam,
      isHoliday: todayIsHoliday,
      holidayName: todayIsHoliday ? holidayEntry?.name : null,
      tomorrowCourses: tomorrowCourses,
      tomorrowWeek: tomorrowWeek,
      tomorrowDayOfWeek: tomorrow.weekday,
      showTomorrowCourses: settings.widgetShowTomorrowCourses,
      originalTodayCourseCount: todayIsHoliday ? 0 : originalTodayCount,
      isAdjustedWorkdayToday: todayIsAdjustedWorkday,
      isAdjustedWorkdayTomorrow: tomorrowIsAdjustedWorkday,
    );
  }

  /// 情侣合并视图某一天的课程：我的当前课表为主表（沿用 active 路径的
  /// 地点规则/别名解析），叠加 TA 课表按周偏移映射后的同天课程；同行程
  /// （同时段、同名、双方各自周次有效）按我的那份去重（与 App 内情侣
  /// 覆盖层同口径），其余 TA 课程追加，全部按情侣三色（我/TA/一起）着色
  /// 后按起始节次排序。TA 未绑定或课表不存在时返回空列表。
  static List<Course> _liveCoupleMergedDayCourses(
    TimetableLiveActivityPort host, {
    required int dayOfWeek,
    required int myWeek,
  }) {
    final partnerProfile = host.partnerProfile;
    final binding = host.partnerBinding;
    if (partnerProfile == null || binding == null) {
      return const <Course>[];
    }
    final partnerWeek = CoupleTimetableLogic.partnerWeekForMyWeek(
      myWeek,
      binding.weekOffset,
    );
    final mine = host
        .getActiveCoursesForDay(dayOfWeek, week: myWeek)
        .map(host.resolveCourseDisplayName)
        .toList(growable: false);
    final partner =
        partnerProfile.courses.where((course) => course.dayOfWeek == dayOfWeek && course.isActiveInWeek(partnerWeek)).toList()
          ..sort((a, b) => a.startSection.compareTo(b.startSection));
    String colorFor(CoupleCourseKind kind) =>
        CoupleTimetableLogic.colorHexForKind(
          kind,
          mineColorHex: binding.mineColorHex,
          partnerColorHex: binding.partnerColorHex,
          togetherColorHex: binding.togetherColorHex,
        );
    final merged = <Course>[];
    final usedPartnerIds = <String>{};
    for (final course in mine) {
      var hasTogetherPartner = false;
      for (final candidate in partner) {
        if (CoupleTimetableLogic.isTogetherClass(
          course,
          candidate,
          week: myWeek,
          partnerWeekOffset: binding.weekOffset,
        )) {
          hasTogetherPartner = true;
          usedPartnerIds.add(candidate.id);
          break;
        }
      }
      merged.add(
        course.copyWith(
          color: colorFor(
            hasTogetherPartner ? CoupleCourseKind.together : CoupleCourseKind.mine,
          ),
        ),
      );
    }
    for (final course in partner) {
      if (usedPartnerIds.contains(course.id)) {
        continue;
      }
      merged.add(course.copyWith(color: colorFor(CoupleCourseKind.partner)));
    }
    return merged..sort((a, b) {
      final bySection = a.startSection.compareTo(b.startSection);
      if (bySection != 0) {
        return bySection;
      }
      // 同一节次内的次序按分钟数比：钟点串可能来自外来存档（`9:00` 不补零），
      // 字典序下 '10:00' < '9:00' 会把情侣合并后的同节次课程排反。
      return compareClockText(a.startTime, b.startTime);
    });
  }

  /// TA 侧某天「含停课」的原始课程数：与 active 路径的 originalTodayCount
  /// 同口径（isInWeek 含停课），供快照区分「没课」与「课全停了」。
  static int _livePartnerOriginalCourseCount(
    TimetableLiveActivityPort host, {
    required int dayOfWeek,
    required int myWeek,
  }) {
    final partnerProfile = host.partnerProfile;
    final binding = host.partnerBinding;
    if (partnerProfile == null || binding == null) {
      return 0;
    }
    final partnerWeek = CoupleTimetableLogic.partnerWeekForMyWeek(
      myWeek,
      binding.weekOffset,
    );
    return partnerProfile.courses
        .where(
          (course) =>
              course.dayOfWeek == dayOfWeek && course.isInWeek(partnerWeek),
        )
        .length;
  }

  /// 情侣课表（合并视图）绑定卡片的快照：学期/节假日/考试/外观/周次标签
  /// 全部锚定我方（与 App 内情侣覆盖层一致——考试提醒、超级岛等都挂在
  /// 「当前课表」上），课程为 [_liveCoupleMergedDayCourses] 的合并结果。
  /// TA 解绑或课表不存在时返回 null，调用方清掉专属快照即回落「跟随当前
  /// 课表」。
  static HomeWidgetSnapshot? buildCoupleMergedHomeWidgetSnapshot(
    TimetableLiveActivityPort host, {
    DateTime? now,
  }) {
    final myProfile = host.activeProfile;
    if (myProfile == null ||
        !host.hasPartnerBinding ||
        host.partnerProfile == null) {
      return null;
    }

    final currentTime = now ?? DateTime.now();
    // Must use calendar week (no semesterWeekCount clamp), same as active path.
    final targetWeek = host.calculateCalendarWeekForDate(currentTime);
    final originalTodayCount =
        host.getCoursesForDay(currentTime.weekday, week: targetWeek).length +
        _livePartnerOriginalCourseCount(
          host,
          dayOfWeek: currentTime.weekday,
          myWeek: targetWeek,
        );
    final todayIsHoliday = host.isHoliday(currentTime);
    final todayCourses = todayIsHoliday
        ? const <Course>[]
        : _liveCoupleMergedDayCourses(
            host,
            dayOfWeek: currentTime.weekday,
            myWeek: targetWeek,
          );

    final tomorrow = currentTime.add(const Duration(days: 1));
    final tomorrowWeek = host.calculateCalendarWeekForDate(tomorrow);
    final tomorrowIsHoliday = host.isHoliday(tomorrow);
    final tomorrowCourses = tomorrowIsHoliday
        ? const <Course>[]
        : _liveCoupleMergedDayCourses(
            host,
            dayOfWeek: tomorrow.weekday,
            myWeek: tomorrowWeek,
          );

    final holidayEntry = host.getHolidayForDate(currentTime);
    // 周末文案档位用（同 active 路径）。
    final todayIsAdjustedWorkday = host.isAdjustedWorkday(currentTime);
    final tomorrowIsAdjustedWorkday = host.isAdjustedWorkday(tomorrow);

    return host.homeWidgetSnapshotService.build(
      profileId: kHomeWidgetCoupleMergedBindingId,
      profileName: myProfile.name,
      currentWeek: targetWeek,
      settings: host.settings,
      todayCourses: todayCourses,
      now: currentTime,
      countdownLeadMinutes: host.settings.widgetCountdownLeadMinutes,
      countdownTextStyle: host.settings.widgetCountdownTextStyle.value,
      nextExam: host.getNextExam(),
      isHoliday: todayIsHoliday,
      holidayName: todayIsHoliday ? holidayEntry?.name : null,
      tomorrowCourses: tomorrowCourses,
      tomorrowWeek: tomorrowWeek,
      tomorrowDayOfWeek: tomorrow.weekday,
      showTomorrowCourses: host.settings.widgetShowTomorrowCourses,
      originalTodayCourseCount: todayIsHoliday ? 0 : originalTodayCount,
      isAdjustedWorkdayToday: todayIsAdjustedWorkday,
      isAdjustedWorkdayTomorrow: tomorrowIsAdjustedWorkday,
    );
  }

  /// 为所有绑定了非当前课表的卡片同步专属快照，返回这些卡片的刷新触发点
  /// （与当前课表的触发点取并集用）。绑定课表已消失（含情侣课表 TA 解绑）
  /// 时清掉专属快照，渲染侧会回落「跟随当前课表」。
  static Future<Set<int>> _liveSyncBoundWidgetSnapshots(
    TimetableLiveActivityPort host,
    DateTime now,
  ) async {
    final instances = await host.homeWidgetBindingService.listTodayWidgetInstances();
    final boundInstances = instances
        .where((instance) => instance.boundProfileId != null)
        .toList(growable: false);
    if (boundInstances.isEmpty) {
      return const <int>{};
    }

    final triggers = <int>{};
    for (final instance in boundInstances) {
      final appWidgetId = instance.appWidgetId;
      final isCoupleBinding =
          instance.boundProfileId == kHomeWidgetCoupleMergedBindingId;
      final profile = isCoupleBinding
          ? null
          : host.profiles
              .where((candidate) => candidate.id == instance.boundProfileId)
              .firstOrNull;
      if (profile == null && !isCoupleBinding) {
        await host.homeWidgetBindingService.clearWidgetSnapshot(appWidgetId);
        host.liveRuntime.widgetSnapshotSignatures.remove(appWidgetId);
        continue;
      }
      final snapshot = isCoupleBinding
          ? buildCoupleMergedHomeWidgetSnapshot(host, now: now)
          : buildHomeWidgetSnapshotForProfile(host, profile!, now: now);
      if (snapshot == null) {
        await host.homeWidgetBindingService.clearWidgetSnapshot(appWidgetId);
        host.liveRuntime.widgetSnapshotSignatures.remove(appWidgetId);
        continue;
      }
      final signature = jsonEncode(snapshot.toDedupJson());
      if (host.liveRuntime.widgetSnapshotSignatures[appWidgetId] != signature) {
        final synced = await host.homeWidgetBindingService.syncWidgetSnapshot(
          appWidgetId,
          snapshot,
        );
        if (synced) {
          host.liveRuntime.widgetSnapshotSignatures[appWidgetId] = signature;
        }
      }
      if (snapshot.state != HomeWidgetSnapshotState.holiday) {
        final triggerCourses = isCoupleBinding
            ? _liveCoupleMergedDayCourses(
                host,
                dayOfWeek: now.weekday,
                myWeek: snapshot.currentWeek,
              )
            : profile!.courses
                .where(
                  (course) =>
                      course.dayOfWeek == now.weekday &&
                      course.isActiveInWeek(snapshot.currentWeek),
                )
                .toList(growable: false);
        triggers.addAll(
          host.homeWidgetSnapshotService.buildRefreshTriggers(
            todayCourses: triggerCourses,
            now: now,
            showCountdown: snapshot.showCountdown,
            state: snapshot.state.value,
            countdownLeadMinutes: isCoupleBinding
                ? host.settings.widgetCountdownLeadMinutes
                : profile!.settings.widgetCountdownLeadMinutes,
          ),
        );
      }
    }
    return triggers;
  }

  static Future<void> updateActivity(
    TimetableLiveActivityPort host, {
    bool syncScheduleSnapshot = true,
  }) {
    return host.runLiveSurfaceExclusive(
      () => updateActivityBody(
        host,
        syncScheduleSnapshot: syncScheduleSnapshot,
      ),
    );
  }

  static Future<void> updateActivityBody(
    TimetableLiveActivityPort host, {
    bool syncScheduleSnapshot = true,
  }) async {
    // 自检预设课全部结束后立刻摘除覆盖层，让随后的快照同步与选课回到纯真实数据。
    disarmFixtureCoursesIfFinished(host, DateTime.now());
    await syncHomeWidgetSnapshot(host);
    if (!host.enableLiveActivitySync) {
      return;
    }

    final suspendedUntil = host.liveRuntime.suspendedUntil;
    if (suspendedUntil != null) {
      if (DateTime.now().isBefore(suspendedUntil)) {
        return;
      }
      host.liveRuntime.suspendedUntil = null;
    }

    if (syncScheduleSnapshot) {
      // 形参 syncScheduleSnapshot 与静态方法同名，这里显式限定到类。`n      await TimetableLiveActivityService.syncScheduleSnapshot(host);
    }

    if (host.isHoliday(DateTime.now())) {
      host.currentLiveCourseId = null;
      host.liveRuntime.lastActivityStageKey = null;
      await host.liveActivitiesService.stopLiveUpdate();
      return;
    }

    final selection = getActivityCourseSelection(host);
    final liveCourse = selection?.currentCourse;

    if (liveCourse != null) {
      final activeSelection = selection!;
      final settings = host.settings;
      final displaySettings =
          activeSelection.stage == LiveActivityStage.beforeClass
          ? settings.beforeClassDisplaySettings
          : settings.duringEndDisplaySettings;
      final nextCourse = activeSelection.nextCourse;
      final nextCourseKey = nextCourse != null
          ? '${nextCourse.id}:${nextCourse.name}:${nextCourse.startSection}'
          : 'null';
      final liveActivityKey =
          '${liveCourse.id}:${activeSelection.stage.name}:${liveCourse.name}:${liveCourse.startSection}:${liveCourse.endSection}:${liveCourse.location}:${liveCourse.teacher}:$nextCourseKey:${settings.hashCode}';
      if (host.currentLiveCourseId == liveActivityKey) {
        return;
      }
      host.currentLiveCourseId = liveActivityKey;

      final displayCourse = liveCourse.copyWith(
        startTime: resolveRealTime(host, liveCourse, true),
        endTime: resolveRealTime(host, liveCourse, false),
      );
      final displayNextCourse = activeSelection.nextCourse?.copyWith(
        startTime: resolveRealTime(host, activeSelection.nextCourse!, true),
        endTime: resolveRealTime(host, activeSelection.nextCourse!, false),
      );
      final startAtMillis = buildCorrectedCourseDateTime(
        host,
        DateTime.now(),
        resolveRealTime(host, displayCourse, true),
      )?.millisecondsSinceEpoch;
      final endAtMillis = buildCorrectedCourseDateTime(
        host,
        DateTime.now(),
        resolveRealTime(host, displayCourse, false),
      )?.millisecondsSinceEpoch;
      final sections = host.resolveSectionsForCourse(
        displayCourse,
        onDate: DateTime.now(),
      );
      final progressMilestones = LiveActivityLogic.buildLiveProgressMilestones(
        displayCourse,
        sections,
        startAtMillis: startAtMillis,
        endAtMillis: endAtMillis,
      );
      final progressBreakOffsetsMillis =
          LiveActivityLogic.buildLiveProgressBreakOffsetsMillis(
            displayCourse,
            sections,
            startAtMillis: startAtMillis,
            endAtMillis: endAtMillis,
          );

      await host.liveActivitiesService.startLiveUpdate(
        displayCourse,
        displayNextCourse,
        stage: selection.stage.name,
        validateAgainstSchedule: true,
        beforeClassLeadMillis: settings.liveShowBeforeClassMinutes * 60000,
        startAtMillis: startAtMillis,
        endAtMillis: endAtMillis,
        liveClassReminderStartMinutes: settings.liveClassReminderStartMinutes,
        endSecondsCountdownThreshold: settings.liveEndSecondsCountdownThreshold,
        promoteDuringClass:
            activeSelection.stage == LiveActivityStage.duringClassStatusBar
            ? false
            : settings.livePromoteDuringClass,
        showNotificationDuringClass:
            activeSelection.stage == LiveActivityStage.duringClassStatusBar
            ? true
            : settings.liveShowDuringClassNotification,
        enableBeforeClass: settings.liveEnableBeforeClass,
        enableDuringClass: settings.liveEnableDuringClass,
        enableBeforeEnd: settings.liveEnableBeforeEnd,
        showCountdown: displaySettings.showCountdown,
        countdownTextStyle: displaySettings.countdownTextStyle,
        showStageText: displaySettings.showStageText,
        showCourseNameInIsland: displaySettings.showCourseName,
        showLocationInIsland: displaySettings.showLocation,
        useShortNameInIsland: displaySettings.useShortName,
        hidePrefixText: displaySettings.hidePrefixText,
        duringClassTimeDisplayMode: displaySettings.duringClassTimeDisplayMode,
        enableMiuiIslandLabelImage: displaySettings.enableMiuiIslandLabelImage,
        miuiIslandLabelStyle: displaySettings.miuiIslandLabelStyle,
        miuiIslandLabelContent: displaySettings.miuiIslandLabelContent,
        miuiIslandLabelFontColor: displaySettings.miuiIslandLabelFontColor,
        miuiIslandLabelFontWeight: displaySettings.miuiIslandLabelFontWeight,
        miuiIslandLabelRenderQuality:
            displaySettings.miuiIslandLabelRenderQuality,
        miuiIslandLabelFontSize: displaySettings.miuiIslandLabelFontSize,
        miuiIslandLabelOffsetX: displaySettings.miuiIslandLabelOffsetX,
        miuiIslandLabelOffsetY: displaySettings.miuiIslandLabelOffsetY,
        miuiIslandLabelLogoPath: displaySettings.miuiIslandLabelLogoPath,
        miuiIslandLabelLogoCornerRadius:
            displaySettings.miuiIslandLabelLogoCornerRadius,
        miuiIslandExpandedIconMode: displaySettings.miuiIslandExpandedIconMode,
        miuiIslandExpandedIconPath: displaySettings.miuiIslandExpandedIconPath,
        expandedDetailFields: displaySettings.expandedDetailFields
            ?.map((field) => field.value)
            .toList(),
        beforeClassQuickAction: settings.liveBeforeClassQuickAction,
        beforeClassQuickActionAutoMinutes:
            settings.liveBeforeClassQuickActionAutoMinutes,
        progressBreakOffsetsMillis: progressBreakOffsetsMillis,
        progressMilestoneLabels: progressMilestones
            .map((milestone) => milestone['label'] as String)
            .toList(),
        progressMilestoneTimeTexts: progressMilestones
            .map((milestone) => milestone['timeText'] as String)
            .toList(),
      );
    } else {
      host.currentLiveCourseId = null;
      host.liveRuntime.lastActivityStageKey = null;
      await host.liveActivitiesService.stopLiveUpdate();
    }
  }

  static Future<void> syncScheduleSnapshot(TimetableLiveActivityPort host) async {
    final activeProfile = host.activeProfile;
    final overlayCourses = host.liveRuntime.fixtureOverlayCourses;
    if (activeProfile == null ||
        (host.courses.isEmpty && overlayCourses.isEmpty)) {
      if (host.liveRuntime.lastLiveSnapshotSignature != null) {
        final cleared = await host.liveActivitiesService.clearScheduleSnapshot();
        if (cleared) {
          host.liveRuntime.lastLiveSnapshotSignature = null;
        }
      }
      return;
    }

    // 自检预设课随覆盖层一并进入原生快照：原生侧的校验与续排都以此为准。
    final displayCourses = [
      ...host.courses,
      ...overlayCourses,
    ].map(host.resolveCourseDisplayName).toList(growable: false);
    final now = DateTime.now();
    // Use calendar week (not UI browse week) so native schedule matches live
    // course selection even when the user has scrolled the timetable.
    final scheduleWeek = host.calculateCalendarWeekForDate(now);
    final todayKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final todayIsHoliday = host.isHoliday(now);
    final holidayDates = _liveBuildHolidayDatesForSnapshot(host);
    final adjustedWorkdayDates = _liveBuildAdjustedWorkdayDatesForSnapshot(host);
    final snapshotSignature = jsonEncode({
      'profileId': activeProfile.id,
      'currentWeek': scheduleWeek,
      'semesterStartDate':
          host.settings.semesterStartDate?.millisecondsSinceEpoch,
      'isHoliday': todayIsHoliday,
      'isHolidayDate': todayKey,
      'holidayDates': holidayDates,
      'adjustedWorkdayDates': adjustedWorkdayDates,
      'holidayOverrideEnabled': host.settings.holidayOverrideEnabled,
      'enableHolidayMarking': host.settings.enableHolidayMarking,
      'settings': host.settings.toJson(),
      'courses': displayCourses.map((course) => course.toJson()).toList(),
    });
    if (host.liveRuntime.lastLiveSnapshotSignature == snapshotSignature) {
      return;
    }

    final synced = await host.liveActivitiesService.syncScheduleSnapshot(
      courses: displayCourses,
      settings: host.settings,
      currentWeek: scheduleWeek,
      semesterStartDate: host.settings.semesterStartDate,
      endReminderLeadMillis:
          _endReminderWindow.inMilliseconds,
      isHoliday: todayIsHoliday,
      isHolidayDate: todayKey,
      holidayDates: holidayDates,
      adjustedWorkdayDates: adjustedWorkdayDates,
      holidayOverrideEnabled: host.settings.holidayOverrideEnabled,
      enableHolidayMarking: host.settings.enableHolidayMarking,
    );
    if (synced) {
      host.liveRuntime.lastLiveSnapshotSignature = snapshotSignature;
    }
  }

  static Future<void> syncHomeWidgetSnapshot(TimetableLiveActivityPort host) async {
    // 统计小组件与今日小组件共用这一入口：冷启动、回前台、课表变更都会走到，
    // 否则用户不进统计页时桌面统计组件永远读不到快照。
    await _liveSyncStatsWidgetSnapshot(host);
    final now = DateTime.now();
    final snapshot = buildHomeWidgetSnapshot(host);
    if (snapshot == null) {
      if (host.liveRuntime.lastHomeWidgetSnapshotSignature != null) {
        final cleared = await host.homeWidgetService.clearSnapshot();
        if (cleared) {
          host.liveRuntime.lastHomeWidgetSnapshotSignature = null;
        }
      }
      return;
    }

    final snapshotSignature = jsonEncode(snapshot.toDedupJson());
    if (host.liveRuntime.lastHomeWidgetSnapshotSignature != snapshotSignature) {
      final synced = await host.homeWidgetService.syncSnapshot(snapshot);
      if (synced) {
        host.liveRuntime.lastHomeWidgetSnapshotSignature = snapshotSignature;
      }
    }
    final triggerAtMillis = snapshot.state == HomeWidgetSnapshotState.holiday
        ? <int>[]
        : host.homeWidgetSnapshotService.buildRefreshTriggers(
            todayCourses: host.getActiveCoursesForDay(
              now.weekday,
              week: snapshot.currentWeek,
            ),
            now: now,
            showCountdown: snapshot.showCountdown,
            state: snapshot.state.value,
            countdownLeadMinutes: host.settings.widgetCountdownLeadMinutes,
          );
    // 绑定卡片：各自课表的专属快照 + 刷新触发点并入并集，
    // 否则 TA 第三节课开始时闹钟仍按当前课表的时间没响。
    final boundTriggers = await _liveSyncBoundWidgetSnapshots(host, now);
    await host.homeWidgetService.scheduleRefresh([
      ...triggerAtMillis,
      ...boundTriggers,
    ]);
  }

  static Future<void> _liveSyncStatsWidgetSnapshot(TimetableLiveActivityPort host) async {
    final snapshot = StatsWidgetSnapshot.fromCourses(
      courses: host.courses,
      currentWeek: host.currentWeek,
      semesterWeekCount: host.settings.semesterWeekCount,
      profileName: host.activeProfile?.name ?? '',
    );
    if (snapshot == null) {
      await StatsWidgetService.clearSnapshot();
      return;
    }
    await StatsWidgetService.syncSnapshot(snapshot);
  }

  static Future<void> refreshNow(
    TimetableLiveActivityPort host, {
    bool forceSnapshotSync = false,
  }) async {
    await host.initialize();
    if (forceSnapshotSync) {
      host.liveRuntime.lastLiveSnapshotSignature = null;
    }
    host.currentLiveCourseId = null;
    await syncScheduleSnapshot(host);
    await updateActivity(host, syncScheduleSnapshot: false);
  }

  /// 今天的课。
  ///
  /// 学期结束后 UI 的 `currentDateWeek` 会被夹在 `semesterWeekCount`，而「今天的
  /// 课」必须用真实日历周，否则结课后每个匹配「最后一个教学周」的星期都会把上完
  /// 的课再列一遍。与超级岛选课同源（[calculateCalendarWeekForDate]）。
  static List<Course> getTodayCourses(
    TimetableLiveActivityPort host, {
    DateTime? now,
  }) {
    final reference = now ?? DateTime.now();
    final targetWeek = host.settings.semesterStartDate == null
        ? host.currentDateWeek
        : host.calculateCalendarWeekForDate(reference);
    return host.getCoursesForDay(host.currentDayOfWeek, week: targetWeek);
  }

  /// 当前正在上的那节课（钟点按 [compareClockText] 比，`9:00` 不补零也正确）。
  static Course? getCurrentCourse(TimetableLiveActivityPort host) {
    final todayCourses = getTodayCourses(host);
    final now = DateTime.now();
    final currentTime =
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}';

    for (final course in todayCourses) {
      if (compareClockText(currentTime, course.startTime) >= 0 &&
          compareClockText(currentTime, course.endTime) < 0) {
        return course;
      }
    }
    return null;
  }

  /// 下一节还没开始的课（同样按分钟数比钟点）。
  static Course? getNextCourse(TimetableLiveActivityPort host) {
    final todayCourses = getTodayCourses(host);
    final now = DateTime.now();
    final currentTime =
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}';

    for (final course in todayCourses) {
      if (compareClockText(currentTime, course.startTime) < 0) {
        return course;
      }
    }
    return null;
  }

  /// 正在上的第一节课；没有则 null（[getCoursesInProgress] 的便利包装）。
  static Course? getCourseInProgress(
    TimetableLiveActivityPort host, {
    required int dayOfWeek,
    int? week,
    DateTime? now,
  }) {
    final courses = getCoursesInProgress(
      host,
      dayOfWeek: dayOfWeek,
      week: week,
      now: now,
    );
    return courses.isEmpty ? null : courses.first;
  }
  /// 正在上的课：[dayOfWeek]/[week] 那天的课里，实时时钟落在起止之间的那些。
  ///
  /// 与超级岛选课共用同一套实时时钟解析（[resolveRealTime]），所以搬来同处，
  /// 免得「岛看到的课」与「日视图高亮的课」各有一套规则慢慢漂移。日期的作息
  /// 覆盖由 [TimetableLiveActivityPort.resolveSectionsForCourse] 在解析时应用。
  static List<Course> getCoursesInProgress(
    TimetableLiveActivityPort host, {
    required int dayOfWeek,
    int? week,
    DateTime? now,
  }) {
    final reference = now ?? DateTime.now();
    final targetWeek = week ?? _weekForDate(host, reference);
    final currentMinutes = reference.hour * 60 + reference.minute;
    final matches = <Course>[];

    for (final course in host.getCoursesForDay(dayOfWeek, week: targetWeek)) {
      final startMinutes = LiveActivityLogic.parseClockMinutes(
        LiveActivityLogic.resolveRealTime(
          course,
          true,
          host.resolveSectionsForCourse(course),
        ),
      );
      final endMinutes = LiveActivityLogic.parseClockMinutes(
        LiveActivityLogic.resolveRealTime(
          course,
          false,
          host.resolveSectionsForCourse(course),
        ),
      );
      if (startMinutes == null || endMinutes == null) {
        continue;
      }
      if (currentMinutes >= startMinutes && currentMinutes < endMinutes) {
        matches.add(host.resolveCourseDisplayName(course));
      }
    }
    return matches;
  }

  static int _weekForDate(
    TimetableLiveActivityPort host,
    DateTime date, {
    int? fallbackWeek,
  }) {
    return WeekCalculator.weekForDate(
      date,
      semesterStart: host.settings.semesterStartDate,
      semesterWeekCount: host.settings.semesterWeekCount,
      fallback: fallbackWeek ?? host.currentWeek,
    );
  }
  // ── 自检预设课覆盖层（只进超级岛选课与原生快照，绝不写真实课表）──

  /// 注入自检预设课（整体替换上一批）。
  static void armFixtureCourses(
    TimetableLiveActivityPort host,
    List<Course> courses,
  ) {
    if (courses.isEmpty) {
      return;
    }
    host.liveRuntime.fixtureOverlayCourses = List.of(courses, growable: false);
    host.notifyStateChanged();
  }

  /// 摘除预设课覆盖层（用户点「取消测试」）。
  static void disarmFixtureCourses(TimetableLiveActivityPort host) {
    if (host.liveRuntime.fixtureOverlayCourses.isEmpty) {
      return;
    }
    host.liveRuntime.fixtureOverlayCourses = const [];
    host.notifyStateChanged();
  }

  /// 预设课全部结束（按其自由时钟）时摘除覆盖层，返回是否真的摘了。
  /// 未结束（含节假日等选课为空的场景）时保持挂载，阶段空窗由岛自身停止。
  /// 注意：这是管线路径（[updateActivityBody] 顶部调用，fire-and-forget，
  /// 可能跨越 provider 生命周期完成），刻意不发 notify——自检页通过 1s 轮询
  /// 感知自动结束并翻转按钮；显式用户动作走 [disarmFixtureCourses]。
  static bool disarmFixtureCoursesIfFinished(
    TimetableLiveActivityPort host,
    DateTime now,
  ) {
    final overlay = host.liveRuntime.fixtureOverlayCourses;
    if (overlay.isEmpty) {
      return false;
    }
    for (final course in overlay) {
      final endTime = buildCorrectedCourseDateTime(
        host,
        now,
        resolveRealTime(host, course, false),
      );
      if (endTime == null || !endTime.isBefore(now)) {
        return false;
      }
    }
    host.liveRuntime.fixtureOverlayCourses = const [];
    return true;
  }

  /// 立即取消自检测试：摘除预设课覆盖层并按正式路径重刷——预设课随本次
  /// 快照同步从原生侧回收；若此刻有真实课在窗，岛直接切回真实课，否则停岛。
  /// 供自检页「取消测试」按钮使用，不等下一个 30s tick。
  static Future<void> cancelFixtureSession(TimetableLiveActivityPort host) async {
    disarmFixtureCourses(host);
    await refreshNow(host, forceSnapshotSync: true);
  }

  /// 临时暂停实时同步（导入、自检等重路径）。
  static void suspendSyncFor(
    TimetableLiveActivityPort host,
    Duration duration,
  ) {
    host.liveRuntime.suspendedUntil = DateTime.now().add(duration);
  }

  /// 清掉临时暂停（含旧测试助手遗留的挂起）。
  static void clearSyncSuspend(TimetableLiveActivityPort host) {
    host.liveRuntime.suspendedUntil = null;
  }
}
