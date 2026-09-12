import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/holiday_entry.dart';
import 'package:university_timetable/models/time_scheme.dart';
import 'package:university_timetable/models/timetable_profile.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/screens/data_transfer_screen.dart';
import 'package:university_timetable/screens/ics_export_screen.dart';
import 'package:university_timetable/services/ics_export_service.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

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

  testWidgets('Backup & Migration exports the time template when schemes exist', (
    tester,
  ) async {
    final TimetableProvider provider = _FakeTimetableProviderWithSchemes(
      _testProfile(),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const TestApp(home: DataTransferScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final button = find.widgetWithText(HyperosButton, '导出时间模板');
    expect(button, findsOneWidget);
    final widget = tester.widget<HyperosButton>(button);
    expect(widget.onPressed, isNotNull);
  });

  testWidgets('Backup & Migration disables the time export without schemes', (
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

    final button = find.widgetWithText(HyperosButton, '导出时间模板');
    expect(button, findsOneWidget);
    final widget = tester.widget<HyperosButton>(button);
    expect(widget.onPressed, isNull);
  });

  group('跳过节假日课程开关', () {
    const toggleKey = Key('ics-export-skip-holiday-courses');

    Future<void> pumpScreen(
      WidgetTester tester, {
      required TimetableProvider provider,
    }) async {
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: const TestApp(home: IcsExportScreen()),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('默认关闭，且勾选课程时可见', (tester) async {
      await pumpScreen(tester, provider: _testProvider());

      expect(find.byKey(toggleKey), findsOneWidget);
      expect(find.text('跳过节假日课程'), findsOneWidget);
      final tile = tester.widget<HyperosSwitchTile>(
        find.byKey(toggleKey),
      );
      expect(tile.value, isFalse, reason: '默认不改变导出结果');
    });

    testWidgets('取消勾选「课程」后该开关隐藏（改了不生效的选项不保留）', (
      tester,
    ) async {
      await pumpScreen(tester, provider: _testProvider());
      expect(find.byKey(toggleKey), findsOneWidget);

      await tester.tap(find.text('课程'));
      await tester.pumpAndSettle();

      expect(find.byKey(toggleKey), findsNothing);
    });

    testWidgets('打开开关后摘要出现「已跳过节假日课程」', (tester) async {
      await pumpScreen(tester, provider: _testProvider());
      expect(find.text('已跳过节假日课程'), findsNothing);

      await tester.tap(find.byKey(toggleKey));
      await tester.pumpAndSettle();

      final tile = tester.widget<HyperosSwitchTile>(
        find.byKey(toggleKey),
      );
      expect(tile.value, isTrue);
      expect(find.text('已跳过节假日课程'), findsOneWidget);
    });

    /// 2026-03-02（周一，第 1 周）设为法定假期；该课表只有这一节课。
    _HolidayTimetableProvider holidayProvider() => _HolidayTimetableProvider(
      _testProfile(),
      HolidayData(
        year: 2026,
        version: 1,
        entries: [
          HolidayEntry(
            date: DateTime(2026, 3, 2),
            name: '国庆节',
            type: HolidayType.vacation,
          ),
        ],
      ),
    );

    testWidgets('关闭时照常导出假期当天的课程', (tester) async {
      var shareCalls = 0;
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: holidayProvider(),
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

      await tester.tap(find.byKey(const Key('ics-export-share')));
      await tester.pumpAndSettle();

      expect(shareCalls, 1, reason: '默认不过滤，假期当天的课程照常导出');
    });

    testWidgets('开启后假期当天无事件可导出，不会调起分享', (tester) async {
      var shareCalls = 0;
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: holidayProvider(),
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

      await tester.tap(find.byKey(toggleKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('ics-export-share')));
      await tester.pumpAndSettle();

      expect(shareCalls, 0, reason: '全部课程都被假期过滤掉后不应分享空日历');
      expect(find.text('所选日期范围内没有日历事件'), findsOneWidget);
    });
  });
}

TimeScheme _testScheme() {
  return TimeScheme(
    id: 'widget-share-scheme',
    name: '测试作息',
    sections: const [
      SectionTime(startTime: '08:00', endTime: '08:45'),
    ],
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
}

class _FakeTimetableProviderWithSchemes extends _FakeTimetableProvider {
  _FakeTimetableProviderWithSchemes(super.profile);

  @override
  List<TimeScheme> get timeSchemes => [_testScheme()];
}

/// 带节假日数据的假 provider，供“跳过节假日课程”用例使用。
class _HolidayTimetableProvider extends _FakeTimetableProvider {
  _HolidayTimetableProvider(super.profile, this._data);

  final HolidayData _data;

  @override
  HolidayData? get holidayData => _data;
}

TimetableProfile _testProfile() {
  final now = DateTime(2026, 2);
  return TimetableProfile(
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
}

TimetableProvider _testProvider() {
  return _FakeTimetableProvider(_testProfile());
}

class _FakeTimetableProvider extends TimetableProvider {
  _FakeTimetableProvider(this._profile)
    : super(autoInitialize: false, enableLiveActivitySync: false);

  final TimetableProfile _profile;

  @override
  List<TimetableProfile> get profiles => [_profile];

  @override
  TimetableProfile? get activeProfile => _profile;

  /// 节假日数据：默认空（无假期）；子类可覆盖。
  @override
  HolidayData? get holidayData => null;
}
