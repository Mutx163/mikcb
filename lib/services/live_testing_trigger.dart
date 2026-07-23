import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:university_timetable/l10n/app_localizations.dart';

import '../logging/app_log_messages.dart';
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

    final selection = provider.getLiveActivityCourseSelection();
    if (selection == null) {
      await liveService.recordDiagnosticEvent(
        'live_update_test_no_selection',
        AppLogMessages.liveUpdateTestNoSelection,
        extras: {
          'from': source,
          'path': 'production_refresh',
          'weekday': DateTime.now().weekday,
          'currentWeek': provider.currentWeek,
          'seededCourseId': seededCourseId,
        },
      );
      return LiveTestingTriggerResult(
        status: LiveTestingTriggerStatus.error,
        message: l10n.liveTestingNoCourseAvailable,
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
    return LiveTestingTriggerResult(
      status: LiveTestingTriggerStatus.success,
      message:
          '${l10n.liveTestingNotificationSent}\n'
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
