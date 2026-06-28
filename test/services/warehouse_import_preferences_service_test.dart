import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/services/warehouse_import_preferences_service.dart';

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
        resolveWarehouseImportUrl(
          customImportUrl: null,
          defaultUrl: ' ',
        ),
        isNull,
      );
    });
  });
}
