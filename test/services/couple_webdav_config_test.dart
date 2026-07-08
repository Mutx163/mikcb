import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/services/couple_webdav_config.dart';

void main() {
  group('CoupleWebdavConfig', () {
    test('normalizes remote folder and builds partner path', () {
      const config = CoupleWebdavConfig(remoteFolder: 'Apps/qingyu-couple');
      expect(config.normalizedRemoteFolder, '/Apps/qingyu-couple/');
      expect(
        config.partnerTimetableRemotePath,
        '/Apps/qingyu-couple/partner-timetable.mikcb',
      );
    });

    test('round-trips json', () {
      final config = CoupleWebdavConfig(
        username: 'user@example.com',
        lastPulledAt: DateTime.utc(2026, 7, 8, 4, 30),
        lastRemoteContentHash: 'abc123',
      );
      final restored = CoupleWebdavConfig.fromJson(config.toJson());
      expect(restored.username, config.username);
      expect(restored.lastPulledAt, config.lastPulledAt);
      expect(restored.lastRemoteContentHash, config.lastRemoteContentHash);
      expect(restored.partnerTimetableRemotePath, config.partnerTimetableRemotePath);
    });
  });
}
