import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/services/couple_webdav_config.dart';

void main() {
  group('CoupleWebdavConfig', () {
    test('normalizes remote folder and builds dual-slot paths', () {
      const config = CoupleWebdavConfig(remoteFolder: 'Apps/qingyu-couple');
      expect(config.normalizedRemoteFolder, '/Apps/qingyu-couple/');
      expect(
        config.mineTimetableRemotePath,
        '/Apps/qingyu-couple/couple-slot-1.mikcb',
      );
      expect(
        config.partnerTimetableRemotePath,
        '/Apps/qingyu-couple/couple-slot-2.mikcb',
      );
      expect(
        config.legacyPartnerTimetableRemotePath,
        '/Apps/qingyu-couple/partner-timetable.mikcb',
      );
    });

    test('slot 2 swaps upload and pull paths', () {
      const config = CoupleWebdavConfig(mySlot: 2);
      expect(config.mineTimetableRemotePath, endsWith('couple-slot-2.mikcb'));
      expect(
        config.partnerTimetableRemotePath,
        endsWith('couple-slot-1.mikcb'),
      );
    });

    test('round-trips json', () {
      final config = CoupleWebdavConfig(
        username: 'user@example.com',
        mySlot: 2,
        lastPulledAt: DateTime.utc(2026, 7, 8, 4, 30),
        lastRemoteContentHash: 'abc123',
      );
      final restored = CoupleWebdavConfig.fromJson(config.toJson());
      expect(restored.username, config.username);
      expect(restored.mySlot, 2);
      expect(restored.lastPulledAt, config.lastPulledAt);
      expect(restored.lastRemoteContentHash, config.lastRemoteContentHash);
      expect(
        restored.partnerTimetableRemotePath,
        config.partnerTimetableRemotePath,
      );
    });
  });
}
