import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import '../models/course.dart';

class MiuiLiveActivitiesService {
  static const MethodChannel _channel = MethodChannel('com.example.university_timetable/miui_live');
  
  static final MiuiLiveActivitiesService _instance = MiuiLiveActivitiesService._internal();
  factory MiuiLiveActivitiesService() => _instance;
  MiuiLiveActivitiesService._internal();

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      await _channel.invokeMethod('initialize');
      _isInitialized = true;
    } catch (e) {
      print('Failed to initialize: $e');
    }
  }

  Future<bool> requestNotificationPermission() async {
    if (!Platform.isAndroid) return true;
    try {
      final result = await _channel.invokeMethod('requestNotificationPermission');
      return result == true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> checkNotificationPermission() async {
    if (!Platform.isAndroid) return true;
    try {
      final result = await _channel.invokeMethod('checkNotificationPermission');
      return result == true;
    } catch (e) {
      return false;
    }
  }

  // 检查推广通知支持
  Future<Map<String, dynamic>> checkPromotedSupport() async {
    try {
      final result = await _channel.invokeMethod('checkPromotedSupport');
      return Map<String, dynamic>.from(result as Map);
    } catch (e) {
      return {
        'androidVersion': 0,
        'hasNotificationPermission': false,
        'hasPromotedPermission': false,
        'canPostPromoted': false,
      };
    }
  }

  // 打开推广通知设置
  Future<void> openPromotedSettings() async {
    try {
      await _channel.invokeMethod('openPromotedSettings');
    } catch (e) {
      print('Failed to open settings: $e');
    }
  }

  Future<void> openNotificationSettings() async {
    try {
      await _channel.invokeMethod('openNotificationSettings');
    } catch (e) {
      print('Failed to open notification settings: $e');
    }
  }

  Future<void> openAutoStartSettings() async {
    try {
      await _channel.invokeMethod('openAutoStartSettings');
    } catch (e) {
      print('Failed to open auto-start settings: $e');
    }
  }

  Future<void> openBatteryOptimizationSettings() async {
    try {
      await _channel.invokeMethod('openBatteryOptimizationSettings');
    } catch (e) {
      print('Failed to open battery optimization settings: $e');
    }
  }

  Future<bool> isIgnoringBatteryOptimizations() async {
    if (!Platform.isAndroid) return true;
    try {
      final result = await _channel.invokeMethod('isIgnoringBatteryOptimizations');
      return result == true;
    } catch (e) {
      return false;
    }
  }

  Future<void> startLiveUpdate(
    Course currentCourse,
    Course? nextCourse, {
    int autoDismissAfterStartMinutes = 0,
    String? stage,
    int? startAtMillis,
    int? endAtMillis,
    int? endReminderLeadMillis,
    int endSecondsCountdownThreshold = 60,
    bool promoteDuringClass = true,
    bool showNotificationDuringClass = true,
    bool enableBeforeClass = true,
    bool enableDuringClass = true,
    bool enableBeforeEnd = true,
    bool showCountdown = true,
    bool showCourseNameInIsland = true,
    bool showLocationInIsland = true,
    bool useShortNameInIsland = true,
    bool hidePrefixText = false,
    List<int> progressBreakOffsetsMillis = const [],
    List<String> progressMilestoneLabels = const [],
    List<String> progressMilestoneTimeTexts = const [],
  }) async {
    await initialize();
    try {
      final data = _buildData(
        currentCourse,
        nextCourse,
        autoDismissAfterStartMinutes: autoDismissAfterStartMinutes,
        stage: stage,
        startAtMillis: startAtMillis,
        endAtMillis: endAtMillis,
        endReminderLeadMillis: endReminderLeadMillis,
        endSecondsCountdownThreshold: endSecondsCountdownThreshold,
        promoteDuringClass: promoteDuringClass,
        showNotificationDuringClass: showNotificationDuringClass,
        enableBeforeClass: enableBeforeClass,
        enableDuringClass: enableDuringClass,
        enableBeforeEnd: enableBeforeEnd,
        showCountdown: showCountdown,
        showCourseNameInIsland: showCourseNameInIsland,
        showLocationInIsland: showLocationInIsland,
        useShortNameInIsland: useShortNameInIsland,
        hidePrefixText: hidePrefixText,
        progressBreakOffsetsMillis: progressBreakOffsetsMillis,
        progressMilestoneLabels: progressMilestoneLabels,
        progressMilestoneTimeTexts: progressMilestoneTimeTexts,
      );
      await _channel.invokeMethod('startLiveUpdate', data);
    } catch (e) {
      print('Failed to start live update: $e');
    }
  }

  Future<void> stopLiveUpdate() async {
    try {
      await _channel.invokeMethod('stopLiveUpdate');
    } catch (e) {
      print('Failed to stop: $e');
    }
  }

  Map<String, dynamic> _buildData(
    Course currentCourse,
    Course? nextCourse, {
    int autoDismissAfterStartMinutes = 0,
    String? stage,
    int? startAtMillis,
    int? endAtMillis,
    int? endReminderLeadMillis,
    int endSecondsCountdownThreshold = 60,
    bool promoteDuringClass = true,
    bool showNotificationDuringClass = true,
    bool enableBeforeClass = true,
    bool enableDuringClass = true,
    bool enableBeforeEnd = true,
    bool showCountdown = true,
    bool showCourseNameInIsland = true,
    bool showLocationInIsland = true,
    bool useShortNameInIsland = true,
    bool hidePrefixText = false,
    List<int> progressBreakOffsetsMillis = const [],
    List<String> progressMilestoneLabels = const [],
    List<String> progressMilestoneTimeTexts = const [],
  }) {
    final data = <String, dynamic>{
      'autoDismissAfterStartMinutes': autoDismissAfterStartMinutes,
      'stage': stage,
      'startAtMillis': startAtMillis,
      'endAtMillis': endAtMillis,
      'endReminderLeadMillis': endReminderLeadMillis,
      'endSecondsCountdownThreshold': endSecondsCountdownThreshold,
      'promoteDuringClass': promoteDuringClass,
      'showNotificationDuringClass': showNotificationDuringClass,
      'enableBeforeClass': enableBeforeClass,
      'enableDuringClass': enableDuringClass,
      'enableBeforeEnd': enableBeforeEnd,
      'showCountdown': showCountdown,
      'progressBreakOffsetsMillis': progressBreakOffsetsMillis,
      'progressMilestoneLabels': progressMilestoneLabels,
      'progressMilestoneTimeTexts': progressMilestoneTimeTexts,
      'islandConfig': {
        'showCourseName': showCourseNameInIsland,
        'showLocation': showLocationInIsland,
        'useShortName': useShortNameInIsland,
        'hidePrefixText': hidePrefixText,
      },
      'currentCourse': {
        'name': currentCourse.name,
        'shortName': currentCourse.shortName,
        'teacher': currentCourse.teacher,
        'location': currentCourse.location,
        'note': currentCourse.note,
        'startTime': currentCourse.startTime,
        'endTime': currentCourse.endTime,
      },
    };
    if (nextCourse != null) {
      data['nextCourse'] = {
        'name': nextCourse.name,
        'shortName': nextCourse.shortName,
        'teacher': nextCourse.teacher,
        'location': nextCourse.location,
        'note': nextCourse.note,
        'startTime': nextCourse.startTime,
        'endTime': nextCourse.endTime,
      };
    }
    return data;
  }
}
