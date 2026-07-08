import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/services/app_log_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    AppLogService.instance.resetForTesting();
  });

  test('initialize tolerates corrupted timetable settings json', () async {
    SharedPreferences.setMockInitialValues({
      'flutter.timetable_settings': '{bad-json',
    });

    await expectLater(AppLogService.instance.initialize(), completes);
  });
}
