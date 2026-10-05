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
    final current = _currentIndexEntries(prefs);
    final entries = current.entries
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    if (current.shouldPersist) {
      // 目录坏了或漏了条目：把修好的目录落盘，别让下一次读再扫一遍本体。
      await _persistIndex(prefs, entries);
    }
    return entries;
  }

  /// 添加或更新索引条目
  Future<void> _addToIndex(
    SharedPreferences prefs,
    String schoolId,
    String adapterId,
  ) async {
    final existing = _currentIndexEntries(prefs).entries;
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
    await _persistIndex(prefs, updated);
  }

  /// 从索引中移除
  Future<void> _removeFromIndex(
    SharedPreferences prefs,
    String schoolId,
    String adapterId,
  ) async {
    final existing = _currentIndexEntries(prefs).entries;
    final updated = existing
        .where((e) => e.schoolId != schoolId || e.adapterId != adapterId)
        .toList();
    await _persistIndex(prefs, updated);
  }

  /// 解析目录。**null 表示目录读坏了**（坏 JSON、不是数组），与「目录是空的」
  /// 必须区分开：前者被当成后者时，下一次保存会把「只剩自己这一条」的目录写回去，
  /// 其它宏的记录本体还好好躺在磁盘上，却再也不会出现在宏列表里，而且
  /// `exportAllMacros` 也是按目录导出的 —— 残缺的目录会跟着进云快照，把别的设备
  /// 一起刷成"没这些宏"。
  List<WarehouseMacroIndexEntry>? _parseIndexEntries(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return null;
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(
            (m) =>
                WarehouseMacroIndexEntry.fromJson(Map<String, dynamic>.from(m)),
          )
          .where((e) => e.schoolId.isNotEmpty && e.adapterId.isNotEmpty)
          .toList();
    } catch (_) {
      return null;
    }
  }

  /// 从单个记录本体取目录条目；本体读不动就返回 null（不删它，只是列不出来）。
  WarehouseMacroIndexEntry? _entryFromRecordBlob(
    SharedPreferences prefs,
    String key,
  ) {
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final record = WarehouseMacroRecord.fromJson(
        Map<String, dynamic>.from(decoded),
      );
      if (record.schoolId.isEmpty || record.adapterId.isEmpty) return null;
      return WarehouseMacroIndexEntry(
        schoolId: record.schoolId,
        adapterId: record.adapterId,
        updatedAt: record.updatedAt,
      );
    } catch (_) {
      return null;
    }
  }

  List<WarehouseMacroIndexEntry> _allEntriesFromRecordBlobs(
    SharedPreferences prefs,
  ) {
    return _recordBlobKeys(prefs, listed: const {})
        .map((key) => _entryFromRecordBlob(prefs, key))
        .whereType<WarehouseMacroIndexEntry>()
        .toList();
  }

  /// 记录本体的 key 集合。注意 `indexKey` 本身也以同一个前缀开头，必须排掉。
  Iterable<String> _recordBlobKeys(
    SharedPreferences prefs, {
    required Set<String> listed,
  }) {
    return prefs.getKeys().where(
      (key) =>
          key.startsWith(WarehouseMacroRecord.recordKeyPrefix) &&
          key != WarehouseMacroRecord.indexKey &&
          !listed.contains(key),
    );
  }

  /// 当前目录 = 目录文件 ∪ 目录里漏掉的记录本体。
  ///
  /// 后者覆盖「本体写完、目录写失败」这种半途中断（进程被杀 / 存储异常）：宏
  /// 还在，只是没进目录，列不出来也导不出去，而 `hasMacro`（直接查本体）又说
  /// 有，于是自动录制被抑制 —— 用户两头对不上，也没有任何路径能自愈。
  /// 目录坏了则整份从本体重建。`shouldPersist` 告诉调用方这次读出了出入，
  /// 值得把修好的目录写回去（只在真的有出入时才付出解码与一次落盘）。
  ({List<WarehouseMacroIndexEntry> entries, bool shouldPersist})
      _currentIndexEntries(SharedPreferences prefs) {
    final parsed = _parseIndexEntries(
      prefs.getString(WarehouseMacroRecord.indexKey),
    );
    if (parsed == null) {
      final rebuilt = _allEntriesFromRecordBlobs(prefs);
      return (entries: rebuilt, shouldPersist: rebuilt.isNotEmpty);
    }
    final listed = parsed
        .map((e) => WarehouseMacroRecord.storageKey(e.schoolId, e.adapterId))
        .toSet();
    final orphans = _recordBlobKeys(prefs, listed: listed)
        .map((key) => _entryFromRecordBlob(prefs, key))
        .whereType<WarehouseMacroIndexEntry>()
        .toList();
    return (
      entries: [...parsed, ...orphans],
      shouldPersist: orphans.isNotEmpty,
    );
  }

  Future<void> _persistIndex(
    SharedPreferences prefs,
    List<WarehouseMacroIndexEntry> entries,
  ) async {
    await prefs.setString(
      WarehouseMacroRecord.indexKey,
      jsonEncode(entries.map((e) => e.toJson()).toList()),
    );
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
    // 先按存储 key 收敛一份：导入的 records 里若有两所学校/适配器拼出同一个
    // key（同名重复项、或上游导出带了重复行），本体天然只留一条，而目录原先是
    // 逐条 records 生成的，于是同一个宏会在列表里出现两遍，删一次还删不干净。
    final byKey = <String, WarehouseMacroRecord>{
      for (final record in records)
        WarehouseMacroRecord.storageKey(
          record.schoolId,
          record.adapterId,
        ): record,
    };
    final serialized = <String, String>{
      for (final entry in byKey.entries)
        entry.key: jsonEncode(entry.value.toJson()),
    };
    final indexJson = jsonEncode([
      for (final record in byKey.values)
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
