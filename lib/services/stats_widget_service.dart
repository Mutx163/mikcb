import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/course.dart';
import 'statistics_service.dart';

/// 统计小组件（桌面）快照：由课表数据计算后同步给原生渲染。
class StatsWidgetSnapshot {
  final String profileName;
  final int currentWeek;
  final int weekSections; // 本周课时
  final int weekCourseCount; // 本周课程门数
  final int deltaVsLastWeek; // 较上周差值
  final int semesterDone; // 已上课时
  final int semesterTotal; // 学期计划总课时
  final int requiredCount; // 必修门数
  final int electiveCount; // 选修门数
  final int longestStreak; // 最长连续上课天数

  const StatsWidgetSnapshot({
    required this.profileName,
    required this.currentWeek,
    required this.weekSections,
    required this.weekCourseCount,
    required this.deltaVsLastWeek,
    required this.semesterDone,
    required this.semesterTotal,
    required this.requiredCount,
    required this.electiveCount,
    required this.longestStreak,
  });

  Map<String, dynamic> toJson() {
    return {
      'profileName': profileName,
      'currentWeek': currentWeek,
      'weekSections': weekSections,
      'weekCourseCount': weekCourseCount,
      'deltaVsLastWeek': deltaVsLastWeek,
      'semesterDone': semesterDone,
      'semesterTotal': semesterTotal,
      'requiredCount': requiredCount,
      'electiveCount': electiveCount,
      'longestStreak': longestStreak,
    };
  }

  /// 从课表数据构建快照；无课时返回 null，由调用方决定跳过还是清空。
  static StatsWidgetSnapshot? fromCourses({
    required List<Course> courses,
    required int currentWeek,
    required int semesterWeekCount,
    required String profileName,
  }) {
    if (courses.isEmpty) {
      return null;
    }
    final weekStats = StatisticsService.calculate(
      allCourses: courses,
      week: currentWeek,
    );
    final semesterStats = StatisticsService.calculateSemester(
      allCourses: courses,
      currentWeek: currentWeek,
      semesterWeekCount: semesterWeekCount,
    );
    final progress = StatisticsService.calculateSemesterProgress(
      allCourses: courses,
      currentWeek: currentWeek,
      semesterWeekCount: semesterWeekCount,
    );
    final comparison = StatisticsService.calculateWeeklyComparison(
      allCourses: courses,
      currentWeek: currentWeek,
      semesterWeekCount: semesterWeekCount,
    );
    return StatsWidgetSnapshot(
      profileName: profileName,
      currentWeek: currentWeek,
      weekSections: weekStats.totalSections,
      weekCourseCount: weekStats.totalCourses,
      deltaVsLastWeek: comparison.deltaVsLastWeek,
      semesterDone: semesterStats.totalSections,
      semesterTotal: progress.sectionsTotal,
      requiredCount: semesterStats.natureStats.requiredCount,
      electiveCount: semesterStats.natureStats.electiveCount,
      longestStreak: semesterStats.longestStreak,
    );
  }
}

/// 同步统计快照到原生小组件（复用 home_widget channel，方法级隔离）。
class StatsWidgetService {
  StatsWidgetService._();

  static const MethodChannel _channel = MethodChannel(
    'com.mutx163.qingyu/home_widget',
  );

  /// 上次成功推送的负载；统计页每次 build 都会调用同步，靠它挡掉重复跨端写入。
  static String? _lastPushedPayload;

  static Future<void> syncSnapshot(StatsWidgetSnapshot snapshot) async {
    final payload = jsonEncode(snapshot.toJson());
    if (payload == _lastPushedPayload) {
      return;
    }
    try {
      await _channel.invokeMethod('syncStatsSnapshot', snapshot.toJson());
      _lastPushedPayload = payload;
    } catch (_) {
      // 平台未实现（非 Android / 桌面调试）时静默
    }
  }

  static Future<void> clearSnapshot() async {
    _lastPushedPayload = null;
    try {
      await _channel.invokeMethod('clearStatsSnapshot');
    } catch (_) {
      // 静默
    }
  }
}
