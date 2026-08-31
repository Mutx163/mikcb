import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/domain/week_calculator.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    StorageService().resetForTesting();
    SharedPreferences.setMockInitialValues({});
  });

  TimetableProvider createProvider() => TimetableProvider(
    autoInitialize: false,
    enableLiveActivitySync: false,
  );

  int expectedCalendarWeek(DateTime semesterStart) =>
      WeekCalculator.calendarWeekForDate(
        DateTime.now(),
        semesterStart: semesterStart,
        fallback: 1,
      );

  test('切换课表：当前周按目标课表自己的开学时间对齐（17/20 场景）', () async {
    final provider = createProvider();
    await provider.initialize();

    // A：2026-02-23 开学；B：晚 16 周（2026-06-15，周一）。今天对 A 已是
    // 期末后的钳制周、对 B 是学期中——两份课表的"当前周"必须各算各的。
    final startA = DateTime(2026, 2, 23);
    final startB = DateTime(2026, 6, 15);
    await provider.updateTimetableSettings(
      provider.settings.copyWith(
        semesterWeekCount: 25,
        semesterStartDate: startA,
      ),
    );
    final weekA = provider.currentWeek;

    final profileB = await provider.createProfile(name: 'B课表');
    // B 激活中：给它设自己的开学时间（等价于用户在设置页改开学日期）。
    await provider.updateTimetableSettings(
      provider.settings.copyWith(
        semesterWeekCount: 25,
        semesterStartDate: startB,
      ),
    );
    final weekB = expectedCalendarWeek(startB);
    // 改开学时间立即对齐（不经设置页的路径也覆盖）。
    expect(provider.currentWeek, weekB);

    // 切回 A 再切回 B：各自对齐各自的日历周，而不是带着上一份的周数。
    final profileAId = provider.profiles
        .firstWhere(
          (profile) => !profile.isPartnerImported && profile.id != profileB.id,
        )
        .id;
    await provider.switchProfile(profileAId);
    expect(provider.currentWeek, weekA);

    await provider.switchProfile(profileB.id);
    expect(provider.currentWeek, weekB);
    expect(provider.currentWeek, isNot(weekA));
    // 对齐结果随切换持久化进 B，桌面卡片快照兜底也拿得到正确周次。
    expect(
      provider.profiles.firstWhere((profile) => profile.id == profileB.id).currentWeek,
      weekB,
    );
  });

  test('无开学时间的课表切换仍恢复持久化周次（v2.0 行为保留）', () async {
    final provider = createProvider();
    await provider.initialize();
    await provider.updateTimetableSettings(
      provider.settings.copyWith(
        semesterWeekCount: 25,
        semesterStartDate: DateTime(2026, 2, 23),
      ),
    );

    final profileB = await provider.createProfile(name: 'B课表');
    await provider.setCurrentWeek(8);

    final profileAId = provider.profiles
        .firstWhere(
          (profile) => !profile.isPartnerImported && profile.id != profileB.id,
        )
        .id;
    await provider.switchProfile(profileAId);
    final weekA = provider.currentWeek;

    await provider.switchProfile(profileB.id);
    // B 没有开学时间无从推导，保留"上次停留的周次"。
    expect(provider.currentWeek, 8);
    expect(provider.currentWeek, isNot(weekA));
  });

  test('开学时间在未来：对齐为第 1 周（开学前）', () async {
    final provider = createProvider();
    await provider.initialize();
    await provider.updateTimetableSettings(
      provider.settings.copyWith(semesterWeekCount: 25),
    );
    await provider.setCurrentWeek(8);

    final futureStart = DateTime.now().add(const Duration(days: 30));
    await provider.updateTimetableSettings(
      provider.settings.copyWith(semesterStartDate: futureStart),
    );

    expect(provider.currentWeek, 1);
    expect(provider.currentDateWeek, 1);
  });
}
