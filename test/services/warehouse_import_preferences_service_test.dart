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
      // Legacy entries without bound host keep legacy behavior.
      expect(
          rememberedLoginAllowsUrl(
              unboundLegacy, 'https://evil.example.com/login'),
          isTrue);
      // Same-host pages pass.
      expect(
          rememberedLoginAllowsUrl(bound, 'https://jw.example.edu.cn/login'),
          isTrue);
      expect(
          rememberedLoginAllowsUrl(
              bound, 'https://jw.example.edu.cn:8080/login'),
          isTrue);
      // Cross-origin pages are denied.
      expect(
          rememberedLoginAllowsUrl(bound, 'https://evil.example.com/login'),
          isFalse);
      expect(
          rememberedLoginAllowsUrl(bound, 'https://jw.example.edu.cn.evil.io'),
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
