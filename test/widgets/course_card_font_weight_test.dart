import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/ui/app_fonts.dart';
import 'package:university_timetable/widgets/course_card.dart';

// 课卡的主次完全靠字重表达（标题粗、详情常规）。全局「字重」滑杆接入时
// 必须**按角色平移**而不是绝对覆盖，否则标题与详情会被压成同一档、
// 卡片失去层级。这里锁死平移语义：用户调粗/调细时两者同步移动、差值保留。
void main() {
  Course course() => Course(
    id: 'c1',
    name: '高等数学',
    teacher: '张老师',
    location: 'A101',
    dayOfWeek: 1,
    startSection: 1,
    endSection: 2,
    startTime: '08:00',
    endTime: '09:40',
  );

  Future<void> pumpCard(
    WidgetTester tester, {
    required int userWeight,
    required bool isCompact,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: AppFontScope(
            userFontWeight: userWeight,
            systemFontWeightDelta: 0,
            fontSpec: const AppFontSpec(),
            child: SizedBox(
              width: 220,
              height: 160,
              child: CourseCard(
                course: course(),
                isCompact: isCompact,
                showTime: true,
                showWeeks: true,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  int? renderedWeight(WidgetTester tester, String text) {
    final widget = tester.widget<Text>(find.text(text));
    return widget.style?.fontWeight?.value;
  }

  for (final isCompact in [false, true]) {
    final label = isCompact ? '紧凑卡' : '完整卡';

    testWidgets('$label：默认字重保留标题/详情层级', (tester) async {
      await pumpCard(
        tester,
        userWeight: kAppFontWeightDefault,
        isCompact: isCompact,
      );

      expect(renderedWeight(tester, '高等数学'), 700);
      expect(renderedWeight(tester, '张老师'), 400);
    });

    testWidgets('$label：字重调粗时整体平移且差值保留', (tester) async {
      await pumpCard(tester, userWeight: 500, isCompact: isCompact);

      expect(renderedWeight(tester, '高等数学'), 800);
      expect(renderedWeight(tester, '张老师'), 500);
    });

    testWidgets('$label：字重调细时整体平移且差值保留', (tester) async {
      await pumpCard(tester, userWeight: 300, isCompact: isCompact);

      expect(renderedWeight(tester, '高等数学'), 600);
      expect(renderedWeight(tester, '张老师'), 300);
    });

    testWidgets('$label：平移结果钳制在 w100–w900', (tester) async {
      await pumpCard(tester, userWeight: 900, isCompact: isCompact);

      expect(renderedWeight(tester, '高等数学'), 900);
      expect(renderedWeight(tester, '张老师'), 900);
    });
  }

  testWidgets('没有 AppFontScope 时按设计字重渲染（预览/单测场景）', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            width: 220,
            height: 160,
            child: CourseCard(course: course()),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(renderedWeight(tester, '高等数学'), 700);
    expect(renderedWeight(tester, '张老师'), 400);
  });
}

