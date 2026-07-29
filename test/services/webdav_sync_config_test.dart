import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/services/webdav_sync_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WebdavSyncConfig path helpers', () {
    test('normalizedRemoteFolder adds leading and trailing slashes', () {
      const bare = WebdavSyncConfig(remoteFolder: 'Apps/qingyu-sync');
      expect(bare.normalizedRemoteFolder, '/Apps/qingyu-sync/');

      const empty = WebdavSyncConfig(remoteFolder: '   ');
      expect(
        empty.normalizedRemoteFolder,
        WebdavSyncConfig.defaultRemoteFolder,
      );

      const already = WebdavSyncConfig(remoteFolder: '/Apps/qingyu-sync/');
      expect(already.normalizedRemoteFolder, '/Apps/qingyu-sync/');
    });

    test('builds snapshot meta and history paths', () {
      const config = WebdavSyncConfig(remoteFolder: 'Apps/qingyu-sync');
      expect(config.snapshotRemotePath, '/Apps/qingyu-sync/snapshot.mikcb');
      expect(config.metaRemotePath, '/Apps/qingyu-sync/snapshot.meta.json');
      expect(config.historyRemoteFolder, '/Apps/qingyu-sync/history/');
      expect(
        config.historyIndexRemotePath,
        '/Apps/qingyu-sync/history/index.json',
      );
    });

    test('sanitizeHistoryBackupFileName keeps basename only', () {
      expect(
        WebdavSyncConfig.sanitizeHistoryBackupFileName('nested/../safe.mikcb'),
        'safe.mikcb',
      );
      expect(
        WebdavSyncConfig.sanitizeHistoryBackupFileName(r'folder\file.mikcb'),
        'file.mikcb',
      );
    });

    test('sanitizeHistoryBackupFileName rejects empty and traversal', () {
      expect(
        () => WebdavSyncConfig.sanitizeHistoryBackupFileName(''),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => WebdavSyncConfig.sanitizeHistoryBackupFileName('..'),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => WebdavSyncConfig.sanitizeHistoryBackupFileName('.'),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('WebdavSyncConfig json and copyWith', () {
    test('round-trips through toJson/fromJson', () {
      final original = WebdavSyncConfig(
        enabled: true,
        provider: WebdavSyncProvider.custom,
        syncMode: WebdavSyncMode.manual,
        baseUrl: 'https://dav.example.com/dav/',
        remoteFolder: '/Apps/custom/',
        username: 'user@example.com',
        lastSyncedAt: DateTime.utc(2026, 7, 1, 12),
        lastAppliedRemoteHash: 'remote-hash',
        lastUploadedLocalHash: 'local-hash',
        maxBackupCount: 9,
        maxBackupAgeDays: 14,
        manualBackupProtected: false,
      );

      final restored = WebdavSyncConfig.fromJson(original.toJson());

      expect(restored.enabled, isTrue);
      expect(restored.provider, WebdavSyncProvider.custom);
      expect(restored.syncMode, WebdavSyncMode.manual);
      expect(restored.baseUrl, original.baseUrl);
      expect(restored.remoteFolder, original.remoteFolder);
      expect(restored.username, original.username);
      expect(restored.lastSyncedAt, original.lastSyncedAt);
      expect(restored.lastAppliedRemoteHash, 'remote-hash');
      expect(restored.lastUploadedLocalHash, 'local-hash');
      expect(restored.maxBackupCount, 9);
      expect(restored.maxBackupAgeDays, 14);
      expect(restored.manualBackupProtected, isFalse);
    });

    test('fromJson uses defaults for unknown enums and missing fields', () {
      final restored = WebdavSyncConfig.fromJson(const {
        'provider': 'not-a-provider',
        'syncMode': 'not-a-mode',
      });

      expect(restored.enabled, isFalse);
      expect(restored.provider, WebdavSyncProvider.jianguoyun);
      expect(restored.syncMode, WebdavSyncMode.auto);
      expect(restored.baseUrl, WebdavSyncConfig.defaultJianguoyunBaseUrl);
      expect(restored.remoteFolder, WebdavSyncConfig.defaultRemoteFolder);
      expect(restored.maxBackupCount, WebdavSyncConfig.defaultMaxBackupCount);
      expect(
        restored.maxBackupAgeDays,
        WebdavSyncConfig.defaultMaxBackupAgeDays,
      );
      expect(restored.manualBackupProtected, isTrue);
    });

    test('copyWith can clear nullable sync markers', () {
      final original = WebdavSyncConfig(
        lastSyncedAt: DateTime.utc(2026, 7, 1),
        lastAppliedRemoteHash: 'a',
        lastUploadedLocalHash: 'b',
      );

      final cleared = original.copyWith(
        clearLastSyncedAt: true,
        clearLastAppliedRemoteHash: true,
        clearLastUploadedLocalHash: true,
        enabled: true,
      );

      expect(cleared.enabled, isTrue);
      expect(cleared.lastSyncedAt, isNull);
      expect(cleared.lastAppliedRemoteHash, isNull);
      expect(cleared.lastUploadedLocalHash, isNull);
    });
  });

  group('WebdavSyncConfigStore', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('load returns defaults when unset', () async {
      const store = WebdavSyncConfigStore();
      final config = await store.load();
      expect(config.enabled, isFalse);
      expect(config.provider, WebdavSyncProvider.jianguoyun);
    });

    test('save and load round-trip', () async {
      const store = WebdavSyncConfigStore();
      final original = WebdavSyncConfig(
        enabled: true,
        username: 'demo',
        provider: WebdavSyncProvider.custom,
        baseUrl: 'https://example.com/dav/',
      );

      await store.save(original);
      final restored = await store.load();

      expect(restored.enabled, isTrue);
      expect(restored.username, 'demo');
      expect(restored.provider, WebdavSyncProvider.custom);
      expect(restored.baseUrl, 'https://example.com/dav/');
    });

    test('load returns defaults on corrupt json', () async {
      SharedPreferences.setMockInitialValues({
        WebdavSyncConfig.prefsKey: '{not-json',
      });
      const store = WebdavSyncConfigStore();
      final config = await store.load();
      expect(config.enabled, isFalse);
      expect(config.username, '');
    });
  });
}
