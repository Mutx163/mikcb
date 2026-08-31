import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/widgets/course_card.dart';

import '../helpers_test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('invalid course color does not crash course card', (
    tester,
  ) async {
    final course = Course(
      id: 'course-1',
      name: '高等数学',
      teacher: '张老师',
      location: 'A101',
      dayOfWeek: 1,
      startSection: 1,
      endSection: 2,
      startTime: '08:00',
      endTime: '09:40',
      color: 'broken',
    );

    await tester.pumpWidget(TestApp(home: CourseCard(course: course)));

    expect(find.text('高等数学'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('solid card keeps title and description on the same polarity', (
    tester,
  ) async {
    // 回归：白标题在饱和色卡上对比度达标被保留，而黑简介同样达标被保留，
    // 同卡混色；详情墨必须跟随标题墨。
    final course = Course(
      id: 'course-2',
      name: '数据结构',
      teacher: '',
      location: '',
      dayOfWeek: 1,
      startSection: 1,
      endSection: 2,
      startTime: '08:00',
      endTime: '09:40',
      color: '#FF9800',
      description: '线性表与树',
    );

    await tester.pumpWidget(
      TestApp(
        home: CourseCard(
          course: course,
          showTeacher: false,
          showLocation: false,
          showDescription: true,
          titleColorHex: '#FFFFFF',
          detailColorHex: '#000000',
        ),
      ),
    );

    final title = tester.widget<Text>(find.text('数据结构'));
    expect(title.style?.color, const Color(0xFFFFFFFF));

    final description = tester.widget<Text>(find.text('线性表与树'));
    final detailInk = description.style!.color!;
    expect(detailInk.r, closeTo(1.0, 0.001)); // 跟随白标题，不再用黑
    expect(detailInk.g, closeTo(1.0, 0.001));
    expect(detailInk.b, closeTo(1.0, 0.001));
    expect(detailInk.a, closeTo(0.7, 0.01));
  });

  testWidgets('gaussian card over bright wallpaper auto-flips to dark ink', (
    tester,
  ) async {
    // 回归：玻璃档此前原样保留用户/导入墨色，亮壁纸上白字洗没、橙字突兀。
    // 玻璃规则：彩色墨回落自动黑白，中性墨对比度不足同样回落，详情跟随标题。
    final course = Course(
      id: 'course-3',
      name: '操作系统',
      teacher: '',
      location: '',
      dayOfWeek: 1,
      startSection: 1,
      endSection: 2,
      startTime: '08:00',
      endTime: '09:40',
      color: '#FF9800',
      description: '进程与线程',
    );

    await tester.pumpWidget(
      TestApp(
        home: CourseCard(
          course: course,
          showTeacher: false,
          showLocation: false,
          showDescription: true,
          surfaceStyle: CourseCardSurfaceStyle.gaussian,
          wallpaperLuminance: 0.8,
          titleColorHex: '#FFFFFF',
          detailColorHex: '#B34700',
        ),
      ),
    );

    // effective ≈ 0.62：白字对比度 1.6 < 3 → 自动黑。
    final title = tester.widget<Text>(find.text('操作系统'));
    expect(title.style?.color, const Color(0xFF1A1A1A));

    // 橙色详情（彩色墨）在玻璃档一律跟随标题墨。
    final description = tester.widget<Text>(find.text('进程与线程'));
    final detailInk = description.style!.color!;
    expect(detailInk.r, closeTo(0x1A / 255, 0.002));
    expect(detailInk.g, closeTo(0x1A / 255, 0.002));
    expect(detailInk.b, closeTo(0x1A / 255, 0.002));
    expect(detailInk.a, closeTo(0.7, 0.01));
  });
}
