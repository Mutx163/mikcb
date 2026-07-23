import 'dart:convert';
import 'dart:async';
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

  /// Whether [url] uses HTTPS.
  ///
  /// Kept for callers that want to display a soft hint. HTTP is fully allowed
  /// (campus portals, LAN WebDAV, release builds).
  static bool isSecureUrl(String url) {
    return url.trim().toLowerCase().startsWith('https://');
  }
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

  /// Default network timeout for list/get/put/delete. Weak networks should fail
  /// instead of hanging the sync UI indefinitely.
  static const Duration defaultOperationTimeout = Duration(seconds: 30);

  WebdavClient createClient(WebdavConnectionParams params) {
    return WebdavClient.withCredentials(
      params.username,
      params.password,
      baseUrl: params.baseUrl,
    );
  }

  Future<void> testConnection(WebdavConnectionParams params) async {
    final client = createClient(params);
    await _withTimeout(client.list('/'));
  }

  Future<void> ensureRemoteFolder({
    required WebdavClient client,
    required String remoteFolder,
    Duration timeout = defaultOperationTimeout,
  }) async {
    final segments = remoteFolder
        .split('/')
        .where((segment) => segment.trim().isNotEmpty)
        .toList();
    var current = '';
    for (final segment in segments) {
      current = '$current/$segment';
      try {
        await _withTimeout(
          client.createDirectory('$current/'),
          timeout: timeout,
        );
      } catch (_) {
        // Directory may already exist.
      }
    }
  }

  Future<void> putBytes({
    required WebdavClient client,
    required String remotePath,
    required Uint8List bytes,
    Duration timeout = defaultOperationTimeout,
  }) async {
    await _withTimeout(client.put(remotePath, bytes), timeout: timeout);
  }

  Future<Uint8List?> getBytes({
    required WebdavClient client,
    required String remotePath,
    Duration timeout = defaultOperationTimeout,
  }) async {
    final result = await getBytesResult(
      client: client,
      remotePath: remotePath,
      timeout: timeout,
    );
    return result.bytes;
  }

  /// Distinguishes missing remote file (not found) from transport/auth errors.
  Future<WebdavGetBytesResult> getBytesResult({
    required WebdavClient client,
    required String remotePath,
    Duration timeout = defaultOperationTimeout,
  }) async {
    try {
      final bytes = await _withTimeout(
        client.get(remotePath),
        timeout: timeout,
      );
      if (bytes.isEmpty) {
        return const WebdavGetBytesResult.notFound();
      }
      return WebdavGetBytesResult.ok(bytes);
    } catch (error) {
      return classifyGetBytesFailure(error);
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
    Duration timeout = defaultOperationTimeout,
  }) async {
    await _withTimeout(client.delete(remotePath), timeout: timeout);
  }

  Future<List<String>> listHistoryBackupFiles({
    required WebdavClient client,
    required String historyRemoteFolder,
    Duration timeout = defaultOperationTimeout,
  }) async {
    try {
      final resources = await _withTimeout(
        client.list(historyRemoteFolder),
        timeout: timeout,
      );
      return resources
          .where((resource) => !resource.isDirectory)
          .map((resource) => resource.href.pathSegments.last)
          .where((name) => name.endsWith('.mikcb'))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<T> _withTimeout<T>(
    Future<T> future, {
    Duration timeout = defaultOperationTimeout,
  }) {
    return future.timeout(
      timeout,
      onTimeout: () =>
          throw TimeoutException('webdav_operation_timeout', timeout),
    );
  }

  /// Maps transport / protocol failures from [get] into a structured result.
  static WebdavGetBytesResult classifyGetBytesFailure(Object error) {
    if (error is TimeoutException) {
      return const WebdavGetBytesResult.failed('connection_timeout');
    }
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
