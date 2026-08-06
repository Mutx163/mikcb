import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../logging/app_debug_log.dart';
import '../models/course.dart';
import '../models/exam.dart';
import '../models/schedule_item.dart';

/// One scheduled fire point for an exam reminder (local wall clock).
class ExamReminderFire {
  const ExamReminderFire({
    required this.examId,
    required this.offsetMinutes,
    required this.fireAtMillis,
    required this.examStartMillis,
    required this.title,
    required this.body,
    required this.requestCode,
  });

  final String examId;
  final int offsetMinutes;
  final int fireAtMillis;
  final int examStartMillis;
  final String title;
  final String body;
  final int requestCode;

  Map<String, dynamic> toNativeMap() {
    return {
      'examId': examId,
      'offsetMinutes': offsetMinutes,
      'fireAtMillis': fireAtMillis,
      'examStartMillis': examStartMillis,
      'title': title,
      'body': body,
      'requestCode': requestCode,
    };
  }
}

/// Builds fire points and syncs them to the native AlarmManager scheduler.
class ExamReminderService {
  static const MethodChannel _channel = MethodChannel(
    'com.mutx163.qingyu/exam_reminder',
  );

  /// Namespace for PendingIntent request codes (must match native cancel).
  static const int requestCodeNamespace = 0x46000000;

  static final ExamReminderService _instance = ExamReminderService._internal();
  factory ExamReminderService() => _instance;
  ExamReminderService._internal();

  /// Stable request code shared with native cancel/schedule.
  static int stableRequestCode(String examId, int offsetMinutes) {
    final key = '$examId#$offsetMinutes';
    var hash = 0x811c9dc5;
    for (final codeUnit in key.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return requestCodeNamespace | (hash & 0x00ffffff);
  }

  /// Identifies one logical reminder fire, including its lead time.
  ///
  /// Keeping the offset in the key matters when a user changes a reminder
  /// from (for example) 30 minutes to 60 minutes: the old overdue fire must
  /// not be retried as if it were still part of the active schedule.
  static String fireKey(ExamReminderFire fire) =>
      '${fire.examId}#${fire.offsetMinutes}';

  static Set<String> buildActiveFireKeys(Iterable<ExamReminderFire> fires) {
    return fires.map(fireKey).toSet();
  }

  static const Duration _scheduleReminderHorizon = Duration(days: 366);
  static const Duration _scheduleReminderRetryWindow = Duration(days: 1);

  /// Expands schedule instances and resolves moved overrides by their actual
  /// displayed date. The persisted occurrence id remains the identity used by
  /// native cancellation, while this key prevents a moved override from being
  /// shown/scheduled alongside the natural occurrence at its destination.
  static Map<String, ScheduleItemInstance> _buildScheduleInstances({
    required List<ScheduleItem> scheduleItems,
    required DateTime fromDate,
    required DateTime toDate,
  }) {
    final rootEnabledById = <String, bool>{
      for (final item in scheduleItems)
        if (item.seriesId == null) item.id: item.enabled,
    };
    final instancesByDisplayDate = <String, ScheduleItemInstance>{};

    for (final item in scheduleItems) {
      // Disabling a recurring root disables the whole series, including any
      // persisted overrides. Disabled overrides remain eligible below as
      // tombstones when their root is enabled.
      if (item.seriesId == null && !item.enabled) {
        continue;
      }
      if (item.seriesId != null && rootEnabledById[item.seriesId] == false) {
        continue;
      }

      for (final instance in item.expandInstances(
        fromDate: fromDate,
        toDate: toDate,
      )) {
        final key =
            '${instance.sourceItemId}@${ScheduleItem.formatCalendarDate(instance.date)}';
        final existing = instancesByDisplayDate[key];
        if (existing == null ||
            (instance.item.seriesId != null &&
                existing.item.seriesId == null)) {
          instancesByDisplayDate[key] = instance;
        }
      }
    }
    return instancesByDisplayDate;
  }

  /// Builds one-shot fires for enabled schedule occurrences.
  ///
  /// The native scheduler already reconciles and persists one-shot fires, so
  /// recurring rules are expanded here into a bounded future window. The
  /// occurrence id is namespaced to keep it disjoint from exam ids while
  /// retaining deterministic cancellation across edits and restarts.
  static List<ExamReminderFire> buildScheduleFires({
    required List<ScheduleItem> scheduleItems,
    DateTime? now,
  }) {
    final referenceNow = now ?? DateTime.now();
    final fromDate = ScheduleItem.dateOnly(
      referenceNow.subtract(_scheduleReminderRetryWindow),
    );
    final toDate = ScheduleItem.dateOnly(
      referenceNow.add(_scheduleReminderHorizon),
    );
    final instancesByDisplayDate = _buildScheduleInstances(
      scheduleItems: scheduleItems,
      fromDate: fromDate,
      toDate: toDate,
    );

    final fires = <ExamReminderFire>[];
    for (final instance in instancesByDisplayDate.values) {
      final item = instance.effectiveItem;
      if (!item.enabled) {
        continue;
      }
      final offsetMinutes = item.reminderMinutesBefore;
      if (offsetMinutes == null || offsetMinutes <= 0) {
        continue;
      }
      final start = _buildScheduleDateTime(instance.date, item.startTime);
      if (start == null) {
        continue;
      }
      final fireAt = start.subtract(Duration(minutes: offsetMinutes));
      if (!fireAt.isAfter(referenceNow.subtract(const Duration(seconds: 30)))) {
        continue;
      }
      final scheduleId = _scheduleFireId(instance.occurrenceId);
      fires.add(
        ExamReminderFire(
          examId: scheduleId,
          offsetMinutes: offsetMinutes,
          fireAtMillis: fireAt.millisecondsSinceEpoch,
          examStartMillis: start.millisecondsSinceEpoch,
          title: item.title.trim(),
          body: _buildScheduleBody(item),
          requestCode: stableRequestCode(scheduleId, offsetMinutes),
        ),
      );
    }

    fires.sort(
      (left, right) => left.fireAtMillis.compareTo(right.fireAtMillis),
    );
    return fires;
  }

  static Set<String> buildScheduleActiveIds({
    required List<ScheduleItem> scheduleItems,
    DateTime? now,
  }) {
    final referenceNow = now ?? DateTime.now();
    final fromDate = ScheduleItem.dateOnly(
      referenceNow.subtract(_scheduleReminderRetryWindow),
    );
    final toDate = ScheduleItem.dateOnly(
      referenceNow.add(_scheduleReminderHorizon),
    );
    final instancesByDisplayDate = _buildScheduleInstances(
      scheduleItems: scheduleItems,
      fromDate: fromDate,
      toDate: toDate,
    );
    return instancesByDisplayDate.values
        .where((instance) {
          final item = instance.effectiveItem;
          return item.enabled &&
              item.reminderMinutesBefore != null &&
              item.reminderMinutesBefore! > 0;
        })
        .map((instance) => _scheduleFireId(instance.occurrenceId))
        .toSet();
  }

  static String _scheduleFireId(String occurrenceId) =>
      'schedule:$occurrenceId';

  static DateTime? _buildScheduleDateTime(DateTime date, String value) {
    final parts = value.split(':');
    if (parts.length != 2) {
      return null;
    }
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null || hour < 0 || hour > 23) {
      return null;
    }
    if (minute < 0 || minute > 59) {
      return null;
    }
    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  static String _buildScheduleBody(ScheduleItem item) {
    final parts = <String>['${item.startTime.trim()}-${item.endTime.trim()}'];
    final location = item.location?.trim();
    if (location != null && location.isNotEmpty) {
      parts.add(location);
    }
    return parts.join(' · ');
  }

  /// Expands [exams] into future fire points. Pure function for unit tests.
  static List<ExamReminderFire> buildFires({
    required List<Exam> exams,
    required Course? Function(Exam exam) resolveCourse,
    DateTime? now,
  }) {
    final referenceNow = now ?? DateTime.now();
    final fires = <ExamReminderFire>[];

    for (final exam in exams) {
      final endParts = Exam.parseTimeOfDayParts(
        exam.endTime,
        fallbackHour: 23,
        fallbackMinute: 59,
      );
      final examEnd = DateTime(
        exam.dateTime.year,
        exam.dateTime.month,
        exam.dateTime.day,
        endParts.$1,
        endParts.$2,
      );
      if (!examEnd.isAfter(referenceNow)) {
        continue;
      }

      final offsets = exam.effectiveReminderMinutes.toSet().toList()..sort();
      if (offsets.isEmpty) {
        continue;
      }

      final examStart = exam.examStartDateTime;
      final examStartMillis = examStart.millisecondsSinceEpoch;
      final course = resolveCourse(exam);
      final body = _buildBody(exam, course);

      for (final offsetMinutes in offsets) {
        if (offsetMinutes <= 0) {
          continue;
        }
        final fireAt = examStart.subtract(Duration(minutes: offsetMinutes));
        // Skip fires already in the past (with a small grace for clock skew).
        // Native separately retains only points that actually fired but could
        // not post, so reconstructing past points here would cause duplicates.
        if (!fireAt.isAfter(
          referenceNow.subtract(const Duration(seconds: 30)),
        )) {
          continue;
        }
        // Empty title → native falls back to localized
        // notification_exam_reminder_default_title (do not hardcode zh-CN).
        fires.add(
          ExamReminderFire(
            examId: exam.id,
            offsetMinutes: offsetMinutes,
            fireAtMillis: fireAt.millisecondsSinceEpoch,
            examStartMillis: examStartMillis,
            title: exam.name.trim(),
            body: body,
            requestCode: stableRequestCode(exam.id, offsetMinutes),
          ),
        );
      }
    }

    fires.sort(
      (left, right) => left.fireAtMillis.compareTo(right.fireAtMillis),
    );
    return fires;
  }

  static String _buildBody(Exam exam, Course? course) {
    final parts = <String>['${exam.startTime}-${exam.endTime}'];
    final location = exam.location?.trim().isNotEmpty == true
        ? exam.location!.trim()
        : course?.location.trim();
    if (location != null && location.isNotEmpty) {
      parts.add(location);
    }
    final seatNumber = exam.seatNumber?.trim();
    if (seatNumber != null && seatNumber.isNotEmpty) {
      parts.add(seatNumber);
    }
    return parts.join(' · ');
  }

  /// Full reconcile: replaces all native exam-reminder alarms with [exams].
  Future<bool> reconcile({
    required List<Exam> exams,
    required Course? Function(Exam exam) resolveCourse,
    List<ScheduleItem> scheduleItems = const [],
    DateTime? now,
  }) async {
    final referenceNow = now ?? DateTime.now();
    final fires = <ExamReminderFire>[
      ...buildFires(
        exams: exams,
        resolveCourse: resolveCourse,
        now: referenceNow,
      ),
      ...buildScheduleFires(scheduleItems: scheduleItems, now: referenceNow),
    ];
    final activeExamIds = exams
        .where((exam) => !exam.isExpired)
        .map((exam) => exam.id)
        .toSet();
    activeExamIds.addAll(
      buildScheduleActiveIds(scheduleItems: scheduleItems, now: referenceNow),
    );
    return syncFires(
      fires,
      activeExamIds: activeExamIds,
      activeFireKeys: buildActiveFireKeys(fires),
    );
  }

  Future<bool> syncFires(
    List<ExamReminderFire> fires, {
    Set<String> activeExamIds = const {},
    Set<String>? activeFireKeys,
  }) async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return true;
    }
    try {
      final payload = <String, dynamic>{
        'fires': fires.map((fire) => fire.toNativeMap()).toList(),
        'activeExamIds': activeExamIds.toList(growable: false),
      };
      if (activeFireKeys != null) {
        payload['activeFireKeys'] = activeFireKeys.toList(growable: false);
      }
      await _channel.invokeMethod<void>('reconcile', payload);
      return true;
    } on MissingPluginException {
      if (kDebugMode) {
        return true;
      }
    } catch (error) {
      appDebugLog('ExamReminder', 'reconcile failed: $error');
    }
    return false;
  }

  Future<bool> clearAll() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return true;
    }
    try {
      await _channel.invokeMethod<void>('clear');
      return true;
    } on MissingPluginException {
      if (kDebugMode) {
        return true;
      }
    } catch (error) {
      appDebugLog('ExamReminder', 'clear failed: $error');
    }
    return false;
  }
}
