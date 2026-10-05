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
        // 这条读路径的回写只为**脱敏**（旧记录里存过密码之类），不能顺手把结构
        // 改动也落盘：一旦解析真的丢过步骤，写回去就等于把「用户录的宏少了几步」
        // 永久存下来 —— 打开一次宏列表就会触发，升级 App 也恢复不回来。
        final droppedStepCount =
            parseWarehouseMacroStepsWithDiagnostics(decoded['steps'])
                .droppedStepCount;
        if (droppedStepCount == 0) {
          await prefs.setString(key, sanitizedRaw);
        }
      }
      return record;
    } catch (_) {
      return null;
    }
  }

  /// 导入成功后的记账：读回记录、累加成功次数、把最新的脚本页地址一并存回。
  ///
  /// **绝不抛出**。调用点在「课程已经写完」之后（`_markMacroImportCompleted`），
  /// 而那里外层是一个把异常一律翻成「导入失败」的 catch —— 原先 `getMacro` /
  /// `saveMacro` 任何一步出错（共享首选项写失败、记录里有编码不了的值、
  /// 同步钩子抛异常……）都会顺着 await 冒上去，于是**一次其实已经成功的导入被
  /// 报成失败**：状态写「导入失败」、弹错误提示、后台模式还回 `false`，而
  /// 「导入完成」的 sheet 永远不出现。这一步最多让计数停在旧值，不该影响结论。
  /// 返回是否真的更新了。
  Future<bool> recordSuccessfulImport({
    required String schoolId,
    required String adapterId,
    String? scriptPageUrl,
  }) async {
    try {
      final existing = await getMacro(schoolId, adapterId);
      if (existing == null) return false;
      await saveMacro(
        existing.copyWith(
          successfulImportCount: existing.successfulImportCount + 1,
          updatedAt: DateTime.now(),
          scriptPageUrl: scriptPageUrl,
        ),
      );
      return true;
    } catch (_) {
      return false;
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
          .whereType<Map<String, dynamic>>()
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
          .whereType<Map<String, dynamic>>()
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
    // 先序列化全部记录再动本地数据：逐条「先删后写」在写路径中途抛出
    // （磁盘满 / 进程被杀）时会留下本地宏被清空、远端记录只落一半的
    // 两头丢状态。字符串全部就绪后，删除+写入阶段只剩纯 key-value 落盘，
    // 失败窗口收窄到单条写入，不再有「整库已清、数据未落」的中间态。
    final serialized = <String, String>{
      for (final record in records)
        WarehouseMacroRecord.storageKey(
          record.schoolId,
          record.adapterId,
        ): jsonEncode(record.toJson()),
    };
    final indexJson = jsonEncode([
      for (final record in records)
        WarehouseMacroIndexEntry(
          schoolId: record.schoolId,
          adapterId: record.adapterId,
          updatedAt: record.updatedAt,
        ).toJson(),
    ]);

    final existingKeys = prefs
        .getKeys()
        .where(
          (key) =>
              key.startsWith('warehouse_macro_record_') &&
              !serialized.containsKey(key),
        )
        .toList();
    for (final key in existingKeys) {
      await prefs.remove(key);
    }
    for (final entry in serialized.entries) {
      await prefs.setString(entry.key, entry.value);
    }
    await prefs.setString(WarehouseMacroRecord.indexKey, indexJson);
    notifyUserDataChangedForSync();
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
