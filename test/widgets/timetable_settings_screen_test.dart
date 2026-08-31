import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/timetable_profile.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/screens/timetable_settings_screen.dart';
import 'package:university_timetable/services/live_testing_trigger.dart';
import 'package:university_timetable/services/storage_service.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';
import '../helpers_test_app.dart';

Future<void> _pumpScreen(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

Finder _scrollableUnder(Finder host) {
  return find.descendant(of: host, matching: find.byType(Scrollable)).first;
}

void _seedInitializedPrefs() {
  final now = DateTime(2026, 4, 12);
  final settings = TimetableSettings.defaults();
  final profile = TimetableProfile(
    id: 'profile-1',
    name: '默认课表',
    courses: const [],
    settings: settings,
    currentWeek: 1,
    createdAt: now,
    lastUsedAt: now,
  );
  SharedPreferences.setMockInitialValues({
    'did_migrate_app_logs_default': true,
    'did_migrate_live_hide_prefix_default': true,
    'timetable_profiles': jsonEncode([profile.toJson()]),
    'active_timetable_profile_id': profile.id,
    'time_schemes': '[]',
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const homeWidgetChannel = MethodChannel('com.mutx163.qingyu/home_widget');
  const analyticsChannel = MethodChannel('com.mutx163.qingyu/umeng_analytics');
  const liveChannel = MethodChannel('com.mutx163.qingyu/miui_live');

  setUp(() {
    StorageService().resetForTesting();
    _seedInitializedPrefs();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(homeWidgetChannel, (call) async => null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(analyticsChannel, (call) async => null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(liveChannel, (call) async {
          switch (call.method) {
            case 'initialize':
              return null;
            case 'getLiveUpdateDebugStatus':
              return {
                'summary': {
                  'serviceRunning': false,
                  'isActuallyPromotable': false,
                  'statusText': '读取成功',
                  'notIslandReason': '',
                },
                'recentDiagnostics': <String, dynamic>{},
              };
            default:
              return null;
          }
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(homeWidgetChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(analyticsChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(liveChannel, null);
  });

  testWidgets('live testing screen keeps one-second auto refresh cadence', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final provider = await createInitializedTestProvider(tester);

    // 超级岛设置页的「自检」重复入口行已删除（诊断页入口保留）；
    // 直接泵起 _LiveTestingSettingsScreen 子页（公开工厂
    // [createLiveTestingSettingsScreen]），验证一秒自刷新不变。
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: TestApp(home: createLiveTestingSettingsScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final diagnosticsList = find.byType(HyperosListView).last;
    await tester.scrollUntilVisible(
      find.textContaining('自动刷新'),
      200,
      scrollable: _scrollableUnder(diagnosticsList),
    );
    expect(find.textContaining('每 1 秒自动拉取一次诊断状态'), findsOneWidget);
    expect(find.textContaining('上次刷新：'), findsOneWidget);
  });

  testWidgets('before class reminder popup includes 30 to 60 minute options', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final provider = await createInitializedTestProvider(tester);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const TestApp(home: TimetableSettingsScreen()),
      ),
    );
    await _pumpScreen(tester);

    final homeList = find.byType(HyperosListView).first;
    await tester.scrollUntilVisible(
      find.text('超级岛与通知'),
      200,
      scrollable: _scrollableUnder(homeList),
    );
    await tester.tap(find.text('超级岛与通知'));
    await tester.pumpAndSettle();

    // Verify we're on the live settings screen.
    expect(find.text('提醒时段'), findsWidgets);

    await tester.tap(find.text('提醒时段'));
    await tester.pumpAndSettle();

    // We should now be on LiveReminderTimingScreen.
    // Verify the before-class minutes select includes 30–60 minute options.
    await tester.scrollUntilVisible(
      find.text('时间阈值'),
      200,
      scrollable: _scrollableUnder(find.byType(HyperosListView).last),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('20 分钟').first);
    await tester.pumpAndSettle();
    for (final minutes in [30, 40, 50, 60]) {
      expect(find.text('$minutes 分钟'), findsWidgets);
    }
  });

  testWidgets('main settings preserves scroll after subpage pop', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final provider = await createInitializedTestProvider(tester);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const TestApp(home: TimetableSettingsScreen()),
      ),
    );
    await _pumpScreen(tester);

    final homeList = find.byType(HyperosListView).first;
    final homeScrollable = _scrollableUnder(homeList);
    await tester.scrollUntilVisible(
      find.text('超级岛与通知'),
      200,
      scrollable: homeScrollable,
    );
    await tester.pumpAndSettle();

    final pixelsBefore = tester
        .state<ScrollableState>(homeScrollable)
        .position
        .pixels;
    expect(pixelsBefore, greaterThan(100));

    final liveTile = find.byKey(const ValueKey<String>('settings-live-entry'));
    expect(liveTile, findsOneWidget);
    await tester.tap(liveTile);
    await tester.pumpAndSettle();
    expect(find.text('提醒时段'), findsWidgets);

    Navigator.of(tester.element(find.text('提醒时段'))).pop();
    await tester.pumpAndSettle();
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();

    final pixelsAfter = tester
        .state<ScrollableState>(homeScrollable)
        .position
        .pixels;
    expect(pixelsAfter, closeTo(pixelsBefore, 1));
  });

  // 2026-08-30 OPPO 反馈回归锚点：用户自添加假期覆盖当天后，自检永远查不出
  // 真正原因——状态卡兜底报「原生实时服务未运行」、测试 toast 只解释「上课前
  // 提醒」。假日门在选课最上游（预设课也一并被拦），必须在两处显式点名假期。
  testWidgets('island status card blames holiday when holiday blocks the island', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final provider = await createInitializedTestProvider(tester);
    await runRealAsync(tester, () {
      return provider.updateTimetableSettings(
        provider.settings.copyWith(holidayOverrideEnabled: true),
      );
    });

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: TestApp(home: createLiveTestingSettingsScreen()),
      ),
    );
    await _pumpScreen(tester);

    final diagnosticsList = find.byType(HyperosListView).last;
    await tester.scrollUntilVisible(
      find.textContaining('超级岛在假期期间不显示'),
      200,
      scrollable: _scrollableUnder(diagnosticsList),
    );
    expect(find.textContaining('超级岛在假期期间不显示'), findsOneWidget);
  });

  testWidgets('live testing trigger reports holiday gate before hidden-preset hint', (
    tester,
  ) async {
    final provider = await createInitializedTestProvider(tester);
    await runRealAsync(tester, () {
      return provider.updateTimetableSettings(
        provider.settings.copyWith(holidayOverrideEnabled: true),
      );
    });
    // 触发器的「在飞」标记由 unawaited 定时器重置，FakeAsync 测试结束后该
    // 定时器被丢弃；直接复位，避免同进程后续用例误判测试进行中。
    liveTestingTriggerInFlight = false;

    BuildContext? probeContext;
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: TestApp(
          home: Builder(
            builder: (context) {
              probeContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    LiveTestingTriggerResult? result;
    await runRealAsync(tester, () async {
      result = await triggerLiveUpdateTest(
        context: probeContext!,
        provider: provider,
      );
    });

    expect(result?.status, LiveTestingTriggerStatus.error);
    expect(
      result?.message,
      AppLocalizations.of(probeContext!)!.liveTestingHolidayBlocked,
    );
    // 核心回归锚点：假期时提示必须指向假期（旧代码此时报「已注入但此刻不会
    // 弹出」或「无课」）；两种旧文案都不等于假期文案，任一回归都会在此失败。
  });

  // 选课测试：强制起岛、与时间无关。payload 必须跳过课表校验且锁定单一
  // 恒定阶段（调度暂停期间原生阶段切换分支会收岛，见 LiveCourseTestStage 注释）。
  testWidgets('course island test force-starts single-stage payload', (tester) async {
    final provider = await createInitializedTestProvider(tester);
    final course = Course(
      id: 'c-island-test',
      name: '高等数学',
      teacher: '张老师',
      location: 'A101',
      dayOfWeek: DateTime.now().weekday,
      startSection: 1,
      endSection: 1,
      startTime: '08:00',
      endTime: '08:45',
      color: '#E91E63',
    );
    await runRealAsync(tester, () => provider.addCourse(course));

    const liveChannel = MethodChannel('com.mutx163.qingyu/miui_live');
    final payloads = <Map<Object?, Object?>>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(liveChannel, (call) async {
          if (call.method == 'startLiveUpdate') {
            payloads.add(call.arguments as Map<Object?, Object?>);
          }
          return null;
        });

    liveTestingTriggerInFlight = false;
    BuildContext? probeContext;
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: TestApp(
          home: Builder(
            builder: (context) {
              probeContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    final beforeResult = await runRealAsync(tester, () {
      return triggerLiveUpdateCourseTest(
        context: probeContext!,
        provider: provider,
        course: course,
        stage: LiveCourseTestStage.beforeClass,
      );
    });
    expect(beforeResult.status, LiveTestingTriggerStatus.success);
    expect(payloads, hasLength(1));
    expect(payloads.single['stage'], 'beforeClass');
    // 强制 payload 与快照必然不一致：必须跳过原生校验，否则 ticker 第一拍判死。
    expect(payloads.single['validateAgainstSchedule'], false);
    expect(payloads.single['enableBeforeClass'], true);
    expect(payloads.single['enableDuringClass'], false);
    final startAt = payloads.single['startAtMillis'] as int;
    final endAt = payloads.single['endAtMillis'] as int;
    // 课前变体：合成开课锚在约 3 分钟后的未来。
    expect(startAt, greaterThan(DateTime.now().millisecondsSinceEpoch - 5000));
    expect(endAt, greaterThan(startAt));
    expect(
      (payloads.single['currentCourse'] as Map)['name'] as String,
      '高等数学',
    );

    // 课中变体：开课锚定在过去，课中开关强制放开。
    liveTestingTriggerInFlight = false;
    final duringResult = await runRealAsync(tester, () {
      return triggerLiveUpdateCourseTest(
        context: probeContext!,
        provider: provider,
        course: course,
        stage: LiveCourseTestStage.duringClass,
      );
    });
    expect(duringResult.status, LiveTestingTriggerStatus.success);
    expect(payloads, hasLength(2));
    expect(payloads.last['stage'], 'duringClass');
    expect(payloads.last['validateAgainstSchedule'], false);
    expect(payloads.last['enableBeforeClass'], false);
    expect(payloads.last['enableDuringClass'], true);
    expect(
      payloads.last['startAtMillis'] as int,
      lessThan(DateTime.now().millisecondsSinceEpoch),
    );
  });

  testWidgets('live testing screen exposes the course test entry', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final provider = await createInitializedTestProvider(tester);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: TestApp(home: createLiveTestingSettingsScreen()),
      ),
    );
    await _pumpScreen(tester);

    final diagnosticsList = find.byType(HyperosListView).last;
    await tester.scrollUntilVisible(
      find.text('选课测试'),
      200,
      scrollable: _scrollableUnder(diagnosticsList),
    );
    expect(find.text('选课测试'), findsOneWidget);
  });
}
