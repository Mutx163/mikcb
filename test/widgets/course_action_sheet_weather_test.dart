import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/providers/weather_provider.dart';
import 'package:university_timetable/widgets/course_action_sheet.dart';
import 'package:university_timetable/widgets/course_weather_display.dart';

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

  testWidgets('预报没到时先留一格空位：下面那格不动', (tester) async {
    // 判据是**几何**：天气格下面紧挨着备注格，预报到达时那一格如果被顶下去，
    // 用户看到的就是弹层内容「闪一下」。
    final provider = await _providerWithTodayCourse(tester);
    // 显式打开这个开关：本文件里上一条用例把它关掉并落盘了，而设置是跟着档案
    // 走的，不显式打开的话这条会跟着执行顺序变红。
    await runRealAsync(tester, () async {
      await provider.updateTimetableSettings(
        provider.settings.copyWith(weatherShowOnSheet: true),
      );
    });
    final pending = await pendingWeatherProvider(tester);

    await tester.pumpWidget(_wrap(provider, weather: pending.provider));
    await tester.pump();

    // 空位占住了：天气格在（只有占位图标、没有文字），备注格被压在它下面。
    final reservedAnchor = _noteTileTop(tester);
    expect(find.byIcon(weatherPlaceholderIcon), findsOneWidget);
    expect(find.textContaining('23°'), findsNothing);

    await pending.awaitArrival(tester);

    expect(find.text('小雨 · 23°'), findsOneWidget);
    // 这条就是本次改动的全部意义：内容换了几何没动。
    expect(_noteTileTop(tester), reservedAnchor);
  });

  testWidgets('天气没开时不留空位（空位会变成永久空行）', (tester) async {
    final provider = await _providerWithTodayCourse(tester);
    await runRealAsync(tester, () async {
      await provider.updateTimetableSettings(
        provider.settings.copyWith(weatherShowOnSheet: true),
      );
    });
    final pending = await pendingWeatherProvider(tester, enabled: false);

    await tester.pumpWidget(_wrap(provider, weather: pending.provider));
    await tester.pump();
    final withoutWeatherRow = _noteTileTop(tester);
    expect(find.byIcon(weatherPlaceholderIcon), findsNothing);

    // 对照：把「课程详情弹窗」开关也关掉（那一格整格不画），备注格必须落在同一个
    // 位置。这条红了说明「不留位」其实偷偷留了一格空行。
    await runRealAsync(tester, () async {
      await provider.updateTimetableSettings(
        provider.settings.copyWith(weatherShowOnSheet: false),
      );
    });
    await tester.pumpWidget(_wrap(provider, weather: pending.provider));
    await tester.pump();
    expect(_noteTileTop(tester), withoutWeatherRow);
    // 天气总开关关着 → provider 压根不发请求，所以这里没有「等它到货」这回事
    // （真去等会空等到超时）。
  });
}

/// 天气格下面那一格（备注格）的顶边 y：它一动就说明上面的内容在动。
double _noteTileTop(WidgetTester tester) =>
    tester.getTopLeft(find.byIcon(Icons.sticky_note_2_outlined)).dy;
