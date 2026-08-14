import 'package:flutter/services.dart';

/// 统计小组件（桌面）快照：由统计页计算后同步给原生渲染。
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
}

/// 同步统计快照到原生小组件（复用 home_widget channel，方法级隔离）。
class StatsWidgetService {
  StatsWidgetService._();

  static const MethodChannel _channel = MethodChannel(
    'com.mutx163.qingyu/home_widget',
  );

  static Future<void> syncSnapshot(StatsWidgetSnapshot snapshot) async {
    try {
      await _channel.invokeMethod('syncStatsSnapshot', snapshot.toJson());
    } catch (_) {
      // 平台未实现（非 Android / 桌面调试）时静默
    }
  }

  static Future<void> clearSnapshot() async {
    try {
      await _channel.invokeMethod('clearStatsSnapshot');
    } catch (_) {
      // 静默
    }
  }
}
