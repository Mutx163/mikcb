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

/// 周网格实际传给课卡的那一行：紧凑密度下文字只有温度，现象由图标表达
/// （见 `WeatherTextDensity.compact`）。
const _rain = CourseWeatherDisplay(
  icon: Icons.water_drop_outlined,
  text: '23°',
);

/// 长到在窄卡里必然放不下的一行，用来验证「锁死单行」。
const _longRain = CourseWeatherDisplay(
  icon: Icons.water_drop_outlined,
  text: '雷阵雨伴有冰雹 · 18° · 30%',
);

/// 窄卡（周视图用的那条路）外面必须给个有限高度：内部是
/// `Expanded → LayoutBuilder → FittedBox`，无约束时量不出东西。
///
/// [width] 调到卡片能容下整行文字时，那一行就是「不折行的高度」，可拿来与
/// 窄卡里的实测高度对照——折行会成倍变高，这是最直接的判据。
Widget _wrap({
  required Course course,
  CourseWeatherDisplay? weather,
  bool showName = true,
  bool showLocation = false,
  double width = 120,
}) {
  return TestApp(
    home: Center(
      child: SizedBox(
        width: width,
        height: 64,
        child: CourseCard(
          course: course,
          isCompact: true,
          weather: weather,
          showName: showName,
          showTeacher: false,
          showLocation: showLocation,
        ),
      ),
    ),
  );
}

/// 某一行文字的布局高度。取的是 `RenderParagraph` 自己的 size——外层
/// `FittedBox` 的等比缩放只是绘制变换、不改它，所以这个数直接反映行数：
/// 折行就成倍变高。
double _lineHeight(WidgetTester tester, String text) =>
    tester.getSize(find.text(text)).height;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('传了天气就在窄卡上多出一行（图标 + 文字）', (tester) async {
    await tester.pumpWidget(_wrap(course: _course(), weather: _rain));

    expect(find.text('23°'), findsOneWidget);
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

    expect(find.text('23°'), findsNothing);
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
    final weatherY = tester.getTopLeft(find.text('23°')).dy;
    expect(weatherY, greaterThan(nameY));
  });

  testWidgets('课卡字段全关时课名兜底仍在（天气不算课卡字段）', (tester) async {
    await tester.pumpWidget(
      _wrap(course: _course(), weather: _rain, showName: false),
    );

    // 兜底逻辑判的是「课卡自身字段是不是全关了」；天气不该把课名顶掉，
    // 否则卡片上只剩一行温度，认不出是哪门课。
    expect(find.text('高等数学'), findsOneWidget);
    expect(find.text('23°'), findsOneWidget);
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

  testWidgets('天气行锁死单行：文字再长也不折行', (tester) async {
    // 折行的代价不只是多一行：掉到第二行的那半截没有图标顶着，而且会把整块
    // 内容撑高，外层 FittedBox 随即把整张卡（含课名）等比缩小——同一屏里就
    // 出现「有天气的卡字小、没天气的卡字大」。所以宁可省略也不折。
    await tester.pumpWidget(
      _wrap(course: _course(), weather: _longRain, width: 400),
    );
    final oneLine = _lineHeight(tester, _longRain.text);

    await tester.pumpWidget(_wrap(course: _course(), weather: _longRain));
    expect(_lineHeight(tester, _longRain.text), oneLine);

    // 顺带钉住配置本身：宽卡里能放下一整行，所以上面这个比较不是空转。
    final text = tester.widget<Text>(find.text(_longRain.text));
    expect(text.maxLines, 1);
    expect(text.softWrap, isFalse);
  });

  testWidgets('对照：不带图标的地点行仍允许折行', (tester) async {
    // 「锁死单行」是天气行特有的（它是「图标 + 一项内容」，折行会散架），
    // 不是把紧凑卡的所有文字都改成单行——地点、课名这些字段长起来照样折。
    // 这条对照红了说明有人把 maxLines 加到了所有行上。
    const longLocation = '第三教学楼四层东侧机房最里面那一间';

    await tester.pumpWidget(
      _wrap(
        course: _course(location: longLocation),
        showLocation: true,
        width: 400,
      ),
    );
    final oneLine = _lineHeight(tester, longLocation);

    await tester.pumpWidget(
      _wrap(course: _course(location: longLocation), showLocation: true),
    );
    expect(_lineHeight(tester, longLocation), greaterThan(oneLine));
  });
}
