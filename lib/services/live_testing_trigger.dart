import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:university_timetable/l10n/app_localizations.dart';

import '../logging/app_log_messages.dart';
import '../models/course.dart';
import '../models/timetable_settings.dart';
import '../providers/timetable_provider.dart';
import '../services/miui_live_activities_service.dart';
import '../services/umeng_analytics_service.dart';
import 'live_testing_fixture_service.dart';

enum LiveTestingTriggerStatus { success, inFlight, error }

/// 选课测试的阶段变体。强制会话必须锁定单一恒定阶段：调度被暂停期间，原生
/// ticker 的阶段切换分支会因 reschedule 被推迟而收岛（MainActivity.kt
/// `lastTickerStage` 分支），只有 beforeClass→null（到点）/ end+30s 两个
/// 收尾路径不经过切换。故不提供「完整生命周期」变体。
enum LiveCourseTestStage { beforeClass, duringClass }

class LiveTestingTriggerResult {
  final LiveTestingTriggerStatus status;
  final String? message;

  const LiveTestingTriggerResult({required this.status, this.message});
}

bool liveTestingTriggerInFlight = false;

/// Runs the same production live-update path used after normal course edits.
///
/// Does **not** force-start the island, suspend schedule triggers, or invent a
/// temporary course payload. Selection honors calendar week, endWeek, holiday,
/// and before-class windows exactly like a normal tick.
Future<LiveTestingTriggerResult> triggerLiveUpdateProductionRefresh({
  required BuildContext context,
  required TimetableProvider provider,
  required String source,
  String? seededCourseId,
}) async {
  if (liveTestingTriggerInFlight) {
    final locale = Localizations.localeOf(context);
    return LiveTestingTriggerResult(
      status: LiveTestingTriggerStatus.inFlight,
      message: locale.languageCode == 'zh'
          ? '测试进行中，请勿重复点击，请稍后再试'
          : 'Test in progress. Please wait before tapping again.',
    );
  }
  liveTestingTriggerInFlight = true;

  final locale = Localizations.localeOf(context);
  final l10n = AppLocalizations.of(context)!;
  final liveService = MiuiLiveActivitiesService();

  try {
    await provider.initialize();
    await liveService.initialize();

    final now = DateTime.now();
    final selectionPreview = provider.getLiveActivityCourseSelection(now: now);
    await liveService.recordDiagnosticEvent(
      'live_update_test_requested',
      AppLogMessages.liveUpdateTestRequested,
      extras: {
        'from': source,
        'path': 'production_refresh',
        'currentWeek': provider.currentWeek,
        'courseId': seededCourseId,
        'hasImmediateSelection': selectionPreview != null,
      },
    );

    // Older test helpers paused Flutter/native schedule sync; production refresh
    // must not inherit that pause or the real path appears broken.
    provider.clearLiveActivitySyncSuspend();
    await liveService.suspendScheduleTriggers(0);

    // Same entry used after resume / settings changes: re-select from courses.
    await provider.refreshLiveActivityNow(forceSnapshotSync: true);

    if (!context.mounted) {
      return const LiveTestingTriggerResult(
        status: LiveTestingTriggerStatus.error,
        message: null,
      );
    }

    var selection = provider.getLiveActivityCourseSelection();
    var usedPresetFallback = false;
    if (selection == null) {
      // 真实课表无课可测（如刚安装还没有课）：注入自检预设课，再走一遍同一条
      // 正式路径。预设课只进超级岛内存覆盖层与原生快照，不写入真实课表。
      final presetSelection = await _triggerWithPresetFixtureCourses(
        context: context,
        provider: provider,
        liveService: liveService,
        source: source,
      );
      if (!context.mounted) {
        return const LiveTestingTriggerResult(
          status: LiveTestingTriggerStatus.error,
          message: null,
        );
      }
      if (presetSelection != null) {
        selection = presetSelection;
        usedPresetFallback = true;
      }
    }

    if (selection == null) {
      final overlayArmed = provider.hasLiveTestFixtureCourses;
      final holidayNow = provider.isHoliday(DateTime.now());
      await liveService.recordDiagnosticEvent(
        'live_update_test_no_selection',
        AppLogMessages.liveUpdateTestNoSelection,
        extras: {
          'from': source,
          'path': 'production_refresh',
          'weekday': DateTime.now().weekday,
          'currentWeek': provider.currentWeek,
          'seededCourseId': seededCourseId,
          'isHoliday': holidayNow,
          'liveEnableBeforeClass': provider.settings.liveEnableBeforeClass,
          'liveShowBeforeClassMinutes':
              provider.settings.liveShowBeforeClassMinutes,
          'hasLiveTestFixtureCourses': overlayArmed,
        },
      );
      // 预设课已注入却选不出阶段（课前显示被关/假日门拦截）时，与「真的没有
      // 课」分开提示——前者岛会在课程真正开始后弹出，笼统的「无课」会误导用户。
      // 假日门在选课最上游（预设课也一并被拦）且无时限：必须最先分流，否则
      // 「约 1 分钟后出现」的承诺在假期里永远不会兑现（2026-08-30 OPPO 案例：
      // 用户自添加假期覆盖当天，课前提醒全程开着，岛依旧永远不弹）。
      return LiveTestingTriggerResult(
        status: LiveTestingTriggerStatus.error,
        message: holidayNow
            ? l10n.liveTestingHolidayBlocked
            : overlayArmed
                ? l10n.liveTestingPresetArmedButHidden
                : l10n.liveTestingNoCourseAvailable,
      );
    }

    await liveService.recordDiagnosticEvent(
      'live_update_test_started',
      AppLogMessages.liveUpdateTestStarted,
      extras: {
        'from': source,
        'path': 'production_refresh',
        'courseName': selection.currentCourse.name,
        'stage': selection.stage.name,
      },
    );

    final homeHint = locale.languageCode == 'zh'
        ? '已走正式超级岛选课路径。请按 Home 键回到桌面查看（停留在应用内时系统通常不会弹出）'
        : 'Used the production island selection path. Press Home to watch it; it usually will not pop while the app stays open.';
    final presetNote = usedPresetFallback
        ? (locale.languageCode == 'zh'
              ? '（未检测到可测试的真实课程，已改用自检预设课程，不会写入课表）\n'
              : '(No testable real course found; used self-check preset courses instead, nothing was written to your timetable.)\n')
        : '';
    return LiveTestingTriggerResult(
      status: LiveTestingTriggerStatus.success,
      message:
          '${l10n.liveTestingNotificationSent}\n'
          '$presetNote'
          '${selection.currentCourse.name} · ${selection.stage.name}\n'
          '$homeHint',
    );
  } catch (error, stackTrace) {
    await UmengAnalyticsService.reportDiagnostic(
      'live_update_test_failed',
      AppLogMessages.liveUpdateTestFailed,
      error: error,
      stackTrace: stackTrace,
      dedupeKey: 'live_update_test_failed',
    );
    return LiveTestingTriggerResult(
      status: LiveTestingTriggerStatus.error,
      message: l10n.sendFailedWithError('$error'),
    );
  } finally {
    unawaited(
      Future<void>.delayed(const Duration(seconds: 2), () {
        liveTestingTriggerInFlight = false;
      }),
    );
  }
}

/// Settings entry: only re-run production live selection (no forced payload).
Future<LiveTestingTriggerResult> triggerLiveUpdateTest({
  required BuildContext context,
  required TimetableProvider provider,
  String source = 'settings_screen',
}) {
  return triggerLiveUpdateProductionRefresh(
    context: context,
    provider: provider,
    source: source,
  );
}

/// 选课测试：用户从课表任选一门已有课程，强制起岛预览其显示，与时间无关——
/// 不查假日门、周次、当天是否有课或上课窗口，也不写入真实课表。
///
/// 实现：直接向原生服务投递完整 payload（`validateAgainstSchedule=false`，
/// 跳过快照校验），并双路暂停调度——Dart 侧 30s tick（`suspendLiveActivitySyncFor`）
/// 与原生闹钟/WorkManager（`suspendScheduleTriggers`）在会话结束前都不得
/// 收岛或用真实课覆盖。暂停期到点后自动恢复正式调度。
///
/// [stage] 决定预览哪个阶段的显示（课前倒计时 / 上课中），全程恒定，原因见
/// [LiveCourseTestStage] 注释。
Future<LiveTestingTriggerResult> triggerLiveUpdateCourseTest({
  required BuildContext context,
  required TimetableProvider provider,
  required Course course,
  required LiveCourseTestStage stage,
  String source = 'settings_screen',
}) async {
  if (liveTestingTriggerInFlight) {
    final locale = Localizations.localeOf(context);
    return LiveTestingTriggerResult(
      status: LiveTestingTriggerStatus.inFlight,
      message: locale.languageCode == 'zh'
          ? '测试进行中，请勿重复点击，请稍后再试'
          : 'Test in progress. Please wait before tapping again.',
    );
  }
  liveTestingTriggerInFlight = true;

  final l10n = AppLocalizations.of(context)!;
  final liveService = MiuiLiveActivitiesService();
  final settings = provider.settings;
  final isBeforeClass = stage == LiveCourseTestStage.beforeClass;

  // 合成时间窗：课前变体 3 分钟倒计时；课中变体把开课锚定在 1 分钟前，
  // 已上课 4 分钟后自动收岛。时间只属于本次会话，与课程真实时间无关。
  final now = DateTime.now();
  final start = isBeforeClass
      ? now.add(const Duration(minutes: 3))
      : now.subtract(const Duration(minutes: 1));
  final end = isBeforeClass
      ? start.add(const Duration(minutes: 3))
      : now.add(const Duration(minutes: 4));
  final displayCourse = provider.resolveCourseDisplayName(
    course.copyWith(
      startTime: LiveTestingFixtureService.formatClock(start),
      endTime: LiveTestingFixtureService.formatClock(end),
    ),
  );
  final displaySettings = isBeforeClass
      ? settings.beforeClassDisplaySettings
      : settings.duringEndDisplaySettings;

  try {
    await provider.initialize();
    await liveService.initialize();
    await liveService.recordDiagnosticEvent(
      'live_update_test_requested',
      AppLogMessages.liveUpdateTestRequested,
      extras: {
        'from': source,
        'path': 'course_test',
        'stage': stage.name,
        'courseId': course.id,
        'currentWeek': provider.currentWeek,
      },
    );

    provider.suspendLiveActivitySyncFor(
      end.difference(now) + const Duration(seconds: 20),
    );
    await liveService.suspendScheduleTriggers(
      end.add(const Duration(seconds: 20)).millisecondsSinceEpoch,
    );

    final milestones = provider.buildLiveProgressMilestones(
      displayCourse,
      startAtMillis: start.millisecondsSinceEpoch,
      endAtMillis: end.millisecondsSinceEpoch,
    );

    await liveService.startLiveUpdate(
      displayCourse,
      null,
      stage: stage.name,
      // 强制 payload 与课表快照必然不一致（课程此刻并未在窗），必须跳过
      // 原生校验，否则 ticker 第一拍就会按快照判死本会话。
      validateAgainstSchedule: false,
      beforeClassLeadMillis: isBeforeClass
          ? start.difference(now).inMilliseconds
          : 0,
      startAtMillis: start.millisecondsSinceEpoch,
      endAtMillis: end.millisecondsSinceEpoch,
      endReminderLeadMillis: 0,
      liveClassReminderStartMinutes: 0,
      endSecondsCountdownThreshold: settings.liveEndSecondsCountdownThreshold,
      // 展示开关按阶段强制放开：测试的目的是「看到岛的显示」，不能被用户
      // 关掉的课上/课下开关吞掉；显示样式仍取用户自己的阶段显示设置。
      promoteDuringClass: !isBeforeClass,
      showNotificationDuringClass: !isBeforeClass,
      enableBeforeClass: isBeforeClass,
      enableDuringClass: !isBeforeClass,
      enableBeforeEnd: false,
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
      beforeClassQuickAction: isBeforeClass
          ? settings.liveBeforeClassQuickAction
          : LiveBeforeClassQuickAction.none,
      beforeClassQuickActionAutoMinutes:
          settings.liveBeforeClassQuickActionAutoMinutes,
      progressBreakOffsetsMillis: provider.buildLiveProgressBreakOffsetsMillis(
        displayCourse,
        startAtMillis: start.millisecondsSinceEpoch,
        endAtMillis: end.millisecondsSinceEpoch,
      ),
      progressMilestoneLabels: milestones
          .map((milestone) => milestone['label'] as String)
          .toList(),
      progressMilestoneTimeTexts: milestones
          .map((milestone) => milestone['timeText'] as String)
          .toList(),
    );

    await liveService.recordDiagnosticEvent(
      'live_update_test_started',
      AppLogMessages.liveUpdateTestStarted,
      extras: {
        'from': source,
        'path': 'course_test',
        'courseName': displayCourse.name,
        'stage': stage.name,
      },
    );

    return LiveTestingTriggerResult(
      status: LiveTestingTriggerStatus.success,
      message: l10n.liveTestingCourseTestStartedToast(
        displayCourse.name,
        isBeforeClass
            ? l10n.liveTestingCourseTestStageBeforeClass
            : l10n.liveTestingCourseTestStageDuringClass,
      ),
    );
  } catch (error, stackTrace) {
    await UmengAnalyticsService.reportDiagnostic(
      'live_update_test_failed',
      AppLogMessages.liveUpdateTestFailed,
      error: error,
      stackTrace: stackTrace,
      dedupeKey: 'live_update_test_failed',
    );
    // 失败时立刻解除双路暂停，避免把正式调度吊死到会话终点。
    provider.clearLiveActivitySyncSuspend();
    await liveService.suspendScheduleTriggers(0);
    return LiveTestingTriggerResult(
      status: LiveTestingTriggerStatus.error,
      message: l10n.sendFailedWithError('$error'),
    );
  } finally {
    unawaited(
      Future<void>.delayed(const Duration(seconds: 2), () {
        liveTestingTriggerInFlight = false;
      }),
    );
  }
}

/// 停止选课测试：解除双路暂停并按正式路径重刷（真实课在窗则立即接管）。
Future<void> cancelLiveUpdateCourseTest(TimetableProvider provider) async {
  final liveService = MiuiLiveActivitiesService();
  provider.clearLiveActivitySyncSuspend();
  await liveService.suspendScheduleTriggers(0);
  await liveService.stopLiveUpdate();
  await provider.refreshLiveActivityNow(forceSnapshotSync: true);
}

/// Fixture slot entry: write a normal course time change, then production refresh.
///
/// The written course is a regular [Course] in the active profile (same storage
/// and week rules as user-created courses). Starting the island is left entirely
/// to [TimetableProvider.refreshLiveActivityNow].
Future<LiveTestingTriggerResult> triggerLiveUpdateTestForSectionSlot({
  required BuildContext context,
  required TimetableProvider provider,
  required int sectionNumber,
  required Duration lead,
  String source = 'quick_fixture_grid',
}) async {
  final now = DateTime.now();
  final timedCourse = await LiveTestingFixtureService.upsertTimedFixtureCourse(
    provider: provider,
    sectionNumber: sectionNumber,
    now: now,
    lead: lead,
  );
  if (!context.mounted) {
    return const LiveTestingTriggerResult(
      status: LiveTestingTriggerStatus.error,
      message: null,
    );
  }
  return triggerLiveUpdateProductionRefresh(
    context: context,
    provider: provider,
    source: source,
    seededCourseId: timedCourse.id,
  );
}

/// Preset-course fallback: arms self-check preset courses in the provider's
/// in-memory live overlay and reruns the same production refresh.
///
/// Presets never touch the real timetable — they only exist in the overlay
/// consumed by live selection and the native schedule snapshot, and the
/// overlay disarms itself once every preset has ended.
Future<LiveActivityCourseSelection?> _triggerWithPresetFixtureCourses({
  required BuildContext context,
  required TimetableProvider provider,
  required MiuiLiveActivitiesService liveService,
  required String source,
}) async {
  final List<Course> presets;
  try {
    presets = LiveTestingFixtureService.buildPresetCourses(
      now: DateTime.now(),
      targetWeek: provider.liveSelectionCalendarWeek,
      semesterWeekCount: provider.settings.semesterWeekCount,
    );
  } catch (error) {
    // 午夜附近无法生成不跨日预设课：按无课处理，维持原有「无课」提示。
    await liveService.recordDiagnosticEvent(
      'live_update_test_preset_skipped',
      AppLogMessages.liveUpdateTestPresetSkipped,
      extras: {'from': source, 'reason': '$error'},
    );
    return null;
  }

  provider.armLiveTestFixtureCourses(presets);
  await liveService.recordDiagnosticEvent(
    'live_update_test_preset_armed',
    AppLogMessages.liveUpdateTestPresetArmed,
    extras: {
      'from': source,
      'courseIds': presets.map((course) => course.id).toList(),
    },
  );

  await provider.refreshLiveActivityNow(forceSnapshotSync: true);
  if (!context.mounted) {
    return null;
  }
  return provider.getLiveActivityCourseSelection();
}
