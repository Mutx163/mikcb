import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/timetable_profile.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/screens/timetable_screen.dart';
import 'package:university_timetable/screens/timetable_profiles_screen.dart';
import 'package:university_timetable/services/storage_service.dart';
import '../helpers_test_app.dart';

Future<void> _pumpTimetableFrame(WidgetTester tester) async {
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
        .setMockMethodCallHandler(liveChannel, (call) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(homeWidgetChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(analyticsChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(liveChannel, null);
  });

  testWidgets('home screen can quick switch profiles from title trigger', (
    tester,
  ) async {
    final provider = await createInitializedTestProvider(tester);
    final defaultProfileId = provider.activeProfileId!;
    await runRealAsync(tester, () async {
      await provider.createProfile(name: '秋季课表');
    });
    await runRealAsync(tester, () async {
      await provider.switchProfile(defaultProfileId);
    });

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const TestApp(
          home: TimetableScreen(
            enableUpdateCheck: false,
            enableProgressTimer: false,
          ),
        ),
      ),
    );
    await _pumpTimetableFrame(tester);

    expect(
      find.byKey(const ValueKey('profile_switcher_trigger')),
      findsOneWidget,
    );
    expect(find.text('轻屿课表'), findsOneWidget);
    expect(find.text('默认课表'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('profile_switcher_trigger')));
    await _pumpTimetableFrame(tester);

    expect(find.text('切换课表'), findsOneWidget);
    expect(find.text('秋季课表'), findsOneWidget);

    await tester.tap(find.text('秋季课表'));
    await runRealAsync(tester, () async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await _pumpTimetableFrame(tester);

    expect(provider.activeProfile?.name, '秋季课表');
    expect(find.text('秋季课表'), findsNothing);
  });

  testWidgets('brand title style shows active profile name on home', (
    tester,
  ) async {
    final provider = await createInitializedTestProvider(tester);
    await runRealAsync(tester, () async {
      await provider.updateTimetableSettings(
        provider.settings.copyWith(homeTitleStyle: HomeTitleStyle.brand),
      );
    });

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const TestApp(
          home: TimetableScreen(
            enableUpdateCheck: false,
            enableProgressTimer: false,
          ),
        ),
      ),
    );
    await _pumpTimetableFrame(tester);

    expect(
      find.byKey(const ValueKey('profile_switcher_trigger')),
      findsOneWidget,
    );
    expect(find.text('默认课表'), findsOneWidget);
  });

  testWidgets('home overflow menu omits timetable management entry', (
    tester,
  ) async {
    final provider = await createInitializedTestProvider(tester);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const TestApp(
          home: TimetableScreen(
            enableUpdateCheck: false,
            enableProgressTimer: false,
          ),
        ),
      ),
    );
    await _pumpTimetableFrame(tester);

    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await _pumpTimetableFrame(tester);

    expect(find.text('课表管理'), findsNothing);
    expect(find.text('课程总览'), findsOneWidget);
  });

  testWidgets('profile switch sheet can open timetable management screen', (
    tester,
  ) async {
    final provider = await createInitializedTestProvider(tester);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const TestApp(
          home: TimetableScreen(
            enableUpdateCheck: false,
            enableProgressTimer: false,
          ),
        ),
      ),
    );
    await _pumpTimetableFrame(tester);

    await tester.tap(find.byKey(const ValueKey('profile_switcher_trigger')));
    await _pumpTimetableFrame(tester);

    await tester.tap(find.text('课表管理'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(TimetableProfilesScreen), findsOneWidget);
  });

  testWidgets('switching profiles restores each profile timetable view state', (
    tester,
  ) async {
    final provider = await createInitializedTestProvider(tester);
    final defaultProfileId = provider.activeProfileId!;

    await runRealAsync(tester, () async {
      await provider.updateTimetableSettings(
        provider.settings.copyWith(
          timetableHomeViewMode: TimetableHomeViewMode.day,
          timetableLastViewedDayOfWeek: 3,
        ),
      );
    });
    await runRealAsync(tester, () async {
      await provider.setCurrentWeek(2);
    });

    await runRealAsync(tester, () async {
      await provider.createProfile(name: '周视图课表');
    });
    final weekProfileId = provider.activeProfileId!;
    await runRealAsync(tester, () async {
      await provider.updateTimetableSettings(
        provider.settings.copyWith(
          timetableHomeViewMode: TimetableHomeViewMode.week,
        ),
      );
    });

    await runRealAsync(tester, () async {
      await provider.switchProfile(defaultProfileId);
    });

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const TestApp(
          home: TimetableScreen(
            enableUpdateCheck: false,
            enableProgressTimer: false,
          ),
        ),
      ),
    );
    await _pumpTimetableFrame(tester);

    expect(
      find.byKey(const ValueKey('timetable-day-view-2-3')),
      findsOneWidget,
    );

    await runRealAsync(tester, () async {
      await provider.switchProfile(weekProfileId);
    });
    await _pumpTimetableFrame(tester);

    expect(find.byKey(const ValueKey('timetable-day-view-1-3')), findsNothing);

    await runRealAsync(tester, () async {
      await provider.switchProfile(defaultProfileId);
    });
    await _pumpTimetableFrame(tester);

    expect(
      find.byKey(const ValueKey('timetable-day-view-2-3')),
      findsOneWidget,
    );
  });
}
