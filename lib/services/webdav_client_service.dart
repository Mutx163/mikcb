import 'dart:convert';
import 'dart:typed_data';

import 'package:webdav_plus/webdav_plus.dart';

import 'app_sync_snapshot_service.dart';

class WebdavConnectionParams {
  final String baseUrl;
  final String username;
  final String password;

  const WebdavConnectionParams({
    required this.baseUrl,
    required this.username,
    required this.password,
  });
}

class WebdavGetBytesResult {
  final Uint8List? bytes;
  final bool isFailed;
  final String? errorMessage;

  const WebdavGetBytesResult._({
    this.bytes,
    this.isFailed = false,
    this.errorMessage,
  });

  const WebdavGetBytesResult.ok(Uint8List bytes)
    : this._(bytes: bytes, isFailed: false);

  const WebdavGetBytesResult.notFound() : this._(bytes: null, isFailed: false);

  const WebdavGetBytesResult.failed(String message)
    : this._(bytes: null, isFailed: true, errorMessage: message);
}

class WebdavRemoteMetaResult {
  final AppSyncSnapshotMeta? meta;
  final bool isFailed;
  final String? errorMessage;

  const WebdavRemoteMetaResult._({
    this.meta,
    this.isFailed = false,
    this.errorMessage,
  });

  const WebdavRemoteMetaResult.ok(AppSyncSnapshotMeta meta)
    : this._(meta: meta, isFailed: false);

  const WebdavRemoteMetaResult.notFound() : this._(meta: null, isFailed: false);

  const WebdavRemoteMetaResult.failed(String message)
    : this._(meta: null, isFailed: true, errorMessage: message);
}

class WebdavClientService {
  const WebdavClientService();

  WebdavClient createClient(WebdavConnectionParams params) {
    return WebdavClient.withCredentials(
      params.username,
      params.password,
      baseUrl: params.baseUrl,
    );
  }

  Future<void> testConnection(WebdavConnectionParams params) async {
    final client = createClient(params);
    await client.list('/');
  }

  Future<void> ensureRemoteFolder({
    required WebdavClient client,
    required String remoteFolder,
  }) async {
    final segments = remoteFolder
        .split('/')
        .where((segment) => segment.trim().isNotEmpty)
        .toList();
    var current = '';
    for (final segment in segments) {
      current = '$current/$segment';
      try {
        await client.createDirectory('$current/');
      } catch (_) {
        // Directory may already exist.
      }
    }
  }

  Future<void> putBytes({
    required WebdavClient client,
    required String remotePath,
    required Uint8List bytes,
  }) async {
    await client.put(remotePath, bytes);
  }

  Future<Uint8List?> getBytes({
    required WebdavClient client,
    required String remotePath,
  }) async {
    final result = await getBytesResult(client: client, remotePath: remotePath);
    return result.bytes;
  }

  /// Distinguishes missing remote file (not found) from transport/auth errors.
  Future<WebdavGetBytesResult> getBytesResult({
    required WebdavClient client,
    required String remotePath,
  }) async {
    try {
      final bytes = await client.get(remotePath);
      if (bytes.isEmpty) {
        return const WebdavGetBytesResult.notFound();
      }
      return WebdavGetBytesResult.ok(bytes);
    } catch (error) {
      final message = error.toString().toLowerCase();
      final looksMissing =
          message.contains('404') ||
          message.contains('not found') ||
          message.contains('not_found') ||
          message.contains('does not exist') ||
          message.contains('no such file');
      if (looksMissing) {
        return const WebdavGetBytesResult.notFound();
      }
      return WebdavGetBytesResult.failed(error.toString());
    }
  }

  Future<AppSyncSnapshotMeta?> getRemoteMeta({
    required WebdavClient client,
    required String remotePath,
  }) async {
    final result = await getRemoteMetaResult(
      client: client,
      remotePath: remotePath,
    );
    return result.meta;
  }

  Future<WebdavRemoteMetaResult> getRemoteMetaResult({
    required WebdavClient client,
    required String remotePath,
  }) async {
    final bytesResult = await getBytesResult(
      client: client,
      remotePath: remotePath,
    );
    if (bytesResult.isFailed) {
      return WebdavRemoteMetaResult.failed(
        bytesResult.errorMessage ?? 'remote_meta_unavailable',
      );
    }
    if (bytesResult.bytes == null || bytesResult.bytes!.isEmpty) {
      return const WebdavRemoteMetaResult.notFound();
    }
    try {
      final decoded = jsonDecode(utf8.decode(bytesResult.bytes!));
      if (decoded is! Map) {
        return const WebdavRemoteMetaResult.failed('remote_meta_invalid');
      }
      return WebdavRemoteMetaResult.ok(
        AppSyncSnapshotMeta.fromJson(Map<String, dynamic>.from(decoded)),
      );
    } catch (error) {
      return WebdavRemoteMetaResult.failed(error.toString());
    }
  }

  Future<void> deleteRemoteFile({
    required WebdavClient client,
    required String remotePath,
  }) async {
    await client.delete(remotePath);
  }

  Future<List<String>> listHistoryBackupFiles({
    required WebdavClient client,
    required String historyRemoteFolder,
  }) async {
    try {
      final resources = await client.list(historyRemoteFolder);
      return resources
          .where((resource) => !resource.isDirectory)
          .map((resource) => resource.href.pathSegments.last)
          .where((name) => name.endsWith('.mikcb'))
          .toList();
    } catch (_) {
      return const [];
    }
  }
}
