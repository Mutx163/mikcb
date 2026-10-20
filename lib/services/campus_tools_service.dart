import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/campus_tool_presets.dart';
import '../models/campus_tool_entry.dart';
import 'app_log_service.dart';

/// 校园小工具的本地存储。
///
/// 存一份 JSON（`{version, entries}`）而不是逐字段塞进 `TimetableSettings`：
/// 入口列表是「用户随便加」的自由结构，塞进设置模型会把课表设置的序列化、
/// 迁移、云同步快照全部拽进来，改一条快捷链接就触发一次设置写盘。这里自持
/// 一个 prefs 键，与 `ImportRandomColorPreferences` / `DiagnosticsLogViewerPreferences`
/// 同一条「小功能自建键」的先例。
///
/// 容错口径：**读失败一律回落到默认预设**（不是空列表）。空列表会让页面看起来
/// 像「功能没做」，而默认预设至少还能点；坏条目逐条丢弃，不让一条坏 JSON 把
/// 用户其余配置一起带走。
abstract final class CampusToolsService {
  CampusToolsService._();

  /// 存储键。带 `_v1` 后缀：将来改结构时按版本分流读，不覆盖老数据。
  static const String preferenceKey = 'campus_tools_v1';

  /// 当前结构版本（写进 JSON，读完不做版本迁移时也能靠它判断来源）。
  static const int schemaVersion = 1;

  static const String _logCategory = 'campus_tools';

  /// 读入口列表；首次使用 / 数据损坏 / 用户清空都回落到默认预设。
  static Future<List<CampusToolEntry>> load() async {
    final SharedPreferences prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (error, stackTrace) {
      await _logWarn('load_prefs_unavailable', error, stackTrace);
      return campusToolDefaultEntries();
    }
    final raw = prefs.getString(preferenceKey);
    if (raw == null || raw.trim().isEmpty) {
      return campusToolDefaultEntries();
    }
    final decoded = _decode(raw);
    if (decoded == null) {
      await _logWarn('load_decode_failed', null, null);
      return campusToolDefaultEntries();
    }
    final entries = CampusToolEntry.normalizeList(decoded);
    if (entries.isEmpty) {
      // 解析成功但一条都没剩下：整份数据已不可用，别把「全丢」当用户配置。
      await _logWarn('load_empty_after_normalize', null, null);
      return campusToolDefaultEntries();
    }
    return entries;
  }

  /// 写入口列表；失败返回 false（调用方提示，不抛）。
  static Future<bool> save(List<CampusToolEntry> entries) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = <String, Object?>{
        'version': schemaVersion,
        'entries': <Object?>[for (final entry in entries) entry.toJson()],
      };
      return await prefs.setString(preferenceKey, jsonEncode(payload));
    } catch (error, stackTrace) {
      await _logWarn('save_failed', error, stackTrace);
      return false;
    }
  }

  /// 清掉自定义配置，回到默认预设（供「重置」类入口使用）。
  static Future<bool> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.remove(preferenceKey);
    } catch (error, stackTrace) {
      await _logWarn('clear_failed', error, stackTrace);
      return false;
    }
  }

  /// 解析持久化里的载荷：兼容 `[entry, ...]` 与 `{entries: [...]}` 两种形状。
  static List<Object?>? _decode(String raw) {
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return null;
    }
    if (decoded is List) {
      return decoded;
    }
    if (decoded is Map) {
      for (final entry in decoded.entries) {
        if (entry.key == 'entries' && entry.value is List) {
          return entry.value as List<Object?>;
        }
      }
    }
    return null;
  }

  static Future<void> _logWarn(
    String event,
    Object? error,
    StackTrace? stackTrace,
  ) {
    return AppLogService.instance.warn(
      _logCategory,
      event,
      error: error,
      stackTrace: stackTrace,
    );
  }
}
