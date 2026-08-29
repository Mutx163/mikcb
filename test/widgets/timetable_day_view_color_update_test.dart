import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/timetable_profile.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/screens/add_course_screen.dart';
import 'package:university_timetable/screens/timetable_screen.dart';
import 'package:university_timetable/services/storage_service.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';
import 'package:university_timetable/widgets/course_surface.dart';

import '../helpers_test_app.dart';

// Regression: editing a course colour from the day-view agenda card must both
// persist and repaint the agenda card surface. Test-structure notes: (1) the
// provider is created inside tester.runAsync (real zone), so before any
// unawaited post-build mutation we issue ONE bridge op from the test zone —
// otherwise the gate tail stays in the real zone and fake pumps never drain it
// (the original repro hung here); (2) the editor save crosses the plugin
// message channel, so landing is awaited via runAsync polling, then frames are
// pumped for the closing transition and the repaint assertion.

void _seedInitializedPrefs() {
  final now = DateTime(2026, 4, 12);
  final profile = TimetableProfile(
    id: 'profile-1',
    name: '默认课表',
    courses: const [],
    settings: TimetableSettings.defaults(),
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

DateTime _startOfCurrentWeek(DateTime now) {
  final normalized = DateTime(now.year, now.month, now.day);
  return normalized.subtract(Duration(days: normalized.weekday - 1));
}

CourseSurface _agendaCardSurface(WidgetTester tester) {
  final finder = find.descendant(
    of: find.byKey(const ValueKey('day-view-edit-card-today-course')),
    matching: find.byType(CourseSurface),
  );
  return tester.widget<CourseSurface>(finder.first);
}

Future<void> _pumpUntilSettled(
  WidgetTester tester, {
  int maxFrames = 120,
  Duration step = const Duration(milliseconds: 60),
}) async {
  for (var i = 0; i < maxFrames; i++) {
    await tester.pump(step);
    if (!tester.binding.hasScheduledFrame) {
      break;
    }
  }
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

  testWidgets('day view agenda card repaints after editor colour change', (tester) async {
    final provider = await createInitializedTestProvider(tester);
    final today = DateTime.now();

    // Seed inside the real zone so init-time I/O never races these mutations.
    await tester.runAsync(() async {
      await provider.updateTimetableSettings(
        provider.settings.copyWith(
          semesterStartDate: _startOfCurrentWeek(today),
          semesterWeekCount: 20,
          timetableHideWeekends: false,
        ),
      );
      await provider.setCurrentWeek(1);
      await provider.addCourse(
        Course(
          id: 'today-course',
          name: '高等数学',
          teacher: '张老师',
          location: 'A101',
          dayOfWeek: today.weekday,
          startSection: 1,
          endSection: 2,
          startTime: '08:00',
          endTime: '09:40',
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });

    // Bridge: hand the mutation gate tail back to the test zone (see header).
    var bridged = false;
    unawaited(provider.setCurrentWeek(1).then((_) => bridged = true));
    for (var i = 0; i < 40 && !bridged; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
    }
    expect(bridged, true, reason: 'bridge op must land before post-build mutations');

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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Enter day view.
    await tester.tap(find.byKey(ValueKey('weekday-header-1-${today.weekday}')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final beforeColor = _agendaCardSurface(tester).color;

    // Tap the agenda card -> editor opens via container transform.
    await tester.tap(find.byKey(const ValueKey('day-view-edit-card-today-course')));
    await tester.pump();
    await _pumpUntilSettled(tester);
    expect(find.byType(AddCourseScreen), findsOneWidget);

    // Pick a different preset colour (#4CAF50 green) through the palette
    // sheet: editor entry row -> sheet chip (preview-only tap) -> confirm.
    const targetHex = '#4CAF50';
    final colorEntry = find.widgetWithText(HyperosPickerField, '课程颜色');
    expect(colorEntry, findsOneWidget);
    await tester.ensureVisible(colorEntry.last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(colorEntry.last);
    await tester.pump();
    await _pumpUntilSettled(tester);
    expect(find.text('使用这个颜色'), findsOneWidget);

    final swatchFinder = find.byWidgetPredicate(
      (w) =>
          w is Container &&
          w.decoration is BoxDecoration &&
          (w.decoration! as BoxDecoration).color == const Color(0xFF4CAF50),
    );
    await tester.ensureVisible(swatchFinder.last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(swatchFinder.last);
    await tester.pump();

    // Confirm-based sheet: the tap above only moves the preview; the button
    // below commits the selection back to the editor.
    await tester.tap(find.text('使用这个颜色'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Save via the checkmark action. The save flow starts with a short fake
    //-timer delay, so advance fake time first to let it get going.
    await tester.tap(find.byIcon(Icons.check_rounded));
    await tester.pump(const Duration(milliseconds: 120));

    // Persistence inside the save crosses the plugin message channel, so
    // drive real time via runAsync (repo-wide pattern) until it lands, then
    // settle frames for the closing transition.
    var landed = false;
    for (var i = 0; i < 60 && !landed; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      landed = provider.courses.first.color == targetHex;
    }
    var closed = false;
    for (var i = 0; i < 40 && !closed; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      closed = find.byType(AddCourseScreen).evaluate().isEmpty;
    }
    expect(landed, true, reason: 'editor save must land while frames pump');
    expect(closed, true, reason: 'editor must close after saving');

    await tester.pump(const Duration(milliseconds: 600));
    await _pumpUntilSettled(tester);

    expect(provider.courses.first.color, targetHex);

    final afterColor = _agendaCardSurface(tester).color;
    // CourseSurface derives its fill through a tint/alpha pipeline, so compare
    // semantically: the rendered colour must sit closer to the chosen green
    // than to the previous default blue.
    double distTo(Color c) {
      final dr = afterColor.r - c.r;
      final dg = afterColor.g - c.g;
      final db = afterColor.b - c.b;
      return dr * dr + dg * dg + db * db;
    }
    expect(distTo(const Color(0xFF4CAF50)), lessThan(distTo(const Color(0xFF2196F3))),
        reason: 'day view agenda card should repaint with the new course colour');
    // Sanity: the surface actually participates in this regression only if it
    // rendered the old colour before the edit.
    expect(beforeColor, isNot(const Color(0xFF4CAF50)));
  });
}
