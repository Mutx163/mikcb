import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'user_data_sync_hooks.dart';

class WarehouseRememberedLogin {
  final String username;
  final String password;

  /// 绑定的教务站点主机名（保存凭据时的页面 host，小写）。
  /// 自动填充前必须与当前页面 host 一致；旧版本数据无该字段（空串），
  /// 按旧契约放行，待下次保存时补绑。
  final String host;

  const WarehouseRememberedLogin({
    required this.username,
    required this.password,
    this.host = '',
  });

  Map<String, dynamic> toJson() => {
    'username': username,
    'password': password,
    'host': host,
  };

  factory WarehouseRememberedLogin.fromJson(Map<String, dynamic> json) {
    return WarehouseRememberedLogin(
      username: json['username'] as String? ?? '',
      password: json['password'] as String? ?? '',
      host: json['host'] as String? ?? '',
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
    FlutterSecureStorage? storage,
  }) : _storage = storage ?? _defaultStorage;

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
    // Must stay symmetric with fromJson, which reads 'host' back via
    // WarehouseRememberedLogin.fromJson. Dropping it here made every cloud
    // restore return host: '', and rememberedLoginAllowsUrl treats an empty
    // bound host as "allow any site" — so a credential bound to one school
    // domain came back willing to autofill anywhere.
    'host': login.host,
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
                host: entry.login.host,
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
          .whereType<Map<String, dynamic>>()
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
              .whereType<Map<String, dynamic>>()
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

/// 云端快照里 warehouse 各子字段的**在场标记**（2026-10-19 安全清单 #2）。
///
/// 快照 JSON 缺某个子键（旧版本快照 / 上游裁剪 / 手工编辑）时，对应的本地
/// 类别在还原时**原样保留**——「云端没说」不等于「云端说是空的」。旧实现把
/// 缺字段当空列表处理，还原时会先清空本地再写回，一次恢复就可能把本机
/// 全部导入偏好永久抹掉。
class WarehouseSyncSections {
  final bool rememberedLogins;
  final bool customImportUrls;
  final bool recentSchoolIds;
  final bool customDebugRecords;

  /// 全部在场（默认）：本 App 自己产出的快照序列化时四类键恒定输出，
  /// 还原语义与旧版一致——按云端**替换**。
  const WarehouseSyncSections({
    this.rememberedLogins = true,
    this.customImportUrls = true,
    this.recentSchoolIds = true,
    this.customDebugRecords = true,
  });

  /// 全部不在场：这份快照根本不带可辨识的 warehouse 段。
  const WarehouseSyncSections.absent()
    : rememberedLogins = false,
      customImportUrls = false,
      recentSchoolIds = false,
      customDebugRecords = false;

  /// 从快照 JSON 的 warehouse 对象推导：warehouse 整体缺失 → 全部不在场；
  /// warehouse 在但缺某个子键 → 只有该类别不在场。
  factory WarehouseSyncSections.fromSnapshotJson(Object? warehouseRaw) {
    if (warehouseRaw is! Map) {
      return const WarehouseSyncSections.absent();
    }
    return WarehouseSyncSections(
      rememberedLogins: warehouseRaw.containsKey('rememberedLogins'),
      customImportUrls: warehouseRaw.containsKey('customImportUrls'),
      recentSchoolIds: warehouseRaw.containsKey('recentSchoolIds'),
      customDebugRecords: warehouseRaw.containsKey('customDebugRecords'),
    );
  }
}

class WarehouseImportPreferencesService {
  static const String _customImportUrlPrefix = 'warehouse_custom_import_url_';
  static const String _customImportUrlSourcePrefix =
      'warehouse_custom_import_url_source_';
  static const String _rememberedLoginPrefix = 'warehouse_remembered_login_';
  static const String _secureRememberedLoginPrefix =
      'warehouse_secure_remembered_login_';
  static const String _recentSchoolIdsKey = 'warehouse_recent_school_ids';
  static const String _customDebugRecordsKey = 'warehouse_custom_debug_records';

  final WarehouseSecureStorage _secureStorage;

  WarehouseImportPreferencesService({
    WarehouseSecureStorage? secureStorage,
  }) : _secureStorage = secureStorage ?? const FlutterWarehouseSecureStorage();

  Future<SharedPreferences> get _prefs async => SharedPreferences.getInstance();


  Future<String?> getCustomImportUrl(String adapterId) async {
    final prefs = await _prefs;
    final value = prefs.getString('$_customImportUrlPrefix$adapterId');
    return (value == null || value.trim().isEmpty) ? null : value.trim();
  }

  /// 这个自定义地址是**用户在本机亲手填的**，还是**从云快照还原来的**。
  ///
  /// 两者在自动填充白名单那道闸上待遇不同（见 `isTrustedCustomImportUrl`）：
  /// 用户亲手填的，落地页就在眼前，http 也放行；云快照下发的，用户没看见
  /// 过那个页面，必须是 https 且与登记地址同域。
  Future<CustomImportUrlSource> getCustomImportUrlSource(
    String adapterId,
  ) async {
    final prefs = await _prefs;
    final raw = prefs.getString('$_customImportUrlSourcePrefix$adapterId');
    return raw == 'cloud'
        ? CustomImportUrlSource.cloud
        : CustomImportUrlSource.userEntered;
  }

  Future<void> setCustomImportUrl(
    String adapterId,
    String url, {
    CustomImportUrlSource source = CustomImportUrlSource.userEntered,
  }) async {
    final prefs = await _prefs;
    await prefs.setString('$_customImportUrlPrefix$adapterId', url.trim());
    await prefs.setString(
      '$_customImportUrlSourcePrefix$adapterId',
      source == CustomImportUrlSource.cloud ? 'cloud' : 'user',
    );
    notifyUserDataChangedForSync();
  }

  Future<void> clearCustomImportUrl(String adapterId) async {
    final prefs = await _prefs;
    await prefs.remove('$_customImportUrlPrefix$adapterId');
    await prefs.remove('$_customImportUrlSourcePrefix$adapterId');
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
    // This getter sits on the snapshot-export path, so an unhandled throw here
    // fails the entire WebDAV upload; the records page also awaits it from
    // initState, where a throw leaves its loading spinner up forever. Decode
    // defensively and skip individual malformed entries rather than dropping
    // the whole list, matching _decodeRememberedLogin above.
    final List<dynamic> decoded;
    try {
      final value = jsonDecode(raw);
      if (value is! List) {
        return const [];
      }
      decoded = value;
    } catch (_) {
      return const [];
    }
    final records = <WarehouseCustomDebugRecord>[];
    for (final item in decoded) {
      if (item is! Map) {
        continue;
      }
      try {
        final record = WarehouseCustomDebugRecord.fromJson(
          Map<String, dynamic>.from(item.cast<String, dynamic>()),
        );
        if (record.id.isNotEmpty) {
          records.add(record);
        }
      } catch (_) {
        continue;
      }
    }
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
      // 来源标记键（`..._source_<adapterId>`）也是这个前缀开头的，别把它当成地址收走。
      if (key.startsWith(_customImportUrlSourcePrefix)) {
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
  ///
  /// 2026-10-19 重写（安全清单 #2）。旧实现是「先删光、再写回」：一次性删掉
  /// prefs + 安全存储里四类键的全部旧值，然后逐条写回云端带来的新值——
  /// 中途被杀（进程死亡 / 断电 / 平台通道异常上抛）就停在「本地已清空、
  /// 云端没写完」的状态，云端缺什么本地就永久丢什么，且无任何 journal。
  /// 现在分三步：
  ///
  /// 1. 在内存里把「还原后的完整终态」算出来（密码保留 / 地址过滤 / 记录
  ///    脱敏都在这一步，任何 throw 都不会碰盘）；
  /// 2. 先写新值（与旧键同名的直接覆写）；
  /// 3. **最后**才清「云端没有、本地还在」的旧残留。任何时刻被杀，最坏
  ///    结果只是多留几条旧数据（复活），不再存在「全空」窗口——复活是
  ///    可再还原的，丢失不可逆。
  ///
  /// [sections] 标记云端到底带了哪些类别（见 [WarehouseSyncSections]）：
  /// 不在场的类别**整体跳过**，既不写也不清。
  Future<void> importSyncBundle(
    WarehouseSyncBundle bundle, {
    WarehouseSyncSections sections = const WarehouseSyncSections(),
  }) async {
    final prefs = await _prefs;
    final localRememberedLogins = await _readRememberedLoginsByAdapterId();

    // —— 1) 内存终态 ——
    final desiredLogins = <String, WarehouseRememberedLogin>{};
    if (sections.rememberedLogins) {
      for (final entry in bundle.rememberedLogins) {
        if (entry.adapterId.isEmpty) {
          continue;
        }
        // 密码与绑定站点必须作为一对一起解析：保留本地密码时若沿用云端的
        // host，等于把用户真密码配到备份指定的域名上（见
        // resolveRememberedLoginForImport）。
        desiredLogins[entry.adapterId] = resolveRememberedLoginForImport(
          incoming: entry.login,
          localLogin: localRememberedLogins[entry.adapterId],
        );
      }
    }
    final desiredUrls = <String, String>{};
    if (sections.customImportUrls) {
      for (final entry in bundle.customImportUrls.entries) {
        // 2026-10-10：云端下发的地址照原样存下来（**不再按协议丢**——那会让
        // 只支持明文 http 的学校在换机还原后丢掉自己配的地址，导航退化成
        // 站点外壳），但来源记为 cloud：它进自动填充白名单时要按 https +
        // 同域复核。只挡解析不出主机、或不是 http(s) 的
        // （`javascript:`/`file:`/`data:` 这类）。
        if (!isNavigableWarehouseImportUrl(entry.value)) {
          continue;
        }
        desiredUrls[entry.key] = entry.value;
      }
    }
    List<WarehouseCustomDebugRecord>? desiredDebugRecords;
    if (sections.customDebugRecords) {
      // 2026-10-14：云端下发的调试记录不再原样入库。`record.script` 会在
      // 「自定义调试」页被原样 `runJavaScript`（warehouse_custom_debug_screen
      // 的 `_openDebug` → debugScriptOverride），而 WebView 里是用户已登录的
      // 教务会话——一份随备份/快照进来的记录等于一个零校验的任意 JS 入口
      // （.agents/audit/2026-10-09/warehouse.md 第 3 节）。脚本内容本机无法
      // 验证真伪，所以**只保留展示、不给执行**：script 落库为空串，用户点开
      // 能看到这条记录的名字与地址，但点「调试」时脚本为空、不会执行任何
      // 远端带来的代码；想要可用脚本，请在本机重新录入。
      desiredDebugRecords = bundle.customDebugRecords
          .map(
            (item) => WarehouseCustomDebugRecord(
              id: item.id,
              name: item.name,
              importUrl: item.importUrl,
              script: '',
              createdAt: item.createdAt,
              updatedAt: item.updatedAt,
            ),
          )
          .toList();
    }

    // —— 2) 先写新值 ——
    for (final entry in desiredLogins.entries) {
      await setRememberedLogin(entry.key, entry.value);
    }
    for (final entry in desiredUrls.entries) {
      await setCustomImportUrl(
        entry.key,
        entry.value,
        source: CustomImportUrlSource.cloud,
      );
    }
    if (sections.recentSchoolIds && bundle.recentSchoolIds.isNotEmpty) {
      await prefs.setStringList(_recentSchoolIdsKey, bundle.recentSchoolIds);
    }
    final debugRecords = desiredDebugRecords;
    if (debugRecords != null && debugRecords.isNotEmpty) {
      await prefs.setString(
        _customDebugRecordsKey,
        jsonEncode(debugRecords.map((item) => item.toJson()).toList()),
      );
    }

    // —— 3) 最后清残留 ——
    if (sections.rememberedLogins) {
      for (final adapterId in localRememberedLogins.keys) {
        if (!desiredLogins.containsKey(adapterId)) {
          await clearRememberedLogin(adapterId);
        }
      }
    }
    if (sections.customImportUrls) {
      final localUrlAdapterIds = prefs.getKeys()
          .where(
            (key) =>
                key.startsWith(_customImportUrlPrefix) &&
                !key.startsWith(_customImportUrlSourcePrefix),
          )
          .map((key) => key.substring(_customImportUrlPrefix.length))
          .where((adapterId) => adapterId.isNotEmpty)
          .toList();
      for (final adapterId in localUrlAdapterIds) {
        if (desiredUrls.containsKey(adapterId)) {
          continue;
        }
        await prefs.remove('$_customImportUrlPrefix$adapterId');
        await prefs.remove('$_customImportUrlSourcePrefix$adapterId');
      }
    }
    if (sections.recentSchoolIds && bundle.recentSchoolIds.isEmpty) {
      await prefs.remove(_recentSchoolIdsKey);
    }
    if (debugRecords != null && debugRecords.isEmpty) {
      await prefs.remove(_customDebugRecordsKey);
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

/// 提取 URL 的主机名（小写）；无法解析或为空时返回 null。
String? extractUrlHost(String? url) {
  final trimmed = (url ?? '').trim();
  if (trimmed.isEmpty) {
    return null;
  }
  final uri = Uri.tryParse(trimmed);
  final host = uri?.host.trim().toLowerCase() ?? '';
  return host.isEmpty ? null : host;
}

/// 自动填充门禁（凭据绑定站点）：自动填充只允许发生在 **App 自己会把
/// WebView 带过去的站点** 上 —— 凭据绑定的 host、该适配器在仓库里登记的登录
/// 地址、以及用户为该适配器自定义的登录地址。跨源页面（钓鱼页 / 换站）不提示
/// 也不回放填充；手动「填充」菜单属于用户看清当前页面后的显式动作，不受此
/// 门禁限制。
///
/// [trustedHosts] 是上面后两项的域名集合（可含空串，会被忽略）。传空集合时
/// 只认凭据绑定的 host。
///
/// Why the empty-host fallback is a whitelist and not "allow everything":
/// `host` only started being persisted in v2.1.3.2, so on any install older
/// than that **every** remembered login has an empty host. Allowing those
/// unconditionally left the gate open for exactly the users it was written to
/// protect — the fix was live but inert. The same entry re-binds its host the
/// first time the user saves a password, so the legacy shape is transient.
bool rememberedLoginAllowsUrl(
  WarehouseRememberedLogin? login,
  String? currentUrl, {
  Iterable<String> trustedHosts = const <String>{},
}) {
  if (login == null) {
    return false;
  }
  final currentHost = extractUrlHost(currentUrl);
  if (currentHost == null) {
    return false;
  }
  final boundHost = login.host.trim().toLowerCase();
  if (boundHost.isNotEmpty) {
    return _hostMatches(currentHost, boundHost);
  }
  return trustedHosts
      .map((host) => host.trim().toLowerCase())
      .where((host) => host.isNotEmpty)
      .any((host) => _hostMatches(currentHost, host));
}

/// Exact host match, or a subdomain of it.
///
/// Subdomains matter because a 教务 login commonly bounces across
/// `jw.x.edu` / `a.jw.x.edu` within the same school domain; rejecting those
/// would lock out legitimate users. The `.$host` form cannot be spoofed by
/// suffix games: `jw.x.edu.evil.com` does not end with `.jw.x.edu`.
bool _hostMatches(String currentHost, String trustedHost) =>
    currentHost == trustedHost || currentHost.endsWith('.$trustedHost');

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

/// Cloud restore: resolve the remembered login as a (password, host) **pair**.
///
/// [resolveRememberedLoginPasswordForImport] deliberately keeps the local
/// password when the snapshot ships an empty one. Pairing that kept password
/// with the snapshot's `host` handed the user's real password to whatever
/// domain the snapshot named: a crafted backup made autofill offer the real
/// credentials on an attacker's site while blocking it on the real 教务 site.
///
/// So whenever the local password survives, the local host must survive with
/// it — the two were bound together at save time and must not be separable.
/// A non-empty remote password is self-consistent (its own host comes with
/// it) and is adopted as-is.
WarehouseRememberedLogin resolveRememberedLoginForImport({
  required WarehouseRememberedLogin incoming,
  WarehouseRememberedLogin? localLogin,
}) {
  final password = resolveRememberedLoginPasswordForImport(
    incomingPassword: incoming.password,
    incomingUsername: incoming.username,
    localLogin: localLogin,
  );
  // 只有在「云端没给密码、且确实从本地留下了非空密码」时才把 host 一并留在本地。
  // localLogin 为空（或本地也没密码）时 password 为 ''，此时不存在真密码外泄，
  // host 照常采用云端的，否则无谓地把用户的绑定站点清掉。
  //
  // 判空写成显式的 `localLogin != null`，并靠条件表达式的分支收窄取值，不靠
  // `!`。原先那行 `!` 的安全来自「上一个函数在 null 时恰好返回空串」——
  // 那是它的实现细节而不是契约，本函数第一版就因此踩过一次：两边都空被误判成
  // 「留下了本地密码」，结果把云端的 host 也一起丢了。
  final host = (incoming.password.isEmpty &&
          localLogin != null &&
          localLogin.password.isNotEmpty &&
          password == localLogin.password)
      ? localLogin.host
      : incoming.host;
  return WarehouseRememberedLogin(
    username: incoming.username,
    password: password,
    host: host,
  );
}

/// 一个自定义登录地址是谁填的。
///
/// 2026-10-10 引入。此前自动填充白名单按「是不是 https」判真假，只支持明文
/// http 的教务学校一律拿不到自动填充——按 http 判真假是判错了维度。但 2026-10-08
/// 堵的那个洞（云端快照可污染白名单）是真的，所以换成按**来源**判：
///
/// - [userEntered]：用户在本机亲手填的。填的时候 WebView 就摆在他眼前，落地页
///   是他自己认得的，http 一样放行。
/// - [cloud]：随云同步快照下发的。用户从没见过那个页面，来源不可信。
enum CustomImportUrlSource { userEntered, cloud }

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

/// 这个地址是不是一个 WebView 能打开的 http(s) 站点。
///
/// 只查「能不能导航」，**不看协议安不安全**——那是自动填充那道闸的事
/// （见 [isTrustedCustomImportUrl]）。本函数用来挡 `javascript:`/`file:`/`data:`
/// 这类连主机都没有的，以及 `ftp://` 之类 WebView 打不开的。
bool isNavigableWarehouseImportUrl(String? url) {
  final trimmed = (url ?? '').trim();
  if (trimmed.isEmpty) {
    return false;
  }
  final uri = Uri.tryParse(trimmed);
  if (uri == null) {
    return false;
  }
  final scheme = uri.scheme.toLowerCase();
  if (scheme != 'http' && scheme != 'https') {
    return false;
  }
  return uri.host.trim().isNotEmpty;
}

/// 自定义导入地址是否**可以进自动填充白名单**。
///
/// 2026-10-10 重写判据。此前（2026-10-08）要求 `https`，于是**只支持明文 http
/// 的教务学校一律拿不到自动填充**——协议在这里判错了维度：攻击面来自「这个地址
/// 是谁提供的」，不是「它用什么协议」。而原来要堵的洞是真的，不能撤：
/// `customImportUrls` 随云快照上下行（`AppSyncSnapshot.warehouse`），一份构造过
/// 的快照就能把自动填充白名单换成攻击者主机，让已保存的教务密码自动填到钓鱼页上
/// （见 `warehouse_adapter_web_login_screen.dart` 的 `_warehouseAutofillTrustedHosts`）。
///
/// 新判据：
/// - [CustomImportUrlSource.userEntered]（本机亲手填的）：只要能解析出主机就放行，
///   **明文 http 一样放行**。落地页就在用户眼前，这个选择是他自己做的。
/// - [CustomImportUrlSource.cloud]（云快照下发的）：必须是 `https`，且与
///   [registeredHost] 同域（本身或子域）——用户没看见过那个页面，不予采信。
///   学校把教务挂在 `jwxt.example.edu.cn` 而 App 登记的是 `example.edu.cn` 是常见
///   形态，要留；`example.edu.cn.evil.com` 这种后缀伪装则被拒（判据是
///   `endsWith('.base')`，不是裸 `endsWith`）。大小写不敏感。
bool isTrustedCustomImportUrl({
  required String? url,
  required String? registeredHost,
  required CustomImportUrlSource source,
}) {
  final trimmed = (url ?? '').trim();
  if (trimmed.isEmpty) {
    return false;
  }
  final uri = Uri.tryParse(trimmed);
  if (uri == null) {
    return false;
  }
  final host = uri.host.trim().toLowerCase();
  if (host.isEmpty) {
    return false;
  }
  if (source == CustomImportUrlSource.userEntered) {
    // 本机填的：不再要求 https —— **明文 http 放行正是本次修改的目的**，
    // 只支持 http 的教务站很多，不该因此丢掉自动填充。
    // 但协议仍须是 http(s)：`ftp://host/x` 这类有主机名、WebView 却打不开的，
    // 不该拿到「可以自动填密码」的信任。
    final scheme = uri.scheme.toLowerCase();
    return scheme == 'http' || scheme == 'https';
  }
  // 云端下发的：先要求 https，再要求同域。
  if (uri.scheme.toLowerCase() != 'https') {
    return false;
  }
  final base = (registeredHost ?? '').trim().toLowerCase();
  if (base.isEmpty) {
    // 没有登记地址可对（适配器本身没配 importUrl）：https 就放行。这一支只由
    // 云端来源走到，本机填写的在上面已经返回。
    return true;
  }
  return host == base || host.endsWith('.$base');
}
