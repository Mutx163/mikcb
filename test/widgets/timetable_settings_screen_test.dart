import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/timetable_profile.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/screens/timetable_settings_screen.dart';
import 'package:university_timetable/services/storage_service.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';
import '../helpers_test_app.dart';

Future<void> _pumpScreen(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
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

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const TestApp(home: TimetableSettingsScreen()),
      ),
    );
    await _pumpScreen(tester);

    await tester.scrollUntilVisible(
      find.text('超级岛与通知'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('超级岛与通知'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('测试与诊断'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('测试与诊断'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.textContaining('自动刷新'),
      200,
      scrollable: find.byType(Scrollable).last,
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

    await tester.scrollUntilVisible(
      find.text('超级岛与通知'),
      200,
      scrollable: find.byType(Scrollable).first,
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
      scrollable: find.byType(Scrollable).last,
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

    final homeScrollable = find.descendant(
      of: find.byType(HyperosListView).first,
      matching: find.byType(Scrollable),
    );
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

    final liveTile = find.widgetWithText(HyperosListTile, '超级岛与通知');
    final onTap = tester.widget<HyperosListTile>(liveTile).onTap;
    expect(onTap, isNotNull);
    onTap!.call();
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
}
