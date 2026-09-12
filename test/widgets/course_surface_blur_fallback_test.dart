// CourseSurface 高斯档在模糊管线不可用时的回退回归测试。
//
// 回归背景（2026-09-12）：全局材质「实体卡片」= 模糊总开关关，高斯档没有
// 可采样的模糊管线，旧实现只剩裸 tint（课程色 42% 透明）过壁纸，读作
// 「透明卡片」。修复后必须回退实体渐变卡面。
//
// 测试环境（VM）`liveBlurSupported` 恒为 false，正对应「模糊管线不可用」
// 的运行时状态；有管线的真机路径无法在本环境覆盖，由真机验收兜底。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/widgets/course_surface.dart';

void main() {
  Future<void> pumpSurface(
    WidgetTester tester,
    CourseCardSurfaceStyle style,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CourseSurface(
          style: style,
          color: const Color(0xFF2196F3),
          borderRadius: 12,
          child: const SizedBox.expand(),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('blur pipeline unavailable: gaussian style renders solid card', (
    tester,
  ) async {
    await pumpSurface(tester, CourseCardSurfaceStyle.gaussian);

    // 高斯路径的正常渲染是 ClipRRect + BackdropFilter/预模糊位图 + 弱 tint；
    // 管线不可用时必须整体回退实体：不透明渐变 DecoratedBox，无 BackdropFilter。
    expect(find.byType(BackdropFilter), findsNothing);
    final surface = tester.widget<DecoratedBox>(find.byType(DecoratedBox));
    final decoration = surface.decoration as BoxDecoration;
    expect(
      decoration.gradient,
      isNotNull,
      reason: '高斯档在无模糊管线时应回退实体渐变卡面，而非裸透明 tint',
    );
    expect(
      decoration.gradient!.colors.first.a,
      1.0,
      reason: '回退卡面必须不透明，否则过壁纸仍读作透明卡片',
    );
  });

  testWidgets('solid style keeps its opaque gradient surface', (tester) async {
    await pumpSurface(tester, CourseCardSurfaceStyle.solid);

    final surface = tester.widget<DecoratedBox>(find.byType(DecoratedBox));
    final decoration = surface.decoration as BoxDecoration;
    expect(decoration.gradient, isNotNull);
    expect(decoration.gradient!.colors.first.a, 1.0);
  });
}
