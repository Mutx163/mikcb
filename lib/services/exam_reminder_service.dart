import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../logging/app_debug_log.dart';
import '../models/course.dart';
import '../models/exam.dart';

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
  }) async {
    final fires = buildFires(exams: exams, resolveCourse: resolveCourse);
    return syncFires(fires);
  }

  Future<bool> syncFires(List<ExamReminderFire> fires) async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return true;
    }
    try {
      await _channel.invokeMethod<void>('reconcile', {
        'fires': fires.map((fire) => fire.toNativeMap()).toList(),
      });
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
