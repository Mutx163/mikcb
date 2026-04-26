import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/holiday_entry.dart';

/// 节假日数据加载/缓存/远程更新服务
///
/// 优先级：内存缓存 > 本地存储 > 远程拉取 > 内置资源（离线兜底）
class HolidayService {
  static const _cacheKeyPrefix = 'holiday_data_';

  /// 内存缓存
  final Map<int, HolidayData> _memoryCache = {};

  SharedPreferences? _prefs;

  /// 获取指定年份的节假日数据
  Future<HolidayData> getDataForYear(int year) async {
    // 1. 内存缓存
    final cached = _memoryCache[year];
    if (cached != null) return cached;

    // 2. SharedPreferences 缓存
    final localCached = await _loadFromLocalCache(year);
    if (localCached != null) {
      _memoryCache[year] = localCached;
      return localCached;
    }

    // 3. 远程拉取（主数据源）
    final remote = await _fetchRemoteUpdate(year);
    if (remote != null && remote.entries.isNotEmpty) {
      _memoryCache[year] = remote;
      await _saveToLocalCache(year, remote);
      return remote;
    }

    // 4. 离线兜底：加载内置资源
    final builtin = await _loadBuiltin(year);
    _memoryCache[year] = builtin;
    await _saveToLocalCache(year, builtin);
    return builtin;
  }

  Future<HolidayData?> _loadFromLocalCache(int year) async {
    try {
      final prefs = await _ensurePrefs();
      final raw = prefs.getString('$_cacheKeyPrefix$year');
      if (raw == null) return null;
      return HolidayData.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
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
      return HolidayData.fromJson(
        jsonDecode(json) as Map<String, dynamic>,
      );
    } catch (_) {
      // If the asset file doesn't exist for this year, return empty data
      return HolidayData(year: year, version: 1, entries: const []);
    }
  }

  Future<HolidayData?> _fetchRemoteUpdate(int year) async {
    try {
      final uri = Uri.parse('http://api.haoshenqi.top/holiday?date=$year');
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;

      final list = jsonDecode(response.body) as List<dynamic>;
      final entries = _convertApiEntries(list, year);
      if (entries.isEmpty) return null;

      return HolidayData(year: year, version: 1, entries: entries);
    } catch (_) {
      return null;
    }
  }

  /// Convert flat API response to grouped HolidayEntry list.
  /// API status: 0=workday, 1=weekend, 2=makeup workday, 3=holiday
  List<HolidayEntry> _convertApiEntries(List<dynamic> list, int year) {
    // Collect holidays and makeup workdays
    final holidayDates = <DateTime>[];
    final makeupDates = <DateTime>[];
    for (final item in list) {
      final map = item as Map<String, dynamic>;
      final status = map['status'] as int;
      final date = DateTime.parse(map['date'] as String);
      if (status == 3) holidayDates.add(date);
      if (status == 2) makeupDates.add(date);
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
        entries.add(HolidayEntry(
          date: date,
          name: name,
          type: HolidayType.vacation,
          groupId: groupId,
        ));
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
      entries.add(HolidayEntry(
        date: date,
        name: '调休上班',
        type: HolidayType.adjustedWorkday,
        groupId: nearestGroupId,
      ));
    }

    return entries;
  }

  bool _isConsecutive(DateTime a, DateTime b) =>
      b.difference(a).inDays == 1;

  int _absDays(DateTime a, DateTime b) =>
      a.difference(b).inDays.abs();

  String _nameForGroup(List<DateTime> group) {
    final first = group.first;
    final spanDays = group.length;

    // Fixed-date holidays
    if (first.month == 1 && first.day <= 3) return '元旦';
    if (first.month == 5 && first.day <= 5) return '劳动节';
    if (first.month == 10 && first.day <= 7) return '国庆节';

    // Lunar holidays by approximate date range
    if (first.month >= 1 && first.month <= 2 && spanDays >= 5) return '春节';
    if (first.month >= 1 && first.month <= 3 && spanDays >= 7) return '春节';
    if (first.month == 4 && spanDays <= 4) return '清明节';
    if (first.month >= 5 && first.month <= 6 && spanDays <= 4) return '端午节';
    if (first.month >= 9 && first.month <= 10 && spanDays <= 4) return '中秋节';

    return '法定假日';
  }

  Future<SharedPreferences> _ensurePrefs() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  /// Clear all cached data for a year so next getDataForYear reloads from remote
  Future<void> clearCache(int year) async {
    _memoryCache.remove(year);
    try {
      final prefs = await _ensurePrefs();
      await prefs.remove('$_cacheKeyPrefix$year');
    } catch (_) {}
  }
}
