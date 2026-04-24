import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/timetable_profile.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/screens/timetable_settings_screen.dart';
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

  testWidgets('live testing screen keeps one-second auto refresh cadence',
      (tester) async {
    final provider = TimetableProvider(
      autoInitialize: false,
      enableLiveActivitySync: false,
    );
    await provider.initialize();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const TestApp(
          home: TimetableSettingsScreen(),
        ),
      ),
    );
    await _pumpScreen(tester);

    await tester.tap(find.text('超级岛与通知'));
    await _pumpScreen(tester);

    await tester.tap(find.text('测试与诊断'));
    await _pumpScreen(tester);

    expect(find.textContaining('每 1 秒自动拉取一次诊断状态'), findsOneWidget);
    expect(find.textContaining('上次刷新：'), findsOneWidget);
  });

  testWidgets('before class reminder popup includes 30 to 60 minute options',
      (tester) async {
    final provider = TimetableProvider(
      autoInitialize: false,
      enableLiveActivitySync: false,
    );
    await provider.initialize();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const TestApp(
          home: TimetableSettingsScreen(),
        ),
      ),
    );
    await _pumpScreen(tester);

    await tester.tap(find.text('超级岛与通知'));
    await tester.pumpAndSettle();

    // Verify we're on the live settings screen.
    expect(find.text('提醒时段'), findsWidgets);

    await tester.tap(find.text('提醒时段'));
    await tester.pumpAndSettle();

    // We should now be on LiveReminderTimingScreen.
    // Verify the before-class minutes dropdown includes 30–60 minute options.
    // Find the DropdownButtonFormField whose label is '上课前弹出时间'.
    final formFieldFinder = find.byWidgetPredicate((w) {
      if (w is! DropdownButtonFormField<int>) return false;
      return w.decoration.labelText == '上课前弹出时间';
    });
    await tester.scrollUntilVisible(
      formFieldFinder,
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    final formField =
        tester.widget<DropdownButtonFormField<int>>(formFieldFinder);
    // The items are set on the form field constructor.
    // Access the internal DropdownButton to get the items.
    final dropdownFinder = find.descendant(
      of: formFieldFinder,
      matching: find.byType(DropdownButton<int>),
    );
    final dropdown = tester.widget<DropdownButton<int>>(dropdownFinder);
    final optionValues = dropdown.items!
        .map((item) => item.value)
        .toList();
    expect(optionValues, containsAll([30, 40, 50, 60]));
  });
}
