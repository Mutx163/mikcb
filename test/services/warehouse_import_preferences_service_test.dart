import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/services/warehouse_import_preferences_service.dart';

class _FakeSecureStorage extends WarehouseSecureStorage {
  final Map<String, String> values = {};
  final List<String> deletedKeys = [];

  @override
  Future<String?> read({required String key}) async => values[key];

  @override
  Future<void> write({required String key, required String value}) async {
    values[key] = value;
  }

  @override
  Future<void> delete({required String key}) async {
    deletedKeys.add(key);
    values.remove(key);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('stores remembered login in secure storage only', () async {
    final secureStorage = _FakeSecureStorage();
    final service = WarehouseImportPreferencesService(
      secureStorage: secureStorage,
    );

    await service.setRememberedLogin(
      'adapter-1',
      const WarehouseRememberedLogin(username: 'alice', password: 'secret'),
    );

    final prefs = await SharedPreferences.getInstance();
    final restored = await service.getRememberedLogin('adapter-1');

    expect(restored?.username, 'alice');
    expect(restored?.password, 'secret');
    expect(prefs.getString('warehouse_remembered_login_adapter-1'), isNull);
    expect(
      secureStorage.values['warehouse_secure_remembered_login_adapter-1'],
      contains('secret'),
    );
  });

  test('migrates legacy remembered login out of shared preferences', () async {
    SharedPreferences.setMockInitialValues({
      'warehouse_remembered_login_adapter-1':
          '{"username":"alice","password":"secret"}',
    });
    final secureStorage = _FakeSecureStorage();
    final service = WarehouseImportPreferencesService(
      secureStorage: secureStorage,
    );

    final restored = await service.getRememberedLogin('adapter-1');
    final prefs = await SharedPreferences.getInstance();

    expect(restored?.username, 'alice');
    expect(restored?.password, 'secret');
    expect(prefs.getString('warehouse_remembered_login_adapter-1'), isNull);
    expect(
      secureStorage.values['warehouse_secure_remembered_login_adapter-1'],
      contains('secret'),
    );
  });

  test('clears secure and legacy remembered login values', () async {
    SharedPreferences.setMockInitialValues({
      'warehouse_remembered_login_adapter-1':
          '{"username":"alice","password":"secret"}',
    });
    final secureStorage = _FakeSecureStorage()
      ..values['warehouse_secure_remembered_login_adapter-1'] =
          '{"username":"alice","password":"secret"}';
    final service = WarehouseImportPreferencesService(
      secureStorage: secureStorage,
    );

    await service.clearRememberedLogin('adapter-1');
    final prefs = await SharedPreferences.getInstance();

    expect(prefs.getString('warehouse_remembered_login_adapter-1'), isNull);
    expect(
      secureStorage.values['warehouse_secure_remembered_login_adapter-1'],
      isNull,
    );
  });
}
