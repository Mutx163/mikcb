import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/services/home_widget_binding_service.dart';
import 'package:university_timetable/services/home_widget_snapshot_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.mutx163.qingyu/home_widget');
  final handlerRegistry = <String, Object? Function(MethodCall call)>{};

  Future<Object?>? fakeHandler(MethodCall call) async {
    final handler = handlerRegistry[call.method];
    if (handler == null) {
      throw MissingPluginException();
    }
    return handler(call);
  }

  setUp(() {
    handlerRegistry.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, fakeHandler);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  HomeWidgetSnapshot minimalSnapshot({String profileId = 'profile-b'}) {
    return HomeWidgetSnapshot(
      profileId: profileId,
      profileName: 'TA的课表',
      currentWeek: 1,
      dayOfWeek: 1,
      generatedAtMillis: 1700000000000,
      state: HomeWidgetSnapshotState.noCourse,
      backgroundStyle: WidgetBackgroundStyle.solid,
      showLocation: true,
      showCountdown: false,
      countdownTextStyle: 'smart',
      hideCompletedCourses: false,
      heightAdjustment: -11,
      cornerRadius: 22,
      totalTodayCourseCount: 0,
      todayCourses: const [],
      visibleTodayCourses: const [],
    );
  }

  group('HomeWidgetBindingService', () {
    test('listTodayWidgetInstances 解析原生返回的卡片实例与绑定', () async {
      handlerRegistry['listTodayWidgetInstances'] = (_) => [
        {
          'appWidgetId': 11,
          'widgetType': 'compact',
          'boundProfileId': 'profile-a',
        },
        {'appWidgetId': 12, 'widgetType': 'today_wide', 'boundProfileId': null},
      ];
      final service = HomeWidgetBindingService();
      final instances = await service.listTodayWidgetInstances();

      expect(instances, hasLength(2));
      expect(instances[0].appWidgetId, 11);
      expect(instances[0].widgetType, HomeWidgetType.compact);
      expect(instances[0].boundProfileId, 'profile-a');
      expect(instances[1].widgetType, HomeWidgetType.todayWide);
      expect(instances[1].boundProfileId, isNull);
    });

    test('listTodayWidgetInstances 通道不可用时返回空列表不抛出', () async {
      handlerRegistry.clear(); // 触发 MissingPluginException
      final service = HomeWidgetBindingService();
      final instances = await service.listTodayWidgetInstances();
      expect(instances, isEmpty);
    });

    test('setWidgetBinding/getWidgetBinding 往返；解除绑定传 null', () async {
      final stored = <int, String?>{};
      handlerRegistry['setWidgetBinding'] = (call) {
        stored[(call.arguments as Map)['appWidgetId'] as int] =
            (call.arguments as Map)['profileId'] as String?;
        return true;
      };
      handlerRegistry['getWidgetBinding'] =
          (call) => stored[(call.arguments as Map)['appWidgetId'] as int];

      final service = HomeWidgetBindingService();
      expect(await service.setWidgetBinding(7, 'profile-a'), isTrue);
      expect(await service.getWidgetBinding(7), 'profile-a');

      // 解除绑定：原生侧会 remove 对应 key，get 回 null。
      expect(await service.setWidgetBinding(7, null), isTrue);
      expect(await service.getWidgetBinding(7), isNull);
    });

    test('consumePendingWidgetLaunch 返回原生 pending 的 appWidgetId', () async {
      handlerRegistry['getPendingWidgetLaunch'] = (_) => 42;
      final service = HomeWidgetBindingService();
      expect(await service.consumePendingWidgetLaunch(), 42);

      handlerRegistry['getPendingWidgetLaunch'] = (_) => null;
      expect(await service.consumePendingWidgetLaunch(), isNull);
    });

    test('syncWidgetSnapshot 透传快照 JSON；失败不抛出', () async {
      final payloads = <Map>[];
      handlerRegistry['syncWidgetSnapshot'] = (call) {
        payloads.add(call.arguments as Map);
        return true;
      };
      final service = HomeWidgetBindingService();
      final ok = await service.syncWidgetSnapshot(9, minimalSnapshot());
      expect(ok, isTrue);
      expect(payloads.single['appWidgetId'], 9);
      final snapshot = payloads.single['snapshot'] as Map;
      expect(snapshot['profileId'], 'profile-b');

      handlerRegistry['syncWidgetSnapshot'] = (_) => throw PlatformException(
        code: 'INVALID_ARGUMENTS',
        message: 'missing',
      );
      expect(await service.syncWidgetSnapshot(9, minimalSnapshot()), isFalse);
    });
  });
}
