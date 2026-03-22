import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/time_scheme.dart';
import 'package:university_timetable/models/timetable_profile.dart';
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

  test('full backup json preserves profiles and time schemes', () {
    final service = DataTransferService();
    final json = service.buildFullBackupJson(
      profiles: [
        TimetableProfile(
          id: 'profile-1',
          name: '大二下',
          courses: const [],
          settings: TimetableSettings.defaults(),
          currentWeek: 5,
          createdAt: DateTime(2026, 3, 22, 8),
          lastUsedAt: DateTime(2026, 3, 22, 9),
        ),
      ],
      activeProfileId: 'profile-1',
      timeSchemes: [
        TimeScheme(
          id: 'scheme-1',
          name: '本校作息',
          sections: const [
            SectionTime(startTime: '08:00', endTime: '08:45'),
          ],
          createdAt: DateTime(2026, 3, 22, 8),
          updatedAt: DateTime(2026, 3, 22, 9),
        ),
      ],
    );

    final backup = service.parseFullBackupJson(json);

    expect(backup.activeProfileId, 'profile-1');
    expect(backup.profiles.single.name, '大二下');
    expect(backup.timeSchemes.single.name, '本校作息');
  });
}
