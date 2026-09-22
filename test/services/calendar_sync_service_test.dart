import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/services/calendar_sync_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.mutx163.qingyu/calendar_sync');
  final service = CalendarSyncService();

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('权限问询', () {
    test('checkPermission 原样回传原生结果', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async => true);
      expect(await service.isPermissionGranted(), isTrue);

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async => false);
      expect(await service.isPermissionGranted(), isFalse);
    });

    test('原生异常与未实现平台都按未授权处理，不抛出', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            channel,
            (call) async => throw PlatformException(code: 'boom'),
          );
      expect(await service.isPermissionGranted(), isFalse);

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            channel,
            (call) async => throw MissingPluginException(),
          );
      expect(await service.isPermissionGranted(), isFalse);
      expect(await service.requestPermission(), isFalse);
    });

    test('连点两次请求权限：两个 Future 都必须落结果，不许永挂', () async {
      // 回归钉：原生侧旧版只有一个 pendingPermissionResult 槽位，第二次会
      // 覆盖第一次，第一次的 Future 永挂。现在原生排队扇出，Dart 侧只要
      // 两次 invoke 都能 await 到布尔值即可。
      var calls = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        calls++;
        return calls == 1;
      });

      final first = service.requestPermission();
      final second = service.requestPermission();
      expect(await first, isTrue);
      expect(await second, isFalse);
      expect(calls, 2);
    });
  });

  group('sync 载荷', () {
    test('按 calendarName + 事件列表打包，epoch 毫秒来自本地时间', () async {
      Object? capturedArguments;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'sync');
        capturedArguments = call.arguments;
        return 3;
      });

      final outcome = await service.sync(
        calendarName: '轻屿课表·主课表',
        events: [
          CalendarSyncEvent(
            start: DateTime(2026, 3, 2, 8, 20),
            end: DateTime(2026, 3, 2, 10),
            title: '高等数学',
            location: '教一 101',
            description: 'Teacher: 张老师',
          ),
          CalendarSyncEvent(start: DateTime(2026), end: DateTime(2026), title: '空字段事件'),
        ],
      );

      expect(outcome.isSuccess, isTrue);
      expect(outcome.syncedCount, 3);
      final payload = capturedArguments as Map<Object?, Object?>;
      expect(payload['calendarName'], '轻屿课表·主课表');
      final events = payload['events'] as List<Object?>;
      expect(events, hasLength(2));
      expect(
        (events.first as Map)['startMs'],
        DateTime(2026, 3, 2, 8, 20).millisecondsSinceEpoch,
      );
      expect((events.first as Map)['title'], '高等数学');
      expect((events.first as Map)['location'], '教一 101');
      // 空字段按 null 原样传递，原生侧落库为空。
      expect((events.last as Map)['location'], isNull);
    });

    test('原生错误收敛为失败结果', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            channel,
            (call) async => throw PlatformException(
              code: 'SYNC_FAILED',
              message: 'provider dead',
            ),
          );

      final outcome = await service.sync(
        calendarName: 'c',
        events: const [],
      );

      expect(outcome.isSuccess, isFalse);
      expect(outcome.syncedCount, 0);
      expect(outcome.error, 'provider dead');
    });
  });

  group('deleteSynced 三态', () {
    test('原生 true/false/异常分别映射 deleted/notSynced/failed', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'deleteCalendar');
        return true;
      });
      expect(
        await service.deleteSynced(),
        CalendarDeleteResult.deleted,
      );

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async => false);
      expect(
        await service.deleteSynced(),
        CalendarDeleteResult.notSynced,
      );

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            channel,
            (call) async => throw PlatformException(code: 'PERMISSION_DENIED'),
          );
      expect(
        await service.deleteSynced(),
        CalendarDeleteResult.failed,
      );
    });
  });
}
