import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'user_data_sync_hooks.dart';

class WarehouseRememberedLogin {
  final String username;
  final String password;

  const WarehouseRememberedLogin({
    required this.username,
    required this.password,
  });

  Map<String, dynamic> toJson() => {'username': username, 'password': password};

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
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
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

abstract class WarehouseSecureStorage {
  const WarehouseSecureStorage();

  Future<String?> read({required String key});

  Future<Map<String, String>> readAll();

  Future<void> write({required String key, required String value});

  Future<void> delete({required String key});

  Future<void> deleteAll();
}

class FlutterWarehouseSecureStorage extends WarehouseSecureStorage {
  const FlutterWarehouseSecureStorage({
    FlutterSecureStorage storage = _defaultStorage,
  }) : _storage = storage;

  static const FlutterSecureStorage _defaultStorage = FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read({required String key}) => _storage.read(key: key);

  @override
  Future<Map<String, String>> readAll() => _storage.readAll();

  @override
  Future<void> write({required String key, required String value}) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete({required String key}) => _storage.delete(key: key);

  @override
  Future<void> deleteAll() => _storage.deleteAll();
}

class WarehouseRememberedLoginEntry {
  final String adapterId;
  final WarehouseRememberedLogin login;

  const WarehouseRememberedLoginEntry({
    required this.adapterId,
    required this.login,
  });

  Map<String, dynamic> toJson() => {
    'adapterId': adapterId,
    'username': login.username,
    'password': login.password,
  };

  factory WarehouseRememberedLoginEntry.fromJson(Map<String, dynamic> json) {
    return WarehouseRememberedLoginEntry(
      adapterId: json['adapterId'] as String? ?? '',
      login: WarehouseRememberedLogin.fromJson(json),
    );
  }
}

class WarehouseSyncBundle {
  final List<WarehouseRememberedLoginEntry> rememberedLogins;
  final Map<String, String> customImportUrls;
  final List<String> recentSchoolIds;
  final List<WarehouseCustomDebugRecord> customDebugRecords;

  const WarehouseSyncBundle({
    this.rememberedLogins = const [],
    this.customImportUrls = const {},
    this.recentSchoolIds = const [],
    this.customDebugRecords = const [],
  });

  Map<String, dynamic> toJson() => {
    'rememberedLogins': rememberedLogins.map((item) => item.toJson()).toList(),
    'customImportUrls': customImportUrls,
    'recentSchoolIds': recentSchoolIds,
    'customDebugRecords': customDebugRecords
        .map((item) => item.toJson())
        .toList(),
  };

  /// Cloud sync must not carry teaching-system passwords in plaintext.
  WarehouseSyncBundle withoutPasswords() {
    return WarehouseSyncBundle(
      rememberedLogins: rememberedLogins
          .map(
            (entry) => WarehouseRememberedLoginEntry(
              adapterId: entry.adapterId,
              login: WarehouseRememberedLogin(
                username: entry.login.username,
                password: '',
              ),
            ),
          )
          .toList(),
      customImportUrls: customImportUrls,
      recentSchoolIds: recentSchoolIds,
      customDebugRecords: customDebugRecords,
    );
  }

  factory WarehouseSyncBundle.fromJson(Map<String, dynamic> json) {
    final rawUrls = json['customImportUrls'];
    final customImportUrls = rawUrls is Map
        ? rawUrls.map(
            (key, value) => MapEntry(key.toString(), value.toString()),
          )
        : const <String, String>{};

    return WarehouseSyncBundle(
      rememberedLogins: (json['rememberedLogins'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map(
            (item) => WarehouseRememberedLoginEntry.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .where((item) => item.adapterId.isNotEmpty)
          .toList(),
      customImportUrls: customImportUrls,
      recentSchoolIds: (json['recentSchoolIds'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .where((item) => item.isNotEmpty)
          .toList(),
      customDebugRecords:
          (json['customDebugRecords'] as List<dynamic>? ?? const [])
              .whereType<Map>()
              .map(
                (item) => WarehouseCustomDebugRecord.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .where((item) => item.id.isNotEmpty)
              .toList(),
    );
  }
}

class WarehouseImportPreferencesService {
  static const String _customImportUrlPrefix = 'warehouse_custom_import_url_';
  static const String _rememberedLoginPrefix = 'warehouse_remembered_login_';
  static const String _secureRememberedLoginPrefix =
      'warehouse_secure_remembered_login_';
  static const String _recentSchoolIdsKey = 'warehouse_recent_school_ids';
  static const String _customDebugRecordsKey = 'warehouse_custom_debug_records';

  final WarehouseSecureStorage _secureStorage;

  WarehouseImportPreferencesService({
    WarehouseSecureStorage secureStorage =
        const FlutterWarehouseSecureStorage(),
  }) : _secureStorage = secureStorage;

  Future<SharedPreferences> get _prefs async => SharedPreferences.getInstance();

  Future<String?> getCustomImportUrl(String adapterId) async {
    final prefs = await _prefs;
    final value = prefs.getString('$_customImportUrlPrefix$adapterId');
    return (value == null || value.trim().isEmpty) ? null : value.trim();
  }

  Future<void> setCustomImportUrl(String adapterId, String url) async {
    final prefs = await _prefs;
    await prefs.setString('$_customImportUrlPrefix$adapterId', url.trim());
    notifyUserDataChangedForSync();
  }

  Future<void> clearCustomImportUrl(String adapterId) async {
    final prefs = await _prefs;
    await prefs.remove('$_customImportUrlPrefix$adapterId');
  }

  Future<WarehouseRememberedLogin?> getRememberedLogin(String adapterId) async {
    final prefs = await _prefs;
    final secureKey = '$_secureRememberedLoginPrefix$adapterId';
    final secureRaw = await _secureStorage.read(key: secureKey);
    final secureLogin = _decodeRememberedLogin(secureRaw);
    if (secureLogin != null) {
      return secureLogin;
    }

    if (secureRaw != null) {
      await _secureStorage.delete(key: secureKey);
    }

    final raw = prefs.getString('$_rememberedLoginPrefix$adapterId');
    final legacyLogin = _decodeRememberedLogin(raw);
    if (legacyLogin == null) {
      return null;
    }

    await _secureStorage.write(
      key: secureKey,
      value: jsonEncode(legacyLogin.toJson()),
    );
    await prefs.remove('$_rememberedLoginPrefix$adapterId');
    return legacyLogin;
  }

  Future<void> setRememberedLogin(
    String adapterId,
    WarehouseRememberedLogin login,
  ) async {
    final prefs = await _prefs;
    await _secureStorage.write(
      key: '$_secureRememberedLoginPrefix$adapterId',
      value: jsonEncode(login.toJson()),
    );
    await prefs.remove('$_rememberedLoginPrefix$adapterId');
    notifyUserDataChangedForSync();
  }

  Future<void> clearRememberedLogin(String adapterId) async {
    final prefs = await _prefs;
    await _secureStorage.delete(key: '$_secureRememberedLoginPrefix$adapterId');
    await prefs.remove('$_rememberedLoginPrefix$adapterId');
  }

  WarehouseRememberedLogin? _decodeRememberedLogin(String? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return null;
      }
      final login = WarehouseRememberedLogin.fromJson(
        Map<String, dynamic>.from(decoded),
      );
      if (login.username.isEmpty && login.password.isEmpty) {
        return null;
      }
      return login;
    } catch (_) {
      return null;
    }
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
        .map(
          (item) => WarehouseCustomDebugRecord.fromJson(
            Map<String, dynamic>.from(item.cast<String, dynamic>()),
          ),
        )
        .where((item) => item.id.isNotEmpty)
        .toList();
    records.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return records;
  }

  Future<void> saveCustomDebugRecord(WarehouseCustomDebugRecord record) async {
    final prefs = await _prefs;
    final records = await getCustomDebugRecords();
    final next = [record, ...records.where((item) => item.id != record.id)]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    await prefs.setString(
      _customDebugRecordsKey,
      jsonEncode(next.map((item) => item.toJson()).toList()),
    );
    notifyUserDataChangedForSync();
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

  Future<WarehouseSyncBundle> exportSyncBundle() async {
    final prefs = await _prefs;
    final rememberedLogins = (await _readRememberedLoginsByAdapterId()).entries
        .map(
          (entry) => WarehouseRememberedLoginEntry(
            adapterId: entry.key,
            login: entry.value,
          ),
        )
        .toList();

    final customImportUrls = <String, String>{};
    for (final key in prefs.getKeys()) {
      if (!key.startsWith(_customImportUrlPrefix)) {
        continue;
      }
      final adapterId = key.substring(_customImportUrlPrefix.length);
      final value = prefs.getString(key)?.trim();
      if (adapterId.isEmpty || value == null || value.isEmpty) {
        continue;
      }
      customImportUrls[adapterId] = value;
    }

    return WarehouseSyncBundle(
      rememberedLogins: rememberedLogins,
      customImportUrls: customImportUrls,
      recentSchoolIds: await getRecentSchoolIds(),
      customDebugRecords: await getCustomDebugRecords(),
    );
  }

  /// Cloud snapshots strip passwords ([WarehouseSyncBundle.withoutPasswords]).
  /// Before replace-import, keep local passwords when remote password is empty
  /// and the remembered account identity still matches.
  Future<void> importSyncBundle(WarehouseSyncBundle bundle) async {
    final prefs = await _prefs;
    final localRememberedLogins = await _readRememberedLoginsByAdapterId();

    for (final key in prefs.getKeys()) {
      if (key.startsWith(_customImportUrlPrefix) ||
          key.startsWith(_rememberedLoginPrefix)) {
        await prefs.remove(key);
      }
    }
    await prefs.remove(_recentSchoolIdsKey);
    await prefs.remove(_customDebugRecordsKey);

    final secureEntries = await _secureStorage.readAll();
    for (final key in secureEntries.keys) {
      if (key.startsWith(_secureRememberedLoginPrefix)) {
        await _secureStorage.delete(key: key);
      }
    }

    for (final entry in bundle.rememberedLogins) {
      if (entry.adapterId.isEmpty) {
        continue;
      }
      final resolvedPassword = resolveRememberedLoginPasswordForImport(
        incomingPassword: entry.login.password,
        incomingUsername: entry.login.username,
        localLogin: localRememberedLogins[entry.adapterId],
      );
      await setRememberedLogin(
        entry.adapterId,
        WarehouseRememberedLogin(
          username: entry.login.username,
          password: resolvedPassword,
        ),
      );
    }
    for (final entry in bundle.customImportUrls.entries) {
      await setCustomImportUrl(entry.key, entry.value);
    }
    if (bundle.recentSchoolIds.isNotEmpty) {
      await prefs.setStringList(_recentSchoolIdsKey, bundle.recentSchoolIds);
    }
    if (bundle.customDebugRecords.isNotEmpty) {
      await prefs.setString(
        _customDebugRecordsKey,
        jsonEncode(
          bundle.customDebugRecords.map((item) => item.toJson()).toList(),
        ),
      );
    }
  }

  Future<Map<String, WarehouseRememberedLogin>>
  _readRememberedLoginsByAdapterId() async {
    final prefs = await _prefs;
    final rememberedLogins = <String, WarehouseRememberedLogin>{};

    final secureEntries = await _secureStorage.readAll();
    for (final entry in secureEntries.entries) {
      if (!entry.key.startsWith(_secureRememberedLoginPrefix)) {
        continue;
      }
      final adapterId = entry.key.substring(
        _secureRememberedLoginPrefix.length,
      );
      if (adapterId.isEmpty) {
        continue;
      }
      final login = _decodeRememberedLogin(entry.value);
      if (login == null) {
        continue;
      }
      rememberedLogins[adapterId] = login;
    }

    for (final legacyKey in prefs.getKeys()) {
      if (!legacyKey.startsWith(_rememberedLoginPrefix)) {
        continue;
      }
      final adapterId = legacyKey.substring(_rememberedLoginPrefix.length);
      if (adapterId.isEmpty || rememberedLogins.containsKey(adapterId)) {
        continue;
      }
      final login = _decodeRememberedLogin(prefs.getString(legacyKey));
      if (login == null) {
        continue;
      }
      rememberedLogins[adapterId] = login;
    }

    return rememberedLogins;
  }
}

/// Cloud restore / sync import: prefer non-empty remote password; otherwise
/// keep the local password when the account still looks like the same user.
String resolveRememberedLoginPasswordForImport({
  required String incomingPassword,
  required String incomingUsername,
  WarehouseRememberedLogin? localLogin,
}) {
  if (incomingPassword.isNotEmpty) {
    return incomingPassword;
  }
  if (localLogin == null || localLogin.password.isEmpty) {
    return '';
  }
  if (incomingUsername.isEmpty || incomingUsername == localLogin.username) {
    return localLogin.password;
  }
  return '';
}

/// Prefers a user-set custom import URL, otherwise falls back to [defaultUrl].
String? resolveWarehouseImportUrl({
  String? customImportUrl,
  required String defaultUrl,
}) {
  final custom = (customImportUrl ?? '').trim();
  if (custom.isNotEmpty) {
    return custom;
  }
  final fallback = defaultUrl.trim();
  return fallback.isNotEmpty ? fallback : null;
}
