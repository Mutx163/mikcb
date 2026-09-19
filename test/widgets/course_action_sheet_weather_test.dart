import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/providers/weather_provider.dart';
import 'package:university_timetable/widgets/course_action_sheet.dart';

import '../helpers_test_app.dart';
import '../helpers_weather.dart';

/// 让 `_dateForWeekDay(settings, 1, dayOfWeek)` 正好落在今天：
/// semesterStartDate 会被归一到所在周的周一，第 1 周第 `today.weekday` 天即今天。
Future<TimetableProvider> _providerWithTodayCourse(
  WidgetTester tester, {
  List<int>? suspendedWeeks,
}) async {
  final provider = await createInitializedTestProvider(tester);
  final today = DateTime.now();
  await runRealAsync(tester, () async {
    await provider.updateTimetableSettings(
      provider.settings.copyWith(semesterStartDate: today),
    );
    await provider.addCourse(
      Course(
        id: 'sheet-course',
        name: '数据结构',
        teacher: '张老师',
        location: 'A101',
        dayOfWeek: today.weekday,
        startSection: 1,
        endSection: 2,
        startTime: '08:00',
        endTime: '09:40',
        suspendedWeeks: suspendedWeeks,
      ),
    );
  });
  return provider;
}

Widget _wrap(
  TimetableProvider provider, {
  WeatherProvider? weather,
  bool isPartnerCourse = false,
}) {
  return TestApp(
    home: MultiProvider(
      providers: [
        ChangeNotifierProvider<TimetableProvider>.value(value: provider),
        if (weather != null)
          ChangeNotifierProvider<WeatherProvider>.value(value: weather),
      ],
      // 只测内容面板：容器（面板材质 / 圆角 / 拖拽把手 / 蒙层）归宿主，2026-09-19 起
      // 是上游的通栏底部弹窗（`showCourseActionSheet` → `showMiuixBottomSheet`）。
      // 面板自己带滚动与限高，所以这里直接摆，不套额外的容器。
      child: CourseActionSheetBody(
        previewItems: [
          CourseActionPreviewItem(
            course: provider.courses.first,
            isPartnerCourse: isPartnerCourse,
          ),
        ],
        week: 1,
        onEdit: (_) {},
        onReschedule: (_) {},
        onDelete: (_) {},
        onSuspend: (_) {},
        onAddTask: (_) {},
      ),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('详情里出现这节课时段的天气，并说明取的是课程时段', (tester) async {
    final provider = await _providerWithTodayCourse(tester);
    final weather = await readyWeatherProvider(tester);

    await tester.pumpWidget(_wrap(provider, weather: weather));
    await tester.pump();

    expect(find.text('小雨 · 23°'), findsOneWidget);
    expect(find.text('该课程时段内的天气'), findsOneWidget);
  });

  testWidgets('关掉「课程详情弹窗」开关后整行消失', (tester) async {
    final provider = await _providerWithTodayCourse(tester);
    final weather = await readyWeatherProvider(tester);
    await runRealAsync(tester, () async {
      await provider.updateTimetableSettings(
        provider.settings.copyWith(weatherShowOnSheet: false),
      );
    });

    await tester.pumpWidget(_wrap(provider, weather: weather));
    await tester.pump();

    expect(find.text('小雨 · 23°'), findsNothing);
  });

  testWidgets('这一周停课的课程不显示天气', (tester) async {
    final provider = await _providerWithTodayCourse(
      tester,
      suspendedWeeks: const [1],
    );
    final weather = await readyWeatherProvider(tester);

    await tester.pumpWidget(_wrap(provider, weather: weather));
    await tester.pump();

    // 停课周代表的那天并不上课，挂上当天天气会让人以为要带伞。
    expect(find.text('小雨 · 23°'), findsNothing);
  });

  testWidgets('情侣对方的课程不显示本地天气', (tester) async {
    final provider = await _providerWithTodayCourse(tester);
    final weather = await readyWeatherProvider(tester);

    await tester.pumpWidget(
      _wrap(provider, weather: weather, isPartnerCourse: true),
    );
    await tester.pump();

    // 对方在别的城市，本地天气对他是错的。
    expect(find.text('小雨 · 23°'), findsNothing);
  });

  testWidgets('没挂 WeatherProvider 时详情照常打开，不抛异常', (tester) async {
    final provider = await _providerWithTodayCourse(tester);

    await tester.pumpWidget(_wrap(provider));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('小雨 · 23°'), findsNothing);
    expect(find.text('数据结构'), findsWidgets);
  });

  testWidgets('天气没开时不显示', (tester) async {
    final provider = await _providerWithTodayCourse(tester);
    final weather = await readyWeatherProvider(tester);
    await runRealAsync(tester, () async {
      await weather.setEnabled(false);
    });

    await tester.pumpWidget(_wrap(provider, weather: weather));
    await tester.pump();

    expect(find.text('小雨 · 23°'), findsNothing);
  });
}
