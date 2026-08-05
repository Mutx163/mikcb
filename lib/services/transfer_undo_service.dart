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

  const TransferUndoToken({
    required this.id,
    required this.backupJson,
    required this.scope,
    required this.channel,
    required this.mode,
    required this.preview,
    required this.createdAt,
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
    DateTime? createdAt,
  }) {
    final token = TransferUndoToken(
      id: TransferPackage.newPackageId(now: createdAt),
      backupJson: backupJson,
      scope: incoming.scope,
      channel: incoming.channel,
      mode: mode,
      preview: preview,
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

  void clear() {
    _pending = null;
  }
}
