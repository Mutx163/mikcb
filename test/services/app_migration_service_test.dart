import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/services/app_migration_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const migrationChannel = MethodChannel('com.mutx163.qingyu/migration');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(migrationChannel, null);
  });

  test(
    'migration service degrades gracefully when platform channel fails',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            migrationChannel,
            (call) async =>
                throw MissingPluginException('missing migration plugin'),
          );

      final service = AppMigrationService();

      expect(await service.findInstalledLegacyPackage(), isNull);
      expect(await service.openPackage('com.example.legacy'), isFalse);
    },
  );
}
