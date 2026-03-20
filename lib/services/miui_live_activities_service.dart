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

  Future<void> startLiveUpdate(
    Course currentCourse,
    Course? nextCourse, {
    int autoDismissAfterStartMinutes = 0,
  }) async {
    await initialize();
    try {
      final data = _buildData(
        currentCourse,
        nextCourse,
        autoDismissAfterStartMinutes: autoDismissAfterStartMinutes,
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
  }) {
    final data = <String, dynamic>{
      'currentCourse': {
        'name': currentCourse.name,
        'teacher': currentCourse.teacher,
        'location': currentCourse.location,
        'startTime': currentCourse.startTime,
        'endTime': currentCourse.endTime,
      },
      'autoDismissAfterStartMinutes': autoDismissAfterStartMinutes,
    };
    if (nextCourse != null) {
      data['nextCourse'] = {
        'name': nextCourse.name,
        'teacher': nextCourse.teacher,
        'location': nextCourse.location,
        'startTime': nextCourse.startTime,
        'endTime': nextCourse.endTime,
      };
    }
    return data;
  }
}
