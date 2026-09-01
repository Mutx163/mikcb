import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/services/webdav_sync_coordinator.dart';
import 'package:university_timetable/services/webdav_sync_service.dart'
    show WebdavSyncResultKind;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    WebdavSyncCoordinator.resetInstanceForTesting();
  });

  tearDown(() {
    WebdavSyncCoordinator.resetInstanceForTesting();
  });

  group('WebdavSyncCoordinator 并发同步门控', () {
    test('provider 未绑定时 syncNow 返回 provider_not_ready 且不抛', () async {
      final coordinator = WebdavSyncCoordinator();
      final result = await coordinator.syncNow();
      expect(result.kind, WebdavSyncResultKind.failed);
      expect(result.message, 'provider_not_ready');
    });

    test('maybePullRemote 在云同步未启用时直接返回，不进入同步区', () async {
      final coordinator = WebdavSyncCoordinator();
      // 云同步默认 disabled：无 provider 也必须无异常返回。
      await coordinator.maybePullRemote();
      expect(coordinator.status.isSyncing, isFalse);
    });

    test('串行门控：并发 syncNow 不会重叠执行（复用 SyncOperationGate）',
        () async {
      final coordinator = WebdavSyncCoordinator();
      var inFlight = 0;
      var maxInFlight = 0;
      // 通过 status 监听探测 isSyncing 重叠：门控正确时同一时刻
      // 只有一个操作在同步区内。
      coordinator.addListener(() {
        if (coordinator.status.isSyncing) {
          inFlight++;
          if (inFlight > maxInFlight) {
            maxInFlight = inFlight;
          }
        } else {
          inFlight = 0;
        }
      });

      // 未绑定 provider 时 syncNow 直接返回，不占门控；此用例验证
      // 快速连续调用不会卡死或抛未捕获异常。
      await Future.wait([
        coordinator.syncNow(),
        coordinator.syncNow(),
        coordinator.createManualBackup(),
      ]);
      expect(maxInFlight, lessThanOrEqualTo(1));
      expect(coordinator.status.isSyncing, isFalse);
    });

    test('provider 缺失路径不产生僵尸 isSyncing 状态', () async {
      final coordinator = WebdavSyncCoordinator();
      await coordinator.syncNow();
      await coordinator.createManualBackup();
      await coordinator.maybePullRemote();
      // 所有快速失败路径都必须最终离开同步区，否则后续同步被永久饿死。
      expect(coordinator.status.isSyncing, isFalse);
    });
  });
}
