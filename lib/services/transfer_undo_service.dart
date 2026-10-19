import '../models/partner_timetable_binding.dart';
import 'transfer_diff_service.dart';
import 'transfer_package.dart';

/// A local, one-shot restore point created immediately before an import.
///
/// The token contains a full app backup rather than a reverse patch. This
/// makes undo deterministic even when a merge touched several entity types.
class TransferUndoToken {
  final String id;
  final String backupJson;
  final TransferScope scope;
  final TransferChannel channel;
  final TransferApplyMode mode;
  final TransferDiff preview;
  final DateTime createdAt;

  /// 取快照那一刻的情侣绑定。
  ///
  /// **不能靠 `backupJson` 带回来**：全量备份的 schema 不含情侣绑定，而
  /// `importFullAppDataBackup` 在恢复出的课表里找不到情侣档时会主动把绑定清成
  /// null 并落盘（`import_export_service.dart:650-658`）。于是「导入失败 → 自动
  /// 回滚」这条路走完，绑定连快照里都没有，用户的周偏移与情侣三色就永久没了，
  /// 而界面报的是「导入失败」。所以在这里单独存一份，撤销时写回。
  final PartnerTimetableBinding? partnerBinding;

  const TransferUndoToken({
    required this.id,
    required this.backupJson,
    required this.scope,
    required this.channel,
    required this.mode,
    required this.preview,
    required this.createdAt,
    this.partnerBinding,
  });
}

/// Holds the most recent restore points for the active migration flow.
///
/// It is intentionally in-memory: an app restart is a new session and the
/// durable full backup remains available through the existing backup/export
/// paths. The caller must clear or consume a token after a successful undo.
///
/// ## 为什么是多槽而不是单槽（2026-10-20）
///
/// 单槽时代的真实损失：导入 A 成功（撤销点 T1 在槽里），紧接着导入 B——
/// `create` 用 T2 顶掉 T1；若 B 失败并自动回滚，回滚成功后调用方还会 `clear`
/// 清槽。结果是状态明明回到了「A 之后」，A 的撤销点却永远没了（UI 上那条
/// 「撤销导入」点了只会失败）。保留最近 3 个撤销点让「上一次导入」在更早
/// 导入撤销链上不被静默吞掉；容量取 3 是因为每个槽都是一份全量备份 JSON，
/// 更多槽只徒增内存。`pending` 仍返回最新一个，「撤销最近一次导入」的语义
/// 与单槽时代完全一致。
class TransferUndoService {
  /// 保留的撤销点上限。每个槽一份全量备份 JSON，取 3 足够覆盖
  /// 「连做两次导入 + 一次失败回滚」的真实链路。
  static const int _maxTokens = 3;

  final List<TransferUndoToken> _tokensNewestFirst = <TransferUndoToken>[];

  /// 最新一个撤销点（「撤销最近一次导入」语义的入口）。
  TransferUndoToken? get pending =>
      _tokensNewestFirst.isEmpty ? null : _tokensNewestFirst.first;

  TransferUndoToken create({
    required String backupJson,
    required TransferPackage incoming,
    required TransferApplyMode mode,
    required TransferDiff preview,
    PartnerTimetableBinding? partnerBinding,
    DateTime? createdAt,
  }) {
    final token = TransferUndoToken(
      id: TransferPackage.newPackageId(now: createdAt),
      backupJson: backupJson,
      scope: incoming.scope,
      channel: incoming.channel,
      mode: mode,
      preview: preview,
      partnerBinding: partnerBinding,
      createdAt: createdAt ?? DateTime.now(),
    );
    _tokensNewestFirst.insert(0, token);
    while (_tokensNewestFirst.length > _maxTokens) {
      _tokensNewestFirst.removeLast();
    }
    return token;
  }

  /// 按 id 取走一个撤销点（槽内删除）。多槽下 id 是唯一的消费键：
  /// 旧撤销点不会被新导入顶掉后「点了没反应」，而是仍可按自己的 id 取到。
  TransferUndoToken? take(String id) {
    final index = _tokensNewestFirst.indexWhere((token) => token.id == id);
    if (index == -1) {
      return null;
    }
    return _tokensNewestFirst.removeAt(index);
  }

  /// Removes a token without returning it (e.g. after its restore point was
  /// applied by an automatic rollback and no longer describes a change).
  void remove(String id) {
    _tokensNewestFirst.removeWhere((token) => token.id == id);
  }

  /// Returns a token to the pending slot after a failed undo attempt.
  ///
  /// Do not replace a token created while the undo operation was in flight:
  /// that newer token belongs to the latest transfer and must remain usable.
  /// 回炉位置 = 比它新的 token 之后、比它旧的之前，槽序始终按创建时间排列。
  void restore(TransferUndoToken token) {
    if (_tokensNewestFirst.any((candidate) => candidate.id == token.id)) {
      return;
    }
    final newerCount = _tokensNewestFirst
        .where((candidate) => candidate.createdAt.isAfter(token.createdAt))
        .length;
    _tokensNewestFirst.insert(newerCount, token);
  }

  void clear() {
    _tokensNewestFirst.clear();
  }
}
