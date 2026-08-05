import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/schedule_item.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    StorageService().resetForTesting();
    SharedPreferences.setMockInitialValues({});
  });

  Future<TimetableProvider> createProvider() async {
    final provider = TimetableProvider(
      autoInitialize: false,
      enableLiveActivitySync: false,
    );
    await provider.initialize();
    return provider;
  }

  test('schedule items can be created, updated, and deleted', () async {
    final provider = await createProvider();
    final item = ScheduleItem(
      id: 'schedule-1',
      title: '学院会议',
      location: '行政楼 301',
      note: '提前十分钟到',
      date: DateTime(2026, 4, 16),
      startTime: '10:00',
      endTime: '11:00',
      createdAt: DateTime(2026, 4, 16, 9),
      updatedAt: DateTime(2026, 4, 16, 9),
    );

    await provider.addScheduleItem(item);
    expect(
      provider.getScheduleItemsForDate(DateTime(2026, 4, 16)).single.title,
      '学院会议',
    );

    await provider.updateScheduleItem(
      item.copyWith(
        title: '学院例会',
        note: '改到十点半签到',
        updatedAt: DateTime(2026, 4, 16, 9, 30),
      ),
    );
    final updated = provider
        .getScheduleItemsForDate(DateTime(2026, 4, 16))
        .single;
    expect(updated.title, '学院例会');
    expect(updated.note, '改到十点半签到');

    await provider.deleteScheduleItem(item.id);
    expect(provider.getScheduleItemsForDate(DateTime(2026, 4, 16)), isEmpty);
  });

  test('schedule items persist with active profile state', () async {
    final provider = await createProvider();
    final item = ScheduleItem(
      id: 'schedule-persist',
      title: '领取材料',
      location: '教务处',
      date: DateTime(2026, 4, 18),
      startTime: '14:00',
      endTime: '14:30',
      createdAt: DateTime(2026, 4, 18, 12),
      updatedAt: DateTime(2026, 4, 18, 12),
    );

    await provider.addScheduleItem(item);

    final reloaded = await createProvider();
    final restored = reloaded
        .getScheduleItemsForDate(DateTime(2026, 4, 18))
        .single;
    expect(restored.title, '领取材料');
    expect(restored.location, '教务处');
    expect(restored.startTime, '14:00');
    expect(restored.endTime, '14:30');
  });

  test('cross-day schedule items are visible on each covered date', () async {
    final provider = await createProvider();
    final item = ScheduleItem(
      id: 'schedule-cross-day',
      title: '跨夜值班',
      startDate: DateTime(2026, 4, 18),
      endDate: DateTime(2026, 4, 19),
      startTime: '22:30',
      endTime: '01:30',
      createdAt: DateTime(2026, 4, 18, 12),
      updatedAt: DateTime(2026, 4, 18, 12),
    );

    await provider.addScheduleItem(item);

    expect(
      provider.getScheduleItemsForDate(DateTime(2026, 4, 18)).single.title,
      '跨夜值班',
    );
    expect(
      provider.getScheduleItemsForDate(DateTime(2026, 4, 19)).single.title,
      '跨夜值班',
    );
    expect(provider.getScheduleItemsForDate(DateTime(2026, 4, 20)), isEmpty);
  });

  test(
    'daily and weekly recurrence are expanded by local calendar date',
    () async {
      final provider = await createProvider();
      final daily = ScheduleItem(
        id: 'schedule-daily',
        title: '每日自习',
        startDate: DateTime(2026, 4, 16, 18),
        endDate: DateTime(2026, 4, 19, 9),
        startTime: '18:00',
        endTime: '19:00',
        recurrence: ScheduleRecurrence.daily,
        createdAt: DateTime(2026, 4, 1),
        updatedAt: DateTime(2026, 4, 1),
      );
      final weekly = ScheduleItem(
        id: 'schedule-weekly',
        title: '每周例会',
        startDate: DateTime(2026, 4, 16),
        endDate: DateTime(2026, 5, 1),
        startTime: '10:00',
        endTime: '11:00',
        recurrence: ScheduleRecurrence.weekly,
        createdAt: DateTime(2026, 4, 1),
        updatedAt: DateTime(2026, 4, 1),
      );

      await provider.addScheduleItem(daily);
      await provider.addScheduleItem(weekly);

      expect(
        provider.getScheduleItemInstancesForDate(DateTime(2026, 4, 17)),
        hasLength(1),
      );
      expect(
        provider
            .getScheduleItemInstancesForDate(DateTime(2026, 4, 17))
            .single
            .occurrenceId,
        'schedule-daily@2026-04-17',
      );
      expect(
        provider.getScheduleItemsForDate(DateTime(2026, 4, 23)).single.title,
        '每周例会',
      );
      expect(provider.getScheduleItemsForDate(DateTime(2026, 4, 24)), isEmpty);
      expect(
        provider.getScheduleItemsForDate(DateTime(2026, 4, 19)).single.title,
        '每日自习',
      );
      expect(provider.getScheduleItemsForDate(DateTime(2026, 4, 20)), isEmpty);
    },
  );

  test(
    'exceptions suppress one occurrence and persist with the series',
    () async {
      final provider = await createProvider();
      final item = ScheduleItem(
        id: 'schedule-exception',
        title: '固定活动',
        startDate: DateTime(2026, 4, 16),
        endDate: DateTime(2026, 4, 19),
        startTime: '09:00',
        endTime: '10:00',
        recurrence: ScheduleRecurrence.daily,
        exceptionDates: [DateTime(2026, 4, 17)],
        createdAt: DateTime(2026, 4, 1),
        updatedAt: DateTime(2026, 4, 1),
      );

      await provider.addScheduleItem(item);
      expect(provider.getScheduleItemsForDate(DateTime(2026, 4, 17)), isEmpty);

      await provider.deleteScheduleItemOccurrence(
        item.id,
        DateTime(2026, 4, 18),
      );
      expect(provider.getScheduleItemsForDate(DateTime(2026, 4, 18)), isEmpty);

      final reloaded = await createProvider();
      final restored = reloaded.scheduleItems.single;
      expect(restored.recurrence, ScheduleRecurrence.daily);
      expect(restored.exceptionDates, [
        DateTime(2026, 4, 17),
        DateTime(2026, 4, 18),
      ]);
      expect(
        reloaded.getScheduleItemsForDate(DateTime(2026, 4, 19)).single.title,
        '固定活动',
      );
    },
  );

  test(
    'single-occurrence edit creates a stable override and series edit removes it',
    () async {
      final provider = await createProvider();
      final item = ScheduleItem(
        id: 'schedule-edit',
        title: '固定活动',
        startDate: DateTime(2026, 4, 16),
        endDate: DateTime(2026, 4, 18),
        startTime: '09:00',
        endTime: '10:00',
        recurrence: ScheduleRecurrence.daily,
        createdAt: DateTime(2026, 4, 1),
        updatedAt: DateTime(2026, 4, 1),
      );
      await provider.addScheduleItem(item);

      await provider.updateScheduleItemOccurrence(
        item.id,
        DateTime(2026, 4, 17),
        item.copyWith(
          title: '本次改到下午',
          startDate: DateTime(2026, 4, 17),
          startTime: '14:00',
          endTime: '15:00',
          updatedAt: DateTime(2026, 4, 17, 8),
        ),
      );

      final editedInstance = provider
          .getScheduleItemInstancesForDate(DateTime(2026, 4, 17))
          .single;
      expect(editedInstance.item.title, '本次改到下午');
      expect(editedInstance.item.startTime, '14:00');
      expect(editedInstance.occurrenceId, 'schedule-edit@2026-04-17');
      expect(
        provider.getScheduleItemsForDate(DateTime(2026, 4, 16)).single.title,
        '固定活动',
      );
      expect(provider.scheduleItems, hasLength(2));

      final reloaded = await createProvider();
      expect(
        reloaded
            .getScheduleItemInstancesForDate(DateTime(2026, 4, 17))
            .single
            .title,
        '本次改到下午',
      );
      expect(reloaded.scheduleItems, hasLength(2));

      await reloaded.updateScheduleItem(
        reloaded.scheduleItems
            .firstWhere((entry) => entry.id == item.id)
            .copyWith(title: '全系列更新', exceptionDates: const <DateTime>[]),
      );
      expect(reloaded.scheduleItems, hasLength(1));
      expect(
        reloaded.getScheduleItemsForDate(DateTime(2026, 4, 17)).single.title,
        '全系列更新',
      );

      await reloaded.deleteScheduleItemSeries(item.id);
      expect(reloaded.scheduleItems, isEmpty);
    },
  );

  test('stable occurrence id can delete only one occurrence', () async {
    final provider = await createProvider();
    final item = ScheduleItem(
      id: 'schedule-stable-id',
      title: '每日打卡',
      startDate: DateTime(2026, 4, 16),
      endDate: DateTime(2026, 4, 18),
      startTime: '08:00',
      endTime: '08:30',
      recurrence: ScheduleRecurrence.daily,
      createdAt: DateTime(2026, 4, 1),
      updatedAt: DateTime(2026, 4, 1),
    );
    await provider.addScheduleItem(item);

    final occurrence = provider
        .getScheduleItemInstancesForDate(DateTime(2026, 4, 17))
        .single;
    await provider.deleteScheduleItemInstance(occurrence.instanceId);

    expect(provider.getScheduleItemsForDate(DateTime(2026, 4, 17)), isEmpty);
    expect(
      provider.getScheduleItemsForDate(DateTime(2026, 4, 18)).single.title,
      '每日打卡',
    );
    expect(provider.scheduleItems, hasLength(1));
  });
}
