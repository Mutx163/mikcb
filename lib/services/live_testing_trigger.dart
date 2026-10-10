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

  /// 选课测试会话的强制摘除终点（原生暂停终点 = 会话结束 + 20 秒缓冲），
  /// 供 UI 在此刻摘除测试芯片。仅 [triggerLiveUpdateCourseTest] 成功时填充。
  final DateTime? sessionEnd;

  const LiveTestingTriggerResult({
    required this.status,
    this.message,
    this.sessionEnd,
  });
}

bool liveTestingTriggerInFlight = false;

/// 当前进行中的强制起岛会话（选课测试 / 显示页速览共用）。
///
/// 单槽全局：新会话覆盖旧会话，[cancelLiveUpdateCourseTest] 与正式路径刷新
/// （[triggerLiveUpdateProductionRefresh]）清空。会话终点后原生自动收岛，
/// 记录不再有意义——读取一律走 [currentLiveCourseTestSession]，它把已过期
/// 的记录惰性清掉，无需定时器兜底。此前会话状态只存页面内存，返回再进
/// 页面按钮就「忘了」测试还在跑（2026-10-10 用户反馈），故上收到这里。
LiveCourseTestSession? activeLiveCourseTestSession;

/// 读取当前会话；已过暂停终点（岛已被原生收尾）视为无会话并顺手清槽。
LiveCourseTestSession? currentLiveCourseTestSession() {
  final session = activeLiveCourseTestSession;
  if (session == null) return null;
  if (session.sessionEnd.isBefore(DateTime.now())) {
    activeLiveCourseTestSession = null;
    return null;
  }
  return session;
}

/// 强制起岛会话的跨页面记录：UI 据此在重进页面时恢复「停止测试」态。
class LiveCourseTestSession {
  final LiveCourseTestStage stage;
  final String courseName;

  /// 与原生暂停终点对齐的摘除时刻（end + 缓冲）。
  final DateTime sessionEnd;

  const LiveCourseTestSession({
    required this.stage,
    required this.courseName,
    required this.sessionEnd,
  });
}

/// 选课测试的合成时间窗：由基准时刻、阶段变体与会话长度唯一决定，是纯可
/// 推导逻辑（独立成值对象以便无 widget 树直接测试）。
class LiveCourseTestWindow {
  /// 会话起点（课前变体 = now+lead，课中变体 = 已开课锚点）。
  final DateTime start;

  /// 会话终点（到点后原生 ticker 因 stage→null / end 收尾）。
  final DateTime end;

  /// 岛上「开始-结束」钟面用的结束时刻：分钟精度显示，速览窗口不足 1 分钟
  /// 时拉到 start+1min，避免「10:16 - 10:16」的零时长观感。真实起止毫秒
  /// 仍用 [start]/[end]。
  final DateTime clockEnd;

  /// Dart tick 与原生闹钟共同的暂停缓冲（终点 = end + buffer）。
  final Duration suspendBuffer;

  const LiveCourseTestWindow({
    required this.start,
    required this.end,
    required this.clockEnd,
    required this.suspendBuffer,
  });

  /// UI 芯片/按钮的摘除终点（= 原生暂停终点）。
  DateTime sessionEndFrom(DateTime now) => now.add(
    end.difference(now) + suspendBuffer,
  );
}

/// 合成选课测试窗口。
///
/// 经典变体（sessionLength == null）：课前 3 分钟倒计时 + 3 分钟课程，
/// 课中锚定已开课 1 分钟 + 4 分钟后收尾，缓冲 20 秒。
/// 速览变体（sessionLength 非空，如 30 秒）：整段窗口锁在单一阶段——
/// 课前 = 25 秒倒计时 + 5 秒课程尾巴；课中 = 已开课 2 秒、sessionLength
/// 后收尾；缓冲收窄到 5 秒以加快收岛（仍覆盖 Dart 30s tick 的影响窗）。
LiveCourseTestWindow buildCourseTestWindow({
  required DateTime now,
  required LiveCourseTestStage stage,
  Duration? sessionLength,
}) {
  final isBeforeClass = stage == LiveCourseTestStage.beforeClass;
  final DateTime start;
  final DateTime end;
  final Duration suspendBuffer;
  if (sessionLength != null) {
    if (isBeforeClass) {
      start = now.add(sessionLength - const Duration(seconds: 5));
      end = start.add(const Duration(seconds: 5));
    } else {
      start = now.subtract(const Duration(seconds: 2));
      end = now.add(sessionLength);
    }
    suspendBuffer = const Duration(seconds: 5);
  } else {
    start = isBeforeClass
        ? now.add(const Duration(minutes: 3))
        : now.subtract(const Duration(minutes: 1));
    end = isBeforeClass
        ? start.add(const Duration(minutes: 3))
        : now.add(const Duration(minutes: 4));
    suspendBuffer = const Duration(seconds: 20);
  }
  final clockEnd = end.difference(start) < const Duration(minutes: 1)
      ? start.add(const Duration(minutes: 1))
      : end;
  return LiveCourseTestWindow(
    start: start,
    end: end,
    clockEnd: clockEnd,
    suspendBuffer: suspendBuffer,
  );
}

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
    return LiveTestingTriggerResult(
      status: LiveTestingTriggerStatus.inFlight,
      message: AppLocalizations.of(context)!.liveTestingInFlight,
    );
  }
  liveTestingTriggerInFlight = true;

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
    // 正式路径刷新会解除暂停并重选真实课，强制起岛会话随之失效。
    activeLiveCourseTestSession = null;

    // Same entry used after resume / settings changes: re-select from courses.
    await provider.refreshLiveActivityNow(forceSnapshotSync: true);

    if (!context.mounted) {
      return const LiveTestingTriggerResult(
        status: LiveTestingTriggerStatus.error,
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

    final homeHint = l10n.liveTestingProductionHomeHint;
    final presetNote = usedPresetFallback
        ? '${l10n.liveTestingPresetFallbackNote}\n'
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
///
/// [sessionLength] 控制整个强制会话的时长；缺省时用经典变体窗口（课前
/// 3+3 分钟 / 课中 1+4 分钟）。显示设置页的「速览」入口传固定 30 秒。
Future<LiveTestingTriggerResult> triggerLiveUpdateCourseTest({
  required BuildContext context,
  required TimetableProvider provider,
  required Course course,
  required LiveCourseTestStage stage,
  String source = 'settings_screen',
  Duration? sessionLength,
}) async {
  if (liveTestingTriggerInFlight) {
    return LiveTestingTriggerResult(
      status: LiveTestingTriggerStatus.inFlight,
      message: AppLocalizations.of(context)!.liveTestingInFlight,
    );
  }
  liveTestingTriggerInFlight = true;

  final l10n = AppLocalizations.of(context)!;
  final liveService = MiuiLiveActivitiesService();
  final settings = provider.settings;
  final isBeforeClass = stage == LiveCourseTestStage.beforeClass;

  // 合成时间窗：课前变体 3 分钟倒计时；课中变体把开课锚定在 1 分钟前，
  // 已上课 4 分钟后自动收岛。时间只属于本次会话，与课程真实时间无关。
  // 速览变体（sessionLength 非空）：整段窗口锁在单一阶段（见
  // [buildCourseTestWindow]）。窗口合成是纯逻辑，已抽到该函数并单测覆盖。
  final now = DateTime.now();
  final window = buildCourseTestWindow(
    now: now,
    stage: stage,
    sessionLength: sessionLength,
  );
  final start = window.start;
  final end = window.end;
  final suspendBuffer = window.suspendBuffer;
  final displayCourse = provider.resolveCourseDisplayName(
    course.copyWith(
      startTime: LiveTestingFixtureService.formatClock(start),
      endTime: LiveTestingFixtureService.formatClock(window.clockEnd),
    ),
  );
  final testSession = LiveCourseTestSession(
    stage: stage,
    courseName: displayCourse.name,
    sessionEnd: end.add(suspendBuffer),
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
      end.difference(now) + suspendBuffer,
    );
    await liveService.suspendScheduleTriggers(
      end.add(suspendBuffer).millisecondsSinceEpoch,
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
      beforeClassLeadMillis: isBeforeClass
          ? start.difference(now).inMilliseconds
          : 0,
      startAtMillis: start.millisecondsSinceEpoch,
      endAtMillis: end.millisecondsSinceEpoch,
      endReminderLeadMillis: 0,
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
      expandedDetailFields: displaySettings.expandedDetailFields
          ?.map((field) => field.value)
          .toList(),
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

    // 成功起岛后登记跨页面会话：任何页面（含返回重进的显示设置页）都能
    // 据此恢复「停止测试」态并正确取消。
    activeLiveCourseTestSession = testSession;

    return LiveTestingTriggerResult(
      status: LiveTestingTriggerStatus.success,
      // 芯片/按钮摘除终点与原生暂停终点对齐（end + 缓冲）：岛最迟在暂停
      // 到点时被收尾，UI 此刻强制摘芯片，两者不再各写各的时间。
      sessionEnd: end.add(suspendBuffer),
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
    // 失败时立刻解除双路暂停，避免把正式调度吊死到会话终点；并清掉可能
    // 残留的旧会话记录（新会话没起来，不能让旧记录误导 UI）。
    provider.clearLiveActivitySyncSuspend();
    await liveService.suspendScheduleTriggers(0);
    activeLiveCourseTestSession = null;
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
  activeLiveCourseTestSession = null;
  provider.clearLiveActivitySyncSuspend();
  await liveService.suspendScheduleTriggers(0);
  await liveService.stopLiveUpdate();
  await provider.refreshLiveActivityNow(forceSnapshotSync: true);
}

/// 显示设置页「速览」：跳过选课单，直接对指定阶段强制起岛约 [sessionLength]。
///
/// 课程取课表第一组；课表为空时用自检预设课（只进超级岛内存层，不写入
/// 课表）。核心窗口/暂停机制与 [triggerLiveUpdateCourseTest] 完全同路。
Future<LiveTestingTriggerResult> triggerLiveStagePreviewTest({
  required BuildContext context,
  required TimetableProvider provider,
  required LiveCourseTestStage stage,
  Duration sessionLength = const Duration(seconds: 30),
  String source = 'display_settings_preview',
}) async {
  final l10n = AppLocalizations.of(context)!;
  final groups = provider.courseGroups;
  Course course;
  if (groups.isNotEmpty) {
    course = groups.first.courses.first;
  } else {
    // 无课表兜底：借自检预设课的构造规则造一门单节测试课。跨日约束同源
    // （课表不支持隔夜课），午夜附近退回「无课」提示而不是半途崩给用户。
    try {
      final presets = LiveTestingFixtureService.buildPresetCourses(
        now: DateTime.now(),
        targetWeek: provider.liveSelectionCalendarWeek,
        semesterWeekCount: provider.settings.semesterWeekCount,
      );
      course = presets.first;
    } catch (_) {
      return LiveTestingTriggerResult(
        status: LiveTestingTriggerStatus.error,
        message: l10n.liveTestingNoCourseAvailable,
      );
    }
  }
  return triggerLiveUpdateCourseTest(
    context: context,
    provider: provider,
    course: course,
    stage: stage,
    source: source,
    sessionLength: sessionLength,
  );
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
