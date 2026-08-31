import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../logging/app_debug_log.dart';
import 'app_log_service.dart';
import '../services/app_http_client.dart';
import '../models/holiday_entry.dart';
import 'user_data_sync_hooks.dart';

/// A single log entry from the holiday update process.
class HolidayLogEntry {
  final DateTime timestamp;
  final String message;

  const HolidayLogEntry(this.timestamp, this.message);

  String get timeString {
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    final s = timestamp.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}

/// 节假日数据加载/缓存/远程更新服务
///
/// 优先级：内存缓存 > 本地存储 > 远程拉取 > 内置资源（离线兜底）
class HolidayService {
  static const _cacheKeyPrefix = 'holiday_data_';
  static const _customHolidaysKey = 'custom_holidays';
  static const _remoteHolidayBaseUrl =
      'https://publicapi.xiaoai.me/holiday/year';
  static const _fallbackHolidayBaseUrl =
      'https://holiday.ailcc.com/api/holiday/year';

  final http.Client _client;
  final bool _ownsClient;

  /// 内存缓存
  final Map<int, HolidayData> _memoryCache = {};

  @visibleForTesting
  SharedPreferences? prefsForTesting;

  HolidayService({http.Client? client})
    : this._internal(client ?? createAppHttpClient(), client == null);

  HolidayService._internal(this._client, bool ownsCandidate)
    : _ownsClient = ownsCandidate && !isSharedAppHttpClient(_client);

  /// 释放 HTTP 客户端资源
  void dispose() {
    if (_ownsClient) {
      _client.close();
    }
  }

  /// Update process logs (most recent first, capped at 50).
  final List<HolidayLogEntry> logs = [];

  /// Fired when a background remote fetch overwrites in-memory + prefs cache
  /// with different data. Provider should reload and re-push live surfaces.
  void Function(int year)? onRemoteHolidayDataUpdated;

  void _log(String message, {bool verbose = false}) {
    final entry = HolidayLogEntry(DateTime.now(), message);
    logs.insert(0, entry);
    if (logs.length > 50) logs.removeLast();
    if (kDebugMode && !verbose) {
      appDebugLog('HolidayService', message);
    }
  }

  void _logKey(
    String key, {
    Map<String, Object?> params = const {},
    bool verbose = false,
  }) {
    if (params.isEmpty) {
      _log(key, verbose: verbose);
      return;
    }
    final buffer = StringBuffer(key);
    for (final entry in params.entries) {
      buffer.write('|${entry.key}=${entry.value}');
    }
    _log(buffer.toString(), verbose: verbose);
  }

  static const holidayNameMakeupWorkdayKey = 'holiday_name:makeup_workday';

  /// 获取指定年份的节假日数据
  ///
  /// 有本地缓存时先返回缓存、后台拉远程覆盖；
  /// 无缓存时阻塞拉远程，失败才用内置资产兜底。
  Future<HolidayData> getDataForYear(int year) async {
    // 1. 内存缓存
    final cached = _memoryCache[year];
    if (cached != null) {
      _logKey(
        'holiday_log_memory_cache_hit',
        params: {'year': year, 'count': cached.entries.length},
        verbose: true,
      );
      _backgroundRefresh(year);
      return cached;
    }

    // 2. SharedPreferences 缓存
    final localCached = await _loadFromLocalCache(year);
    if (localCached != null) {
      _memoryCache[year] = localCached;
      _logKey(
        'holiday_log_local_cache_hit',
        params: {'year': year, 'count': localCached.entries.length},
        verbose: true,
      );
      _backgroundRefresh(year);
      return localCached;
    }

    // 3. 无缓存 → 阻塞拉远程
    _logKey('holiday_log_no_cache_fetching', params: {'year': year});
    final remote = await _fetchRemoteUpdate(year);
    if (remote != null && remote.entries.isNotEmpty) {
      _memoryCache[year] = remote;
      await _saveToLocalCache(year, remote);
      _logKey(
        'holiday_log_remote_success',
        params: {'year': year, 'count': remote.entries.length},
      );
      return remote;
    }

    // 4. 离线兜底：加载内置资源
    _logKey('holiday_log_remote_failed_builtin', params: {'year': year});
    final builtin = await _loadBuiltin(year);
    _memoryCache[year] = builtin;
    await _saveToLocalCache(year, builtin);
    _logKey(
      'holiday_log_builtin_loaded',
      params: {'year': year, 'count': builtin.entries.length},
    );
    return builtin;
  }

  /// 后台拉取远程数据并覆盖本地缓存
  void _backgroundRefresh(int year) {
    unawaited(
      _fetchRemoteUpdate(year).then((remote) {
        if (remote != null && remote.entries.isNotEmpty) {
          final previous = _memoryCache[year];
          final previousJson = previous?.toJsonString();
          final remoteJson = remote.toJsonString();
          final didChange = previousJson != remoteJson;
          _memoryCache[year] = remote;
          unawaited(_saveToLocalCache(year, remote));
          _logKey(
            'holiday_log_background_success',
            params: {
              'year': year,
              'count': remote.entries.length,
              'changed': didChange,
            },
            verbose: true,
          );
          if (didChange) {
            onRemoteHolidayDataUpdated?.call(year);
          }
        } else {
          _logKey('holiday_log_background_no_data', params: {'year': year});
        }
      }).catchError((Object e, StackTrace stackTrace) {
        // .then 回调链无兜底时的防线：远程刷新失败不外抛为 unhandled
        // zone 异常（顶层兜底虽有，但这里补齐让失败可归因到后台刷新）。
        unawaited(
          AppLogService.instance.warn(
            'holiday_background_refresh_failed',
            '节假日后台刷新异常',
            error: e,
            stackTrace: stackTrace,
          ),
        );
      }),
    );
  }

  /// Test-only: run the same background refresh path as [getDataForYear].
  @visibleForTesting
  Future<void> backgroundRefreshForTest(int year) async {
    final remote = await _fetchRemoteUpdate(year);
    if (remote != null && remote.entries.isNotEmpty) {
      final previous = _memoryCache[year];
      final previousJson = previous?.toJsonString();
      final remoteJson = remote.toJsonString();
      final didChange = previousJson != remoteJson;
      _memoryCache[year] = remote;
      await _saveToLocalCache(year, remote);
      if (didChange) {
        onRemoteHolidayDataUpdated?.call(year);
      }
    }
  }

  Future<HolidayData?> _loadFromLocalCache(int year) async {
    try {
      final prefs = await _ensurePrefs();
      final raw = prefs.getString('$_cacheKeyPrefix$year');
      if (raw == null) return null;
      return HolidayData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveToLocalCache(int year, HolidayData data) async {
    try {
      final prefs = await _ensurePrefs();
      await prefs.setString('$_cacheKeyPrefix$year', data.toJsonString());
    } catch (_) {
      // ignore cache write failures
    }
  }

  Future<HolidayData> _loadBuiltin(int year) async {
    try {
      final json = await rootBundle.loadString('assets/holidays/$year.json');
      return HolidayData.fromJson(jsonDecode(json) as Map<String, dynamic>);
    } catch (_) {
      // If the asset file doesn't exist for this year, return empty data
      return HolidayData(year: year, version: 1, entries: const []);
    }
  }

  Future<HolidayData?> _fetchRemoteUpdate(int year) async {
    // Try primary API first, then fallback
    final result = await _fetchFromXiaoai(year);
    if (result != null) return result;
    _logKey('holiday_log_primary_api_failed');
    return _fetchFromAilcc(year);
  }

  Future<HolidayData?> _fetchFromXiaoai(int year) async {
    try {
      final uri = Uri.parse('$_remoteHolidayBaseUrl?year=$year');
      _logKey(
        'holiday_log_requesting',
        params: {'uri': uri.toString()},
        verbose: true,
      );
      final response = await _client
          .get(
            uri,
            headers: const {
              'Accept': 'application/json',
              'User-Agent': 'mikcb-holiday-sync',
            },
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) {
        _logKey(
          'holiday_log_primary_api_status',
          params: {'statusCode': response.statusCode},
        );
        return null;
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (json['code'] != 0) {
        _logKey(
          'holiday_log_primary_api_error',
          params: {'message': '${json['msg']}'},
        );
        return null;
      }
      final list = json['data'] as List<dynamic>;
      _logKey(
        'holiday_log_primary_api_parsing',
        params: {'count': list.length},
        verbose: true,
      );
      final entries = _convertApiEntries(list, year);
      if (entries.isEmpty) {
        _logKey('holiday_log_no_valid_entries');
        return null;
      }

      return HolidayData(year: year, version: 1, entries: entries);
    } catch (e) {
      _logKey('holiday_log_primary_api_exception', params: {'error': '$e'});
      return null;
    }
  }

  Future<HolidayData?> _fetchFromAilcc(int year) async {
    try {
      final uri = Uri.parse('$_fallbackHolidayBaseUrl/$year');
      _logKey(
        'holiday_log_requesting',
        params: {'uri': uri.toString()},
        verbose: true,
      );
      final response = await _client
          .get(
            uri,
            headers: const {
              'Accept': 'application/json',
              'User-Agent': 'mikcb-holiday-sync',
            },
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) {
        _logKey(
          'holiday_log_fallback_api_status',
          params: {'statusCode': response.statusCode},
        );
        return null;
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (json['code'] != 0) {
        _logKey('holiday_log_fallback_api_error');
        return null;
      }
      final holidayMap = json['holiday'] as Map<String, dynamic>;
      _logKey(
        'holiday_log_fallback_api_parsing',
        params: {'count': holidayMap.length},
        verbose: true,
      );
      final entries = _convertAilccEntries(holidayMap, year);
      if (entries.isEmpty) {
        _logKey('holiday_log_no_valid_entries');
        return null;
      }

      return HolidayData(year: year, version: 1, entries: entries);
    } catch (e) {
      _logKey('holiday_log_fallback_api_exception', params: {'error': '$e'});
      return null;
    }
  }

  /// Convert API response to grouped HolidayEntry list.
  /// xiaoai API daytype: 1=holiday, 2=makeup workday, 3=weekend, 4=workday
  List<HolidayEntry> _convertApiEntries(List<dynamic> list, int year) {
    // Collect holidays and makeup workdays — skip malformed remote entries.
    final holidayDates = <DateTime>[];
    final makeupDates = <DateTime>[];
    for (final item in list) {
      try {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);
        final rawDaytype = map['daytype'];
        int daytype;
        if (rawDaytype is int) {
          daytype = rawDaytype;
        } else if (rawDaytype is num) {
          daytype = rawDaytype.toInt();
        } else {
          continue;
        }
        final rest = (map['rest'] as num?)?.toInt() ?? 1;
        final rawDate = map['date'];
        if (rawDate is! String || rawDate.trim().isEmpty) continue;
        final date = DateTime.tryParse(rawDate);
        if (date == null) continue;
        if (daytype == 1) holidayDates.add(date); // 假期
        if (daytype == 3 && rest == 0) makeupDates.add(date); // 调休上班
      } catch (_) {
        continue;
      }
    }

    // Group consecutive holidays
    final groups = <List<DateTime>>[];
    List<DateTime>? current;
    for (final date in holidayDates) {
      if (current != null && _isConsecutive(current.last, date)) {
        current.add(date);
      } else {
        if (current != null) groups.add(current);
        current = [date];
      }
    }
    if (current != null) groups.add(current);

    // Build entries — vacation groups first, then assign makeup workdays
    // to the nearest holiday group.
    final entries = <HolidayEntry>[];
    final groupIds = <String>[];
    for (int i = 0; i < groups.length; i++) {
      final group = groups[i];
      final name = _nameForGroup(group);
      final groupId = 'holiday-$year-$i';
      groupIds.add(groupId);
      for (final date in group) {
        entries.add(
          HolidayEntry(
            date: date,
            name: name,
            type: HolidayType.vacation,
            groupId: groupId,
          ),
        );
      }
    }
    for (final date in makeupDates) {
      // Find the nearest holiday group (within 21 days).
      String? nearestGroupId;
      int minDist = 22;
      for (int i = 0; i < groups.length; i++) {
        final group = groups[i];
        final dist = _absDays(date, group.first);
        final distEnd = _absDays(date, group.last);
        final d = dist < distEnd ? dist : distEnd;
        if (d < minDist) {
          minDist = d;
          nearestGroupId = groupIds[i];
        }
      }
      entries.add(
        HolidayEntry(
          date: date,
          name: holidayNameMakeupWorkdayKey,
          type: HolidayType.adjustedWorkday,
          groupId: nearestGroupId,
        ),
      );
    }

    return entries;
  }

  /// Convert ailcc API response to grouped HolidayEntry list.
  /// ailcc format: {"01-01": {holiday: true, name: "元旦节（休）", ...}}
  List<HolidayEntry> _convertAilccEntries(
    Map<String, dynamic> holidayMap,
    int year,
  ) {
    final holidayDates = <DateTime>[];
    final makeupDates = <DateTime>[];

    for (final entry in holidayMap.entries) {
      try {
        final rawVal = entry.value;
        if (rawVal is! Map) continue;
        final map = Map<String, dynamic>.from(rawVal);
        final rawDate = map['date'];
        if (rawDate is! String || rawDate.trim().isEmpty) continue;
        final date = DateTime.tryParse(rawDate);
        if (date == null) continue;
        final rawHoliday = map['holiday'];
        final bool? isHoliday = switch (rawHoliday) {
          final bool value => value,
          final num value when value == 1 => true,
          final num value when value == 0 => false,
          final String value => switch (value.trim().toLowerCase()) {
              'true' || '1' || 'yes' => true,
              'false' || '0' || 'no' => false,
              _ => null,
            },
          _ => null,
        };
        if (isHoliday == null) continue;
        final name = map['name'] is String ? map['name'] as String : '';
        if (isHoliday) {
          holidayDates.add(date);
        } else if (name.contains('班')) {
          makeupDates.add(date);
        }
      } catch (_) {
        continue;
      }
    }

    // Group consecutive holidays
    final groups = <List<DateTime>>[];
    List<DateTime>? current;
    for (final date in holidayDates) {
      if (current != null && _isConsecutive(current.last, date)) {
        current.add(date);
      } else {
        if (current != null) groups.add(current);
        current = [date];
      }
    }
    if (current != null) groups.add(current);

    // Build entries
    final entries = <HolidayEntry>[];
    final groupIds = <String>[];
    for (int i = 0; i < groups.length; i++) {
      final group = groups[i];
      final name = _nameForGroup(group);
      final groupId = 'holiday-$year-$i';
      groupIds.add(groupId);
      for (final date in group) {
        entries.add(
          HolidayEntry(
            date: date,
            name: name,
            type: HolidayType.vacation,
            groupId: groupId,
          ),
        );
      }
    }
    for (final date in makeupDates) {
      String? nearestGroupId;
      int minDist = 22;
      for (int i = 0; i < groups.length; i++) {
        final group = groups[i];
        final dist = _absDays(date, group.first);
        final distEnd = _absDays(date, group.last);
        final d = dist < distEnd ? dist : distEnd;
        if (d < minDist) {
          minDist = d;
          nearestGroupId = groupIds[i];
        }
      }
      entries.add(
        HolidayEntry(
          date: date,
          name: holidayNameMakeupWorkdayKey,
          type: HolidayType.adjustedWorkday,
          groupId: nearestGroupId,
        ),
      );
    }

    return entries;
  }

  /// Exposed for unit tests that validate API → [HolidayEntry] conversion.
  @visibleForTesting
  List<HolidayEntry> convertApiEntriesForTest(List<dynamic> list, int year) {
    return _convertApiEntries(list, year);
  }

  bool _isConsecutive(DateTime a, DateTime b) => b.difference(a).inDays == 1;

  int _absDays(DateTime a, DateTime b) => a.difference(b).inDays.abs();

  String _nameForGroup(List<DateTime> group) {
    final first = group.first;
    final last = group.last;
    final spanDays = group.length;

    // Fixed-date holidays
    if (first.month == 1 && first.day <= 3) return 'holiday_name:new_year';
    if (first.month == 5 && first.day <= 5) return 'holiday_name:labor_day';
    if (first.month == 10 && first.day <= 7) return 'holiday_name:national_day';

    // 跨年假期：12月31日开始，1月结束 → 元旦
    if (first.month == 12 && last.month == 1) return 'holiday_name:new_year';

    // Lunar holidays by approximate date range
    if (first.month >= 1 && first.month <= 2 && spanDays >= 5) {
      return 'holiday_name:spring_festival';
    }
    if (first.month >= 1 && first.month <= 3 && spanDays >= 7) {
      return 'holiday_name:spring_festival';
    }
    if (first.month == 4 && spanDays <= 4) return 'holiday_name:qingming';
    if (first.month >= 5 && first.month <= 6 && spanDays <= 4) {
      return 'holiday_name:dragon_boat';
    }
    if (first.month >= 9 && first.month <= 10 && spanDays <= 4) {
      return 'holiday_name:mid_autumn';
    }

    return 'holiday_name:statutory';
  }

  Future<SharedPreferences> _ensurePrefs() async {
    return _prefs ??= prefsForTesting ?? await SharedPreferences.getInstance();
  }

  /// Clear all cached data for a year so next getDataForYear reloads from remote
  Future<void> clearCache(int year) async {
    _memoryCache.remove(year);
    try {
      final prefs = await _ensurePrefs();
      await prefs.remove('$_cacheKeyPrefix$year');
    } catch (e) {
      // 清除失败只影响下次是否读到旧缓存，不阻塞调用方；落 AppLogService
      // 而非 appDebugLog，保证 release 包可观测。
      await AppLogService.instance.warn(
        'holiday_cache_clear_failed',
        '清除 $year 年节假日缓存失败',
        error: e,
      );
    }
    _log('$year年：缓存已清除');
  }

  // ---- 自定义假期 ----

  /// 加载用户自定义假期列表
  ///
  /// 返回 null 表示本地持久化数据损坏（JSON 解析失败）：调用方必须把它与
  /// 「合法的空列表」区分开，绝不能把 null 当作空数据继续走 add/save 链，
  /// 否则损坏态会被一次保存写回、把真实数据覆盖清零（数据丢失）。
  /// 单条 entry 损坏仍按容错粒度跳过（见内层 catch）。
  Future<List<HolidayEntry>?> loadCustomHolidays() async {
    try {
      final prefs = await _ensurePrefs();
      final raw = prefs.getString(_customHolidaysKey);
      if (raw == null) return <HolidayEntry>[];
      final list = jsonDecode(raw) as List<dynamic>;
      final out = <HolidayEntry>[];
      for (final e in list) {
        try {
          if (e is! Map) continue;
          out.add(HolidayEntry.fromJson(Map<String, dynamic>.from(e)));
        } catch (_) {
          // 单条记录损坏：跳过该条，不影响其余条目。
          continue;
        }
      }
      return out;
    } catch (e, stackTrace) {
      // 整体解析失败 = 数据损坏，不是「没有数据」。返回 null 让调用方
      // 显式决定如何处理，并落日志（release 包可见）。
      await AppLogService.instance.error(
        'holiday_custom_load_corrupted',
        '自定义假期持久化数据解析失败，已阻止后续写回以防覆盖丢失',
        error: e,
        stackTrace: stackTrace,
      );
      _log('custom_holidays_corrupted|error=${e.toString()}');
      return null;
    }
  }

  /// 保存整个自定义假期列表
  ///
  /// 写入失败时抛出 [HolidayCustomSaveException]：调用方（UI/同步链路）需要
  /// 感知失败并提示用户，静默吞掉会导致用户编辑「看似成功、重启即丢」。
  /// 注意同步钩子必须在写入成功后才触发。
  Future<void> saveCustomHolidays(List<HolidayEntry> entries) async {
    try {
      final prefs = await _ensurePrefs();
      final json = jsonEncode(entries.map((e) => e.toJson()).toList());
      await prefs.setString(_customHolidaysKey, json);
    } catch (e, stackTrace) {
      await AppLogService.instance.error(
        'holiday_custom_save_failed',
        '自定义假期写入本地存储失败',
        error: e,
        stackTrace: stackTrace,
      );
      throw HolidayCustomSaveException(
        'custom holiday persist failed',
        cause: e,
        stackTrace: stackTrace,
      );
    }
    // 仅在确认写盘成功后通知同步链路，失败路径不得触发。
    notifyUserDataChangedForSync();
  }

  /// 新增一条自定义假期
  Future<void> addCustomHoliday(HolidayEntry entry) async {
    final existing = await _loadExistingForMutation();
    existing.add(entry);
    await saveCustomHolidays(existing);
  }

  /// 按 groupId 删除自定义假期
  Future<void> removeCustomHoliday(String groupId) async {
    final existing = await _loadExistingForMutation();
    existing.removeWhere((e) => e.groupId == groupId);
    await saveCustomHolidays(existing);
  }

  /// 按 groupId 更新自定义假期（替换同组所有 entries）
  Future<void> updateCustomHoliday(
    String groupId,
    List<HolidayEntry> newEntries,
  ) async {
    final existing = await _loadExistingForMutation();
    existing.removeWhere((e) => e.groupId == groupId);
    existing.addAll(newEntries);
    await saveCustomHolidays(existing);
  }

  /// 批量新增自定义假期（单次 load → append → save，避免逐条写入的竞态问题）
  Future<void> addCustomHolidays(List<HolidayEntry> entries) async {
    final existing = await _loadExistingForMutation();
    existing.addAll(entries);
    await saveCustomHolidays(existing);
  }

  /// 变更（增/删/改）前的读取：数据损坏时抛出而不是当空列表处理，
  /// 否则 load → mutate → save 链会把空列表写回、覆盖清零真实数据。
  Future<List<HolidayEntry>> _loadExistingForMutation() async {
    final existing = await loadCustomHolidays();
    if (existing == null) {
      throw const HolidayCustomSaveException(
        'custom holiday storage corrupted; refusing to overwrite',
      );
    }
    return existing;
  }
}

/// 自定义假期持久化失败/数据损坏异常。
///
/// 携带 cause 便于上层归因；错误信息不含用户数据，可直接展示或上报。
class HolidayCustomSaveException implements Exception {
  const HolidayCustomSaveException(this.message, {this.cause, this.stackTrace});

  final String message;
  final Object? cause;
  final StackTrace? stackTrace;

  @override
  String toString() =>
      'HolidayCustomSaveException: $message${cause == null ? '' : ' ($cause)'}';
}
