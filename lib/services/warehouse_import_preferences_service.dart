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

class WarehouseImportPreferencesService {
  static const String _customImportUrlPrefix = 'warehouse_custom_import_url_';
  static const String _rememberedLoginPrefix = 'warehouse_remembered_login_';
  static const String _recentSchoolIdsKey = 'warehouse_recent_school_ids';

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
}
