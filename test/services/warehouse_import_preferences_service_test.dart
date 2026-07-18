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
        resolveWarehouseImportUrl(customImportUrl: null, defaultUrl: ' '),
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
          localLogin: null,
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
}
