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
    try {
      return await client.get(remotePath);
    } catch (_) {
      return null;
    }
  }

  Future<AppSyncSnapshotMeta?> getRemoteMeta({
    required WebdavClient client,
    required String remotePath,
  }) async {
    final bytes = await getBytes(client: client, remotePath: remotePath);
    if (bytes == null || bytes.isEmpty) {
      return null;
    }
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map) {
      return null;
    }
    return AppSyncSnapshotMeta.fromJson(Map<String, dynamic>.from(decoded));
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
