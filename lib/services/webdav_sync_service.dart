import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:webdav_plus/webdav_plus.dart';

import '../providers/timetable_provider.dart';
import 'app_sync_snapshot_service.dart';
import 'cloud_backup_index_service.dart';
import 'webdav_client_service.dart';
import 'webdav_error_message.dart';
import 'webdav_sync_config.dart';
import 'webdav_sync_credentials_store.dart';
import 'transfer_diff_service.dart';
import 'transfer_package.dart';

enum WebdavSyncResultKind {
  idle,
  uploaded,
  downloaded,
  upToDate,
  conflictResolvedLocal,
  conflictResolvedRemote,
  cancelled,
  failed,
  backupCreated,
  backupRestored,
  backupDeleted,
}

/// Controls whether [WebdavSyncService.uploadSnapshot] may overwrite remote.
enum WebdavUploadConflictPolicy {
  /// Manual sync / keep-local: always PUT.
  force,

  /// Auto upload: only PUT when remote is missing or still our baseline.
  requireUnchangedRemote,
}

class WebdavSyncResult {
  final WebdavSyncResultKind kind;
  final String? message;

  const WebdavSyncResult({required this.kind, this.message});
}

class WebdavBackupListResult {
  final List<CloudBackupEntry> entries;
  final String? errorMessage;

  const WebdavBackupListResult({required this.entries, this.errorMessage});

  bool get hasError => errorMessage != null;
}

enum WebdavBackupIndexRecoveryAction {
  useIndex,
  empty,
  rebuildFromListing,
  failed,
}

WebdavBackupIndexRecoveryAction decideWebdavBackupIndexRecovery({
  required WebdavGetBytesResult indexResult,
  required WebdavHistoryListResult listingResult,
}) {
  if (indexResult.isFailed) {
    if (listingResult.isFailed ||
        listingResult.isNotFound ||
        listingResult.fileNames.isEmpty) {
      return WebdavBackupIndexRecoveryAction.failed;
    }
    return WebdavBackupIndexRecoveryAction.rebuildFromListing;
  }
  if (!indexResult.isNotFound) {
    return WebdavBackupIndexRecoveryAction.useIndex;
  }
  if (listingResult.isFailed) {
    return WebdavBackupIndexRecoveryAction.failed;
  }
  return listingResult.fileNames.isEmpty
      ? WebdavBackupIndexRecoveryAction.empty
      : WebdavBackupIndexRecoveryAction.rebuildFromListing;
}

class WebdavTransferPreview {
  final String entryId;
  final AppSyncSnapshot snapshot;
  final TransferPackage incoming;
  final TransferDiff diff;
  final TransferPackage mergePackage;
  final TransferPackage overwritePackage;
  final TransferDiff mergeDiff;
  final TransferDiff overwriteDiff;

  const WebdavTransferPreview({
    required this.entryId,
    required this.snapshot,
    required this.incoming,
    required this.diff,
    required this.mergePackage,
    required this.overwritePackage,
    required this.mergeDiff,
    required this.overwriteDiff,
  });
}

class WebdavTransferApplyResult {
  final bool applied;
  final String? error;
  final WebdavTransferPreview preview;

  const WebdavTransferApplyResult({
    required this.applied,
    required this.preview,
    this.error,
  });

  bool get hasError => !applied;
}

typedef WebdavSyncConflictHandler =
    Future<SyncConflictChoice?> Function(SyncConflictInfo info);

class WebdavSyncService {
  WebdavSyncService({
    AppSyncSnapshotService? snapshotService,
    WebdavSyncConfigStore? configStore,
    WebdavSyncCredentialsStore? credentialsStore,
    WebdavClientService? clientService,
    CloudBackupIndexService? backupIndexService,
  }) : _snapshotService = snapshotService ?? AppSyncSnapshotService(),
       _configStore = configStore ?? const WebdavSyncConfigStore(),
       _credentialsStore =
           credentialsStore ?? const WebdavSyncCredentialsStore(),
       _clientService = clientService ?? const WebdavClientService(),
       _backupIndexService =
           backupIndexService ?? const CloudBackupIndexService() {
    // 云快照应用失败并成功回滚后，清掉 pull/upload 基线哈希，防止自动
    // 上传把「半应用后回滚」的本地状态当成基线内改动推上云端（覆盖云端
    // 最后一份好数据）。
    _snapshotService.setCloudSyncBaselineReset(clearSyncBaselines);
  }

  final AppSyncSnapshotService _snapshotService;
  final WebdavSyncConfigStore _configStore;
  final WebdavSyncCredentialsStore _credentialsStore;
  final WebdavClientService _clientService;
  final CloudBackupIndexService _backupIndexService;
  bool _disposed = false;

  WebdavSyncConflictHandler? conflictHandler;

  /// Unregisters the baseline-reset hook from the shared snapshot service.
  ///
  /// AppSyncSnapshotService 的钩子槽位只有一个。多实例 WebdavSyncService
  /// （测试间连建、或将来其他 WebDAV 衍生服务）不注销会互相覆盖钩子，
  /// 回滚时可能清错实例的基线。实例生命周期结束时调用本方法注销，之后
  /// 回滚分支的钩子调用静默跳过。
  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _snapshotService.setCloudSyncBaselineReset(null);
  }

  Future<WebdavSyncConfig> loadConfig() => _configStore.load();

  Future<void> saveConfig(WebdavSyncConfig config) => _configStore.save(config);

  Future<WebdavConnectionParams?> buildConnectionParams(
    WebdavSyncConfig config,
  ) async {
    final password = await _credentialsStore.readPassword();
    if (config.username.trim().isEmpty ||
        password == null ||
        password.isEmpty) {
      return null;
    }

    final baseUrl = config.baseUrl.trim().isEmpty
        ? WebdavSyncConfig.defaultJianguoyunBaseUrl
        : config.baseUrl.trim();

    return WebdavConnectionParams(
      baseUrl: baseUrl,
      username: config.username.trim(),
      password: password,
    );
  }

  Future<void> testConnection({
    required WebdavSyncConfig config,
    String? passwordOverride,
  }) async {
    final password = passwordOverride ?? await _credentialsStore.readPassword();
    if (config.username.trim().isEmpty ||
        password == null ||
        password.isEmpty) {
      throw StateError('missing_credentials');
    }

    final baseUrl = config.baseUrl.trim().isEmpty
        ? WebdavSyncConfig.defaultJianguoyunBaseUrl
        : config.baseUrl.trim();

    await _clientService.testConnection(
      WebdavConnectionParams(
        baseUrl: baseUrl,
        username: config.username.trim(),
        password: password,
      ),
    );
  }

  Future<String> resolveDeviceLabel() async {
    final stored = await _credentialsStore.readDeviceLabel();
    if (stored != null && stored.isNotEmpty) {
      return stored;
    }
    try {
      final hostname = Platform.localHostname.trim();
      if (hostname.isNotEmpty) {
        return hostname;
      }
    } catch (_) {}
    return '';
  }

  Future<WebdavSyncResult> uploadSnapshot({
    required TimetableProvider provider,
    WebdavSyncConfig? configOverride,
    CloudBackupSource backupSource = CloudBackupSource.auto,
    bool writeHistory = true,
    bool updateSyncTimestamps = true,

    /// Auto upload must not silently overwrite a drifted remote.
    /// Manual keep-local / force paths pass [force].
    WebdavUploadConflictPolicy conflictPolicy =
        WebdavUploadConflictPolicy.force,
  }) async {
    final config = configOverride ?? await _configStore.load();
    if (!config.enabled) {
      return const WebdavSyncResult(kind: WebdavSyncResultKind.idle);
    }

    final params = await buildConnectionParams(config);
    if (params == null) {
      return const WebdavSyncResult(
        kind: WebdavSyncResultKind.failed,
        message: 'missing_credentials',
      );
    }

    WebdavClient? client;
    try {
      final deviceId = await _credentialsStore.getOrCreateDeviceId();
      final deviceLabel = await resolveDeviceLabel();
      final snapshot = await _snapshotService.collectSnapshot(
        provider: provider,
        deviceId: deviceId,
      );
      final snapshotJson = _snapshotService.buildSnapshotJsonFromSnapshot(
        snapshot,
      );
      final snapshotBytes = Uint8List.fromList(utf8.encode(snapshotJson));
      final packageInfo = await PackageInfo.fromPlatform();
      client = _clientService.createClient(params);
      await _clientService.ensureRemoteFolder(
        client: client,
        remoteFolder: config.normalizedRemoteFolder,
      );

      // The metadata points to an immutable body version. This keeps a
      // concurrent writer from pairing its body with our metadata even when
      // the server has neither locks nor ETag support.
      final snapshotPath = _versionedSnapshotRemotePath(config, snapshot);
      final meta = _snapshotService.buildMetaFromSnapshot(
        snapshot,
        appVersion: packageInfo.version,
        snapshotPath: snapshotPath,
      );
      final metaBytes = Uint8List.fromList(
        utf8.encode(_snapshotService.buildMetaJson(meta)),
      );
      final initialRemoteMeta = await _clientService.getRemoteMetaResult(
        client: client,
        remotePath: config.metaRemotePath,
      );
      if (initialRemoteMeta.isFailed) {
        return WebdavSyncResult(
          kind: WebdavSyncResultKind.failed,
          message: initialRemoteMeta.errorMessage ?? 'sync_failed',
        );
      }

      if (conflictPolicy == WebdavUploadConflictPolicy.requireUnchangedRemote) {
        final decision = decideWebdavAutoUpload(
          remoteContentSha256: initialRemoteMeta.meta?.contentSha256,
          lastAppliedRemoteHash: config.lastAppliedRemoteHash,
          lastUploadedLocalHash: config.lastUploadedLocalHash,
          localContentSha256: snapshot.contentSha256,
        );
        switch (decision) {
          case WebdavAutoUploadDecision.allow:
            break;
          case WebdavAutoUploadDecision.upToDate:
            return const WebdavSyncResult(kind: WebdavSyncResultKind.upToDate);
          case WebdavAutoUploadDecision.remoteDrifted:
            return const WebdavSyncResult(
              kind: WebdavSyncResultKind.cancelled,
              message: 'local_changes_pending_sync',
            );
        }
      }

      await _publishSnapshotVersion(
        client: client,
        config: config,
        snapshot: snapshot,
        snapshotBytes: snapshotBytes,
        metaBytes: metaBytes,
        initialRemoteMeta: initialRemoteMeta,
        conflictPolicy: conflictPolicy,
      );

      if (writeHistory) {
        final skipHistory =
            backupSource == CloudBackupSource.auto &&
            config.lastUploadedLocalHash == snapshot.contentSha256;
        if (!skipHistory) {
          await _writeBackupHistory(
            client: client,
            config: config,
            snapshotBytes: snapshotBytes,
            snapshot: snapshot,
            deviceId: deviceId,
            deviceLabel: deviceLabel,
            appVersion: packageInfo.version,
            source: backupSource,
            allowDuplicateHash: backupSource == CloudBackupSource.manual,
          );
        } else {
          await _refreshBackupCurrentMarker(
            client: client,
            config: config,
            currentContentSha256: snapshot.contentSha256,
          );
        }
      }

      if (updateSyncTimestamps) {
        await _configStore.save(
          config.copyWith(
            lastSyncedAt: DateTime.now(),
            lastAppliedRemoteHash: snapshot.contentSha256,
            lastUploadedLocalHash: snapshot.contentSha256,
          ),
        );
      }

      return const WebdavSyncResult(kind: WebdavSyncResultKind.uploaded);
    } catch (error) {
      // An immutable body is intentionally retained when history or metadata
      // publication fails; the next sync can safely retry or garbage-collect it.
      return WebdavSyncResult(
        kind: WebdavSyncResultKind.failed,
        message: sanitizeWebdavErrorMessage(error),
      );
    }
  }

  Future<void> _publishSnapshotVersion({
    required WebdavClient client,
    required WebdavSyncConfig config,
    required AppSyncSnapshot snapshot,
    required Uint8List snapshotBytes,
    required Uint8List metaBytes,
    required WebdavRemoteMetaResult initialRemoteMeta,
    required WebdavUploadConflictPolicy conflictPolicy,
  }) async {
    final lockResult = await _clientService.acquireWriteLock(
      client: client,
      remotePath: config.normalizedRemoteFolder,
    );
    if (lockResult.isFailed) {
      throw StateError(lockResult.errorMessage ?? 'sync_failed');
    }

    final lockToken = lockResult.lockToken;
    try {
      final lockedRemoteMeta = await _clientService.getRemoteMetaResult(
        client: client,
        remotePath: config.metaRemotePath,
      );
      if (lockedRemoteMeta.isFailed) {
        throw StateError(lockedRemoteMeta.errorMessage ?? 'sync_failed');
      }
      if (conflictPolicy == WebdavUploadConflictPolicy.requireUnchangedRemote &&
          lockResult.isUnsupported &&
          (lockedRemoteMeta.etag == null || lockedRemoteMeta.etag!.isEmpty)) {
        throw StateError('sync_failed');
      }
      if (conflictPolicy == WebdavUploadConflictPolicy.requireUnchangedRemote &&
          _remoteMetaChanged(initialRemoteMeta, lockedRemoteMeta)) {
        throw StateError('sync_failed');
      }

      final snapshotPath = _versionedSnapshotRemotePath(config, snapshot);
      await _clientService.putBytes(
        client: client,
        remotePath: snapshotPath,
        bytes: snapshotBytes,
        lockToken: lockToken,
      );
      await _verifyRemoteBytes(
        client: client,
        remotePath: snapshotPath,
        expectedBytes: snapshotBytes,
      );

      // If neither a server lock nor ETag is available, the versioned body and
      // post-publication readback prevent body/meta pairing; an HTTP server
      // cannot reject a last-writer race between this compare and PUT.
      final headers = <String, String>{};
      if (conflictPolicy == WebdavUploadConflictPolicy.requireUnchangedRemote) {
        final etag = lockedRemoteMeta.etag;
        if (etag != null && etag.isNotEmpty) {
          headers['If-Match'] = etag;
        } else if (lockedRemoteMeta.isNotFound) {
          // Prevent two first-sync writers from both creating the pointer when
          // the server has no ETag support.
          headers['If-None-Match'] = '*';
        }
      }
      await _clientService.putBytes(
        client: client,
        remotePath: config.metaRemotePath,
        bytes: metaBytes,
        headers: headers,
        lockToken: lockToken,
      );

      final publishedMeta = await _clientService.getRemoteMetaResult(
        client: client,
        remotePath: config.metaRemotePath,
      );
      if (publishedMeta.isFailed || publishedMeta.meta == null) {
        throw StateError('sync_failed');
      }
      final published = publishedMeta.meta!;
      if (published.contentSha256 != snapshot.contentSha256 ||
          published.snapshotPath != snapshotPath) {
        throw StateError('sync_failed');
      }
    } finally {
      if (lockToken != null && lockToken.isNotEmpty) {
        try {
          await _clientService.releaseWriteLock(
            client: client,
            remotePath: config.normalizedRemoteFolder,
            lockToken: lockToken,
          );
        } catch (_) {
          // Locks have a server-side timeout; do not mask the publication
          // result when an otherwise successful unlock request is lost.
        }
      }
    }
  }

  Future<void> _verifyRemoteBytes({
    required WebdavClient client,
    required String remotePath,
    required Uint8List expectedBytes,
  }) async {
    final result = await _clientService.getBytesResult(
      client: client,
      remotePath: remotePath,
    );
    if (result.isFailed) {
      throw StateError(result.errorMessage ?? 'sync_failed');
    }
    if (result.bytes == null || !_bytesEqual(result.bytes!, expectedBytes)) {
      throw StateError('sync_failed');
    }
  }

  String _versionedSnapshotRemotePath(
    WebdavSyncConfig config,
    AppSyncSnapshot snapshot,
  ) {
    final safeDeviceId = snapshot.deviceId.replaceAll(
      RegExp(r'[^A-Za-z0-9_.-]'),
      '_',
    );
    final devicePart = safeDeviceId.isEmpty ? 'device' : safeDeviceId;
    return '${config.normalizedRemoteFolder}snapshot-${snapshot.contentSha256}-'
        '${snapshot.exportedAt.toUtc().microsecondsSinceEpoch}-$devicePart.mikcb';
  }

  String? _resolveRemoteSnapshotPath(WebdavSyncConfig config, String? rawPath) {
    final candidateRaw = rawPath?.trim();
    if (candidateRaw == null || candidateRaw.isEmpty) {
      return config.snapshotRemotePath;
    }
    final folder = config.normalizedRemoteFolder;
    final candidate = candidateRaw.startsWith('/')
        ? candidateRaw
        : '$folder$candidateRaw';
    if (!candidate.startsWith(folder) ||
        candidate.contains('..') ||
        candidate.contains('\\')) {
      return null;
    }
    final relative = candidate.substring(folder.length);
    if (relative.isEmpty || relative.contains('/')) {
      return null;
    }
    return candidate;
  }

  bool _remoteMetaChanged(
    WebdavRemoteMetaResult before,
    WebdavRemoteMetaResult after,
  ) {
    if (before.isNotFound || after.isNotFound) {
      return before.isNotFound != after.isNotFound;
    }
    final beforeMeta = before.meta;
    final afterMeta = after.meta;
    if (beforeMeta == null || afterMeta == null) {
      return beforeMeta != afterMeta;
    }
    final beforeEtag = before.etag;
    final afterEtag = after.etag;
    if (beforeEtag != null && afterEtag != null && beforeEtag != afterEtag) {
      return true;
    }
    return beforeMeta.contentSha256 != afterMeta.contentSha256 ||
        beforeMeta.deviceId != afterMeta.deviceId ||
        beforeMeta.exportedAt != afterMeta.exportedAt ||
        beforeMeta.snapshotPath != afterMeta.snapshotPath;
  }

  static bool _bytesEqual(Uint8List left, Uint8List right) {
    if (left.length != right.length) {
      return false;
    }
    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) {
        return false;
      }
    }
    return true;
  }

  Future<WebdavSyncResult> createManualBackup({
    required TimetableProvider provider,
  }) async {
    final result = await uploadSnapshot(
      provider: provider,
      backupSource: CloudBackupSource.manual,
    );
    if (result.kind == WebdavSyncResultKind.uploaded) {
      return const WebdavSyncResult(kind: WebdavSyncResultKind.backupCreated);
    }
    return result;
  }

  Future<WebdavBackupListResult> fetchBackupList({
    WebdavSyncConfig? configOverride,
  }) async {
    final config = configOverride ?? await _configStore.load();
    final params = await buildConnectionParams(config);
    if (params == null) {
      return const WebdavBackupListResult(
        entries: [],
        errorMessage: 'missing_credentials',
      );
    }

    try {
      final client = _clientService.createClient(params);
      final index = await _loadRemoteBackupIndex(
        client: client,
        config: config,
      );
      final sorted = [...index.entries]
        ..sort((a, b) => b.exportedAt.compareTo(a.exportedAt));
      return WebdavBackupListResult(entries: sorted);
    } catch (error) {
      return WebdavBackupListResult(
        entries: const [],
        errorMessage: sanitizeWebdavErrorMessage(error),
      );
    }
  }

  Future<WebdavTransferPreview> previewBackupRestore({
    required TimetableProvider provider,
    required String entryId,
    TransferApplyMode mode = TransferApplyMode.overwrite,
  }) async {
    final config = await _configStore.load();
    final params = await buildConnectionParams(config);
    if (params == null) {
      throw StateError('missing_credentials');
    }
    final client = _clientService.createClient(params);
    final index = await _loadRemoteBackupIndex(client: client, config: config);
    final entry = index.entries.firstWhere(
      (item) => item.id == entryId,
      orElse: () => throw StateError('backup_not_found'),
    );
    final bytes = await _clientService.getBytes(
      client: client,
      remotePath: config.historyBackupRemotePath(entry.fileName),
    );
    if (bytes == null || bytes.isEmpty) {
      throw StateError('missing_backup_snapshot');
    }
    final snapshot = _snapshotService.parseSnapshotJson(utf8.decode(bytes));
    final mergePackage = _snapshotService.buildMergeTransferPackageFromSnapshot(
      snapshot: snapshot,
      channel: TransferChannel.cloud,
    );
    final overwritePackage = _snapshotService.buildTransferPackageFromSnapshot(
      snapshot: snapshot,
      channel: TransferChannel.cloud,
    );
    final mergeDiff = _snapshotService.previewSnapshot(
      provider: provider,
      snapshot: snapshot,
      mode: TransferApplyMode.merge,
    );
    final overwriteDiff = _snapshotService.previewSnapshot(
      provider: provider,
      snapshot: snapshot,
      mode: TransferApplyMode.overwrite,
    );
    final incoming = mode == TransferApplyMode.merge
        ? mergePackage
        : overwritePackage;
    final diff = mode == TransferApplyMode.merge ? mergeDiff : overwriteDiff;
    return WebdavTransferPreview(
      entryId: entryId,
      snapshot: snapshot,
      incoming: incoming,
      diff: diff,
      mergePackage: mergePackage,
      overwritePackage: overwritePackage,
      mergeDiff: mergeDiff,
      overwriteDiff: overwriteDiff,
    );
  }

  Future<WebdavTransferApplyResult> applyPreviewedBackupRestore({
    required TimetableProvider provider,
    required WebdavTransferPreview preview,
    required TransferApplyMode mode,
    bool uploadAsCurrent = true,
  }) async {
    final package = mode == TransferApplyMode.merge
        ? preview.mergePackage
        : preview.overwritePackage;
    final error = await _snapshotService.applySnapshotWithMode(
      provider: provider,
      snapshot: preview.snapshot,
      mode: mode,
      transferPackage: package,
    );
    if (error != null) {
      return WebdavTransferApplyResult(
        applied: false,
        error: error,
        preview: preview,
      );
    }
    if (uploadAsCurrent) {
      final config = await _configStore.load();
      final uploadResult = await uploadSnapshot(
        provider: provider,
        configOverride: config.copyWith(
          lastAppliedRemoteHash: preview.snapshot.contentSha256,
          lastUploadedLocalHash: preview.snapshot.contentSha256,
        ),
        backupSource: CloudBackupSource.auto,
        writeHistory: false,
      );
      if (uploadResult.kind == WebdavSyncResultKind.failed) {
        // The local restore succeeded, but publishing the selected cloud
        // version failed. Do not leave the device in a half-applied state.
        final undone = await _snapshotService.undoLastApply(provider: provider);
        return WebdavTransferApplyResult(
          applied: false,
          error: undone
              ? (uploadResult.message ?? 'cloud_upload_failed')
              : 'cloud_upload_failed_and_undo_failed',
          preview: preview,
        );
      }
    }
    return WebdavTransferApplyResult(applied: true, preview: preview);
  }

  Future<WebdavSyncResult> restoreFromBackup({
    required TimetableProvider provider,
    required String entryId,
    bool uploadAsCurrent = true,
  }) async {
    final config = await _configStore.load();
    final params = await buildConnectionParams(config);
    if (params == null) {
      return const WebdavSyncResult(
        kind: WebdavSyncResultKind.failed,
        message: 'missing_credentials',
      );
    }

    try {
      final client = _clientService.createClient(params);
      final index = await _loadRemoteBackupIndex(
        client: client,
        config: config,
      );
      final entry = index.entries.firstWhere(
        (item) => item.id == entryId,
        orElse: () => throw StateError('backup_not_found'),
      );

      final bytes = await _clientService.getBytes(
        client: client,
        remotePath: config.historyBackupRemotePath(entry.fileName),
      );
      if (bytes == null || bytes.isEmpty) {
        return const WebdavSyncResult(
          kind: WebdavSyncResultKind.failed,
          message: 'missing_backup_snapshot',
        );
      }

      final content = utf8.decode(bytes);
      final error = await _snapshotService.applySnapshotJson(
        provider: provider,
        content: content,
      );
      if (error != null) {
        return WebdavSyncResult(
          kind: WebdavSyncResultKind.failed,
          message: error,
        );
      }

      await _configStore.save(
        config.copyWith(
          lastAppliedRemoteHash: entry.contentSha256,
          lastUploadedLocalHash: entry.contentSha256,
        ),
      );

      if (uploadAsCurrent) {
        final uploadResult = await uploadSnapshot(
          provider: provider,
          configOverride: config.copyWith(
            lastAppliedRemoteHash: entry.contentSha256,
            lastUploadedLocalHash: entry.contentSha256,
          ),
          backupSource: CloudBackupSource.auto,
          writeHistory: false,
        );
        if (uploadResult.kind == WebdavSyncResultKind.failed) {
          return uploadResult;
        }
      }

      return const WebdavSyncResult(kind: WebdavSyncResultKind.backupRestored);
    } catch (error) {
      return WebdavSyncResult(
        kind: WebdavSyncResultKind.failed,
        message: sanitizeWebdavErrorMessage(error),
      );
    }
  }

  /// Reverts the most recent cloud snapshot apply in this process session.
  /// The remote backup is never deleted or overwritten by this operation.
  Future<bool> undoLastRestore({required TimetableProvider provider}) {
    return _snapshotService.undoLastApply(provider: provider);
  }

  /// Clears the pull/upload baseline hashes so the next sync re-runs the full
  /// conflict decision instead of treating the post-rollback local state as an
  /// upload against a stale remote baseline. Used after a restore failed and
  /// the local data was rolled back (the remote is still the last good copy).
  Future<void> clearSyncBaselines() async {
    if (_disposed) {
      return;
    }
    final config = await _configStore.load();
    await _configStore.save(
      config.copyWith(
        clearLastAppliedRemoteHash: true,
        clearLastUploadedLocalHash: true,
      ),
    );
  }

  Future<WebdavSyncResult> deleteBackup({required String entryId}) async {
    final config = await _configStore.load();
    final params = await buildConnectionParams(config);
    if (params == null) {
      return const WebdavSyncResult(
        kind: WebdavSyncResultKind.failed,
        message: 'missing_credentials',
      );
    }

    try {
      final client = _clientService.createClient(params);
      final index = await _loadRemoteBackupIndex(
        client: client,
        config: config,
      );
      final entry = index.entries.firstWhere(
        (item) => item.id == entryId,
        orElse: () => throw StateError('backup_not_found'),
      );
      if (entry.isCurrent) {
        return const WebdavSyncResult(
          kind: WebdavSyncResultKind.failed,
          message: 'cannot_delete_current_backup',
        );
      }

      await _clientService.deleteRemoteFile(
        client: client,
        remotePath: config.historyBackupRemotePath(entry.fileName),
      );

      final nextIndex = _backupIndexService.removeEntry(
        index: index,
        entryId: entryId,
      );
      await _saveRemoteBackupIndex(
        client: client,
        config: config,
        index: nextIndex,
      );

      return const WebdavSyncResult(kind: WebdavSyncResultKind.backupDeleted);
    } catch (error) {
      return WebdavSyncResult(
        kind: WebdavSyncResultKind.failed,
        message: sanitizeWebdavErrorMessage(error),
      );
    }
  }

  Future<WebdavSyncResult> downloadAndApply({
    required TimetableProvider provider,
    WebdavSyncConfig? configOverride,
    bool allowConflictPrompt = true,
  }) async {
    final config = configOverride ?? await _configStore.load();
    if (!config.enabled) {
      return const WebdavSyncResult(kind: WebdavSyncResultKind.idle);
    }

    final params = await buildConnectionParams(config);
    if (params == null) {
      return const WebdavSyncResult(
        kind: WebdavSyncResultKind.failed,
        message: 'missing_credentials',
      );
    }

    try {
      final client = _clientService.createClient(params);
      final remoteMetaResult = await _clientService.getRemoteMetaResult(
        client: client,
        remotePath: config.metaRemotePath,
      );
      if (remoteMetaResult.isFailed) {
        return WebdavSyncResult(
          kind: WebdavSyncResultKind.failed,
          message: remoteMetaResult.errorMessage ?? 'sync_failed',
        );
      }
      final remoteMeta = remoteMetaResult.meta;
      if (remoteMeta == null || remoteMeta.contentSha256.isEmpty) {
        // True empty cloud (404 / missing meta) — safe to treat as no pull work.
        return const WebdavSyncResult(kind: WebdavSyncResultKind.upToDate);
      }

      if (remoteMeta.contentSha256 == config.lastAppliedRemoteHash) {
        return const WebdavSyncResult(kind: WebdavSyncResultKind.upToDate);
      }

      final deviceId = await _credentialsStore.getOrCreateDeviceId();
      final localSnapshot = await _snapshotService.collectSnapshot(
        provider: provider,
        deviceId: deviceId,
      );
      if (webdavPullHasSyncConflict(
        lastUploadedLocalHash: config.lastUploadedLocalHash,
        lastAppliedRemoteHash: config.lastAppliedRemoteHash,
        localContentSha256: localSnapshot.contentSha256,
        remoteContentSha256: remoteMeta.contentSha256,
      )) {
        if (!allowConflictPrompt &&
            webdavBackgroundPullShouldCancel(
              lastUploadedLocalHash: config.lastUploadedLocalHash,
              lastAppliedRemoteHash: config.lastAppliedRemoteHash,
              localContentSha256: localSnapshot.contentSha256,
              localHasUserData: localSnapshot.hasUserAuthoredData,
            )) {
          return const WebdavSyncResult(
            kind: WebdavSyncResultKind.cancelled,
            message: 'local_changes_pending_sync',
          );
        }
        final conflict = SyncConflictInfo(
          localExportedAt: localSnapshot.exportedAt,
          remoteExportedAt: remoteMeta.exportedAt,
          localHash: localSnapshot.contentSha256,
          remoteHash: remoteMeta.contentSha256,
        );
        final choice = allowConflictPrompt && conflictHandler != null
            ? await conflictHandler!(conflict)
            : resolveSyncConflictForBackground(conflict);
        switch (choice) {
          case SyncConflictChoice.keepLocal:
            return uploadSnapshot(provider: provider, configOverride: config);
          case SyncConflictChoice.keepRemote:
            break;
          case SyncConflictChoice.cancel:
          case null:
            return const WebdavSyncResult(kind: WebdavSyncResultKind.cancelled);
        }
      }

      final snapshotPath = _resolveRemoteSnapshotPath(
        config,
        remoteMeta.snapshotPath,
      );
      if (snapshotPath == null) {
        return const WebdavSyncResult(
          kind: WebdavSyncResultKind.failed,
          message: 'sync_snapshot_path_invalid',
        );
      }
      final bytes = await _clientService.getBytes(
        client: client,
        remotePath: snapshotPath,
      );
      if (bytes == null || bytes.isEmpty) {
        return const WebdavSyncResult(
          kind: WebdavSyncResultKind.failed,
          message: 'missing_backup_snapshot',
        );
      }

      final content = utf8.decode(bytes);
      final parsed = _snapshotService.parseSnapshotJson(content);
      final snapshotHash = parsed.contentSha256.trim();
      final metaHash = remoteMeta.contentSha256.trim();
      if (snapshotHash.isNotEmpty &&
          metaHash.isNotEmpty &&
          snapshotHash != metaHash) {
        return const WebdavSyncResult(
          kind: WebdavSyncResultKind.failed,
          message: 'sync_snapshot_meta_mismatch',
        );
      }
      final appliedContentHash = snapshotHash.isNotEmpty
          ? snapshotHash
          : metaHash;
      final error = await _snapshotService.applySnapshotJson(
        provider: provider,
        content: content,
      );
      if (error != null) {
        return WebdavSyncResult(
          kind: WebdavSyncResultKind.failed,
          message: error,
        );
      }

      await _configStore.save(
        config.copyWith(
          lastSyncedAt: DateTime.now(),
          lastAppliedRemoteHash: appliedContentHash,
          lastUploadedLocalHash: appliedContentHash,
        ),
      );
      return const WebdavSyncResult(kind: WebdavSyncResultKind.downloaded);
    } catch (error) {
      return WebdavSyncResult(
        kind: WebdavSyncResultKind.failed,
        message: sanitizeWebdavErrorMessage(error),
      );
    }
  }

  Future<WebdavSyncResult> syncNow({
    required TimetableProvider provider,
    bool allowConflictPrompt = true,
  }) async {
    final config = await _configStore.load();
    if (!config.enabled) {
      return const WebdavSyncResult(kind: WebdavSyncResultKind.idle);
    }

    final pullResult = await downloadAndApply(
      provider: provider,
      configOverride: config,
      allowConflictPrompt: allowConflictPrompt,
    );
    if (pullResult.kind == WebdavSyncResultKind.downloaded ||
        pullResult.kind == WebdavSyncResultKind.cancelled ||
        pullResult.kind == WebdavSyncResultKind.failed) {
      return pullResult;
    }

    return uploadSnapshot(provider: provider, configOverride: config);
  }

  Future<void> _writeBackupHistory({
    required WebdavClient client,
    required WebdavSyncConfig config,
    required Uint8List snapshotBytes,
    required AppSyncSnapshot snapshot,
    required String deviceId,
    required String deviceLabel,
    required String appVersion,
    required CloudBackupSource source,
    bool allowDuplicateHash = false,
  }) async {
    await _clientService.ensureRemoteFolder(
      client: client,
      remoteFolder: config.historyRemoteFolder,
    );

    final backupId = CloudBackupIndexService.buildBackupId(
      exportedAt: snapshot.exportedAt,
      contentSha256: snapshot.contentSha256,
    );
    final fileName = CloudBackupIndexService.buildBackupFileName(backupId);
    final snapshotJson = utf8.decode(snapshotBytes);

    await _clientService.putBytes(
      client: client,
      remotePath: config.historyBackupRemotePath(fileName),
      bytes: snapshotBytes,
    );

    var index = await _loadRemoteBackupIndex(client: client, config: config);
    final entry = CloudBackupEntry(
      id: backupId,
      fileName: fileName,
      exportedAt: snapshot.exportedAt,
      contentSha256: snapshot.contentSha256,
      deviceId: deviceId,
      deviceLabel: deviceLabel,
      appVersion: appVersion,
      source: source,
      profileCount: CloudBackupIndexService.countProfilesInSnapshotJson(
        snapshotJson,
      ),
      courseCount: CloudBackupIndexService.countCoursesInSnapshotJson(
        snapshotJson,
      ),
    );

    index = _backupIndexService.addEntry(
      index: index,
      entry: entry,
      currentContentSha256: snapshot.contentSha256,
      allowDuplicateHash: allowDuplicateHash,
    );

    final pruned = _backupIndexService.prune(
      index: index,
      maxBackupCount: config.maxBackupCount,
      maxBackupAgeDays: config.maxBackupAgeDays,
      manualBackupProtected: config.manualBackupProtected,
      now: DateTime.now(),
    );

    for (final removed in pruned.removedEntries) {
      try {
        await _clientService.deleteRemoteFile(
          client: client,
          remotePath: config.historyBackupRemotePath(removed.fileName),
        );
      } catch (_) {}
    }

    await _saveRemoteBackupIndex(
      client: client,
      config: config,
      index: pruned.index,
    );
  }

  Future<void> _refreshBackupCurrentMarker({
    required WebdavClient client,
    required WebdavSyncConfig config,
    required String currentContentSha256,
  }) async {
    final index = await _loadRemoteBackupIndex(client: client, config: config);
    if (index.entries.isEmpty) {
      return;
    }
    final nextIndex = _backupIndexService.markCurrent(
      index: index,
      currentContentSha256: currentContentSha256,
    );
    await _saveRemoteBackupIndex(
      client: client,
      config: config,
      index: nextIndex,
    );
  }

  Future<CloudBackupIndex> _loadRemoteBackupIndex({
    required WebdavClient client,
    required WebdavSyncConfig config,
  }) async {
    final indexResult = await _clientService.getBytesResult(
      client: client,
      remotePath: config.historyIndexRemotePath,
    );
    var readableIndexResult = indexResult;
    if (!indexResult.isFailed && !indexResult.isNotFound) {
      final bytes = indexResult.bytes!;
      try {
        final decoded = jsonDecode(utf8.decode(bytes));
        if (decoded is Map && decoded['entries'] is List) {
          return _backupIndexService.decodeIndex(utf8.decode(bytes));
        }
        readableIndexResult = const WebdavGetBytesResult.failed('sync_failed');
      } catch (_) {
        readableIndexResult = const WebdavGetBytesResult.failed('sync_failed');
      }
    }

    final listingResult = await _clientService.listHistoryBackupFilesResult(
      client: client,
      historyRemoteFolder: config.historyRemoteFolder,
    );
    final recovery = decideWebdavBackupIndexRecovery(
      indexResult: readableIndexResult,
      listingResult: listingResult,
    );
    switch (recovery) {
      case WebdavBackupIndexRecoveryAction.useIndex:
        // A successful index is returned above. Keep this branch defensive if
        // the result model grows another successful state later.
        throw StateError('sync_failed');
      case WebdavBackupIndexRecoveryAction.empty:
        return const CloudBackupIndex();
      case WebdavBackupIndexRecoveryAction.failed:
        throw StateError(
          listingResult.errorMessage ??
              readableIndexResult.errorMessage ??
              'sync_failed',
        );
      case WebdavBackupIndexRecoveryAction.rebuildFromListing:
        break;
    }

    final remoteMetaResult = await _clientService.getRemoteMetaResult(
      client: client,
      remotePath: config.metaRemotePath,
    );
    if (remoteMetaResult.isFailed) {
      throw StateError(remoteMetaResult.errorMessage ?? 'sync_failed');
    }
    final currentHash = remoteMetaResult.meta?.contentSha256 ?? '';
    final entries = <CloudBackupEntry>[];

    for (final fileName in listingResult.fileNames) {
      final backupResult = await _clientService.getBytesResult(
        client: client,
        remotePath: config.historyBackupRemotePath(fileName),
      );
      if (backupResult.isFailed) {
        throw StateError(backupResult.errorMessage ?? 'sync_failed');
      }
      if (backupResult.isNotFound) {
        // A concurrent prune may remove a listed file; it is safe to omit the
        // missing entry while retaining all entries that were readable.
        continue;
      }
      try {
        final content = utf8.decode(backupResult.bytes!);
        final parsed = _snapshotService.parseSnapshotJson(content);
        final id = fileName.endsWith('.mikcb')
            ? fileName.substring(0, fileName.length - '.mikcb'.length)
            : fileName;
        entries.add(
          CloudBackupEntry(
            id: id,
            fileName: fileName,
            exportedAt: parsed.exportedAt,
            contentSha256: parsed.contentSha256,
            deviceId: parsed.deviceId,
            deviceLabel: '',
            source: CloudBackupSource.auto,
            profileCount: CloudBackupIndexService.countProfilesInSnapshotJson(
              content,
            ),
            courseCount: CloudBackupIndexService.countCoursesInSnapshotJson(
              content,
            ),
            isCurrent: parsed.contentSha256 == currentHash,
          ),
        );
      } catch (_) {
        // 单个备份体损坏（传输截断/坏 UTF-8 字节/旧版本 schema/字段类型
        // 异常抛 TypeError 等）：一律跳过该条，其余备份仍然可见可选。
        // 此前任何一条坏数据都抛 StateError('sync_failed') 让整个索引
        // 重建失败——一个坏文件把全部历史备份从列表里藏掉，恢复入口被
        // 一条坏数据绑架。parseSnapshotJson 的子解析路径分散，异常并不
        // 总被归一化为 FormatException（如 TypeError），故放宽为 catch
        // 全部后跳过。坏文件仍留在远端，可被后续清理。
        continue;
      }
    }

    entries.sort((a, b) => b.exportedAt.compareTo(a.exportedAt));
    return CloudBackupIndex(entries: entries);
  }

  Future<void> _saveRemoteBackupIndex({
    required WebdavClient client,
    required WebdavSyncConfig config,
    required CloudBackupIndex index,
  }) async {
    await _clientService.putBytes(
      client: client,
      remotePath: config.historyIndexRemotePath,
      bytes: Uint8List.fromList(
        utf8.encode(_backupIndexService.encodeIndex(index)),
      ),
    );
  }
}
