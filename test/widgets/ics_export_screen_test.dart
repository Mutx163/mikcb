import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/timetable_profile.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/screens/data_transfer_screen.dart';
import 'package:university_timetable/screens/ics_export_screen.dart';

import '../helpers_test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('renders profile, date range, and event type controls', (
    tester,
  ) async {
    final provider = _testProvider();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const TestApp(home: IcsExportScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('课表'), findsWidgets);
    expect(find.text('日期范围'), findsOneWidget);
    expect(find.text('日历内容'), findsOneWidget);
    expect(find.text('课程'), findsOneWidget);
    expect(find.text('考试'), findsOneWidget);
    expect(find.text('日程'), findsOneWidget);
    expect(find.byKey(const Key('ics-export-share')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses the HyperOS Miuix date picker for the export range', (
    tester,
  ) async {
    final provider = _testProvider();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const TestApp(home: IcsExportScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('开始日期'));
    await tester.pumpAndSettle();

    expect(find.byType(MiuixDatePicker), findsOneWidget);
    expect(find.byType(DatePickerDialog), findsNothing);
  });

  testWidgets('empty event selection is reported without sharing', (
    tester,
  ) async {
    final provider = _testProvider();
    var shareCalls = 0;

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: TestApp(
          home: IcsExportScreen(
            shareCallback: (_) async {
              shareCalls++;
              return const ShareResult('shared', ShareResultStatus.success);
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final label in ['课程', '考试', '日程']) {
      await tester.tap(find.text(label));
      await tester.pump();
    }
    final button = find.byKey(const Key('ics-export-share'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();

    expect(shareCalls, 0);
    expect(find.text('至少选择一种日历内容'), findsOneWidget);
  });

  testWidgets('passes generated ICS data to the share callback', (
    tester,
  ) async {
    final provider = _testProvider();

    ShareParams? sharedParams;
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: TestApp(
          home: IcsExportScreen(
            shareCallback: (params) async {
              sharedParams = params;
              return const ShareResult('shared', ShareResultStatus.success);
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final button = find.byKey(const Key('ics-export-share'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(sharedParams, isNotNull);
    expect(sharedParams!.files, hasLength(1));
    final sharedContent = utf8.decode(
      await sharedParams!.files!.single.readAsBytes(),
    );
    expect(sharedContent, startsWith('BEGIN:VCALENDAR\r\n'));
    expect(sharedContent, contains('BEGIN:VEVENT'));
    expect(find.text('已导出并分享 1 个日历事件'), findsOneWidget);
  });

  testWidgets('exposes calendar export from Backup & Migration', (
    tester,
  ) async {
    final provider = _testProvider();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const TestApp(home: DataTransferScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('导出日历'), findsNWidgets(2));
    expect(find.text('选择课程、考试和日程，生成 ICS 日历并分享'), findsOneWidget);
    expect(find.byIcon(Icons.event_outlined), findsNothing);
  });
}

TimetableProvider _testProvider() {
  final now = DateTime(2026, 2);
  final profile = TimetableProfile(
    id: 'ics-widget-profile',
    name: '测试课表',
    courses: [
      Course(
        id: 'ics-widget-course',
        name: 'ICS 测试课程',
        teacher: '测试老师',
        location: 'A101',
        dayOfWeek: DateTime.monday,
        startSection: 1,
        endSection: 2,
        startTime: '08:00',
        endTime: '09:40',
        endWeek: 1,
      ),
    ],
    settings: TimetableSettings.defaults().copyWith(
      semesterStartDate: DateTime(2026, 3, 2),
      semesterWeekCount: 1,
    ),
    currentWeek: 1,
    createdAt: now,
    lastUsedAt: now,
  );
  return _FakeTimetableProvider(profile);
}

class _FakeTimetableProvider extends TimetableProvider {
  _FakeTimetableProvider(this._profile)
    : super(autoInitialize: false, enableLiveActivitySync: false);

  final TimetableProfile _profile;

  @override
  List<TimetableProfile> get profiles => [_profile];

  @override
  TimetableProfile? get activeProfile => _profile;
}
