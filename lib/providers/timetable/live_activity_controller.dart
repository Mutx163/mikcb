part of '../timetable_provider.dart';

String _liveResolveRealTime(
  TimetableProvider host,
  Course course,
  bool isStart,
) {
  // Diagnostic fixtures intentionally carry temporary free-form clocks. They
  // must exercise the production selection path without mutating a user's
  // active time scheme.
  if (_isLiveTestingFixture(course)) {
    return isStart ? course.startTime : course.endTime;
  }
  // Live always resolves against the calendar day being evaluated so date
  // rules (e.g. summer timetable) apply for today without being baked into
  // persisted Course clocks.
  final onDate = DateTime.now();
  return LiveActivityLogic.resolveRealTime(
    course,
    isStart,
    host._resolveSectionsForCourse(course, onDate: onDate),
  );
}

DateTime _liveApplyTimeCorrection(TimetableProvider host, DateTime dateTime) {
  final correctionSeconds = host._settings.liveTimeCorrectionSeconds;
  if (correctionSeconds == 0) {
    return dateTime;
  }
  return dateTime.add(Duration(seconds: correctionSeconds));
}

DateTime? _liveBuildCorrectedCourseDateTime(
  TimetableProvider host,
  DateTime date,
  String courseTime,
) {
  final base = LiveActivityLogic.buildCourseDateTime(date, courseTime);
  if (base == null) {
    return null;
  }
  return _liveApplyTimeCorrection(host, base);
}

DateTime? _liveResolveBeforeClassBlockedUntil(
  TimetableProvider host,
  List<Course> todayCourses,
  int courseIndex,
  DateTime referenceDate,
) {
  if (courseIndex <= 0 || courseIndex >= todayCourses.length) {
    return null;
  }

  final course = todayCourses[courseIndex];
  final courseStartTime = _liveBuildCorrectedCourseDateTime(
    host,
    referenceDate,
    _liveResolveRealTime(host, course, true),
  );
  if (courseStartTime == null) {
    return null;
  }

  DateTime? blockedUntil;
  for (var i = 0; i < courseIndex; i++) {
    final previousCourse = todayCourses[i];
    final previousStartTime = _liveBuildCorrectedCourseDateTime(
      host,
      referenceDate,
      _liveResolveRealTime(host, previousCourse, true),
    );
    final previousEndTime = _liveBuildCorrectedCourseDateTime(
      host,
      referenceDate,
      _liveResolveRealTime(host, previousCourse, false),
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

List<String> _liveBuildHolidayDatesForSnapshot(TimetableProvider host) {
  if (!host._settings.enableHolidayMarking || host._holidayData == null) {
    return const [];
  }
  // Full HolidayData.isHoliday semantics (custom makeup beats statutory hide).
  // Do not use TimetableProvider.isHoliday: holidayOverride is sent separately.
  return host._holidayData!.holidayDateKeysForSnapshot();
}

/// Makeup days that must punch through native [holidayOverrideEnabled].
List<String> _liveBuildAdjustedWorkdayDatesForSnapshot(TimetableProvider host) {
  if (host._holidayData == null) {
    return const [];
  }
  return host._holidayData!.adjustedWorkdayDateKeysForSnapshot();
}

void _liveStartActivityTick(TimetableProvider host) {
  host._liveActivityTimer?.cancel();
  unawaited(host.syncTemporalContext());
  unawaited(_liveUpdateActivity(host));
  _liveScheduleActivityTick(host);
}

Future<void> _liveHandleAppResumed(TimetableProvider host) async {
  host._liveActivityTimer?.cancel();
  await host.syncTemporalContext();
  // Clear + push under one exclusive section so a concurrent WebDAV apply
  // cannot interleave a half-updated native snapshot.
  await host._runLiveSurfaceExclusive(() async {
    host._lastLiveSnapshotSignature = null;
    host._currentLiveCourseId = null;
    await _liveUpdateActivityBody(host);
  });
  _liveScheduleActivityTick(host);
}

void _liveScheduleActivityTick(TimetableProvider host) {
  host._liveActivityTimer = Timer.periodic(const Duration(seconds: 30), (_) {
    unawaited(host.syncTemporalContext());
    _liveCheckActivityStageTransition(host);
  });
}

void _liveCheckActivityStageTransition(TimetableProvider host) {
  final selection = host.getLiveActivityCourseSelection();
  final liveCourse = selection?.currentCourse;
  if (liveCourse == null || selection == null) {
    if (host._lastLiveActivityStageKey != null ||
        host._currentLiveCourseId != null) {
      host._lastLiveActivityStageKey = null;
      host._currentLiveCourseId = null;
      unawaited(_liveUpdateActivity(host));
    }
    return;
  }

  final key = LiveActivityLogic.buildStageTransitionKey(selection);
  if (host._lastLiveActivityStageKey != null &&
      host._lastLiveActivityStageKey != key) {
    host._currentLiveCourseId = null;
    unawaited(_liveUpdateActivity(host));
  }
  host._lastLiveActivityStageKey = key;
}

void _liveSeedTrackingForTesting(
  TimetableProvider host, {
  String? lastStageKey,
  String? currentCourseId,
}) {
  host._lastLiveActivityStageKey = lastStageKey;
  host._currentLiveCourseId = currentCourseId;
}

Future<void> _liveUpdateActivityForTesting(
  TimetableProvider host, {
  bool syncScheduleSnapshot = true,
}) => _liveUpdateActivity(host, syncScheduleSnapshot: syncScheduleSnapshot);

/// Comparator that orders live candidates by their resolved (corrected) start
/// time. Preset fixture courses carry free-form clocks, so section order alone
/// is not chronological once the overlay is merged in.
int _liveCompareByResolvedStart(
  TimetableProvider host,
  DateTime referenceDate,
  Course a,
  Course b,
) {
  final aStart = _liveBuildCorrectedCourseDateTime(
    host,
    referenceDate,
    _liveResolveRealTime(host, a, true),
  );
  final bStart = _liveBuildCorrectedCourseDateTime(
    host,
    referenceDate,
    _liveResolveRealTime(host, b, true),
  );
  if (aStart == null || bStart == null) {
    if (aStart == null && bStart == null) {
      return a.startSection.compareTo(b.startSection);
    }
    return aStart == null ? 1 : -1;
  }
  return aStart.compareTo(bStart);
}

LiveActivityCourseSelection? _liveGetActivityCourseSelection(
  TimetableProvider host, {
  DateTime? now,
  bool allowUpcomingFallback = false,
  int? week,
}) {
  final currentTime = now ?? DateTime.now();
  // Selection must honor holiday semantics; do not rely solely on the stop
  // branch in _liveUpdateActivityBody (tick/stage paths call selection first).
  if (host.isHoliday(currentTime)) {
    return null;
  }
  final targetWeek = week ?? host._calculateCalendarWeekForDate(currentTime);
  var todayCourses = host.getActiveCoursesForDay(
    currentTime.weekday,
    week: targetWeek,
  );
  final fixtureCourses = host._liveTestFixtureOverlayCourses
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
    final startTime = _liveBuildCorrectedCourseDateTime(
      host,
      currentTime,
      _liveResolveRealTime(host, course, true),
    );
    final endTime = _liveBuildCorrectedCourseDateTime(
      host,
      currentTime,
      _liveResolveRealTime(host, course, false),
    );
    if (startTime == null || endTime == null) {
      continue;
    }

    final aheadTime = startTime.subtract(
      Duration(minutes: host._settings.liveShowBeforeClassMinutes),
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
      settings: host._settings,
      endReminderWindow: TimetableProvider._liveEndReminderWindow,
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

  if (!allowUpcomingFallback || !host._settings.liveEnableBeforeClass) {
    return null;
  }

  for (var i = 0; i < todayCourses.length; i++) {
    final course = todayCourses[i];
    final startTime = _liveBuildCorrectedCourseDateTime(
      host,
      currentTime,
      _liveResolveRealTime(host, course, true),
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

LiveActivityCourseSelection? _liveGetTestActivityCourseSelection(
  TimetableProvider host, {
  DateTime? now,
}) {
  final currentTime = now ?? DateTime.now();
  final targetWeek = host._calculateCalendarWeekForDate(currentTime);
  final immediateSelection = host.getLiveActivityCourseSelection(
    now: currentTime,
    allowUpcomingFallback: true,
    week: targetWeek,
  );
  if (immediateSelection != null) {
    return immediateSelection;
  }

  final today = DateTime(currentTime.year, currentTime.month, currentTime.day);
  final maxWeek = host._courses.isEmpty
      ? targetWeek
      : host._courses
            .map((course) => course.endWeek)
            .reduce((a, b) => a > b ? a : b);

  Course? bestCourse;
  DateTime? bestStartTime;
  int? bestWeek;

  for (final course in host._courses) {
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
      final candidateStart = _liveBuildCorrectedCourseDateTime(
        host,
        candidateDate,
        _liveResolveRealTime(host, course, true),
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

  final fallbackStage = LiveActivityLogic.preferredTestStage(host._settings);
  if (bestCourse == null || bestWeek == null || fallbackStage == null) {
    return null;
  }
  final resolvedWeek = bestWeek;

  final sameDayCourses =
      host._courses
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

HomeWidgetSnapshot? _liveBuildHomeWidgetSnapshot(
  TimetableProvider host, {
  DateTime? now,
}) {
  final profile = host.activeProfile;
  if (profile == null) {
    return null;
  }

  final currentTime = now ?? DateTime.now();
  // Must use calendar week (no semesterWeekCount clamp). Clamping to the last
  // teaching week after the term ends would revive endWeek=N courses forever.
  final targetWeek = host._calculateCalendarWeekForDate(currentTime);
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
  final tomorrowWeek = host._calculateCalendarWeekForDate(tomorrow);
  final tomorrowIsHoliday = host.isHoliday(tomorrow);
  final tomorrowCourses = tomorrowIsHoliday
      ? const <Course>[]
      : host
            .getActiveCoursesForDay(tomorrow.weekday, week: tomorrowWeek)
            .map(host.resolveCourseDisplayName)
            .toList(growable: false);

  final holidayEntry = host.getHolidayForDate(currentTime);

  return host._homeWidgetSnapshotService.build(
    profileId: profile.id,
    profileName: profile.name,
    currentWeek: targetWeek,
    settings: host._settings,
    todayCourses: todayCourses,
    now: currentTime,
    countdownLeadMinutes: host._settings.widgetCountdownLeadMinutes,
    countdownTextStyle: host._settings.widgetCountdownTextStyle.value,
    nextExam: host.getNextExam(),
    isHoliday: todayIsHoliday,
    holidayName: todayIsHoliday ? holidayEntry?.name : null,
    tomorrowCourses: tomorrowCourses,
    tomorrowWeek: tomorrowWeek,
    tomorrowDayOfWeek: tomorrow.weekday,
    showTomorrowCourses: host._settings.widgetShowTomorrowCourses,
    originalTodayCourseCount: todayIsHoliday ? 0 : originalTodayCount,
  );
}

Future<void> _liveUpdateActivity(
  TimetableProvider host, {
  bool syncScheduleSnapshot = true,
}) {
  return host._runLiveSurfaceExclusive(
    () => _liveUpdateActivityBody(
      host,
      syncScheduleSnapshot: syncScheduleSnapshot,
    ),
  );
}

Future<void> _liveUpdateActivityBody(
  TimetableProvider host, {
  bool syncScheduleSnapshot = true,
}) async {
  // 自检预设课全部结束后立刻摘除覆盖层，让随后的快照同步与选课回到纯真实数据。
  host.disarmLiveTestFixtureCoursesIfFinished(DateTime.now());
  await _liveSyncHomeWidgetSnapshot(host);
  if (!host._enableLiveActivitySync) {
    return;
  }

  final suspendedUntil = host._liveActivitySuspendedUntil;
  if (suspendedUntil != null) {
    if (DateTime.now().isBefore(suspendedUntil)) {
      return;
    }
    host._liveActivitySuspendedUntil = null;
  }

  if (syncScheduleSnapshot) {
    await _liveSyncScheduleSnapshot(host);
  }

  if (host.isHoliday(DateTime.now())) {
    host._currentLiveCourseId = null;
    host._lastLiveActivityStageKey = null;
    await host._liveActivitiesService.stopLiveUpdate();
    return;
  }

  final selection = host.getLiveActivityCourseSelection();
  final liveCourse = selection?.currentCourse;

  if (liveCourse != null) {
    final activeSelection = selection!;
    final settings = host._settings;
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
    if (host._currentLiveCourseId == liveActivityKey) {
      return;
    }
    host._currentLiveCourseId = liveActivityKey;

    final displayCourse = liveCourse.copyWith(
      startTime: _liveResolveRealTime(host, liveCourse, true),
      endTime: _liveResolveRealTime(host, liveCourse, false),
    );
    final displayNextCourse = activeSelection.nextCourse?.copyWith(
      startTime: _liveResolveRealTime(host, activeSelection.nextCourse!, true),
      endTime: _liveResolveRealTime(host, activeSelection.nextCourse!, false),
    );
    final startAtMillis = _liveBuildCorrectedCourseDateTime(
      host,
      DateTime.now(),
      _liveResolveRealTime(host, displayCourse, true),
    )?.millisecondsSinceEpoch;
    final endAtMillis = _liveBuildCorrectedCourseDateTime(
      host,
      DateTime.now(),
      _liveResolveRealTime(host, displayCourse, false),
    )?.millisecondsSinceEpoch;
    final sections = host._resolveSectionsForCourse(
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

    await host._liveActivitiesService.startLiveUpdate(
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
    host._currentLiveCourseId = null;
    host._lastLiveActivityStageKey = null;
    await host._liveActivitiesService.stopLiveUpdate();
  }
}

Future<void> _liveSyncScheduleSnapshot(TimetableProvider host) async {
  final activeProfile = host.activeProfile;
  final overlayCourses = host._liveTestFixtureOverlayCourses;
  if (activeProfile == null ||
      (host._courses.isEmpty && overlayCourses.isEmpty)) {
    if (host._lastLiveSnapshotSignature != null) {
      final cleared = await host._liveActivitiesService.clearScheduleSnapshot();
      if (cleared) {
        host._lastLiveSnapshotSignature = null;
      }
    }
    return;
  }

  // 自检预设课随覆盖层一并进入原生快照：原生侧的校验与续排都以此为准。
  final displayCourses = [
    ...host._courses,
    ...overlayCourses,
  ].map(host.resolveCourseDisplayName).toList(growable: false);
  final now = DateTime.now();
  // Use calendar week (not UI browse week) so native schedule matches live
  // course selection even when the user has scrolled the timetable.
  final scheduleWeek = host._calculateCalendarWeekForDate(now);
  final todayKey =
      '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  final todayIsHoliday = host.isHoliday(now);
  final holidayDates = _liveBuildHolidayDatesForSnapshot(host);
  final adjustedWorkdayDates = _liveBuildAdjustedWorkdayDatesForSnapshot(host);
  final snapshotSignature = jsonEncode({
    'profileId': activeProfile.id,
    'currentWeek': scheduleWeek,
    'semesterStartDate':
        host._settings.semesterStartDate?.millisecondsSinceEpoch,
    'isHoliday': todayIsHoliday,
    'isHolidayDate': todayKey,
    'holidayDates': holidayDates,
    'adjustedWorkdayDates': adjustedWorkdayDates,
    'holidayOverrideEnabled': host._settings.holidayOverrideEnabled,
    'enableHolidayMarking': host._settings.enableHolidayMarking,
    'settings': host._settings.toJson(),
    'courses': displayCourses.map((course) => course.toJson()).toList(),
  });
  if (host._lastLiveSnapshotSignature == snapshotSignature) {
    return;
  }

  final synced = await host._liveActivitiesService.syncScheduleSnapshot(
    courses: displayCourses,
    settings: host._settings,
    currentWeek: scheduleWeek,
    semesterStartDate: host._settings.semesterStartDate,
    endReminderLeadMillis:
        TimetableProvider._liveEndReminderWindow.inMilliseconds,
    isHoliday: todayIsHoliday,
    isHolidayDate: todayKey,
    holidayDates: holidayDates,
    adjustedWorkdayDates: adjustedWorkdayDates,
    holidayOverrideEnabled: host._settings.holidayOverrideEnabled,
    enableHolidayMarking: host._settings.enableHolidayMarking,
  );
  if (synced) {
    host._lastLiveSnapshotSignature = snapshotSignature;
  }
}

Future<void> _liveSyncHomeWidgetSnapshot(TimetableProvider host) async {
  // 统计小组件与今日小组件共用这一入口：冷启动、回前台、课表变更都会走到，
  // 否则用户不进统计页时桌面统计组件永远读不到快照。
  await _liveSyncStatsWidgetSnapshot(host);
  final now = DateTime.now();
  final snapshot = host.buildHomeWidgetSnapshot();
  if (snapshot == null) {
    if (host._lastHomeWidgetSnapshotSignature != null) {
      final cleared = await host._homeWidgetService.clearSnapshot();
      if (cleared) {
        host._lastHomeWidgetSnapshotSignature = null;
      }
    }
    return;
  }

  final snapshotSignature = jsonEncode(snapshot.toDedupJson());
  if (host._lastHomeWidgetSnapshotSignature != snapshotSignature) {
    final synced = await host._homeWidgetService.syncSnapshot(snapshot);
    if (synced) {
      host._lastHomeWidgetSnapshotSignature = snapshotSignature;
    }
  }
  final triggerAtMillis = snapshot.state == HomeWidgetSnapshotState.holiday
      ? <int>[]
      : host._homeWidgetSnapshotService.buildRefreshTriggers(
          todayCourses: host.getActiveCoursesForDay(
            now.weekday,
            week: snapshot.currentWeek,
          ),
          now: now,
          showCountdown: snapshot.showCountdown,
          state: snapshot.state.value,
          countdownLeadMinutes: host._settings.widgetCountdownLeadMinutes,
        );
  await host._homeWidgetService.scheduleRefresh(triggerAtMillis);
}

Future<void> _liveSyncStatsWidgetSnapshot(TimetableProvider host) async {
  final snapshot = StatsWidgetSnapshot.fromCourses(
    courses: host.courses,
    currentWeek: host.currentWeek,
    semesterWeekCount: host._settings.semesterWeekCount,
    profileName: host.activeProfile?.name ?? '',
  );
  if (snapshot == null) {
    await StatsWidgetService.clearSnapshot();
    return;
  }
  await StatsWidgetService.syncSnapshot(snapshot);
}

Future<void> _liveRefreshNow(
  TimetableProvider host, {
  bool forceSnapshotSync = false,
}) async {
  await host.initialize();
  if (forceSnapshotSync) {
    host._lastLiveSnapshotSignature = null;
  }
  host._currentLiveCourseId = null;
  await _liveSyncScheduleSnapshot(host);
  await _liveUpdateActivity(host, syncScheduleSnapshot: false);
}
