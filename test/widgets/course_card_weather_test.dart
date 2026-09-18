import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/widgets/course_card.dart';
import 'package:university_timetable/widgets/course_weather_display.dart';

import '../helpers_test_app.dart';

Course _course({
  String name = '高等数学',
  String teacher = '张老师',
  String location = 'A101',
  String? description,
}) {
  return Course(
    id: 'course-weather',
    name: name,
    teacher: teacher,
    location: location,
    dayOfWeek: 1,
    startSection: 1,
    endSection: 2,
    startTime: '08:00',
    endTime: '09:40',
    description: description,
  );
}

const _rain = CourseWeatherDisplay(
  icon: Icons.water_drop_outlined,
  text: '小雨 · 23°',
);

/// 窄卡（周视图用的那条路）外面必须给个有限高度：内部是
/// `Expanded → LayoutBuilder → FittedBox`，无约束时量不出东西。
Widget _wrap({required Course course, CourseWeatherDisplay? weather, bool showName = true}) {
  return TestApp(
    home: Center(
      child: SizedBox(
        width: 120,
        height: 64,
        child: CourseCard(
          course: course,
          isCompact: true,
          weather: weather,
          showName: showName,
          showTeacher: false,
          showLocation: false,
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('传了天气就在窄卡上多出一行（图标 + 文字）', (tester) async {
    await tester.pumpWidget(_wrap(course: _course(), weather: _rain));

    expect(find.text('小雨 · 23°'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(CourseCard),
        matching: find.byIcon(Icons.water_drop_outlined),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('不传天气时卡片上没有那一行', (tester) async {
    await tester.pumpWidget(_wrap(course: _course()));

    expect(find.text('小雨 · 23°'), findsNothing);
    expect(find.byIcon(Icons.water_drop_outlined), findsNothing);
  });

  testWidgets('天气排在所有课卡字段之后', (tester) async {
    await tester.pumpWidget(
      _wrap(
        course: _course(description: '线性表与树'),
        weather: _rain,
      ),
    );

    // 顺序靠几何位置断言：只断言「文字都在」抓不到顺序被改。
    final nameY = tester.getTopLeft(find.text('高等数学')).dy;
    final weatherY = tester.getTopLeft(find.text('小雨 · 23°')).dy;
    expect(weatherY, greaterThan(nameY));
  });

  testWidgets('课卡字段全关时课名兜底仍在（天气不算课卡字段）', (tester) async {
    await tester.pumpWidget(
      _wrap(course: _course(), weather: _rain, showName: false),
    );

    // 兜底逻辑判的是「课卡自身字段是不是全关了」；天气不该把课名顶掉，
    // 否则卡片上只剩一行温度，认不出是哪门课。
    expect(find.text('高等数学'), findsOneWidget);
    expect(find.text('小雨 · 23°'), findsOneWidget);
  });

  testWidgets('天气图标尺寸跟着同行字号走，不是写死的 dp', (tester) async {
    await tester.pumpWidget(_wrap(course: _course(), weather: _rain));

    // 图标尺寸按 `_compactLineWidget` 的规则由该行 fontSize 推导（×1.25）。
    // 写死 dp 会让用户在设置里调大字号后图标相对变小，比例失衡。
    Icon icon() =>
        tester.widget<Icon>(find.byIcon(Icons.water_drop_outlined));

    expect(icon().size, 8 * 1.25);

    await tester.pumpWidget(
      TestApp(
        home: Center(
          child: SizedBox(
            width: 120,
            height: 64,
            child: CourseCard(
              course: _course(),
              isCompact: true,
              weather: _rain,
              showTeacher: false,
              showLocation: false,
              compactSubtitleFontSize: 12,
            ),
          ),
        ),
      ),
    );

    expect(icon().size, 12 * 1.25);
  });
}
