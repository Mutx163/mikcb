import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

enum WebdavSyncProvider { jianguoyun, custom }

enum WebdavSyncMode { manual, auto }

class WebdavSyncConfig {
  static const String prefsKey = 'webdav_sync_config_v1';
  static const String defaultJianguoyunBaseUrl =
      'https://dav.jianguoyun.com/dav/';
  static const String defaultRemoteFolder = '/Apps/qingyu-sync/';
  static const String snapshotFileName = 'snapshot.mikcb';
  static const String metaFileName = 'snapshot.meta.json';
  static const String historyFolderName = 'history';
  static const String historyIndexFileName = 'index.json';
  static const int defaultMaxBackupCount = 15;
  static const int defaultMaxBackupAgeDays = 30;

  final bool enabled;
  final WebdavSyncProvider provider;
  final WebdavSyncMode syncMode;
  final String baseUrl;
  final String remoteFolder;
  final String username;
  final DateTime? lastSyncedAt;
  final String? lastAppliedRemoteHash;
  final String? lastUploadedLocalHash;
  final int maxBackupCount;
  final int maxBackupAgeDays;
  final bool manualBackupProtected;

  const WebdavSyncConfig({
    this.enabled = false,
    this.provider = WebdavSyncProvider.jianguoyun,
    this.syncMode = WebdavSyncMode.auto,
    this.baseUrl = defaultJianguoyunBaseUrl,
    this.remoteFolder = defaultRemoteFolder,
    this.username = '',
    this.lastSyncedAt,
    this.lastAppliedRemoteHash,
    this.lastUploadedLocalHash,
    this.maxBackupCount = defaultMaxBackupCount,
    this.maxBackupAgeDays = defaultMaxBackupAgeDays,
    this.manualBackupProtected = true,
  });

  String get normalizedRemoteFolder {
    var folder = remoteFolder.trim();
    if (folder.isEmpty) {
      folder = defaultRemoteFolder;
    }
    if (!folder.startsWith('/')) {
      folder = '/$folder';
    }
    if (!folder.endsWith('/')) {
      folder = '$folder/';
    }
    return folder;
  }

  String get snapshotRemotePath => '$normalizedRemoteFolder$snapshotFileName';

  String get metaRemotePath => '$normalizedRemoteFolder$metaFileName';

  String get historyRemoteFolder =>
      '$normalizedRemoteFolder$historyFolderName/';

  String get historyIndexRemotePath =>
      '$historyRemoteFolder$historyIndexFileName';

  String historyBackupRemotePath(String fileName) =>
      '$historyRemoteFolder$fileName';

  WebdavSyncConfig copyWith({
    bool? enabled,
    WebdavSyncProvider? provider,
    WebdavSyncMode? syncMode,
    String? baseUrl,
    String? remoteFolder,
    String? username,
    DateTime? lastSyncedAt,
    String? lastAppliedRemoteHash,
    String? lastUploadedLocalHash,
    int? maxBackupCount,
    int? maxBackupAgeDays,
    bool? manualBackupProtected,
    bool clearLastSyncedAt = false,
    bool clearLastAppliedRemoteHash = false,
    bool clearLastUploadedLocalHash = false,
  }) {
    return WebdavSyncConfig(
      enabled: enabled ?? this.enabled,
      provider: provider ?? this.provider,
      syncMode: syncMode ?? this.syncMode,
      baseUrl: baseUrl ?? this.baseUrl,
      remoteFolder: remoteFolder ?? this.remoteFolder,
      username: username ?? this.username,
      lastSyncedAt: clearLastSyncedAt
          ? null
          : (lastSyncedAt ?? this.lastSyncedAt),
      lastAppliedRemoteHash: clearLastAppliedRemoteHash
          ? null
          : (lastAppliedRemoteHash ?? this.lastAppliedRemoteHash),
      lastUploadedLocalHash: clearLastUploadedLocalHash
          ? null
          : (lastUploadedLocalHash ?? this.lastUploadedLocalHash),
      maxBackupCount: maxBackupCount ?? this.maxBackupCount,
      maxBackupAgeDays: maxBackupAgeDays ?? this.maxBackupAgeDays,
      manualBackupProtected:
          manualBackupProtected ?? this.manualBackupProtected,
    );
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'provider': provider.name,
    'syncMode': syncMode.name,
    'baseUrl': baseUrl,
    'remoteFolder': remoteFolder,
    'username': username,
    'lastSyncedAt': lastSyncedAt?.toIso8601String(),
    'lastAppliedRemoteHash': lastAppliedRemoteHash,
    'lastUploadedLocalHash': lastUploadedLocalHash,
    'maxBackupCount': maxBackupCount,
    'maxBackupAgeDays': maxBackupAgeDays,
    'manualBackupProtected': manualBackupProtected,
  };

  factory WebdavSyncConfig.fromJson(Map<String, dynamic> json) {
    return WebdavSyncConfig(
      enabled: json['enabled'] as bool? ?? false,
      provider: WebdavSyncProvider.values.firstWhere(
        (item) => item.name == json['provider'],
        orElse: () => WebdavSyncProvider.jianguoyun,
      ),
      syncMode: WebdavSyncMode.values.firstWhere(
        (item) => item.name == json['syncMode'],
        orElse: () => WebdavSyncMode.auto,
      ),
      baseUrl: json['baseUrl'] as String? ?? defaultJianguoyunBaseUrl,
      remoteFolder: json['remoteFolder'] as String? ?? defaultRemoteFolder,
      username: json['username'] as String? ?? '',
      lastSyncedAt: DateTime.tryParse(json['lastSyncedAt'] as String? ?? ''),
      lastAppliedRemoteHash: json['lastAppliedRemoteHash'] as String?,
      lastUploadedLocalHash: json['lastUploadedLocalHash'] as String?,
      maxBackupCount:
          (json['maxBackupCount'] as num?)?.toInt() ?? defaultMaxBackupCount,
      maxBackupAgeDays:
          (json['maxBackupAgeDays'] as num?)?.toInt() ?? defaultMaxBackupAgeDays,
      manualBackupProtected: json['manualBackupProtected'] as bool? ?? true,
    );
  }
}

class WebdavSyncConfigStore {
  const WebdavSyncConfigStore();

  Future<WebdavSyncConfig> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(WebdavSyncConfig.prefsKey);
    if (raw == null || raw.isEmpty) {
      return const WebdavSyncConfig();
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return const WebdavSyncConfig();
      }
      return WebdavSyncConfig.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return const WebdavSyncConfig();
    }
  }

  Future<void> save(WebdavSyncConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      WebdavSyncConfig.prefsKey,
      jsonEncode(config.toJson()),
    );
  }
}
