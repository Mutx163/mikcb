import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/timetable_profile.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/screens/statistics_analysis_screen.dart';
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

/// Regression: the analysis subpages used `includeHeaderInset: false`, which
/// dropped the overlay-header top inset and pushed the first screen of chart
/// / list content INTO the frosted title bar. A full-page HyperosListView on
/// an overlay subpage must keep the default header inset.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const homeWidgetChannel = MethodChannel('com.mutx163.qingyu/home_widget');
  const analyticsChannel = MethodChannel('com.mutx163.qingyu/umeng_analytics');
  const liveChannel = MethodChannel('com.mutx163.qingyu/miui_live');

  setUp(() async {
    StorageService().resetForTesting();
    _seedInitializedPrefs();
    // Ensure mock prefs are live before any StorageService.init().
    await SharedPreferences.getInstance();
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

  double headerInsetOf(WidgetTester tester) {
    final scopes = tester.widgetList<HyperosBlurredHeaderScope>(
      find.byType(HyperosBlurredHeaderScope),
    );
    expect(scopes, isNotEmpty);
    return scopes.first.contentTopInset;
  }

  /// Top padding of the page list's own scroll view (outermost match).
  double listTopPaddingOf(WidgetTester tester) {
    final scroller = find
        .descendant(
          of: find.byType(HyperosListView),
          matching: find.byType(SingleChildScrollView),
        )
        .first;
    final padding = tester.widget<SingleChildScrollView>(scroller).padding;
    return padding?.resolve(TextDirection.ltr).top ?? 0;
  }

  Future<TimetableProvider> pumpWithCourse(
    WidgetTester tester,
    StatisticsAnalysisModule module,
  ) async {
    final provider = await createInitializedTestProvider(tester);
    await runRealAsync(tester, () async {
      await provider.addCourse(
        Course(
          id: 'course-a',
          name: '线性代数',
          teacher: '张老师',
          location: 'A101',
          dayOfWeek: 2,
          startSection: 1,
          endSection: 2,
          startTime: '08:00',
          endTime: '09:40',
        ),
      );
    });

    await tester.pumpWidget(
      ChangeNotifierProvider<TimetableProvider>.value(
        value: provider,
        child: TestApp(home: StatisticsAnalysisScreen(module: module)),
      ),
    );
    await _pumpScreen(tester);
    return provider;
  }

  for (final module in StatisticsAnalysisModule.values) {
    testWidgets('${module.name} keeps list below overlay header inset', (
      tester,
    ) async {
      await pumpWithCourse(tester, module);

      // The page shell publishes a positive overlay-header inset, and the
      // list consumes it inside its scroll padding. With the old
      // includeHeaderInset:false bug the padding stayed at the bare list
      // base (~16px), pushing content behind the frosted title.
      final inset = headerInsetOf(tester);
      expect(inset, greaterThan(0));
      expect(
        listTopPaddingOf(tester),
        greaterThan(inset / 2),
        reason:
            '${module.name} list must start below the overlay header, not '
            'behind it',
      );
    });
  }

  testWidgets('empty analysis module rests below header inset', (tester) async {
    final provider = await createInitializedTestProvider(tester);

    await tester.pumpWidget(
      ChangeNotifierProvider<TimetableProvider>.value(
        value: provider,
        child: const TestApp(
          home: StatisticsAnalysisScreen(
            module: StatisticsAnalysisModule.trend,
          ),
        ),
      ),
    );
    await _pumpScreen(tester);

    // No courses → empty state must be padded below the frosted bar
    // (HyperosBlurredBodyInset), not centered behind it.
    final inset = headerInsetOf(tester);
    expect(inset, greaterThan(0));
    final emptyTop = tester.getTopLeft(find.byType(HyperosEmptyState));
    expect(
      emptyTop.dy,
      greaterThan(inset),
      reason: 'empty state must render below the overlay header inset',
    );
  });
}
