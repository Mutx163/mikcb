import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class WarehouseRememberedLogin {
  final String username;
  final String password;

  const WarehouseRememberedLogin({
    required this.username,
    required this.password,
  });

  Map<String, dynamic> toJson() => {
        'username': username,
        'password': password,
      };

  factory WarehouseRememberedLogin.fromJson(Map<String, dynamic> json) {
    return WarehouseRememberedLogin(
      username: json['username'] as String? ?? '',
      password: json['password'] as String? ?? '',
    );
  }
}

class WarehouseCustomDebugRecord {
  final String id;
  final String name;
  final String importUrl;
  final String script;
  final DateTime createdAt;
  final DateTime updatedAt;

  const WarehouseCustomDebugRecord({
    required this.id,
    required this.name,
    required this.importUrl,
    required this.script,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'importUrl': importUrl,
        'script': script,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory WarehouseCustomDebugRecord.fromJson(Map<String, dynamic> json) {
    return WarehouseCustomDebugRecord(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      importUrl: json['importUrl'] as String? ?? '',
      script: json['script'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  WarehouseCustomDebugRecord copyWith({
    String? id,
    String? name,
    String? importUrl,
    String? script,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WarehouseCustomDebugRecord(
      id: id ?? this.id,
      name: name ?? this.name,
      importUrl: importUrl ?? this.importUrl,
      script: script ?? this.script,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class WarehouseImportPreferencesService {
  static const String _customImportUrlPrefix = 'warehouse_custom_import_url_';
  static const String _rememberedLoginPrefix = 'warehouse_remembered_login_';
  static const String _recentSchoolIdsKey = 'warehouse_recent_school_ids';
  static const String _customDebugRecordsKey = 'warehouse_custom_debug_records';

  Future<SharedPreferences> get _prefs async => SharedPreferences.getInstance();

  Future<String?> getCustomImportUrl(String adapterId) async {
    final prefs = await _prefs;
    final value = prefs.getString('$_customImportUrlPrefix$adapterId');
    return (value == null || value.trim().isEmpty) ? null : value.trim();
  }

  Future<void> setCustomImportUrl(String adapterId, String url) async {
    final prefs = await _prefs;
    await prefs.setString('$_customImportUrlPrefix$adapterId', url.trim());
  }

  Future<void> clearCustomImportUrl(String adapterId) async {
    final prefs = await _prefs;
    await prefs.remove('$_customImportUrlPrefix$adapterId');
  }

  Future<WarehouseRememberedLogin?> getRememberedLogin(String adapterId) async {
    final prefs = await _prefs;
    final raw = prefs.getString('$_rememberedLoginPrefix$adapterId');
    if (raw == null || raw.isEmpty) {
      return null;
    }
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }
    final login = WarehouseRememberedLogin.fromJson(decoded);
    if (login.username.isEmpty && login.password.isEmpty) {
      return null;
    }
    return login;
  }

  Future<void> setRememberedLogin(
    String adapterId,
    WarehouseRememberedLogin login,
  ) async {
    final prefs = await _prefs;
    await prefs.setString(
      '$_rememberedLoginPrefix$adapterId',
      jsonEncode(login.toJson()),
    );
  }

  Future<void> clearRememberedLogin(String adapterId) async {
    final prefs = await _prefs;
    await prefs.remove('$_rememberedLoginPrefix$adapterId');
  }

  Future<List<String>> getRecentSchoolIds() async {
    final prefs = await _prefs;
    return prefs.getStringList(_recentSchoolIdsKey) ?? const [];
  }

  Future<void> addRecentSchool(String schoolId, {int limit = 6}) async {
    final prefs = await _prefs;
    final existing = prefs.getStringList(_recentSchoolIdsKey) ?? <String>[];
    final next = <String>[schoolId, ...existing.where((id) => id != schoolId)];
    if (next.length > limit) {
      next.removeRange(limit, next.length);
    }
    await prefs.setStringList(_recentSchoolIdsKey, next);
  }

  Future<List<WarehouseCustomDebugRecord>> getCustomDebugRecords() async {
    final prefs = await _prefs;
    final raw = prefs.getString(_customDebugRecordsKey);
    if (raw == null || raw.isEmpty) {
      return const [];
    }
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return const [];
    }
    final records = decoded
        .whereType<Map>()
        .map((item) => WarehouseCustomDebugRecord.fromJson(
              Map<String, dynamic>.from(item.cast<String, dynamic>()),
            ))
        .where((item) => item.id.isNotEmpty)
        .toList();
    records.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return records;
  }

  Future<void> saveCustomDebugRecord(WarehouseCustomDebugRecord record) async {
    final prefs = await _prefs;
    final records = await getCustomDebugRecords();
    final next = [
      record,
      ...records.where((item) => item.id != record.id),
    ]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    await prefs.setString(
      _customDebugRecordsKey,
      jsonEncode(next.map((item) => item.toJson()).toList()),
    );
  }

  Future<void> deleteCustomDebugRecord(String recordId) async {
    final prefs = await _prefs;
    final records = await getCustomDebugRecords();
    final next = records.where((item) => item.id != recordId).toList();
    await prefs.setString(
      _customDebugRecordsKey,
      jsonEncode(next.map((item) => item.toJson()).toList()),
    );
  }
}
