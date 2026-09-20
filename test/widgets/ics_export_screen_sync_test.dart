import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/holiday_entry.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/screens/ics_export_screen.dart';
import 'package:university_timetable/services/storage_service.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

import '../helpers_test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const syncChannel = MethodChannel('com.mutx163.qingyu/calendar_sync');

  // 与 ics_export_screen.dart 的 _calendarSyncNoticePrefsKey 保持一致：
  // 预置它 = 「首次确认弹层已看过」，用来聚焦测权限/同步路径。
  const noticeAcknowledgeKey = 'ics_calendar_sync_notice_acknowledged_v1';

  setUp(() {
    StorageService().resetForTesting();
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(syncChannel, null);
  });

  Future<TimetableProvider> pumpScreen(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final provider = await createInitializedTestProvider(tester);
    await runRealAsync(tester, () async {
      await provider.createProfile(name: '主课表');
      // 2026-04-13 是周一：默认导出范围=整学期，第 1 周周一的课程在内。
      await provider.updateTimetableSettings(
        provider.settings.copyWith(
          semesterStartDate: DateTime(2026, 4, 13),
          semesterWeekCount: 20,
        ),
      );
      await provider.addCourse(
        Course(
          id: 'course-1',
          name: '高等数学',
          teacher: '张老师',
          location: 'A101',
          dayOfWeek: 1,
          startSection: 1,
          endSection: 2,
          startTime: '08:00',
          endTime: '09:40',
        ),
      );
    });
    await tester.pumpWidget(
      TestApp(
        home: ChangeNotifierProvider.value(
          value: provider,
          child: const IcsExportScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return provider;
  }

  testWidgets('首次同步：确认弹层 → 写入成功 → toast 带数量', (tester) async {
    Object? syncPayload;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(syncChannel, (call) async {
      switch (call.method) {
        case 'checkPermission':
          return true;
        case 'sync':
          syncPayload = call.arguments;
          return ((call.arguments as Map)['events'] as List).length;
      }
      return null;
    });

    await pumpScreen(tester);

    await tester.tap(find.byKey(const Key('ics-export-sync-calendar')));
    await tester.pumpAndSettle();

    // 首次弹确认层，日历名已代入。
    expect(find.text('开始同步'), findsOneWidget);
    expect(find.textContaining('轻屿课表·主课表'), findsOneWidget);
    expect(syncPayload, isNull);

    await tester.tap(find.text('开始同步'));
    await tester.pumpAndSettle();

    final payload = syncPayload! as Map<Object?, Object?>;
    final events = payload['events']! as List<Object?>;
    expect(events, isNotEmpty);
    // 全部事件都是第 1 周那门「高等数学」的每周一出现。
    for (final event in events) {
      expect((event as Map<Object?, Object?>)['title'], '高等数学');
    }
    expect(find.textContaining('个日程到系统日历'), findsOneWidget);
  });

  testWidgets('确认过一次后一键直达，不再弹层', (tester) async {
    SharedPreferences.setMockInitialValues({noticeAcknowledgeKey: true});
    var syncCalls = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(syncChannel, (call) async {
      if (call.method == 'checkPermission') {
        return true;
      }
      if (call.method == 'sync') {
        syncCalls++;
        return 1;
      }
      return null;
    });

    await pumpScreen(tester);

    await tester.tap(find.byKey(const Key('ics-export-sync-calendar')));
    await tester.pumpAndSettle();

    expect(find.text('开始同步'), findsNothing);
    expect(syncCalls, 1);
  });

  testWidgets('权限被拒时不写入，提示去系统设置', (tester) async {
    SharedPreferences.setMockInitialValues({noticeAcknowledgeKey: true});
    var syncCalls = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(syncChannel, (call) async {
      switch (call.method) {
        case 'checkPermission':
        case 'requestPermission':
          return false;
        case 'sync':
          syncCalls++;
          return 1;
      }
      return null;
    });

    await pumpScreen(tester);

    await tester.tap(find.byKey(const Key('ics-export-sync-calendar')));
    await tester.pumpAndSettle();

    expect(syncCalls, 0);
    expect(find.textContaining('未获得日历权限'), findsOneWidget);
  });

  testWidgets('移除：确认弹层 → 删除成功 toast', (tester) async {
    SharedPreferences.setMockInitialValues({noticeAcknowledgeKey: true});
    var deleteCalls = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(syncChannel, (call) async {
      if (call.method == 'deleteCalendar') {
        deleteCalls++;
        return true;
      }
      return null;
    });

    await pumpScreen(tester);

    await tester.tap(find.byKey(const Key('ics-export-remove-calendar')));
    await tester.pumpAndSettle();

    // 破坏性确认弹层每次都出现（无「已阅」记忆）。
    expect(find.text('移除已同步的日程'), findsWidgets);
    expect(deleteCalls, 0);

    await tester.tap(find.text('移除').last);
    await tester.pumpAndSettle();

    expect(deleteCalls, 1);
    expect(find.textContaining('已从系统日历移除'), findsOneWidget);
  });

  testWidgets('移除：从未同步过时如实提示，不误报成功', (tester) async {
    SharedPreferences.setMockInitialValues({noticeAcknowledgeKey: true});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(syncChannel, (call) async {
      if (call.method == 'deleteCalendar') {
        return false;
      }
      return null;
    });

    await pumpScreen(tester);

    await tester.tap(find.byKey(const Key('ics-export-remove-calendar')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('移除').last);
    await tester.pumpAndSettle();

    expect(find.textContaining('还没有同步过日程'), findsOneWidget);
  });

  group('假期开关控制同步', () {
    // 2026-04-13 是周一（第 1 周），同一门周一课每周出现；把 4-13 标成
    // 法定假期后，开关的开/关直接决定这一天写不写进系统日历。
    Future<TimetableProvider> pumpScreenWithHoliday(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final provider = await createInitializedTestProvider(tester);
      await runRealAsync(tester, () async {
        await provider.createProfile(name: '主课表');
        await provider.updateTimetableSettings(
          provider.settings.copyWith(
            semesterStartDate: DateTime(2026, 4, 13),
            semesterWeekCount: 20,
          ),
        );
        await provider.addCourse(
          Course(
            id: 'course-1',
            name: '高等数学',
            teacher: '张老师',
            location: 'A101',
            dayOfWeek: 1,
            startSection: 1,
            endSection: 2,
            startTime: '08:00',
            endTime: '09:40',
          ),
        );
      });
      provider.seedHolidayDataForTesting(
        HolidayData(
          year: 2026,
          version: 1,
          entries: [
            HolidayEntry(
              date: DateTime(2026, 4, 13),
              name: '测试假期',
              type: HolidayType.vacation,
            ),
          ],
        ),
      );
      await tester.pumpWidget(
        TestApp(
          home: ChangeNotifierProvider.value(
            value: provider,
            child: const IcsExportScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return provider;
    }

    final holidayStartMs =
        DateTime(2026, 4, 13, 8).millisecondsSinceEpoch;

    List<Object?> syncedEvents(Object? payload) =>
        (payload! as Map<Object?, Object?>)['events']! as List<Object?>;

    testWidgets('默认开启：假期那天的课不写入', (tester) async {
      SharedPreferences.setMockInitialValues({noticeAcknowledgeKey: true});
      Object? syncPayload;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(syncChannel, (call) async {
        if (call.method == 'checkPermission') {
          return true;
        }
        if (call.method == 'sync') {
          syncPayload = call.arguments;
          return ((call.arguments as Map)['events'] as List).length;
        }
        return null;
      });

      await pumpScreenWithHoliday(tester);

      // 默认值：开关开。
      expect(
        tester
            .widget<HyperosSwitchTile>(
              find.byKey(const Key('ics-export-skip-holiday-courses')),
            )
            .value,
        isTrue,
      );

      await tester.tap(find.byKey(const Key('ics-export-sync-calendar')));
      await tester.pumpAndSettle();

      final events = syncedEvents(syncPayload);
      expect(events, isNotEmpty);
      expect(
        events.where(
          (event) => (event! as Map<Object?, Object?>)['startMs'] == holidayStartMs,
        ),
        isEmpty,
      );
    });

    testWidgets('关掉开关：假期那天的课照常写入', (tester) async {
      SharedPreferences.setMockInitialValues({noticeAcknowledgeKey: true});
      Object? syncPayload;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(syncChannel, (call) async {
        if (call.method == 'checkPermission') {
          return true;
        }
        if (call.method == 'sync') {
          syncPayload = call.arguments;
          return ((call.arguments as Map)['events'] as List).length;
        }
        return null;
      });

      await pumpScreenWithHoliday(tester);

      await tester.tap(find.byKey(const Key('ics-export-skip-holiday-courses')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('ics-export-sync-calendar')));
      await tester.pumpAndSettle();

      final events = syncedEvents(syncPayload);
      expect(events, isNotEmpty);
      expect(
        events.where(
          (event) => (event! as Map<Object?, Object?>)['startMs'] == holidayStartMs,
        ),
        isNotEmpty,
      );
    });
  });
}
