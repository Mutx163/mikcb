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

/// Holds the most recent restore point for the active migration flow.
///
/// It is intentionally in-memory: an app restart is a new session and the
/// durable full backup remains available through the existing backup/export
/// paths. The caller must clear or consume a token after a successful undo.
class TransferUndoService {
  TransferUndoToken? _pending;

  TransferUndoToken? get pending => _pending;

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
    _pending = token;
    return token;
  }

  TransferUndoToken? take(String id) {
    final token = _pending;
    if (token == null || token.id != id) {
      return null;
    }
    _pending = null;
    return token;
  }

  /// Returns a token to the pending slot after a failed undo attempt.
  ///
  /// Do not replace a token created while the undo operation was in flight:
  /// that newer token belongs to the latest transfer and must remain usable.
  void restore(TransferUndoToken token) {
    _pending ??= token;
  }

  void clear() {
    _pending = null;
  }
}
