import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/schedule_item.dart';
import 'package:university_timetable/providers/timetable_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
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
    final updated =
        provider.getScheduleItemsForDate(DateTime(2026, 4, 16)).single;
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
    final restored =
        reloaded.getScheduleItemsForDate(DateTime(2026, 4, 18)).single;
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
}
