import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'home_widget_snapshot_service.dart';

class HomeWidgetService {
  static const MethodChannel _channel =
      MethodChannel('com.mutx163.qingyu/home_widget');

  static final HomeWidgetService _instance = HomeWidgetService._internal();
  factory HomeWidgetService() => _instance;
  HomeWidgetService._internal();

  Future<bool> syncSnapshot(HomeWidgetSnapshot snapshot) async {
    try {
      await _channel.invokeMethod(
        'syncSnapshot',
        snapshot.toJson(),
      );
      return true;
    } on MissingPluginException {
      if (kDebugMode) {
        return true;
      }
    } catch (e) {
      debugPrint('Failed to sync home widget snapshot: $e');
    }
    return false;
  }

  Future<bool> clearSnapshot() async {
    try {
      await _channel.invokeMethod('clearSnapshot');
      return true;
    } on MissingPluginException {
      if (kDebugMode) {
        return true;
      }
    } catch (e) {
      debugPrint('Failed to clear home widget snapshot: $e');
    }
    return false;
  }

  Future<void> scheduleRefresh(List<int> triggerAtMillis) async {
    try {
      await _channel.invokeMethod(
        'scheduleRefresh',
        {'triggerAtMillis': triggerAtMillis},
      );
    } on MissingPluginException {
      if (kDebugMode) {
        return;
      }
    } catch (e) {
      debugPrint('Failed to schedule home widget refresh: $e');
    }
  }
}
