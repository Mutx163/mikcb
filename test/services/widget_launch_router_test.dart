import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/services/miui_live_activities_service.dart';
import 'package:university_timetable/services/partner_timetable_service.dart';
import 'package:university_timetable/services/storage_service.dart';
import 'package:university_timetable/services/widget_launch_router.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.mutx163.qingyu/home_widget');
  const liveChannel = MethodChannel('com.mutx163.qingyu/miui_live');
  const examChannel = MethodChannel('com.mutx163.qingyu/exam_reminder');
  int? pendingWidgetId;
  final bindings = <int, String?>{};
  int popToRootCalls = 0;

  Future<Object?>? fakeHandler(MethodCall call) async {
    switch (call.method) {
      case 'getPendingWidgetLaunch':
        return pendingWidgetId;
      case 'getWidgetBinding':
        return bindings[(call.arguments as Map)['appWidgetId'] as int];
    }
    throw MissingPluginException();
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    StorageService().resetForTesting();
    pendingWidgetId = null;
    bindings.clear();
    popToRootCalls = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, fakeHandler);
    // 分流成功路径会触发 switchProfile 的岛/考试提醒副作用，统一静音。
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(liveChannel, (_) async => null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(examChannel, (_) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(liveChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(examChannel, null);
  });

  Future<TimetableProvider> createProvider() async {
    final provider = TimetableProvider(
      autoInitialize: false,
      enableLiveActivitySync: false,
      liveActivitiesService: TestMiuiLiveActivitiesService(),
    );
    await provider.initialize();
    return provider;
  }

  test('无 pending 点击 → none（普通打开）', () async {
    final provider = await createProvider();
    final outcome = await WidgetLaunchRouter.handleWith(provider: provider);
    expect(outcome, WidgetLaunchOutcome.none);
    expect(provider.activeProfileId, isNotNull);
    expect(popToRootCalls, 0);
  });

  test('绑定的普通课表 → switchProfile 直达', () async {
    final provider = await createProvider();
    final other = await provider.createProfile(name: '秋季课表');

    pendingWidgetId = 33;
    bindings[33] = other.id;
    final outcome = await WidgetLaunchRouter.handleWith(provider: provider);

    expect(outcome, WidgetLaunchOutcome.switchedProfile);
    expect(provider.activeProfileId, other.id);
  });

  test('绑定 TA 课表但已解绑 → bindingMissing，不切课表不弹覆盖层', () async {
    final provider = await createProvider();
    final before = provider.activeProfileId;

    pendingWidgetId = 34;
    bindings[34] = PartnerTimetableService.partnerProfileId;
    final outcome = await WidgetLaunchRouter.handleWith(provider: provider);

    expect(outcome, WidgetLaunchOutcome.bindingMissing);
    expect(provider.activeProfileId, before);
    expect(popToRootCalls, 0);
  });

  test('未登记卡片 → none，保持当前课表', () async {
    final provider = await createProvider();
    final before = provider.activeProfileId;

    pendingWidgetId = 35;
    bindings[35] = null;
    final outcome = await WidgetLaunchRouter.handleWith(provider: provider);

    expect(outcome, WidgetLaunchOutcome.none);
    expect(provider.activeProfileId, before);
  });

  test('绑定的课表已被删除 → switchProfile 守卫静默不动，仍算 switched', () async {
    final provider = await createProvider();
    // createProfile 会把活动课表切到新建的表，先捕获删除前的活动课表。
    final before = provider.activeProfileId;
    final other = await provider.createProfile(name: '被删课表');

    pendingWidgetId = 36;
    bindings[36] = other.id;
    await provider.deleteProfile(other.id);
    final outcome = await WidgetLaunchRouter.handleWith(provider: provider);

    expect(outcome, WidgetLaunchOutcome.switchedProfile);
    expect(provider.activeProfileId, before);
  });

  test('绑定 TA 课表 → partnerOverlay：不切课表、持久化开启覆盖层、回根回调', () async {
    final provider = await createProvider();
    final before = provider.activeProfileId;
    expect(provider.settings.coupleTimetableOverlayEnabled, isFalse);

    final backup = provider.dataTransferService.buildBackupJson(
      profileName: 'TA的课表',
      courses: [
        Course(
          id: 'c1',
          name: '高数',
          teacher: '张老师',
          location: 'A101',
          dayOfWeek: 1,
          startSection: 1,
          endSection: 2,
          startTime: '08:00',
          endTime: '09:40',
        ),
      ],
      settings: TimetableSettings.defaults(),
      currentWeek: 1,
    );
    await provider.importPartnerTimetable(backup);

    pendingWidgetId = 37;
    bindings[37] = PartnerTimetableService.partnerProfileId;
    final outcome = await WidgetLaunchRouter.handleWith(
      provider: provider,
      onRequestPopToRoot: () => popToRootCalls++,
    );

    expect(outcome, WidgetLaunchOutcome.partnerOverlay);
    // 不真的切到 TA 课表。
    expect(provider.activeProfileId, before);
    expect(provider.settings.coupleTimetableOverlayEnabled, isTrue);
    expect(popToRootCalls, 1);
    expect(WidgetLaunchRouter.coupleOverlayRequestTick.value, greaterThan(0));
  });
}
