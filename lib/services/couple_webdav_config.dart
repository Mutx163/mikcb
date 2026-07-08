import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class CoupleWebdavConfig {
  static const String prefsKey = 'couple_webdav_config_v1';
  static const String defaultJianguoyunBaseUrl =
      'https://dav.jianguoyun.com/dav/';
  static const String defaultRemoteFolder = '/Apps/qingyu-couple/';
  static const String partnerTimetableFileName = 'partner-timetable.mikcb';

  final String baseUrl;
  final String remoteFolder;
  final String username;
  final DateTime? lastPulledAt;
  final String? lastRemoteContentHash;

  const CoupleWebdavConfig({
    this.baseUrl = defaultJianguoyunBaseUrl,
    this.remoteFolder = defaultRemoteFolder,
    this.username = '',
    this.lastPulledAt,
    this.lastRemoteContentHash,
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

  String get partnerTimetableRemotePath =>
      '$normalizedRemoteFolder$partnerTimetableFileName';

  CoupleWebdavConfig copyWith({
    String? baseUrl,
    String? remoteFolder,
    String? username,
    DateTime? lastPulledAt,
    String? lastRemoteContentHash,
    bool clearLastPulledAt = false,
    bool clearLastRemoteContentHash = false,
  }) {
    return CoupleWebdavConfig(
      baseUrl: baseUrl ?? this.baseUrl,
      remoteFolder: remoteFolder ?? this.remoteFolder,
      username: username ?? this.username,
      lastPulledAt: clearLastPulledAt
          ? null
          : (lastPulledAt ?? this.lastPulledAt),
      lastRemoteContentHash: clearLastRemoteContentHash
          ? null
          : (lastRemoteContentHash ?? this.lastRemoteContentHash),
    );
  }

  Map<String, dynamic> toJson() => {
    'baseUrl': baseUrl,
    'remoteFolder': remoteFolder,
    'username': username,
    'lastPulledAt': lastPulledAt?.toIso8601String(),
    'lastRemoteContentHash': lastRemoteContentHash,
  };

  factory CoupleWebdavConfig.fromJson(Map<String, dynamic> json) {
    return CoupleWebdavConfig(
      baseUrl: json['baseUrl'] as String? ?? defaultJianguoyunBaseUrl,
      remoteFolder: json['remoteFolder'] as String? ?? defaultRemoteFolder,
      username: json['username'] as String? ?? '',
      lastPulledAt: DateTime.tryParse(json['lastPulledAt'] as String? ?? ''),
      lastRemoteContentHash: json['lastRemoteContentHash'] as String?,
    );
  }
}

class CoupleWebdavConfigStore {
  const CoupleWebdavConfigStore();

  Future<CoupleWebdavConfig> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(CoupleWebdavConfig.prefsKey);
    if (raw == null || raw.isEmpty) {
      return const CoupleWebdavConfig();
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return const CoupleWebdavConfig();
      }
      return CoupleWebdavConfig.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return const CoupleWebdavConfig();
    }
  }

  Future<void> save(CoupleWebdavConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      CoupleWebdavConfig.prefsKey,
      jsonEncode(config.toJson()),
    );
  }
}
