import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 要写入系统日历的单个日程（一次具体出现，非重复规则）。
@immutable
class CalendarSyncEvent {
  const CalendarSyncEvent({
    required this.start,
    required this.end,
    required this.title,
    this.location,
    this.description,
  });

  final DateTime start;
  final DateTime end;
  final String title;
  final String? location;
  final String? description;

  Map<String, Object?> toChannelPayload() => <String, Object?>{
        'startMs': start.millisecondsSinceEpoch,
        'endMs': end.millisecondsSinceEpoch,
        'title': title,
        'location': location,
        'description': description,
      };
}

/// 一次同步的结果。
@immutable
class CalendarSyncOutcome {
  const CalendarSyncOutcome({required this.syncedCount, this.error});

  /// 原生日历里本次写入的日程数；失败时为 0。
  final int syncedCount;

  /// 失败原因（错误码或消息）；成功时为 null。
  final String? error;

  bool get isSuccess => error == null;
}

/// 一次移除的结果（三态，UI 据此给不同提示）。
enum CalendarDeleteResult { deleted, notSynced, failed }

/// 把课表日程一键写入手机系统日历。
///
/// 原生侧（[CalendarSync.kt]）维护一个本应用专属的**本地日历**（不依赖
/// 任何云账户），每次同步 = 清空该日历旧日程 + 写入本次日程，天然幂等，
/// 不会因重复点击产生重复日程。日历权限（READ/WRITE_CALENDAR）的运行时
/// 申请也由原生侧转发，这里只暴露问询与请求两个动作。
class CalendarSyncService {
  CalendarSyncService({MethodChannel? channel})
      : _channel = channel ??
            const MethodChannel('com.mutx163.qingyu/calendar_sync');

  final MethodChannel _channel;

  /// 日历权限（读+写）是否已授予。
  Future<bool> isPermissionGranted() async {
    try {
      return await _channel.invokeMethod<bool>('checkPermission') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// 弹出系统权限对话框请求日历权限；返回是否获得授权。
  ///
  /// 用户拒绝、或当前没有可用 Activity（理论上不会发生）都返回 false。
  Future<bool> requestPermission() async {
    try {
      return await _channel.invokeMethod<bool>('requestPermission') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// 把 [events] 全量写入专属本地日历 [calendarName]，返回写入数量。
  ///
  /// 该日历此前由本应用写入的所有日程会被整体替换；[calendarName] 只是
  /// 在系统日历列表里显示的名字，不参与身份判定（身份=专属账户）。
  Future<CalendarSyncOutcome> sync({
    required String calendarName,
    required List<CalendarSyncEvent> events,
  }) async {
    try {
      final count = await _channel.invokeMethod<int>('sync', <String, Object?>{
        'calendarName': calendarName,
        'events': [for (final event in events) event.toChannelPayload()],
      });
      return CalendarSyncOutcome(syncedCount: count ?? 0);
    } on PlatformException catch (error) {
      return CalendarSyncOutcome(
        syncedCount: 0,
        error: error.message ?? error.code,
      );
    } on MissingPluginException {
      return const CalendarSyncOutcome(
        syncedCount: 0,
        error: 'unsupported_platform',
      );
    }
  }

  /// 删除专属日历及其全部日程（反悔可随时重新 [sync]，日历会原样重建）。
  ///
  /// 三态区分：[CalendarDeleteResult.deleted] = 删掉了；`notSynced` =
  /// 从未同步过（日历不存在）；`failed` = 权限缺失或删除出错。
  Future<CalendarDeleteResult> deleteSynced() async {
    try {
      final deleted = await _channel.invokeMethod<bool>('deleteCalendar') ?? false;
      return deleted
          ? CalendarDeleteResult.deleted
          : CalendarDeleteResult.notSynced;
    } on PlatformException {
      return CalendarDeleteResult.failed;
    } on MissingPluginException {
      return CalendarDeleteResult.failed;
    }
  }
}
