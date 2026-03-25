import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/course.dart';
import '../models/timetable_settings.dart';
import 'umeng_analytics_service.dart';

class MiuiLiveActivitiesService {
  static const MethodChannel _channel =
      MethodChannel('com.example.university_timetable/miui_live');

  static final MiuiLiveActivitiesService _instance =
      MiuiLiveActivitiesService._internal();
  factory MiuiLiveActivitiesService() => _instance;
  MiuiLiveActivitiesService._internal();

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      await _channel.invokeMethod('initialize');
      _isInitialized = true;
    } catch (e, stackTrace) {
      await UmengAnalyticsService.reportDiagnostic(
        'live_update_flutter_initialize_failed',
        'Failed to initialize MIUI live activities channel',
        error: e,
        stackTrace: stackTrace,
      );
      debugPrint('Failed to initialize: $e');
    }
  }

  Future<bool> requestNotificationPermission() async {
    if (!Platform.isAndroid) return true;
    try {
      final result =
          await _channel.invokeMethod('requestNotificationPermission');
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
      debugPrint('Failed to open settings: $e');
    }
  }

  Future<void> openNotificationSettings() async {
    try {
      await _channel.invokeMethod('openNotificationSettings');
    } catch (e) {
      debugPrint('Failed to open notification settings: $e');
    }
  }

  Future<void> openAutoStartSettings() async {
    try {
      await _channel.invokeMethod('openAutoStartSettings');
    } catch (e) {
      debugPrint('Failed to open auto-start settings: $e');
    }
  }

  Future<void> openBatteryOptimizationSettings() async {
    try {
      await _channel.invokeMethod('openBatteryOptimizationSettings');
    } catch (e) {
      debugPrint('Failed to open battery optimization settings: $e');
    }
  }

  Future<void> setHideFromRecents(bool value) async {
    if (!Platform.isAndroid) return;
    await initialize();
    try {
      await _channel.invokeMethod('setHideFromRecents', value);
    } catch (e) {
      debugPrint('Failed to set hide from recents: $e');
    }
  }

  Future<bool> isIgnoringBatteryOptimizations() async {
    if (!Platform.isAndroid) return true;
    try {
      final result =
          await _channel.invokeMethod('isIgnoringBatteryOptimizations');
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
    int beforeClassLeadMillis = 0,
    int? startAtMillis,
    int? endAtMillis,
    int? endReminderLeadMillis,
    int liveClassReminderStartMinutes = 0,
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
    LiveDuringClassTimeDisplayMode duringClassTimeDisplayMode =
        LiveDuringClassTimeDisplayMode.nearest,
    bool enableMiuiIslandLabelImage = false,
    MiuiIslandLabelStyle miuiIslandLabelStyle = MiuiIslandLabelStyle.textOnly,
    MiuiIslandLabelContent miuiIslandLabelContent =
        MiuiIslandLabelContent.courseName,
    String miuiIslandLabelFontColor = '#FFFFFF',
    MiuiIslandLabelFontWeight miuiIslandLabelFontWeight =
        MiuiIslandLabelFontWeight.bold,
    MiuiIslandLabelRenderQuality miuiIslandLabelRenderQuality =
        MiuiIslandLabelRenderQuality.standard,
    double miuiIslandLabelFontSize = 14,
    MiuiIslandExpandedIconMode miuiIslandExpandedIconMode =
        MiuiIslandExpandedIconMode.appIcon,
    String? miuiIslandExpandedIconPath,
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
        beforeClassLeadMillis: beforeClassLeadMillis,
        startAtMillis: startAtMillis,
        endAtMillis: endAtMillis,
        endReminderLeadMillis: endReminderLeadMillis,
        liveClassReminderStartMinutes: liveClassReminderStartMinutes,
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
        duringClassTimeDisplayMode: duringClassTimeDisplayMode,
        enableMiuiIslandLabelImage: enableMiuiIslandLabelImage,
        miuiIslandLabelStyle: miuiIslandLabelStyle,
        miuiIslandLabelContent: miuiIslandLabelContent,
        miuiIslandLabelFontColor: miuiIslandLabelFontColor,
        miuiIslandLabelFontWeight: miuiIslandLabelFontWeight,
        miuiIslandLabelRenderQuality: miuiIslandLabelRenderQuality,
        miuiIslandLabelFontSize: miuiIslandLabelFontSize,
        miuiIslandExpandedIconMode: miuiIslandExpandedIconMode,
        miuiIslandExpandedIconPath: miuiIslandExpandedIconPath,
        progressBreakOffsetsMillis: progressBreakOffsetsMillis,
        progressMilestoneLabels: progressMilestoneLabels,
        progressMilestoneTimeTexts: progressMilestoneTimeTexts,
      );
      await _channel.invokeMethod('startLiveUpdate', data);
    } catch (e, stackTrace) {
      await UmengAnalyticsService.reportDiagnostic(
        'live_update_start_failed',
        'Failed to start live update from Flutter',
        error: e,
        stackTrace: stackTrace,
      );
      debugPrint('Failed to start live update: $e');
    }
  }

  Future<void> stopLiveUpdate() async {
    try {
      await _channel.invokeMethod('stopLiveUpdate');
    } catch (e, stackTrace) {
      await UmengAnalyticsService.reportDiagnostic(
        'live_update_stop_failed',
        'Failed to stop live update from Flutter',
        error: e,
        stackTrace: stackTrace,
      );
      debugPrint('Failed to stop: $e');
    }
  }

  Map<String, dynamic> _buildData(
    Course currentCourse,
    Course? nextCourse, {
    int autoDismissAfterStartMinutes = 0,
    String? stage,
    int beforeClassLeadMillis = 0,
    int? startAtMillis,
    int? endAtMillis,
    int? endReminderLeadMillis,
    int liveClassReminderStartMinutes = 0,
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
    LiveDuringClassTimeDisplayMode duringClassTimeDisplayMode =
        LiveDuringClassTimeDisplayMode.nearest,
    bool enableMiuiIslandLabelImage = false,
    MiuiIslandLabelStyle miuiIslandLabelStyle = MiuiIslandLabelStyle.textOnly,
    MiuiIslandLabelContent miuiIslandLabelContent =
        MiuiIslandLabelContent.courseName,
    String miuiIslandLabelFontColor = '#FFFFFF',
    MiuiIslandLabelFontWeight miuiIslandLabelFontWeight =
        MiuiIslandLabelFontWeight.bold,
    MiuiIslandLabelRenderQuality miuiIslandLabelRenderQuality =
        MiuiIslandLabelRenderQuality.standard,
    double miuiIslandLabelFontSize = 14,
    MiuiIslandExpandedIconMode miuiIslandExpandedIconMode =
        MiuiIslandExpandedIconMode.appIcon,
    String? miuiIslandExpandedIconPath,
    List<int> progressBreakOffsetsMillis = const [],
    List<String> progressMilestoneLabels = const [],
    List<String> progressMilestoneTimeTexts = const [],
  }) {
    final data = <String, dynamic>{
      'autoDismissAfterStartMinutes': autoDismissAfterStartMinutes,
      'stage': stage,
      'beforeClassLeadMillis': beforeClassLeadMillis,
      'startAtMillis': startAtMillis,
      'endAtMillis': endAtMillis,
      'endReminderLeadMillis': endReminderLeadMillis,
      'liveClassReminderStartMinutes': liveClassReminderStartMinutes,
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
        'duringClassTimeDisplayMode': duringClassTimeDisplayMode.value,
        'enableMiuiIslandLabelImage': enableMiuiIslandLabelImage,
        'miuiIslandLabelStyle': miuiIslandLabelStyle.value,
        'miuiIslandLabelContent': miuiIslandLabelContent.value,
        'miuiIslandLabelFontColor': miuiIslandLabelFontColor,
        'miuiIslandLabelFontWeight': miuiIslandLabelFontWeight.value,
        'miuiIslandLabelRenderQuality': miuiIslandLabelRenderQuality.value,
        'miuiIslandLabelFontSize': miuiIslandLabelFontSize,
        'miuiIslandExpandedIconMode': miuiIslandExpandedIconMode.value,
        'miuiIslandExpandedIconPath': miuiIslandExpandedIconPath,
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

  Future<void> syncScheduleSnapshot({
    required List<Course> courses,
    required TimetableSettings settings,
    required int currentWeek,
    DateTime? semesterStartDate,
    required int endReminderLeadMillis,
  }) async {
    await initialize();
    try {
      final snapshotJson = jsonEncode({
        'currentWeek': currentWeek,
        'semesterStartMillis': semesterStartDate?.millisecondsSinceEpoch,
        'endReminderLeadMillis': endReminderLeadMillis,
        'courses': courses.map((course) => course.toJson()).toList(),
        'settings': settings.toJson(),
      });
      await _channel.invokeMethod('syncScheduleSnapshot', snapshotJson);
    } catch (e, stackTrace) {
      await UmengAnalyticsService.reportDiagnostic(
        'live_update_snapshot_sync_failed',
        'Failed to sync live update schedule snapshot',
        error: e,
        stackTrace: stackTrace,
      );
      debugPrint('Failed to sync schedule snapshot: $e');
    }
  }

  Future<void> clearScheduleSnapshot() async {
    await initialize();
    try {
      await _channel.invokeMethod('clearScheduleSnapshot');
    } catch (e, stackTrace) {
      await UmengAnalyticsService.reportDiagnostic(
        'live_update_snapshot_clear_failed',
        'Failed to clear live update schedule snapshot',
        error: e,
        stackTrace: stackTrace,
      );
      debugPrint('Failed to clear schedule snapshot: $e');
    }
  }
}
