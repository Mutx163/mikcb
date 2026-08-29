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
