import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'webdav_sync_config.dart';

class CoupleWebdavConfig {
  static const String prefsKey = 'couple_webdav_config_v1';
  static const String defaultJianguoyunBaseUrl =
      'https://dav.jianguoyun.com/dav/';
  static const String defaultRemoteFolder = '/Apps/qingyu-couple/';
  static const String partnerTimetableFileName = 'partner-timetable.mikcb';

  /// Outgoing share written by this device (legacy single-path name).
  static const String mineTimetableFileName = 'mine-timetable.mikcb';
  static const String coupleSlot1FileName = 'couple-slot-1.mikcb';
  static const String coupleSlot2FileName = 'couple-slot-2.mikcb';

  final String baseUrl;
  final String remoteFolder;
  final String username;

  /// This device's slot (1 or 2). Upload writes this slot; pull reads the other.
  final int mySlot;
  final DateTime? lastPulledAt;
  final String? lastRemoteContentHash;

  const CoupleWebdavConfig({
    this.baseUrl = defaultJianguoyunBaseUrl,
    this.remoteFolder = defaultRemoteFolder,
    this.username = '',
    this.mySlot = 1,
    this.lastPulledAt,
    this.lastRemoteContentHash,
  });

  int get normalizedMySlot => mySlot == 2 ? 2 : 1;

  int get partnerSlot => normalizedMySlot == 1 ? 2 : 1;

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

  String _slotFileName(int slot) =>
      slot == 2 ? coupleSlot2FileName : coupleSlot1FileName;

  /// Remote file this device **reads** as partner's timetable.
  String get partnerTimetableRemotePath =>
      '$normalizedRemoteFolder${_slotFileName(partnerSlot)}';

  /// Remote file this device **writes** for the partner to pull.
  String get mineTimetableRemotePath =>
      '$normalizedRemoteFolder${_slotFileName(normalizedMySlot)}';

  /// Legacy single shared path (pre dual-slot); pull falls back when slot empty.
  String get legacyPartnerTimetableRemotePath =>
      '$normalizedRemoteFolder$partnerTimetableFileName';

  CoupleWebdavConfig copyWith({
    String? baseUrl,
    String? remoteFolder,
    String? username,
    int? mySlot,
    DateTime? lastPulledAt,
    String? lastRemoteContentHash,
    bool clearLastPulledAt = false,
    bool clearLastRemoteContentHash = false,
  }) {
    return CoupleWebdavConfig(
      baseUrl: baseUrl ?? this.baseUrl,
      remoteFolder: remoteFolder ?? this.remoteFolder,
      username: username ?? this.username,
      mySlot: mySlot ?? this.mySlot,
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
    'mySlot': normalizedMySlot,
    'lastPulledAt': lastPulledAt?.toIso8601String(),
    'lastRemoteContentHash': lastRemoteContentHash,
  };

  factory CoupleWebdavConfig.fromJson(Map<String, dynamic> json) {
    final rawSlot = (json['mySlot'] as num?)?.toInt() ?? 1;
    return CoupleWebdavConfig(
      baseUrl: json['baseUrl'] as String? ?? defaultJianguoyunBaseUrl,
      remoteFolder: json['remoteFolder'] as String? ?? defaultRemoteFolder,
      username: json['username'] as String? ?? '',
      mySlot: rawSlot == 2 ? 2 : 1,
      lastPulledAt: DateTime.tryParse(json['lastPulledAt'] as String? ?? ''),
      lastRemoteContentHash: json['lastRemoteContentHash'] as String?,
    );
  }
}

/// 解析并校验情侣同步的 baseUrl，返回可直接交给 WebDAV 客户端的地址；
/// 不可用（非 http/https）返回 null，由调用方按各自契约报错。
///
/// 与云同步同源：2026-10-19 安全清单 #4 给 `inspectWebdavBaseUrlScheme` 上了
/// 三级分级，但当时只接了云同步的保存入口，情侣路径（testConnection / pull /
/// push 三处）漏接——同一个洞留了一半，这里补齐（2026-10-20 体检复核确认）。
///
/// http 明文：与云同步同口径属合法场景（局域网 NAS），但放行的前提是 UI
/// 二次确认（cloud_sync_screen.dart 的 `_saveAdvancedFields` 做法）。情侣
/// 路径当前没有地址输入框、也就没有确认入口，按「未确认不放行」拦截；
/// 将来加输入框时在 UI 层补同款确认弹窗，再把「已确认」传到这里放行。
String? validatedCoupleWebdavBaseUrl(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return CoupleWebdavConfig.defaultJianguoyunBaseUrl;
  }
  return inspectWebdavBaseUrlScheme(trimmed) == WebdavBaseUrlScheme.https
      ? trimmed
      : null;
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
