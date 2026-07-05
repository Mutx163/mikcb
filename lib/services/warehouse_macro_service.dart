import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/warehouse_macro_models.dart';
import 'user_data_sync_hooks.dart';

/// 录制回放持久化服务
class WarehouseMacroService {
  Future<SharedPreferences> get _prefs async => SharedPreferences.getInstance();

  /// 保存宏录制记录
  Future<void> saveMacro(WarehouseMacroRecord record) async {
    final prefs = await _prefs;
    final key = WarehouseMacroRecord.storageKey(
      record.schoolId,
      record.adapterId,
    );
    await prefs.setString(key, jsonEncode(record.toJson()));
    await _addToIndex(prefs, record.schoolId, record.adapterId);
    notifyUserDataChangedForSync();
  }

  /// 加载指定学校+适配器的宏录制记录
  Future<WarehouseMacroRecord?> getMacro(
    String schoolId,
    String adapterId,
  ) async {
    final prefs = await _prefs;
    final key = WarehouseMacroRecord.storageKey(schoolId, adapterId);
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final record = WarehouseMacroRecord.fromJson(
        Map<String, dynamic>.from(decoded),
      );
      final sanitizedRaw = jsonEncode(record.toJson());
      if (sanitizedRaw != raw) {
        await prefs.setString(key, sanitizedRaw);
      }
      return record;
    } catch (_) {
      return null;
    }
  }

  /// 删除宏录制记录
  Future<void> deleteMacro(String schoolId, String adapterId) async {
    final prefs = await _prefs;
    final key = WarehouseMacroRecord.storageKey(schoolId, adapterId);
    await prefs.remove(key);
    await _removeFromIndex(prefs, schoolId, adapterId);
  }

  /// 检查是否存在宏录制记录
  Future<bool> hasMacro(String schoolId, String adapterId) async {
    final prefs = await _prefs;
    final key = WarehouseMacroRecord.storageKey(schoolId, adapterId);
    return prefs.containsKey(key);
  }

  Future<List<WarehouseMacroIndexEntry>> getAllMacroEntries() async {
    final prefs = await _prefs;
    final raw = prefs.getString(WarehouseMacroRecord.indexKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final entries = decoded
          .whereType<Map>()
          .map(
            (m) =>
                WarehouseMacroIndexEntry.fromJson(Map<String, dynamic>.from(m)),
          )
          .where((e) => e.schoolId.isNotEmpty && e.adapterId.isNotEmpty)
          .toList();
      entries.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return entries;
    } catch (_) {
      return const [];
    }
  }

  /// 添加或更新索引条目
  Future<void> _addToIndex(
    SharedPreferences prefs,
    String schoolId,
    String adapterId,
  ) async {
    final existing = await _loadIndexList(prefs);
    final now = DateTime.now();
    final updated = [
      WarehouseMacroIndexEntry(
        schoolId: schoolId,
        adapterId: adapterId,
        updatedAt: now,
      ),
      ...existing.where(
        (e) => e.schoolId != schoolId || e.adapterId != adapterId,
      ),
    ];
    await prefs.setString(
      WarehouseMacroRecord.indexKey,
      jsonEncode(updated.map((e) => e.toJson()).toList()),
    );
  }

  /// 从索引中移除
  Future<void> _removeFromIndex(
    SharedPreferences prefs,
    String schoolId,
    String adapterId,
  ) async {
    final existing = await _loadIndexList(prefs);
    final updated = existing
        .where((e) => e.schoolId != schoolId || e.adapterId != adapterId)
        .toList();
    await prefs.setString(
      WarehouseMacroRecord.indexKey,
      jsonEncode(updated.map((e) => e.toJson()).toList()),
    );
  }

  Future<List<WarehouseMacroIndexEntry>> _loadIndexList(
    SharedPreferences prefs,
  ) async {
    final raw = prefs.getString(WarehouseMacroRecord.indexKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map(
            (m) =>
                WarehouseMacroIndexEntry.fromJson(Map<String, dynamic>.from(m)),
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<List<WarehouseMacroRecord>> exportAllMacros() async {
    final entries = await getAllMacroEntries();
    final records = <WarehouseMacroRecord>[];
    for (final entry in entries) {
      final record = await getMacro(entry.schoolId, entry.adapterId);
      if (record != null) {
        records.add(record);
      }
    }
    return records;
  }

  Future<void> importAllMacros(List<WarehouseMacroRecord> records) async {
    final prefs = await _prefs;
    final existingKeys = prefs
        .getKeys()
        .where((key) => key.startsWith('warehouse_macro_record_'))
        .toList();
    for (final key in existingKeys) {
      await prefs.remove(key);
    }
    await prefs.remove(WarehouseMacroRecord.indexKey);

    for (final record in records) {
      await saveMacro(record);
    }
  }
}

/// 宏索引条目（轻量，只存 key 和更新时间）
class WarehouseMacroIndexEntry {
  final String schoolId;
  final String adapterId;
  final DateTime updatedAt;

  const WarehouseMacroIndexEntry({
    required this.schoolId,
    required this.adapterId,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
    'schoolId': schoolId,
    'adapterId': adapterId,
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory WarehouseMacroIndexEntry.fromJson(Map<String, dynamic> json) {
    return WarehouseMacroIndexEntry(
      schoolId: json['schoolId'] as String? ?? '',
      adapterId: json['adapterId'] as String? ?? '',
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
