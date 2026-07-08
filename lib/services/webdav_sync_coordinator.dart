import 'dart:async';

import 'package:flutter/foundation.dart';

import '../providers/timetable_provider.dart';
import 'app_sync_snapshot_service.dart';
import 'sync_operation_gate.dart';
import 'webdav_sync_config.dart';
import 'webdav_sync_service.dart';

class WebdavSyncCoordinator extends ChangeNotifier {
  WebdavSyncCoordinator({WebdavSyncService? syncService})
    : _syncService = syncService ?? WebdavSyncService() {
    _syncService.conflictHandler = _handleConflict;
  }

  static WebdavSyncCoordinator? _instance;

  factory WebdavSyncCoordinator.instance() {
    return _instance ??= WebdavSyncCoordinator();
  }

  @visibleForTesting
  static void resetInstanceForTesting() {
    _instance = null;
  }

  final WebdavSyncService _syncService;
  TimetableProvider? _provider;
  Timer? _uploadDebounce;
  final SyncOperationGate _syncGate = SyncOperationGate();

  WebdavSyncStatus _status = const WebdavSyncStatus.idle();
  WebdavSyncStatus get status => _status;

  Future<SyncConflictChoice?> Function(SyncConflictInfo info)? onConflict;

  void bindProvider(TimetableProvider provider) {
    _provider = provider;
  }

  WebdavSyncService get syncService => _syncService;

  void scheduleUpload() {
    unawaited(_scheduleUploadDebounced());
  }

  Future<void> maybePullRemote({bool fromManualSync = false}) async {
    final provider = _provider;
    if (provider == null) {
      return;
    }

    final config = await _syncService.loadConfig();
    if (!config.enabled || config.syncMode != WebdavSyncMode.auto) {
      return;
    }

    await _syncGate.runExclusive(() async {
      _setStatus(_status.copyWith(isSyncing: true, clearError: true));
      try {
        final result = await _syncService.downloadAndApply(
          provider: provider,
          allowConflictPrompt: false,
        );
        _applyResult(result);
      } finally {
        _setStatus(_status.copyWith(isSyncing: false));
      }
    });
  }

  Future<WebdavSyncResult> syncNow({bool allowConflictPrompt = true}) async {
    final provider = _provider;
    if (provider == null) {
      return const WebdavSyncResult(
        kind: WebdavSyncResultKind.failed,
        message: 'provider_not_ready',
      );
    }

    return _syncGate.runExclusive(() async {
      _setStatus(_status.copyWith(isSyncing: true, clearError: true));
      try {
        final result = await _syncService.syncNow(
          provider: provider,
          allowConflictPrompt: allowConflictPrompt,
        );
        _applyResult(result);
        return result;
      } finally {
        _setStatus(_status.copyWith(isSyncing: false));
      }
    });
  }

  Future<void> refreshStatus() async {
    final config = await _syncService.loadConfig();
    _setStatus(
      _status.copyWith(
        enabled: config.enabled,
        syncMode: config.syncMode,
        lastSyncedAt: config.lastSyncedAt,
      ),
    );
  }

  Future<WebdavBackupListResult> fetchBackupList() {
    return _syncService.fetchBackupList();
  }

  Future<WebdavSyncResult> createManualBackup() async {
    final provider = _provider;
    if (provider == null) {
      return const WebdavSyncResult(
        kind: WebdavSyncResultKind.failed,
        message: 'provider_not_ready',
      );
    }

    return _syncGate.runExclusive(() async {
      _setStatus(_status.copyWith(isSyncing: true, clearError: true));
      try {
        final result = await _syncService.createManualBackup(provider: provider);
        _applyResult(result);
        return result;
      } finally {
        _setStatus(_status.copyWith(isSyncing: false));
      }
    });
  }

  Future<WebdavSyncResult> restoreBackup(
    String entryId, {
    bool uploadAsCurrent = true,
  }) async {
    final provider = _provider;
    if (provider == null) {
      return const WebdavSyncResult(
        kind: WebdavSyncResultKind.failed,
        message: 'provider_not_ready',
      );
    }

    return _syncGate.runExclusive(() async {
      _setStatus(_status.copyWith(isSyncing: true, clearError: true));
      try {
        final result = await _syncService.restoreFromBackup(
          provider: provider,
          entryId: entryId,
          uploadAsCurrent: uploadAsCurrent,
        );
        _applyResult(result);
        return result;
      } finally {
        _setStatus(_status.copyWith(isSyncing: false));
      }
    });
  }

  Future<WebdavSyncResult> deleteBackup(String entryId) async {
    return _syncGate.runExclusive(() async {
      _setStatus(_status.copyWith(isSyncing: true, clearError: true));
      try {
        final result = await _syncService.deleteBackup(entryId: entryId);
        _applyResult(result);
        return result;
      } finally {
        _setStatus(_status.copyWith(isSyncing: false));
      }
    });
  }

  Future<void> _scheduleUploadDebounced() async {
    _uploadDebounce?.cancel();
    _uploadDebounce = Timer(const Duration(seconds: 3), () {
      unawaited(_performAutoUpload());
    });
  }

  Future<void> _performAutoUpload() async {
    final provider = _provider;
    if (provider == null) {
      return;
    }

    final config = await _syncService.loadConfig();
    if (!config.enabled || config.syncMode != WebdavSyncMode.auto) {
      return;
    }

    await _syncGate.runExclusive(() async {
      _setStatus(_status.copyWith(isSyncing: true, clearError: true));
      try {
        final result = await _syncService.uploadSnapshot(provider: provider);
        _applyResult(result);
      } finally {
        _setStatus(_status.copyWith(isSyncing: false));
      }
    });
  }

  Future<SyncConflictChoice?> _handleConflict(SyncConflictInfo info) async {
    return onConflict?.call(info);
  }

  void _applyResult(WebdavSyncResult result) {
    if (result.kind == WebdavSyncResultKind.failed) {
      _setStatus(_status.copyWith(lastError: result.message ?? 'sync_failed'));
      return;
    }

    unawaited(refreshStatus());
    if (result.kind != WebdavSyncResultKind.idle &&
        result.kind != WebdavSyncResultKind.upToDate) {
      _setStatus(_status.copyWith(clearError: true, lastResult: result.kind));
    }
  }

  void _setStatus(WebdavSyncStatus next) {
    _status = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _uploadDebounce?.cancel();
    super.dispose();
  }
}

class WebdavSyncStatus {
  final bool enabled;
  final WebdavSyncMode syncMode;
  final bool isSyncing;
  final DateTime? lastSyncedAt;
  final String? lastError;
  final WebdavSyncResultKind? lastResult;

  const WebdavSyncStatus({
    required this.enabled,
    required this.syncMode,
    required this.isSyncing,
    this.lastSyncedAt,
    this.lastError,
    this.lastResult,
  });

  const WebdavSyncStatus.idle()
    : enabled = false,
      syncMode = WebdavSyncMode.auto,
      isSyncing = false,
      lastSyncedAt = null,
      lastError = null,
      lastResult = null;

  WebdavSyncStatus copyWith({
    bool? enabled,
    WebdavSyncMode? syncMode,
    bool? isSyncing,
    DateTime? lastSyncedAt,
    String? lastError,
    WebdavSyncResultKind? lastResult,
    bool clearError = false,
  }) {
    return WebdavSyncStatus(
      enabled: enabled ?? this.enabled,
      syncMode: syncMode ?? this.syncMode,
      isSyncing: isSyncing ?? this.isSyncing,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      lastError: clearError ? null : (lastError ?? this.lastError),
      lastResult: lastResult ?? this.lastResult,
    );
  }
}
