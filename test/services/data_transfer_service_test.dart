import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/services/data_transfer_service.dart';

void main() {
  test('backup json preserves profile name', () {
    final service = DataTransferService();
    final json = service.buildBackupJson(
      profileName: '大二下',
      courses: const [],
      settings: TimetableSettings.defaults(),
      currentWeek: 3,
    );

    final backup = service.parseBackupJson(json);

    expect(backup.profileName, '大二下');
    expect(backup.currentWeek, 3);
  });
}
