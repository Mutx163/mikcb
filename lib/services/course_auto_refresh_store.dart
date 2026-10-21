import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/course_auto_refresh_decision.dart';

/// 「课表自动更新」的配置与台账（设备本地）。
///
/// ## 为什么单独一个 prefs 键，而不是塞进 `TimetableSettings`
///
/// 这个功能有两类数据：用户偏好（开关 / 时机 / 间隔）和**运行台账**（上次成功、
/// 上次尝试的时间戳）。台账是设备本地的运行状态，跟着课表档案走会出两个错：
/// 换课表就把「刚抓过」忘掉（立刻再抓一次），云同步把它带到另一台机器上则反过来
/// （那台机器永远等不到时间窗）。既然台账必须本地，偏好也放同一处，避免
/// 「偏好跟着课表走、台账不跟」这种半分裂形态。
///
/// 先例：[BingWallpaperStore] 的「每天自动更换」同样是一个独立 prefs 键，
/// 理由相同（设备级的自动行为，不放课表设置）。
///
/// ## 一次性读入内存
///
/// 与 `BingWallpaperStore` 同口径：`load()` 是唯一给缓存赋值的地方，之后
/// [schedule] / [lastSuccessAt] 都是同步读——判定发生在启动与回前台的同步路径上，
/// 不能在那里等一次异步读盘。
class CourseAutoRefreshStore {
  CourseAutoRefreshStore._();

  static CourseAutoRefreshStore? _instance;

  static CourseAutoRefreshStore get instance =>
      _instance ??= CourseAutoRefreshStore._();

  /// 存档键。改结构而不改这个键的话，旧存档会被 [CourseAutoRefreshSchedule.fromJson]
  /// 逐项容错兜底（未知字段忽略、坏值退回默认），不需要版本迁移。
  static const String preferenceKey = 'course_auto_refresh_v1';

  /// 上次**成功**抓到课表的时间（本地时区）。判定「到点没有」用的是它。
  static const String _lastSuccessKey = 'course_auto_refresh_last_success_v1';

  /// 上次**尝试**的时间（无论成败）。只用于失败后的重试冷却。
  static const String _lastAttemptKey = 'course_auto_refresh_last_attempt_v1';

  CourseAutoRefreshSchedule _schedule = const CourseAutoRefreshSchedule();
  DateTime? _lastSuccessAt;
  DateTime? _lastAttemptAt;
  bool _loaded = false;

  CourseAutoRefreshSchedule get schedule => _schedule;
  DateTime? get lastSuccessAt => _lastSuccessAt;
  DateTime? get lastAttemptAt => _lastAttemptAt;
  bool get isLoaded => _loaded;

  /// 从 prefs 读入内存。重复调用是空操作（启动路径与测试都会调）。
  Future<void> load({SharedPreferences? preferences}) async {
    final prefs = preferences ?? await SharedPreferences.getInstance();
    final raw = prefs.getString(preferenceKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        _schedule = CourseAutoRefreshSchedule.fromJson(jsonDecode(raw));
      } catch (_) {
        // 整串坏掉：退回默认（等于功能关闭），不让一条脏存档把启动路径打断。
        _schedule = const CourseAutoRefreshSchedule();
      }
    } else {
      _schedule = const CourseAutoRefreshSchedule();
    }
    _lastSuccessAt = _readTime(prefs, _lastSuccessKey);
    _lastAttemptAt = _readTime(prefs, _lastAttemptKey);
    _loaded = true;
  }

  /// 写入偏好。失败时**保留内存里的新值**并返回 false：下一次写入会重试，
  /// 而判定读的是内存——用户刚点的开关立刻生效，不会等一次成功的落盘。
  Future<bool> saveSchedule(CourseAutoRefreshSchedule next) async {
    _schedule = next;
    final prefs = await SharedPreferences.getInstance();
    return prefs.setString(preferenceKey, jsonEncode(next.toJson()));
  }

  /// 记一次「尝试开始」。
  ///
  /// 必须在**真正发起抓取之前**写：会话中途被系统杀掉时，若没有这条记录，
  /// 下次打开会立刻重来一次，而后台被杀那次可能已经把教务登录走了一半。
  Future<void> recordAttempt(DateTime at) async {
    _lastAttemptAt = at;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastAttemptKey, at.millisecondsSinceEpoch);
  }

  /// 记一次「成功」。
  ///
  /// 注意它同时也把尝试时间推到 `at`：成功之后再判失败冷却没有意义，留着旧的
  /// 尝试时间会让「刚抓成功、马上又因为上一次失败在冷却」这种自相矛盾的状态存在。
  Future<void> recordSuccess(DateTime at) async {
    _lastSuccessAt = at;
    _lastAttemptAt = at;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastSuccessKey, at.millisecondsSinceEpoch);
    await prefs.setInt(_lastAttemptKey, at.millisecondsSinceEpoch);
  }

  /// 下一次「到点」的时刻（界面用来显示「下次约 …」）。
  ///
  /// 返回 null 表示不会自动跑（功能关着，或数据不足以推算）。
  DateTime? nextRunAt(DateTime now) {
    if (!_schedule.enabled) {
      return null;
    }
    final success = _lastSuccessAt;
    switch (_schedule.mode) {
      case CourseAutoRefreshMode.everyLaunch:
        if (success == null) {
          return now;
        }
        return success.add(kCourseAutoRefreshLaunchCooldown);
      case CourseAutoRefreshMode.intervalHours:
        if (success == null) {
          return now;
        }
        return success.add(Duration(hours: _schedule.intervalHours));
      case CourseAutoRefreshMode.dailyAt:
        final startOfToday = DateTime(now.year, now.month, now.day);
        final todaySlot = startOfToday.add(
          Duration(minutes: _schedule.dailyMinuteOfDay),
        );
        // 已经抓过今天这一档：下次就是明天同一时刻。
        if (success != null && !success.isBefore(todaySlot)) {
          return todaySlot.add(const Duration(days: 1));
        }
        return todaySlot;
    }
  }

  DateTime? _readTime(SharedPreferences prefs, String key) {
    final stamp = prefs.getInt(key);
    if (stamp == null || stamp <= 0) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(stamp);
  }

  /// 测试用：清掉静态单例的内存状态（不碰 prefs）。
  static void resetForTesting() {
    final instance = _instance;
    if (instance == null) {
      return;
    }
    instance._schedule = const CourseAutoRefreshSchedule();
    instance._lastSuccessAt = null;
    instance._lastAttemptAt = null;
    instance._loaded = false;
  }
}
