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

  bool get isNotFound => !isFailed && bytes == null;
}

class WebdavRemoteMetaResult {
  final AppSyncSnapshotMeta? meta;
  final String? etag;
  final bool isFailed;
  final String? errorMessage;

  const WebdavRemoteMetaResult._({
    this.meta,
    this.etag,
    this.isFailed = false,
    this.errorMessage,
  });

  const WebdavRemoteMetaResult.ok(AppSyncSnapshotMeta meta, {String? etag})
    : this._(meta: meta, etag: etag, isFailed: false);

  const WebdavRemoteMetaResult.notFound() : this._(meta: null, isFailed: false);

  const WebdavRemoteMetaResult.failed(String message)
    : this._(meta: null, isFailed: true, errorMessage: message);

  bool get isNotFound => !isFailed && meta == null;
}

/// Result of a history-folder listing. An empty folder and an unavailable
/// listing must not be collapsed into the same value: callers may otherwise
/// overwrite a valid remote index with an empty one after a transient error.
class WebdavHistoryListResult {
  final List<String> fileNames;
  final bool isFailed;
  final bool isNotFound;
  final String? errorMessage;

  const WebdavHistoryListResult._({
    this.fileNames = const [],
    this.isFailed = false,
    this.isNotFound = false,
    this.errorMessage,
  });

  const WebdavHistoryListResult.ok(List<String> fileNames)
    : this._(fileNames: fileNames);

  const WebdavHistoryListResult.notFound() : this._(isNotFound: true);

  const WebdavHistoryListResult.failed(String message)
    : this._(isFailed: true, errorMessage: message);

  bool get isEmpty => fileNames.isEmpty;
}

class WebdavLockResult {
  final String? lockToken;
  final bool isUnsupported;
  final bool isFailed;
  final String? errorMessage;

  const WebdavLockResult._({
    this.lockToken,
    this.isUnsupported = false,
    this.isFailed = false,
    this.errorMessage,
  });

  const WebdavLockResult.acquired(String lockToken)
    : this._(lockToken: lockToken);

  const WebdavLockResult.unsupported() : this._(isUnsupported: true);

  const WebdavLockResult.failed(String message)
    : this._(isFailed: true, errorMessage: message);
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
    Map<String, String> headers = const {},
    String? lockToken,
  }) async {
    final requestHeaders = <String, String>{...headers};
    if (lockToken != null && lockToken.isNotEmpty) {
      requestHeaders.putIfAbsent('If', () => '(<$lockToken>)');
    }
    final request = requestHeaders.isEmpty
        ? client.put(remotePath, bytes)
        : client.putWithHeaders(remotePath, bytes, requestHeaders);
    await _withTimeout(request, timeout: timeout);
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
      final meta = AppSyncSnapshotMeta.fromJson(
        Map<String, dynamic>.from(decoded),
      );
      return WebdavRemoteMetaResult.ok(
        meta,
        etag: await getRemoteEtag(client: client, remotePath: remotePath),
      );
    } catch (error) {
      return WebdavRemoteMetaResult.failed(error.toString());
    }
  }

  /// Reads the server ETag through PROPFIND when the WebDAV server exposes it.
  ///
  /// The package does not expose response headers from GET, so ETag is best
  /// effort. Callers still perform a content re-read when it is unavailable.
  Future<String?> getRemoteEtag({
    required WebdavClient client,
    required String remotePath,
    Duration timeout = defaultOperationTimeout,
  }) async {
    try {
      final resources = await _withTimeout(
        client.propfind(remotePath, 0, const {'getetag'}),
        timeout: timeout,
      );
      final expectedPath = Uri.parse(remotePath).path;
      for (final resource in resources) {
        if (resource.etag == null || resource.etag!.trim().isEmpty) {
          continue;
        }
        if (resource.path == expectedPath ||
            resource.href.toString() == remotePath) {
          return resource.etag!.trim();
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Attempts to acquire an exclusive lock. Unsupported locking is reported
  /// separately so sync can fall back to versioned publication; transport and
  /// lock-conflict failures remain hard failures.
  Future<WebdavLockResult> acquireWriteLock({
    required WebdavClient client,
    required String remotePath,
    Duration timeout = defaultOperationTimeout,
  }) async {
    try {
      final token = await _withTimeout(
        client.lockWithTimeout(remotePath, timeout.inSeconds),
        timeout: timeout,
      );
      return WebdavLockResult.acquired(token);
    } catch (error) {
      final statusCode = error is WebDAVException ? error.statusCode : null;
      if (statusCode == 405 || statusCode == 501) {
        return const WebdavLockResult.unsupported();
      }
      return WebdavLockResult.failed(error.toString());
    }
  }

  Future<void> releaseWriteLock({
    required WebdavClient client,
    required String remotePath,
    required String lockToken,
    Duration timeout = defaultOperationTimeout,
  }) async {
    await _withTimeout(client.unlock(remotePath, lockToken), timeout: timeout);
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
    final result = await listHistoryBackupFilesResult(
      client: client,
      historyRemoteFolder: historyRemoteFolder,
      timeout: timeout,
    );
    return result.fileNames;
  }

  Future<WebdavHistoryListResult> listHistoryBackupFilesResult({
    required WebdavClient client,
    required String historyRemoteFolder,
    Duration timeout = defaultOperationTimeout,
  }) async {
    try {
      final resources = await _withTimeout(
        client.list(historyRemoteFolder),
        timeout: timeout,
      );
      final fileNames = resources
          .where((resource) => !resource.isDirectory)
          .map((resource) => resource.name)
          .where((name) => name.endsWith('.mikcb'))
          .toList();
      return WebdavHistoryListResult.ok(fileNames);
    } catch (error) {
      return classifyHistoryListFailure(error);
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

  /// Maps history-folder listing failures while preserving not-found as an
  /// empty remote folder and transport failures as unavailable state.
  static WebdavHistoryListResult classifyHistoryListFailure(Object error) {
    final classified = classifyGetBytesFailure(error);
    if (classified.isNotFound) {
      return const WebdavHistoryListResult.notFound();
    }
    return WebdavHistoryListResult.failed(
      classified.errorMessage ?? error.toString(),
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
