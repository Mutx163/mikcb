// 首页周网格课卡上的天气行。
//
// 与日视图那套（`timetable_day_view_test.dart`）分开：日视图的天气行是独立的
// `DayCourseWeatherRow` 部件，周网格的是 `CourseCard` 里追加的一行字段，
// 两条渲染路径，各自的判据都要守住。
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/timetable_profile.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/providers/weather_provider.dart';
import 'package:university_timetable/screens/timetable_screen.dart';
import 'package:university_timetable/services/holiday_service.dart';
import 'package:university_timetable/services/storage_service.dart';

import '../helpers_test_app.dart';
import '../helpers_weather.dart';

DateTime _startOfCurrentWeek(DateTime now) {
  final normalized = DateTime(now.year, now.month, now.day);
  return normalized.subtract(Duration(days: normalized.weekday - 1));
}

HolidayService _mockHolidayService() {
  final client = MockClient((request) async {
    final url = request.url.toString();
    if (url.contains('ailcc')) {
      return http.Response('{"code":0,"holiday":{}}', 200);
    }
    return http.Response('{"code":0,"data":[]}', 200);
  });
  return HolidayService(client: client);
}

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

Future<void> _pumpTimetableFrame(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

/// 今天有两节课：本周的（第 1–2 节）与只在第 2 周的（第 3–4 节）。
///
/// 两节课的时段不同但预报温度是常数，所以两张卡若都画天气会命中同一串文案——
/// 「恰好一次」这个断言因此能抓住「非本周灰卡也画了天气」。
Future<TimetableProvider> _providerWithTodayCourses(
  WidgetTester tester, {
  bool showNonCurrentWeekCourses = true,
  bool showWeatherOnWeekCard = true,
}) async {
  late TimetableProvider provider;
  await tester.runAsync(() async {
    final now = DateTime.now();
    provider = TimetableProvider(
      autoInitialize: false,
      enableLiveActivitySync: false,
      holidayService: _mockHolidayService(),
    );
    await provider.initialize();
    await provider.updateTimetableSettings(
      provider.settings.copyWith(
        semesterStartDate: _startOfCurrentWeek(now),
        semesterWeekCount: 20,
        timetableHideWeekends: false,
        timetableShowNonCurrentWeekCourses: showNonCurrentWeekCourses,
        weatherShowOnWeekCard: showWeatherOnWeekCard,
      ),
    );
    await provider.setCurrentWeek(1);
    await provider.addCourse(
      Course(
        id: 'this-week-course',
        name: '本周实验',
        teacher: '周老师',
        location: '实验楼 201',
        dayOfWeek: now.weekday,
        startSection: 1,
        endSection: 2,
        startTime: '08:00',
        endTime: '09:40',
      ),
    );
    await provider.addCourse(
      Course(
        id: 'other-week-course',
        name: '下周实验',
        teacher: '吴老师',
        location: '实验楼 202',
        dayOfWeek: now.weekday,
        startSection: 3,
        endSection: 4,
        startTime: '10:00',
        endTime: '11:40',
        customWeeks: const [2],
      ),
    );
  });
  return provider;
}

Widget _wrap(TimetableProvider provider, {WeatherProvider? weather}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<TimetableProvider>.value(value: provider),
      if (weather != null)
        ChangeNotifierProvider<WeatherProvider>.value(value: weather),
    ],
    child: const TestApp(
      home: TimetableScreen(
        enableUpdateCheck: false,
        enableProgressTimer: false,
      ),
    ),
  );
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

  testWidgets('周网格：本周那节课的卡上有天气，非本周灰卡上没有', (tester) async {
    final provider = await _providerWithTodayCourses(tester);
    final weather = await readyWeatherProvider(tester);

    await tester.pumpWidget(_wrap(provider, weather: weather));
    await _pumpTimetableFrame(tester);

    expect(find.text('本周实验'), findsWidgets);
    expect(find.text('下周实验'), findsWidgets);

    // 恰好一次：非本周灰卡这一周并不上课，它显示的日期不是它的上课日，
    // 挂上那天的天气会让人以为当天要带伞。这条红了说明判据漏了 isActiveInWeek。
    expect(find.text('小雨 · 23°'), findsOneWidget);
  });

  testWidgets('周网格：关掉「周视图课卡」开关后一张卡都不带天气', (tester) async {
    final provider = await _providerWithTodayCourses(
      tester,
      showWeatherOnWeekCard: false,
    );
    final weather = await readyWeatherProvider(tester);

    await tester.pumpWidget(_wrap(provider, weather: weather));
    await _pumpTimetableFrame(tester);

    expect(find.text('本周实验'), findsWidgets);
    expect(find.text('小雨 · 23°'), findsNothing);
  });

  testWidgets('周网格：没挂天气 provider 时照常渲染，不抛异常', (tester) async {
    final provider = await _providerWithTodayCourses(tester);

    await tester.pumpWidget(_wrap(provider));
    await _pumpTimetableFrame(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('本周实验'), findsWidgets);
    expect(find.text('小雨 · 23°'), findsNothing);
  });

  testWidgets('周网格：天气没开时不显示', (tester) async {
    final provider = await _providerWithTodayCourses(tester);
    final weather = await readyWeatherProvider(tester, enabled: false);

    await tester.pumpWidget(_wrap(provider, weather: weather));
    await _pumpTimetableFrame(tester);

    expect(find.text('小雨 · 23°'), findsNothing);
  });
}
