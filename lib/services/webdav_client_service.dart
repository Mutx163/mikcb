import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
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
        bytesResult.errorMessage ?? 'sync_failed',
      );
    }
    if (bytesResult.bytes == null || bytesResult.bytes!.isEmpty) {
      return const WebdavRemoteMetaResult.notFound();
    }
    try {
      final decoded = jsonDecode(utf8.decode(bytesResult.bytes!));
      if (decoded is! Map) {
        return const WebdavRemoteMetaResult.failed('invalid_response');
      }
      final meta = AppSyncSnapshotMeta.fromJson(
        Map<String, dynamic>.from(decoded),
      );
      return WebdavRemoteMetaResult.ok(
        meta,
        etag: await getRemoteEtag(client: client, remotePath: remotePath),
      );
    } catch (error) {
      return const WebdavRemoteMetaResult.failed('invalid_response');
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
  ///
  /// Some providers return 403 for a collection LOCK even though the account
  /// can read and write files. Only a response that explicitly describes an
  /// unsupported LOCK is eligible for the fallback; an opaque 403 remains an
  /// access-denied error.
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
      // 405/501 mean the server does not implement LOCK at all. A 403 is
      // unsupported only when the response explicitly says so; plain 403
      // usually means credentials or ACLs are insufficient.
      if (statusCode == 405 || statusCode == 501) {
        return const WebdavLockResult.unsupported();
      }
      if (statusCode == 403 && _looksLikeUnsupportedLock(error)) {
        return const WebdavLockResult.unsupported();
      }
      final classified = classifyGetBytesFailure(error);
      return WebdavLockResult.failed(classified.errorMessage ?? 'sync_failed');
    }
  }

  static bool _looksLikeUnsupportedLock(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('cannot be locked') ||
        message.contains('can not be locked') ||
        message.contains('lock not supported') ||
        message.contains('unsupported lock') ||
        message.contains('lock method not allowed');
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
      classified.errorMessage ?? 'sync_failed',
    );
  }

  /// Maps transport / protocol failures from [get] into a structured result.
  ///
  /// Returns clean error codes (not raw exception strings) so that
  /// [sanitizeWebdavErrorMessage] and the sync-error localizer can map
  /// them to user-facing text.  Raw exception strings leak internal
  /// details (response bodies, URLs) and cannot be localized.
  static WebdavGetBytesResult classifyGetBytesFailure(Object error) {
    if (error is TimeoutException) {
      return const WebdavGetBytesResult.failed('connection_timeout');
    }
    if (error is SocketException) {
      return const WebdavGetBytesResult.failed('connection_failed');
    }
    if (error is HandshakeException) {
      return const WebdavGetBytesResult.failed('certificate_error');
    }
    if (error is FormatException) {
      return const WebdavGetBytesResult.failed('invalid_response');
    }

    // WebDAVException carries a statusCode — use it for precise mapping.
    final statusCode = error is WebDAVException ? error.statusCode : null;
    if (statusCode != null) {
      if (statusCode == 401) {
        return const WebdavGetBytesResult.failed('auth_failed');
      }
      if (statusCode == 403) {
        return const WebdavGetBytesResult.failed('access_denied');
      }
      if (statusCode == 404) {
        return const WebdavGetBytesResult.notFound();
      }
      if (statusCode >= 500) {
        return const WebdavGetBytesResult.failed('invalid_response');
      }
      // Other 4xx / unexpected status codes.
      return const WebdavGetBytesResult.failed('invalid_response');
    }

    // Fall back to string matching for non-WebDAV exceptions (e.g. raw
    // http client errors that were not wrapped by the package).
    final message = error.toString().toLowerCase();
    final statusMatch = RegExp(
      r'\b(?:http\s+|statuscode\s*[=:]\s*)(\d{3})\b',
      caseSensitive: false,
    ).firstMatch(message);
    final textualStatusCode = statusMatch == null
        ? null
        : int.tryParse(statusMatch.group(1)!);
    if (textualStatusCode == 401) {
      return const WebdavGetBytesResult.failed('auth_failed');
    }
    if (textualStatusCode == 403) {
      return const WebdavGetBytesResult.failed('access_denied');
    }
    if (textualStatusCode == 404) {
      return const WebdavGetBytesResult.notFound();
    }
    if (textualStatusCode != null && textualStatusCode >= 500) {
      return const WebdavGetBytesResult.failed('invalid_response');
    }
    if (textualStatusCode != null && textualStatusCode >= 400) {
      return const WebdavGetBytesResult.failed('invalid_response');
    }
    // Only accept explicit missing-resource forms here. Generic server text
    // such as "the requested item does not exist" is not reliable enough to
    // override the failed result without a real HTTP status.
    final looksMissing =
        RegExp(r'\b404\s+not[ _-]?found\b').hasMatch(message) ||
        RegExp(r'\b(?:file|resource|path|collection)\s+not[ _-]?found\b')
            .hasMatch(message) ||
        message.contains('no such file or directory');
    if (looksMissing) {
      return const WebdavGetBytesResult.notFound();
    }
    if (message.contains('certificate') || message.contains('handshake')) {
      return const WebdavGetBytesResult.failed('certificate_error');
    }
    if (message.contains('timeout')) {
      return const WebdavGetBytesResult.failed('connection_timeout');
    }
    if (message.contains('connection') ||
        message.contains('socket') ||
        message.contains('network')) {
      return const WebdavGetBytesResult.failed('connection_failed');
    }
    return const WebdavGetBytesResult.failed('sync_failed');
  }
}
