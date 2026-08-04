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
           backupIndexService ?? const CloudBackupIndexService();

  final AppSyncSnapshotService _snapshotService;
  final WebdavSyncConfigStore _configStore;
  final WebdavSyncCredentialsStore _credentialsStore;
  final WebdavClientService _clientService;
  final CloudBackupIndexService _backupIndexService;

  WebdavSyncConflictHandler? conflictHandler;

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
    var wroteSnapshot = false;
    var wroteMeta = false;
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
      final meta = _snapshotService.buildMetaFromSnapshot(
        snapshot,
        appVersion: packageInfo.version,
      );

      client = _clientService.createClient(params);
      await _clientService.ensureRemoteFolder(
        client: client,
        remoteFolder: config.normalizedRemoteFolder,
      );

      if (conflictPolicy == WebdavUploadConflictPolicy.requireUnchangedRemote) {
        final remoteMetaResult = await _clientService.getRemoteMetaResult(
          client: client,
          remotePath: config.metaRemotePath,
        );
        if (remoteMetaResult.isFailed) {
          return WebdavSyncResult(
            kind: WebdavSyncResultKind.failed,
            message: remoteMetaResult.errorMessage ?? 'remote_meta_unavailable',
          );
        }
        final remoteMeta = remoteMetaResult.meta;
        final decision = decideWebdavAutoUpload(
          remoteContentSha256: remoteMeta?.contentSha256,
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
              message: 'remote_drifted_manual_sync_required',
            );
        }
      }

      // Write snapshot before meta so a meta-only success cannot advertise a
      // hash whose body never landed. Meta is the publish pointer; if meta
      // fails after snapshot, the next upload retries with the same content.
      final metaBytes = Uint8List.fromList(
        utf8.encode(_snapshotService.buildMetaJson(meta)),
      );
      await _clientService.putBytes(
        client: client,
        remotePath: config.snapshotRemotePath,
        bytes: snapshotBytes,
      );
      wroteSnapshot = true;
      await _clientService.putBytes(
        client: client,
        remotePath: config.metaRemotePath,
        bytes: metaBytes,
      );
      wroteMeta = true;

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
      // Intentionally do not delete remote snapshot/meta on partial failure:
      // deleting would destroy a previously good current snapshot (C6).
      // Keep wrote* flags so future logging can report partial progress.
      if (wroteSnapshot || wroteMeta) {
        // no-op cleanup
      }
      return WebdavSyncResult(
        kind: WebdavSyncResultKind.failed,
        message: sanitizeWebdavErrorMessage(error),
      );
    }
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
          message: remoteMetaResult.errorMessage ?? 'remote_meta_unavailable',
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

      final bytes = await _clientService.getBytes(
        client: client,
        remotePath: config.snapshotRemotePath,
      );
      if (bytes == null || bytes.isEmpty) {
        return const WebdavSyncResult(
          kind: WebdavSyncResultKind.failed,
          message: 'missing_remote_snapshot',
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
    final indexBytes = await _clientService.getBytes(
      client: client,
      remotePath: config.historyIndexRemotePath,
    );
    if (indexBytes != null && indexBytes.isNotEmpty) {
      return _backupIndexService.decodeIndex(utf8.decode(indexBytes));
    }

    final fileNames = await _clientService.listHistoryBackupFiles(
      client: client,
      historyRemoteFolder: config.historyRemoteFolder,
    );
    if (fileNames.isEmpty) {
      return const CloudBackupIndex();
    }

    final remoteMeta = await _clientService.getRemoteMeta(
      client: client,
      remotePath: config.metaRemotePath,
    );
    final currentHash = remoteMeta?.contentSha256 ?? '';
    final entries = <CloudBackupEntry>[];

    for (final fileName in fileNames) {
      final bytes = await _clientService.getBytes(
        client: client,
        remotePath: config.historyBackupRemotePath(fileName),
      );
      if (bytes == null || bytes.isEmpty) {
        continue;
      }
      try {
        final content = utf8.decode(bytes);
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
      } catch (_) {}
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
