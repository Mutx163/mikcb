import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/widgets/course_card.dart';
import 'package:university_timetable/widgets/course_surface.dart';
import 'package:university_timetable/widgets/timetable/flight_card_body.dart';
import 'package:university_timetable/widgets/timetable/flight_card_factory.dart';
import 'package:university_timetable/widgets/timetable/timetable_day_agenda_models.dart';

/// 起点锚点在**开了周数 / 简介**时仍与真网格卡逐值一致（2026-10-24 补）。
///
/// ## 抓的是什么
///
/// 飞行卡的起点锚点由 `measureCompactCardText` 复算。它按「有哪几行」把整块文字
/// 垂直居中/靠上排 —— 行数错一行，**每一行都跟着偏**。
///
/// 旧实现里 `buildFlightCardPlan` 从来没收到周数 / 简介 / 天气这几行，于是用户
/// 一开「显示周数 / 显示简介」：真网格卡上多出两行、飞行卡按「没有这两行」排版
/// ⇒ 实测课名从 45.5 变成 19.5（偏 26dp），接管那一帧整块文字跳一下，那两行还
/// 会消失。
///
/// 这条测试把「真卡量到的位置」与「复算出来的锚点」逐行比，行数一旦对不上就会红。
void main() {
  const dayWidth = 50.0;
  const sectionHeight = 60.0;
  const surfaceSize = Size(46, 116);

  final course = Course(
    id: 'c1',
    name: '高等数学',
    teacher: '张老师',
    location: '教三-201',
    description: '第一章 极限',
    dayOfWeek: 1,
    startSection: 1,
    endSection: 2,
    startTime: '08:00',
    endTime: '09:40',
    color: '#ef4444',
  );

  Widget app(Widget child) => MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('zh'),
    home: Scaffold(body: Stack(children: [child])),
  );

  /// 泵一张真实网格紧凑卡，量出各行相对卡面的顶边。
  Future<Map<String, double>> realCardTops(
    WidgetTester tester,
    TimetableSettings settings,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      app(
        Positioned(
          top: 0,
          left: 0,
          width: dayWidth,
          height: 2 * sectionHeight,
          child: CourseCard(
            course: course,
            isCompact: true,
            compactTitleFontSize: settings.courseCardFontSize,
            compactSubtitleFontSize: (settings.courseCardFontSize - 1).clamp(
              7.0,
              14.0,
            ),
            compactVerticalPadding: sectionHeight < 64 ? 4 : 6,
            showName: settings.courseCardShowName,
            showTeacher: settings.courseCardShowTeacher,
            showLocation: settings.courseCardShowLocation,
            showWeeks: settings.courseCardShowWeeks,
            showDescription: settings.courseCardShowDescription,
          ),
        ),
      ),
    );
    await tester.pump();
    final surface = tester.getRect(
      find
          .descendant(of: find.byType(CourseCard), matching: find.byType(CourseSurface))
          .first,
    );
    double? top(String text) {
      final f = find.text(text);
      if (f.evaluate().isEmpty) return null;
      return tester.getRect(f.first).top - surface.top;
    }

    return {
      'name': ?top('高等数学'),
      'teacher': ?top('张老师'),
      'location': ?top('教三-201'),
    };
  }

  /// **工厂**（`buildFlightCard`）在 t=0 时给出的各行顶边（相对卡面）。
  ///
  /// ⚠️ 必须走工厂而不是自己调 `buildFlightCardPlan`：真正决定线上行为的是
  /// 「工厂有没有把周数/简介/时间标签传下去」。第一版这条测试自己构造 plan，
  /// 于是**把工厂的接线拆掉它照样绿**（反向验证抓到的）—— 测的是度量函数，
  /// 不是装配。
  Future<Map<String, double>> factoryTops(
    WidgetTester tester,
    TimetableSettings settings,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    late FlightCardBody body;
    await tester.pumpWidget(
      app(
        Builder(
          builder: (context) {
            body = buildFlightCard(
              context: context,
              settings: settings,
              course: course,
              palette: const TimetableDayAgendaPalette(
                baseColor: Color(0xFFEF4444),
                fillColor: Color(0xFFEF4444),
                foregroundColor: Color(0xFF1A1A1A),
              ),
              sectionHeight: sectionHeight,
              opacityScale: 1,
              gridSurface: surfaceSize,
              agendaSurface: const Size(364, 200),
              t: 0,
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    await tester.pump();
    return {for (final item in body.layout.items) item.id: item.rect.top};
  }

  testWidgets('默认设置：三行逐值一致（回归保护）', (tester) async {
    const settings = TimetableSettings(sections: <SectionTime>[]);
    final real = await realCardTops(tester, settings);
    final computed = await factoryTops(tester, settings);
    for (final id in ['name', 'teacher', 'location']) {
      expect(real[id], isNotNull, reason: '真卡应该有 $id 这一行');
      expect(
        computed[id],
        closeTo(real[id]!, 1.5),
        reason: '$id 顶边：真卡 ${real[id]} / 复算 ${computed[id]}',
      );
    }
  });

  testWidgets('开周数 + 简介：每一行仍然逐值一致（多出的行必须算进去）', (tester) async {
    const settings = TimetableSettings(
      sections: <SectionTime>[],
      courseCardShowWeeks: true,
      courseCardShowDescription: true,
    );
    final real = await realCardTops(tester, settings);
    final computed = await factoryTops(tester, settings);

    // 前提：这两行确实让真卡变高了（否则这条测试没有区分力）。
    const base = TimetableSettings(sections: <SectionTime>[]);
    final realBase = await realCardTops(tester, base);
    final realName = real['name'] ?? double.infinity;
    final baseName = realBase['name'] ?? double.infinity;
    expect(
      realName,
      lessThan(baseName - 5),
      reason:
          '前提不成立：开了周数+简介之后真卡的课名并没有上移（'
          '${realBase['name']} → ${real['name']}），那这条测试测不到东西',
    );

    for (final id in ['name', 'teacher', 'location']) {
      expect(
        computed[id],
        closeTo(real[id]!, 1.5),
        reason:
            '$id 顶边：真卡 ${real[id]} / 复算 ${computed[id]} —— 差得多说明'
            '「周数 / 简介」这几行没被算进起点锚点，接管那一帧整块文字会跳',
      );
    }
  });
}
