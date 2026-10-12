import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/services/warehouse_import_preferences_service.dart';

class _MemoryWarehouseSecureStorage extends WarehouseSecureStorage {
  final Map<String, String> _values = <String, String>{};

  @override
  Future<String?> read({required String key}) async => _values[key];

  @override
  Future<Map<String, String>> readAll() async =>
      Map<String, String>.from(_values);

  @override
  Future<void> write({required String key, required String value}) async {
    _values[key] = value;
  }

  @override
  Future<void> delete({required String key}) async {
    _values.remove(key);
  }

  @override
  Future<void> deleteAll() async {
    _values.clear();
  }
}

void main() {
  group('resolveWarehouseImportUrl', () {
    test('prefers custom import URL when set', () {
      expect(
        resolveWarehouseImportUrl(
          customImportUrl: ' https://custom.example/login ',
          defaultUrl: 'https://default.example/login',
        ),
        'https://custom.example/login',
      );
    });

    test('falls back to default URL when custom is empty', () {
      expect(
        resolveWarehouseImportUrl(
          customImportUrl: '   ',
          defaultUrl: 'https://default.example/login',
        ),
        'https://default.example/login',
      );
    });

    test('returns null when both URLs are empty', () {
      expect(
        resolveWarehouseImportUrl(defaultUrl: ' '),
        isNull,
      );
    });
  });

  group('resolveRememberedLoginPasswordForImport', () {
    const localLogin = WarehouseRememberedLogin(
      username: 'student',
      password: 'local-secret',
    );

    test('prefers non-empty incoming password', () {
      expect(
        resolveRememberedLoginPasswordForImport(
          incomingPassword: 'remote-secret',
          incomingUsername: 'student',
          localLogin: localLogin,
        ),
        'remote-secret',
      );
    });

    test('keeps local password when cloud password is stripped', () {
      expect(
        resolveRememberedLoginPasswordForImport(
          incomingPassword: '',
          incomingUsername: 'student',
          localLogin: localLogin,
        ),
        'local-secret',
      );
    });

    test('does not reuse password when username changed', () {
      expect(
        resolveRememberedLoginPasswordForImport(
          incomingPassword: '',
          incomingUsername: 'other-student',
          localLogin: localLogin,
        ),
        isEmpty,
      );
    });

    test('returns empty when there is no local password', () {
      expect(
        resolveRememberedLoginPasswordForImport(
          incomingPassword: '',
          incomingUsername: 'student',
        ),
        isEmpty,
      );
    });
  });

  group('importSyncBundle password merge', () {
    late _MemoryWarehouseSecureStorage secureStorage;
    late WarehouseImportPreferencesService service;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      secureStorage = _MemoryWarehouseSecureStorage();
      service = WarehouseImportPreferencesService(secureStorage: secureStorage);
    });

    test(
      'cloud withoutPasswords restore keeps local password for same account',
      () async {
        await service.setRememberedLogin(
          'demo',
          const WarehouseRememberedLogin(
            username: 'student',
            password: 'local-secret',
          ),
        );

        final cloudBundle = const WarehouseSyncBundle(
          rememberedLogins: [
            WarehouseRememberedLoginEntry(
              adapterId: 'demo',
              login: WarehouseRememberedLogin(
                username: 'student',
                password: 'should-not-upload',
              ),
            ),
          ],
        ).withoutPasswords();

        await service.importSyncBundle(cloudBundle);

        final restored = await service.getRememberedLogin('demo');
        expect(restored?.username, 'student');
        expect(restored?.password, 'local-secret');
      },
    );

    test('incoming non-empty password still replaces local password', () async {
      await service.setRememberedLogin(
        'demo',
        const WarehouseRememberedLogin(
          username: 'student',
          password: 'local-secret',
        ),
      );

      await service.importSyncBundle(
        const WarehouseSyncBundle(
          rememberedLogins: [
            WarehouseRememberedLoginEntry(
              adapterId: 'demo',
              login: WarehouseRememberedLogin(
                username: 'student',
                password: 'new-secret',
              ),
            ),
          ],
        ),
      );

      final restored = await service.getRememberedLogin('demo');
      expect(restored?.password, 'new-secret');
    });

    test(
      'drops local password when cloud username no longer matches',
      () async {
        await service.setRememberedLogin(
          'demo',
          const WarehouseRememberedLogin(
            username: 'student',
            password: 'local-secret',
          ),
        );

        await service.importSyncBundle(
          const WarehouseSyncBundle(
            rememberedLogins: [
              WarehouseRememberedLoginEntry(
                adapterId: 'demo',
                login: WarehouseRememberedLogin(
                  username: 'other-student',
                  password: '',
                ),
              ),
            ],
          ),
        );

        final restored = await service.getRememberedLogin('demo');
        expect(restored?.username, 'other-student');
        expect(restored?.password, isEmpty);
      },
    );

    test(
      'crafted snapshot cannot re-point the kept local password at its own host',
      () async {
        // 端到端走 importSyncBundle：先前只有纯函数级测试，而绑定与密码的
        // 配对是在 importSyncBundle 里做的，只测纯函数看不到这里的漏洞。
        await service.setRememberedLogin(
          'demo',
          const WarehouseRememberedLogin(
            username: 'student',
            password: 'local-secret',
            host: 'jw.example.edu.cn',
          ),
        );

        // 攻击者构造的备份：账号对得上、密码留空（触发保留本地密码）、
        // host 指向钓鱼站。
        await service.importSyncBundle(
          const WarehouseSyncBundle(
            rememberedLogins: [
              WarehouseRememberedLoginEntry(
                adapterId: 'demo',
                login: WarehouseRememberedLogin(
                  username: 'student',
                  password: '',
                  host: 'evil.example.com',
                ),
              ),
            ],
          ),
        );

        final restored = await service.getRememberedLogin('demo');
        expect(restored?.password, 'local-secret');
        // 密码保住了，绑定站点也必须保住 —— 否则钓鱼站会自动填入真密码。
        expect(restored?.host, 'jw.example.edu.cn');
        expect(
          rememberedLoginAllowsUrl(restored, 'https://evil.example.com/login'),
          isFalse,
        );
        expect(
          rememberedLoginAllowsUrl(
              restored, 'https://jw.example.edu.cn/login'),
          isTrue,
        );
      },
    );
  });

  group('remembered login host binding', () {
    test('json round-trips host field', () {
      const login = WarehouseRememberedLogin(
        username: 'student',
        password: 'secret',
        host: 'jw.example.edu.cn',
      );

      // Host is stored verbatim; case is normalized when compared at the
      // autofill gate (extractUrlHost / rememberedLoginAllowsUrl).
      final decoded = WarehouseRememberedLogin.fromJson(
        Map<String, dynamic>.from(login.toJson()),
      );
      expect(decoded.host, 'jw.example.edu.cn');
      expect(decoded.username, login.username);
      expect(decoded.password, login.password);
      // Legacy payloads without host keep working.
      final legacy = WarehouseRememberedLogin.fromJson(const {
        'username': 'student',
        'password': 'secret',
      });
      expect(legacy.host, isEmpty);
    });

    test('extractUrlHost lowercases and rejects unusable input', () {
      expect(extractUrlHost('https://JW.Example.edu.cn/login?a=1'),
          'jw.example.edu.cn');
      expect(extractUrlHost('http://10.0.0.8:8080/xk'), '10.0.0.8');
      expect(extractUrlHost('not a url'), isNull);
      expect(extractUrlHost(''), isNull);
      expect(extractUrlHost(null), isNull);
    });

    test('rememberedLoginAllowsUrl gates cross-origin autofill', () {
      const bound = WarehouseRememberedLogin(
        username: 's',
        password: 'p',
        host: 'jw.example.edu.cn',
      );
      const unboundLegacy = WarehouseRememberedLogin(
        username: 's',
        password: 'p',
      );

      // No credentials at all.
      expect(rememberedLoginAllowsUrl(null, 'https://jw.example.edu.cn'),
          isFalse);
      // Legacy entries without a bound host are NOT waved through: every login
      // saved before `host` started being persisted looks like this, so
      // allowing them unconditionally left the gate open for exactly the users
      // it was written to protect.
      expect(
          rememberedLoginAllowsUrl(
              unboundLegacy, 'https://evil.example.com/login'),
          isFalse);
      // They may still autofill on the hosts the app itself navigates to.
      expect(
        rememberedLoginAllowsUrl(
          unboundLegacy,
          'https://jw.example.edu.cn/login',
          trustedHosts: const ['jw.example.edu.cn', '  ', 'mirror.example.cn'],
        ),
        isTrue,
      );
      // A trusted host that is only a substring/suffix must not pass.
      expect(
        rememberedLoginAllowsUrl(
          unboundLegacy,
          'https://jw.example.edu.cn.evil.io/login',
          trustedHosts: const ['jw.example.edu.cn'],
        ),
        isFalse,
      );
      // Subdomains of a trusted host pass: school logins commonly bounce
      // across them.
      expect(
        rememberedLoginAllowsUrl(
          unboundLegacy,
          'https://a.jw.example.edu.cn/login',
          trustedHosts: const ['jw.example.edu.cn'],
        ),
        isTrue,
      );
      // With no trusted hosts at all, an unbound login goes nowhere.
      expect(
          rememberedLoginAllowsUrl(
              unboundLegacy, 'https://jw.example.edu.cn/login'),
          isFalse);
      // Same-host pages pass.
      expect(
          rememberedLoginAllowsUrl(bound, 'https://jw.example.edu.cn/login'),
          isTrue);
      expect(
          rememberedLoginAllowsUrl(
              bound, 'https://jw.example.edu.cn:8080/login'),
          isTrue);
      // Subdomains of the *bound* host pass too.
      expect(
        rememberedLoginAllowsUrl(
            bound, 'https://a.jw.example.edu.cn/login'),
        isTrue,
      );
      // Cross-origin pages are denied — and a bound host wins over the trusted
      // list, so widening the list cannot re-open a bound credential.
      expect(
          rememberedLoginAllowsUrl(bound, 'https://evil.example.com/login'),
          isFalse);
      expect(
        rememberedLoginAllowsUrl(
          bound,
          'https://evil.example.com/login',
          trustedHosts: const ['evil.example.com'],
        ),
        isFalse,
      );
      expect(
          rememberedLoginAllowsUrl(
              bound, 'https://jw.example.edu.cn.evil.io'),
          isFalse);
      // Unknown current URL cannot prove same origin.
      expect(rememberedLoginAllowsUrl(bound, null), isFalse);
      expect(rememberedLoginAllowsUrl(bound, ''), isFalse);
    });

    test('withoutPasswords preserves host while stripping password', () {
      final bundle = const WarehouseSyncBundle(
        rememberedLogins: [
          WarehouseRememberedLoginEntry(
            adapterId: 'demo',
            login: WarehouseRememberedLogin(
              username: 'student',
              password: 'secret',
              host: 'jw.example.edu.cn',
            ),
          ),
        ],
      ).withoutPasswords();

      final entry = bundle.rememberedLogins.single;
      expect(entry.login.password, isEmpty);
      expect(entry.login.username, 'student');
      expect(entry.login.host, 'jw.example.edu.cn');
    });

    test('set/get round-trip keeps bound host through secure storage',
        () async {
      SharedPreferences.setMockInitialValues({});
      final storage = _MemoryWarehouseSecureStorage();
      final service = WarehouseImportPreferencesService(secureStorage: storage);

      await service.setRememberedLogin(
        'demo',
        const WarehouseRememberedLogin(
          username: 'student',
          password: 'secret',
          host: 'jw.example.edu.cn',
        ),
      );

      final loaded = await service.getRememberedLogin('demo');
      expect(loaded?.host, 'jw.example.edu.cn');
      expect(loaded?.username, 'student');
      expect(loaded?.password, 'secret');
    });
  });

  group('getCustomDebugRecords', () {
    // Regression: jsonDecode used to be unguarded here. This getter sits on the
    // snapshot-export path, so one bad record failed the entire WebDAV upload,
    // and the records page awaits it from initState, so a throw left its
    // loading spinner up permanently.
    test('returns empty instead of throwing on malformed JSON', () async {
      SharedPreferences.setMockInitialValues({
        'warehouse_custom_debug_records': '{not valid json',
      });
      final service = WarehouseImportPreferencesService(
        secureStorage: _MemoryWarehouseSecureStorage(),
      );

      expect(await service.getCustomDebugRecords(), isEmpty);
    });

    test('keeps valid records and skips only the malformed one', () async {
      SharedPreferences.setMockInitialValues({
        'warehouse_custom_debug_records': '''
[
  {"id":"good","name":"n","importUrl":"u","script":"s","createdAt":"2026-01-01T00:00:00.000","updatedAt":"2026-01-02T00:00:00.000"},
  {"id":123,"name":"bad","importUrl":"u","script":"s","createdAt":"2026-01-01T00:00:00.000","updatedAt":"2026-01-02T00:00:00.000"},
  "not-even-an-object"
]''',
      });
      final service = WarehouseImportPreferencesService(
        secureStorage: _MemoryWarehouseSecureStorage(),
      );

      final records = await service.getCustomDebugRecords();

      expect(records.map((r) => r.id), ['good']);
    });
  });

  group('remembered login host binding survives the wire', () {
    // Regression: WarehouseRememberedLoginEntry.toJson dropped 'host' while
    // fromJson read it back, so every cloud restore came back with host: ''.
    // rememberedLoginAllowsUrl treats an empty bound host as "allow any site",
    // which meant a credential bound to one school domain would autofill
    // anywhere after a restore. The pre-existing host tests only asserted on
    // the in-memory object, so they never saw this.
    const boundHost = 'jw.example.edu.cn';

    const bundle = WarehouseSyncBundle(
      rememberedLogins: [
        WarehouseRememberedLoginEntry(
          adapterId: 'demo',
          login: WarehouseRememberedLogin(
            username: 'student',
            password: '',
            host: boundHost,
          ),
        ),
      ],
    );

    test('toJson emits host so the wire format keeps the binding', () {
      final entries = bundle.toJson()['rememberedLogins'] as List;

      expect((entries.single as Map)['host'], boundHost);
    });

    test('still refuses a foreign host after a toJson/fromJson round trip', () {
      final wire = bundle.toJson();
      final restored = WarehouseSyncBundle.fromJson(wire);
      final login = restored.rememberedLogins.single.login;

      expect(login.host, boundHost);
      expect(
        rememberedLoginAllowsUrl(login, 'https://$boundHost/login'),
        isTrue,
      );
      expect(
        rememberedLoginAllowsUrl(login, 'https://evil.example.com/login'),
        isFalse,
      );
    });
  });

  group('自定义地址的来源标记（自动填充白名单按来源判，不按协议判）', () {
    WarehouseImportPreferencesService newService() =>
        WarehouseImportPreferencesService(
          secureStorage: _MemoryWarehouseSecureStorage(),
        );

    test('本机填写 → 记为本机，明文 http 一样能进白名单', () async {
      SharedPreferences.setMockInitialValues({});
      final service = newService();

      await service.setCustomImportUrl('a', 'http://jw.example.edu.cn/login');

      expect(await service.getCustomImportUrl('a'),
          'http://jw.example.edu.cn/login');
      expect(
        await service.getCustomImportUrlSource('a'),
        CustomImportUrlSource.userEntered,
      );
      expect(
        isTrustedCustomImportUrl(
          url: await service.getCustomImportUrl('a'),
          registeredHost: 'example.edu.cn',
          source: await service.getCustomImportUrlSource('a'),
        ),
        isTrue,
      );
    });

    test('存量地址（没有来源键）按本机填写处理', () async {
      // 升级上来的用户：这个改动之前存的地址没有来源键。按本机处理，
      // 否则他们配好的 http 地址会在升级当天丢掉自动填充。
      SharedPreferences.setMockInitialValues({
        'warehouse_custom_import_url_a': 'http://jw.example.edu.cn/login',
      });
      final service = newService();

      expect(
        await service.getCustomImportUrlSource('a'),
        CustomImportUrlSource.userEntered,
      );
    });

    test('清空地址时来源标记一起清掉', () async {
      SharedPreferences.setMockInitialValues({});
      final service = newService();
      await service.setCustomImportUrl('a', 'https://x.example.cn/');

      await service.clearCustomImportUrl('a');

      expect(await service.getCustomImportUrl('a'), isNull);
      // 重新填入时不该继承上一次的来源。
      expect(
        await service.getCustomImportUrlSource('a'),
        CustomImportUrlSource.userEntered,
      );
    });

    test('导出不把来源标记当成一条地址收走', () async {
      // 来源键也是 `warehouse_custom_import_url_` 前缀开头。若不过滤，
      // adapterId 会变成 `source_a`，快照里多出一条垃圾条目。
      SharedPreferences.setMockInitialValues({});
      final service = newService();
      await service.setCustomImportUrl('a', 'http://jw.example.edu.cn/login');

      final bundle = await service.exportSyncBundle();

      expect(bundle.customImportUrls.keys, ['a']);
      expect(bundle.customImportUrls['a'], 'http://jw.example.edu.cn/login');
    });

    test('从云快照还原：明文 http 地址不再被丢弃，但来源记为云端', () async {
      SharedPreferences.setMockInitialValues({});
      final service = newService();

      await service.importSyncBundle(
        const WarehouseSyncBundle(
          customImportUrls: {'a': 'http://jw.example.edu.cn/login'},
        ),
      );

      // 地址本身留下来（2026-10-10 之前会被丢掉，换机后导航退化成站点外壳）。
      expect(await service.getCustomImportUrl('a'), 'http://jw.example.edu.cn/login');
      // 但来源是云端：进白名单要按 https + 同域复核。
      expect(
        await service.getCustomImportUrlSource('a'),
        CustomImportUrlSource.cloud,
      );
      expect(
        isTrustedCustomImportUrl(
          url: await service.getCustomImportUrl('a'),
          registeredHost: 'example.edu.cn',
          source: await service.getCustomImportUrlSource('a'),
        ),
        isFalse,
        reason: '云快照下发的明文地址不进自动填充白名单',
      );
    });

    test('从云快照还原：javascript: / 无主机 仍然被挡掉', () async {
      SharedPreferences.setMockInitialValues({});
      final service = newService();

      await service.importSyncBundle(
        const WarehouseSyncBundle(
          customImportUrls: {
            'a': 'javascript:alert(1)',
            'b': 'not a url',
            'c': 'ftp://files.example.cn/x',
          },
        ),
      );

      expect(await service.getCustomImportUrl('a'), isNull);
      expect(await service.getCustomImportUrl('b'), isNull);
      expect(await service.getCustomImportUrl('c'), isNull);
    });

    test('换机往返：本机填的 http 地址还原后仍是 http，只是不再自动填密码', () async {
      // 完整往返：A 机本机填写 → 导出 → B 机还原。
      SharedPreferences.setMockInitialValues({});
      final deviceA = newService();
      await deviceA.setCustomImportUrl('a', 'http://jw.example.edu.cn/login');

      final bundle = await deviceA.exportSyncBundle();
      // 快照上行走一趟（云备份会剥密码，地址字段不动）。
      final overTheWire = WarehouseSyncBundle.fromJson(bundle.toJson());

      SharedPreferences.setMockInitialValues({});
      final deviceB = newService();
      await deviceB.importSyncBundle(overTheWire);

      // B 机仍导航到真正的课表页，而不是站点外壳。
      expect(await deviceB.getCustomImportUrl('a'), 'http://jw.example.edu.cn/login');
      // B 机按云端来源对待：不自动填密码，但地址在、页面能开。
      expect(await deviceB.getCustomImportUrlSource('a'),
          CustomImportUrlSource.cloud);
    });
  });

  group('云端备份不得把本地真密码配到备份指定的域名上', () {
    const localHost = 'jw.example.edu.cn';
    const local = WarehouseRememberedLogin(
      username: 'student',
      password: 'real-password',
      host: localHost,
    );

    test('保留本地密码时必须连本地 host 一起保留', () {
      // 攻击者构造的备份：用户名对上、密码留空、host 指向钓鱼站。
      const crafted = WarehouseRememberedLogin(
        username: 'student',
        password: '',
        host: 'evil.example.com',
      );
      final resolved = resolveRememberedLoginForImport(
        incoming: crafted,
        localLogin: local,
      );

      expect(resolved.password, 'real-password');
      // 关键断言：host 不能跟着云端走。
      expect(resolved.host, localHost);
      // 落到门禁上：钓鱼站被拒、真教务站放行。
      expect(
        rememberedLoginAllowsUrl(resolved, 'https://evil.example.com/login'),
        isFalse,
      );
      expect(
        rememberedLoginAllowsUrl(resolved, 'https://$localHost/login'),
        isTrue,
      );
    });

    test('云端带非空密码时，整对一起采用（云端自洽）', () {
      const remote = WarehouseRememberedLogin(
        username: 'student',
        password: 'cloud-password',
        host: 'jw2.example.edu.cn',
      );
      final resolved = resolveRememberedLoginForImport(
        incoming: remote,
        localLogin: local,
      );
      expect(resolved.password, 'cloud-password');
      expect(resolved.host, 'jw2.example.edu.cn');
    });

    test('本地无记录时不保留密码，host 仍按云端来（无密码可泄露）', () {
      const crafted = WarehouseRememberedLogin(
        username: 'student',
        password: '',
        host: 'evil.example.com',
      );
      final resolved = resolveRememberedLoginForImport(
        incoming: crafted,
      );
      expect(resolved.password, '');
      expect(resolved.host, 'evil.example.com');
    });

    test('用户名不一致时密码不保留，host 也不保留', () {
      const other = WarehouseRememberedLogin(
        username: 'someone-else',
        password: '',
        host: 'evil.example.com',
      );
      final resolved = resolveRememberedLoginForImport(
        incoming: other,
        localLogin: local,
      );
      expect(resolved.password, '');
      expect(resolved.host, 'evil.example.com');
    });
  });
}
