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
}
