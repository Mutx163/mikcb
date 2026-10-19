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

  /// 上一次**成功上传**的快照里是否含用户亲手沉淀的数据（课程/任务/考试等）。
  ///
  /// 自动上传侧的「本地空数据守卫」靠它区分两种情况：
  /// - 「本来就没有用户数据」（例如只改过设置的用户）——以前传的就是空壳，
  ///   这次再传空壳不构成覆盖，不能拦；
  /// - 「上次有、这次没了」——本地数据意外清空/被覆盖，自动上传会把云端最后
  ///   一份好数据顶掉，必须拦。
  ///
  /// null 表示未知（旧版本配置，或从未成功上传过）：按「不能拦」处理，
  /// 保持升级用户的既有行为。
  final bool? lastUploadedHadUserData;

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
    this.lastUploadedHadUserData,
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

  /// Builds a remote history path for [fileName].
  ///
  /// Rejects path traversal (`..`, `/`, `\`) and returns only the basename
  /// under [historyRemoteFolder].
  String historyBackupRemotePath(String fileName) {
    final sanitized = sanitizeHistoryBackupFileName(fileName);
    return '$historyRemoteFolder$sanitized';
  }

  /// Returns a safe single-segment file name for history backups.
  static String sanitizeHistoryBackupFileName(String fileName) {
    final trimmed = fileName.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('backup_file_name_required');
    }
    final withoutSlashes = trimmed
        .replaceAll('\\', '/')
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .last;
    if (withoutSlashes.isEmpty ||
        withoutSlashes == '.' ||
        withoutSlashes == '..' ||
        withoutSlashes.contains('..')) {
      throw ArgumentError('backup_file_name_invalid');
    }
    return withoutSlashes;
  }

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
    bool? lastUploadedHadUserData,
    bool clearLastUploadedHadUserData = false,
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
      lastUploadedHadUserData: clearLastUploadedHadUserData
          ? null
          : (lastUploadedHadUserData ?? this.lastUploadedHadUserData),
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
    'lastUploadedHadUserData': lastUploadedHadUserData,
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
          (json['maxBackupAgeDays'] as num?)?.toInt() ??
          defaultMaxBackupAgeDays,
      manualBackupProtected: json['manualBackupProtected'] as bool? ?? true,
      // 类型不符按「未知」处理：旧配置没有这个键，未来手改坏了也不能把
      // 上传守卫变成一个会误拦的开关。
      lastUploadedHadUserData: json['lastUploadedHadUserData'] is bool
          ? json['lastUploadedHadUserData'] as bool
          : null,
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
