import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:university_timetable/l10n/app_localizations.dart';

import '../logging/app_log_messages.dart';
import '../models/course.dart';
import '../providers/timetable_provider.dart';
import '../services/miui_live_activities_service.dart';
import '../services/umeng_analytics_service.dart';
import 'live_testing_fixture_service.dart';

enum LiveTestingTriggerStatus { success, inFlight, error }

class LiveTestingTriggerResult {
  final LiveTestingTriggerStatus status;
  final String? message;

  const LiveTestingTriggerResult({required this.status, this.message});
}

bool liveTestingTriggerInFlight = false;

Future<LiveTestingTriggerResult> triggerLiveUpdateTest({
  required BuildContext context,
  required TimetableProvider provider,
  required Course testCourse,
  Course? previewNextCourse,
  Duration beforeClassLead = const Duration(minutes: 1),
  Duration totalCourseDuration =
      LiveTestingFixtureService.defaultCourseDuration,
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

  final locale = Localizations.localeOf(context);
  final l10n = AppLocalizations.of(context)!;
  final now = DateTime.now();
  final start = now.add(beforeClassLead);
  final end = start.add(totalCourseDuration);
  final liveService = MiuiLiveActivitiesService();

  try {
    await provider.initialize();
    await liveService.initialize();
    await liveService.recordDiagnosticEvent(
      'live_update_test_requested',
      AppLogMessages.liveUpdateTestRequested,
      extras: {
        'from': source,
        'currentWeek': provider.currentWeek,
        'courseId': testCourse.id,
      },
    );

    final settings = provider.settings;
    final displaySettings = settings.beforeClassDisplaySettings;
    provider.suspendLiveActivitySyncFor(
      end.difference(now) + const Duration(seconds: 20),
    );
    await liveService.suspendScheduleTriggers(
      end.add(const Duration(seconds: 20)).millisecondsSinceEpoch,
    );
    await liveService.recordDiagnosticEvent(
      'live_update_test_suspend_sync',
      AppLogMessages.liveUpdateTestSuspendSync,
      extras: {
        'untilMillis': end
            .add(const Duration(seconds: 20))
            .millisecondsSinceEpoch,
      },
    );

    final progressMilestones = provider.buildLiveProgressMilestones(
      testCourse,
      startAtMillis: start.millisecondsSinceEpoch,
      endAtMillis: end.millisecondsSinceEpoch,
    );
    final progressBreakOffsetsMillis = provider
        .buildLiveProgressBreakOffsetsMillis(
          testCourse,
          startAtMillis: start.millisecondsSinceEpoch,
          endAtMillis: end.millisecondsSinceEpoch,
        );

    await liveService.recordDiagnosticEvent(
      'live_update_test_starting',
      AppLogMessages.liveUpdateTestStarting,
      extras: {
        'courseName': testCourse.name,
        'startAtMillis': start.millisecondsSinceEpoch,
        'endAtMillis': end.millisecondsSinceEpoch,
        'milestoneCount': progressMilestones.length,
      },
    );

    await liveService.startLiveUpdate(
      testCourse,
      previewNextCourse,
      stage: LiveActivityStage.beforeClass.name,
      beforeClassLeadMillis: beforeClassLead.inMilliseconds,
      startAtMillis: start.millisecondsSinceEpoch,
      endAtMillis: end.millisecondsSinceEpoch,
      endReminderLeadMillis: 0,
      endSecondsCountdownThreshold: settings.liveEndSecondsCountdownThreshold,
      promoteDuringClass: settings.livePromoteDuringClass,
      showNotificationDuringClass: settings.liveShowDuringClassNotification,
      enableBeforeClass: true,
      enableDuringClass: true,
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
      beforeClassQuickAction: settings.liveBeforeClassQuickAction,
      progressBreakOffsetsMillis: progressBreakOffsetsMillis,
      progressMilestoneLabels: progressMilestones
          .map((milestone) => milestone['label'] as String)
          .toList(),
      progressMilestoneTimeTexts: progressMilestones
          .map((milestone) => milestone['timeText'] as String)
          .toList(),
    );

    await liveService.recordDiagnosticEvent(
      'live_update_test_started',
      AppLogMessages.liveUpdateTestStarted,
      extras: {
        'courseName': testCourse.name,
        'stage': LiveActivityStage.beforeClass.name,
      },
    );

    final homeHint = locale.languageCode == 'zh'
        ? '请按 Home 键回到桌面查看超级岛（停留在应用内时系统通常不会弹出）'
        : 'Press Home and watch the island; it usually will not pop while the app stays open.';
    return LiveTestingTriggerResult(
      status: LiveTestingTriggerStatus.success,
      message: '${l10n.liveTestingNotificationSent}\n$homeHint',
    );
  } catch (e, stackTrace) {
    await UmengAnalyticsService.reportDiagnostic(
      'live_update_test_failed',
      AppLogMessages.liveUpdateTestFailed,
      error: e,
      stackTrace: stackTrace,
      dedupeKey: 'live_update_test_failed',
    );
    return LiveTestingTriggerResult(
      status: LiveTestingTriggerStatus.error,
      message: l10n.sendFailedWithError('$e'),
    );
  } finally {
    unawaited(
      Future<void>.delayed(const Duration(seconds: 12), () {
        liveTestingTriggerInFlight = false;
      }),
    );
  }
}

Future<LiveTestingTriggerResult> triggerLiveUpdateTestForHourSlot({
  required BuildContext context,
  required TimetableProvider provider,
  required int hour,
  required Duration lead,
  String source = 'quick_fixture_grid',
}) async {
  final now = DateTime.now();
  final timedCourse = await LiveTestingFixtureService.upsertTimedFixtureCourse(
    provider: provider,
    hour: hour,
    now: now,
    lead: lead,
  );
  if (!context.mounted) {
    return const LiveTestingTriggerResult(
      status: LiveTestingTriggerStatus.error,
      message: null,
    );
  }
  final nextHour = LiveTestingFixtureService.nextHourSlotFor(now);
  final nextTemplate = LiveTestingFixtureService.findFixtureForHour(
    provider,
    nextHour,
  );
  return triggerLiveUpdateTest(
    context: context,
    provider: provider,
    testCourse: timedCourse,
    previewNextCourse: nextTemplate,
    beforeClassLead: lead,
    source: source,
  );
}
