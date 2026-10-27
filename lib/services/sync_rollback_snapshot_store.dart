import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'app_log_service.dart';

/// 云快照恢复的「回滚点」落盘仓库。
///
/// ## 为什么需要它
///
/// `AppSyncSnapshotService.applySnapshot` 在动手改本地数据**之前**会先抓一份
/// 回滚快照，但它此前只放在内存里（`_lastRollbackSnapshot`）：用户看到
/// 「恢复成功 + 撤销」按钮，只要在这之前杀一次进程（省电清理、用户手动划掉、
/// 系统低内存回收都算），撤销点就没了，而**已经落盘的新数据还在**。
/// 更糟的是中途被杀的情形：14 处 `await` 逐批落盘，停在半路既没有完整的
/// 新数据、也没有可用的旧快照。
///
/// 这里把回滚快照写进磁盘，目的**不是**把恢复做成事务（那要重写整条写路径，
/// 成本远超收益），而是把保证降到可接受的那一档：
///
/// > 恢复失败或中途被杀之后，重启还能撤销回恢复前的状态。
///
/// ## 状态机
///
/// - `applying`：快照已落盘、本地数据正在被改。进程在这个状态下死掉 =
///   「恢复没做完」，启动时应当提示用户（[SyncRollbackRecord.wasInterrupted]）。
/// - `applied`：恢复已走完，撤销点仍然有效，等用户撤销（或被下一次恢复顶掉）。
///
/// 只有这两个状态：不需要 `rolled_back` 之类，成功回滚意味着本地已回到恢复前，
/// 记录直接删掉即可。
///
/// ## 为什么单独一个文件而不是塞进 TransferUndoService
///
/// `TransferUndoService` 的文档明确写着「intentionally in-memory：重启即新会话」，
/// 且它的槽位语义是「导入撤销」的多槽链。云快照只需要**单槽**（最近一次恢复），
/// 且必须跨重启存活 —— 塞进去会同时破坏那两条既有语义。这里沿用它的
/// 「一份完整快照 + 一个 id」形态，但存储与生命周期独立。
class SyncRollbackSnapshotStore {
  SyncRollbackSnapshotStore({Future<Directory> Function()? directoryProvider})
    : _directoryProvider = directoryProvider ?? _defaultDirectory;

  /// 文件名固定：只保留最近一次恢复的回滚点（单槽）。
  static const String fileName = 'rollback_snapshot.json';

  /// 超过这个大小的回滚快照不落盘。
  ///
  /// 正常课表全量快照在几十到几百 KB 量级；8 MB 意味着「异常膨胀/损坏」，
  /// 硬写会把磁盘写满（低存储设备上那会让整个 App 起不来）。超限时降级为
  /// 「只在内存里可撤销」，并把这件事记进日志，而不是静默跳过。
  static const int maxPersistBytes = 8 * 1024 * 1024;

  final Future<Directory> Function() _directoryProvider;

  static Future<Directory> _defaultDirectory() async {
    final base = await getApplicationSupportDirectory();
    final directory = Directory('${base.path}/sync_rollback');
    if (!directory.existsSync()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  Future<File> _resolveFile() async {
    final directory = await _directoryProvider();
    if (!directory.existsSync()) {
      await directory.create(recursive: true);
    }
    return File('${directory.path}/$fileName');
  }

  /// 写入（或覆写）回滚点。
  ///
  /// 先写临时文件再 rename：直接覆写原来那份时，若在写入中途被杀会留下
  /// **半截 JSON**——那比没有记录更糟，因为撤销时才发现解析不出来。rename 在
  /// 同一目录内是原子的，读到的要么是旧的完整内容、要么是新的完整内容。
  Future<void> save({
    required String undoId,
    required String snapshotJson,
    required String state,
    DateTime? createdAt,
  }) async {
    if (snapshotJson.isEmpty) {
      // 空快照落盘等于「撤销点指向空课表」；不写比写更安全。
      return;
    }
    final bytes = utf8.encode(snapshotJson).length;
    if (bytes > maxPersistBytes) {
      await AppLogService.instance.warn(
        'sync_rollback_snapshot_too_large',
        '回滚快照超过落盘上限，本次恢复将只在内存中可撤销',
        extras: {'bytes': bytes, 'limit': maxPersistBytes, 'undoId': undoId},
      );
      return;
    }
    final record = <String, dynamic>{
      'version': 1,
      'undoId': undoId,
      'state': state,
      'createdAt': (createdAt ?? DateTime.now()).toIso8601String(),
      'snapshot': snapshotJson,
    };
    final file = await _resolveFile();
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(jsonEncode(record), flush: true);
    await temp.rename(file.path);
  }

  /// 把状态改成 `applied`（恢复已经走完，撤销点继续有效）。
  ///
  /// 读不到记录时静默返回：这种情况下撤销点本来就不存在，没有状态可改。
  Future<void> markApplied(String undoId) async {
    final record = await read();
    if (record == null || record.undoId != undoId) {
      return;
    }
    await save(
      undoId: record.undoId,
      snapshotJson: record.snapshotJson,
      state: SyncRollbackRecord.appliedState,
      createdAt: record.createdAt,
    );
  }

  /// 读回最近一次的回滚点；文件不存在或内容损坏时返回 null。
  ///
  /// 损坏时**删掉**而不是留着：一份解析不出来的撤销点永远救不回来，留着只会
  /// 让每次启动都去尝试解析它。删除动作本身记 warn，便于事后确认是「没有记录」
  /// 还是「记录坏了」。
  Future<SyncRollbackRecord?> read() async {
    File file;
    try {
      file = await _resolveFile();
    } catch (_) {
      // 平台通道不可用（测试环境 / 无插件）：当作没有记录。
      return null;
    }
    if (!file.existsSync()) {
      return null;
    }
    String raw;
    try {
      raw = await file.readAsString();
    } catch (_) {
      return null;
    }
    final decoded = _tryDecode(raw);
    if (decoded == null) {
      await _quarantineCorrupt(file, raw);
      return null;
    }
    return decoded;
  }

  static SyncRollbackRecord? _tryDecode(String raw) {
    if (raw.trim().isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return null;
      }
      return SyncRollbackRecord.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
    }
  }

  Future<void> _quarantineCorrupt(File file, String raw) async {
    try {
      await file.delete();
    } catch (_) {
      // 删不掉也不影响本次流程，下次启动再试。
    }
    await AppLogService.instance.warn(
      'sync_rollback_snapshot_corrupt',
      '回滚快照损坏，已丢弃（本次无可用撤销点）',
      extras: {'bytes': raw.length},
    );
  }

  Future<void> clear() async {
    try {
      final file = await _resolveFile();
      if (file.existsSync()) {
        await file.delete();
      }
    } catch (_) {
      // 清不掉不影响正确性：下次 save 会覆写。
    }
  }
}

/// 落盘的回滚点记录。
class SyncRollbackRecord {
  static const String applyingState = 'applying';
  static const String appliedState = 'applied';

  final String undoId;
  final String snapshotJson;
  final String state;
  final DateTime createdAt;

  const SyncRollbackRecord({
    required this.undoId,
    required this.snapshotJson,
    required this.state,
    required this.createdAt,
  });

  /// 恢复**没做完**（进程在改本地数据的过程中被杀）。
  ///
  /// 这时本地数据可能停在半路，撤销点是用户唯一的退路，启动时必须让这件事
  /// 可见 —— 否则用户只会觉得「课表莫名其妙变了一半」。
  bool get wasInterrupted => state == applyingState;

  factory SyncRollbackRecord.fromJson(Map<String, dynamic> json) {
    final undoId = json['undoId'];
    final snapshot = json['snapshot'];
    final state = json['state'];
    if (undoId is! String || undoId.isEmpty) {
      throw const FormatException('invalid_rollback_record_id');
    }
    if (snapshot is! String || snapshot.isEmpty) {
      throw const FormatException('invalid_rollback_record_snapshot');
    }
    return SyncRollbackRecord(
      undoId: undoId,
      snapshotJson: snapshot,
      state: state is String && state.isNotEmpty ? state : appliedState,
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
