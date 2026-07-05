import 'dart:convert';
import 'dart:typed_data';

import 'package:package_info_plus/package_info_plus.dart';

import '../providers/timetable_provider.dart';
import 'app_sync_snapshot_service.dart';
import 'webdav_client_service.dart';
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
}

class WebdavSyncResult {
  final WebdavSyncResultKind kind;
  final String? message;

  const WebdavSyncResult({required this.kind, this.message});
}

typedef WebdavSyncConflictHandler =
    Future<SyncConflictChoice?> Function(SyncConflictInfo info);

class WebdavSyncService {
  WebdavSyncService({
    AppSyncSnapshotService? snapshotService,
    WebdavSyncConfigStore? configStore,
    WebdavSyncCredentialsStore? credentialsStore,
    WebdavClientService? clientService,
  }) : _snapshotService = snapshotService ?? AppSyncSnapshotService(),
       _configStore = configStore ?? const WebdavSyncConfigStore(),
       _credentialsStore =
           credentialsStore ?? const WebdavSyncCredentialsStore(),
       _clientService = clientService ?? const WebdavClientService();

  final AppSyncSnapshotService _snapshotService;
  final WebdavSyncConfigStore _configStore;
  final WebdavSyncCredentialsStore _credentialsStore;
  final WebdavClientService _clientService;

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
    return WebdavConnectionParams(
      baseUrl: config.baseUrl.trim().isEmpty
          ? WebdavSyncConfig.defaultJianguoyunBaseUrl
          : config.baseUrl.trim(),
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
    await _clientService.testConnection(
      WebdavConnectionParams(
        baseUrl: config.baseUrl.trim().isEmpty
            ? WebdavSyncConfig.defaultJianguoyunBaseUrl
            : config.baseUrl.trim(),
        username: config.username.trim(),
        password: password,
      ),
    );
  }

  Future<WebdavSyncResult> uploadSnapshot({
    required TimetableProvider provider,
    WebdavSyncConfig? configOverride,
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
      final deviceId = await _credentialsStore.getOrCreateDeviceId();
      final snapshot = await _snapshotService.collectSnapshot(
        provider: provider,
        deviceId: deviceId,
      );
      final snapshotJson = _snapshotService.buildSnapshotJsonFromSnapshot(
        snapshot,
      );
      final packageInfo = await PackageInfo.fromPlatform();
      final meta = _snapshotService.buildMetaFromSnapshot(
        snapshot,
        appVersion: packageInfo.version,
      );

      final client = _clientService.createClient(params);
      await _clientService.ensureRemoteFolder(
        client: client,
        remoteFolder: config.normalizedRemoteFolder,
      );
      await _clientService.putBytes(
        client: client,
        remotePath: config.snapshotRemotePath,
        bytes: Uint8List.fromList(utf8.encode(snapshotJson)),
      );
      await _clientService.putBytes(
        client: client,
        remotePath: config.metaRemotePath,
        bytes: Uint8List.fromList(
          utf8.encode(_snapshotService.buildMetaJson(meta)),
        ),
      );

      await _configStore.save(
        config.copyWith(
          lastSyncedAt: DateTime.now(),
          lastAppliedRemoteHash: snapshot.contentSha256,
          lastUploadedLocalHash: snapshot.contentSha256,
        ),
      );
      return const WebdavSyncResult(kind: WebdavSyncResultKind.uploaded);
    } catch (error) {
      return WebdavSyncResult(
        kind: WebdavSyncResultKind.failed,
        message: error.toString(),
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
      final remoteMeta = await _clientService.getRemoteMeta(
        client: client,
        remotePath: config.metaRemotePath,
      );
      if (remoteMeta == null || remoteMeta.contentSha256.isEmpty) {
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
      final localChangedSinceSync =
          config.lastUploadedLocalHash != null &&
          localSnapshot.contentSha256 != config.lastUploadedLocalHash;
      final remoteChangedSinceSync =
          config.lastAppliedRemoteHash != null &&
          remoteMeta.contentSha256 != config.lastAppliedRemoteHash;

      if (localChangedSinceSync && remoteChangedSinceSync) {
        final conflict = SyncConflictInfo(
          localExportedAt: localSnapshot.exportedAt,
          remoteExportedAt: remoteMeta.exportedAt,
          localHash: localSnapshot.contentSha256,
          remoteHash: remoteMeta.contentSha256,
        );
        final choice = allowConflictPrompt && conflictHandler != null
            ? await conflictHandler!(conflict)
            : resolveSyncConflictAutomatically(conflict);
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
          lastAppliedRemoteHash: remoteMeta.contentSha256,
          lastUploadedLocalHash: remoteMeta.contentSha256,
        ),
      );
      return const WebdavSyncResult(kind: WebdavSyncResultKind.downloaded);
    } catch (error) {
      return WebdavSyncResult(
        kind: WebdavSyncResultKind.failed,
        message: error.toString(),
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
}
