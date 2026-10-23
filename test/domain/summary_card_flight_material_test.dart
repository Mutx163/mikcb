import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/domain/day_course_display_logic.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';
import 'package:university_timetable/widgets/timetable/day_view/day_view_ink_style.dart';
import 'package:university_timetable/widgets/timetable/day_view/day_view_summary_card.dart';
import 'package:university_timetable/widgets/course_surface.dart';
import 'package:university_timetable/widgets/timetable/flight_card_factory.dart';
import 'package:university_timetable/widgets/timetable/timetable_day_agenda_models.dart';
import 'package:university_timetable/widgets/timetable/summary_card_flight.dart';

/// 飞行中的摘要卡与**真摘要卡**是不是同一个材质（2026-10-23 补）。
///
/// ## 为什么这条必须单独钉
///
/// 用户口径：「这个新卡的是实体卡材质不一样」。
///
/// 第一版飞行摘要卡自己画了个 `DecoratedBox(color: 纯白)`，而真摘要卡走
/// `CourseSurface` —— 玻璃档下真卡是磨砂、飞行卡是实心白。起飞那一瞬间材质就
/// 换了，落定又换回来。几何测试（`summary_card_flight_test`）与渲染测试
/// （`_render_test`）**都抓不到**这个：它们只看位置、字号、有没有叉。
///
/// 所以这里断言的是**实现层面的同源**：两端都必须是 [CourseSurface]，且
/// style / color / 圆角 / 描边 / 投影都对齐。判据用 widget 树，不看像素 ——
/// 像素在测试宿主机上恒为实体档（`liveBlurSupported` 只认 Android/iOS），
/// 玻璃档根本渲染不出来，只有看「走的哪条路径」才验得动。
void main() {
  const settings = TimetableSettings(sections: <SectionTime>[]);
  const palette = TimetableDayAgendaPalette(
    baseColor: Color(0xFFEF4444),
    fillColor: Color(0xFFEF4444),
    foregroundColor: Color(0xFF1A1A1A),
  );
  final course = Course(
    id: 'c1',
    name: '高等数学',
    teacher: '张老师',
    location: '教三-201',
    dayOfWeek: 5,
    startSection: 1,
    endSection: 2,
    startTime: '08:00',
    endTime: '09:40',
    color: '#ef4444',
  );

  const spec = SummaryFlightSpec(
    startCell: Rect.fromLTWH(241.1, -40, 50.3, 40),
    endRect: Rect.fromLTWH(14, 14, 364, 107),
    weekdayLabel: '周五',
    cellDateLabel: '03/20',
    titleLabel: '03月20日 周五',
    metaLabel: '第 3 周',
    countLabel: '1 门课',
    fill: Color(0xFFFFFFFF),
    ink: Color(0xFF1A1A1A),
    mutedInk: Color(0x8A1A1A1A),
  );

  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.binding.setSurfaceSize(const Size(420, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: FrostedAppearanceScope(
          appearance: FrostedAppearance.defaults,
          child: Scaffold(
            body: Align(alignment: Alignment.topLeft, child: child),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('飞行摘要卡必须走 CourseSurface（不是自己画一个色块）', (tester) async {
    await pump(
      tester,
      SizedBox(
        width: 364,
        height: 107,
        child: Stack(
          children: [
            Positioned.fill(
              child: SummaryFlightCard(
                frame: lerpSummaryFlight(spec: spec, t: 1),
                settings: settings,
              ),
            ),
          ],
        ),
      ),
    );

    expect(
      find.descendant(
        of: find.byType(SummaryFlightCard),
        matching: find.byType(CourseSurface),
      ),
      findsOneWidget,
      reason:
          '飞行摘要卡必须走 CourseSurface。自己画 DecoratedBox 的话，玻璃档下真卡'
          '是磨砂、飞行卡是实心白 —— 用户 2026-10-23 报的「材质不一样」就是它。',
    );
  });

  testWidgets('飞行卡与真摘要卡的 surface 参数逐项同源', (tester) async {
    // 真摘要卡（t=1 时飞行卡应当与它完全一致）。
    final item = DayCourseDisplayItem(
      course: course,
      isCurrentWeekCourse: true,
    );
    await pump(
      tester,
      SizedBox(
        width: 364,
        child: TimetableDayViewSummaryCard(
          surfaceKey: null,
          settings: settings,
          week: 3,
          dateLabel: '03月20日 周五',
          isToday: true,
          currentCourse: null,
          courseItems: [item],
          scheduleItems: const [],
          agendaItems: const [],
          dayExams: const [],
          inkEnvironment: const DayViewInkEnvironment(backdropBlurOn: false),
          radius: 20,
          onClose: () {},
        ),
      ),
    );
    final real = tester.widget<CourseSurface>(find.byType(CourseSurface));

    // ⚠️ 用**生产构造器**（`buildSummaryFlightInput`）拿规格，不手写常量：
    // 手写的话测的是「我写的那个值」，而不是「线上真的会用的那个值」。第一版
    // 就是这么漏的 —— 手写 `Colors.white`，而真卡是 `theme.colors.background`
    // （0xFFFEF7FF，带一点紫的暖白），两端差一点色，正是用户报的「材质不一样」。
    await pump(
      tester,
      Builder(
        builder: (context) {
          final input = buildSummaryFlightInput(
            context: context,
            endRect: spec.endRect,
            settings: settings,
            week: 3,
            dayOfWeek: 5,
            inkEnvironment: const DayViewInkEnvironment(backdropBlurOn: false),
            isToday: true,
            courseCount: 1,
            scheduleCount: 0,
            taskCount: 0,
          );
          final frame = lerpSummaryFlight(
            spec: input.specInLayer(layerOrigin: Offset.zero, startCell: spec.startCell),
            t: 1,
          );
          expect(
            frame.fill,
            real.color,
            reason: '飞行的摘要卡底色必须等于真摘要卡的底色。手写白色 vs 主题背景色'
                '（${real.color}）差一点就是这个病。',
          );
          return SizedBox(
            width: 364,
            height: 107,
            child: Stack(
              children: [
                Positioned.fill(
                  child: SummaryFlightCard(frame: frame, settings: settings),
                ),
              ],
            ),
          );
        },
      ),
    );
    final flight = tester.widget<CourseSurface>(find.byType(CourseSurface));

    expect(
      flight.style,
      real.style,
      reason: '材质档必须同一档（玻璃 ↔ 玻璃、实体 ↔ 实体）。差一档就是「材质不一样」。',
    );
    expect(flight.color, real.color, reason: '卡面底色必须同源');
    expect(flight.borderRadius, real.borderRadius, reason: '圆角必须同值');
    expect(
       (flight.border?.top.width ?? 0) > 0,
      (real.border?.top.width ?? 0) > 0,
      reason: '描边要么两端都有、要么两端都没有（只有一边有会读作「换了张卡」）',
    );
    expect(
      (flight.outerShadow?.length ?? 0) > 0,
      (real.outerShadow?.length ?? 0) > 0,
      reason: '投影要么两端都有、要么两端都没有',
    );
    if (flight.outerShadow != null && real.outerShadow != null) {
      expect(
        flight.outerShadow!.first.blurRadius,
        real.outerShadow!.first.blurRadius,
        reason: '投影的模糊半径必须同值（形状不同会在落定那帧「变一下」）',
      );
      expect(
        flight.outerShadow!.first.offset,
        real.outerShadow!.first.offset,
      );
    }
  });

  testWidgets('课程卡与飞行卡都不许把玻璃面塞进 Opacity（会塌）', (tester) async {
    await pump(
      tester,
      SizedBox(
        width: 364,
        height: 107,
        child: Stack(
          children: [
            Positioned.fill(
              child: SummaryFlightCard(
                frame: lerpSummaryFlight(spec: spec, t: 0.5),
                settings: settings,
              ),
            ),
          ],
        ),
      ),
    );
    // 找出所有包着 CourseSurface 的 Opacity —— 有一个就说明玻璃会塌。
    final opacities = find.byType(Opacity);
    for (final element in opacities.evaluate()) {
      final hasSurfaceDescendant = find
          .descendant(
            of: find.byWidget(element.widget),
            matching: find.byType(CourseSurface),
          )
          .evaluate()
          .isNotEmpty;
      expect(
        hasSurfaceDescendant,
        isFalse,
        reason:
            '有 Opacity 包住了 CourseSurface（玻璃铁律）：BackdropFilter 进半透明'
            '层采不到身后内容，磨砂会塌成透明。只允许包文字与图标。',
      );
    }
    // 顺手确认确实有 Opacity 在包文字（否则上面的循环可能空转）。
    expect(opacities, findsWidgets, reason: '中途帧应该有淡入淡出的文字');
  });

  testWidgets('飞行的课程卡也不许用「纯色块」替代课程材质', (tester) async {
    // 课程卡那一侧同理（flight_card_body 走的是 DayViewAgendaSurface）。
    await pump(
      tester,
      SizedBox(
        width: 300,
        height: 120,
        child: Builder(
          builder: (context) => buildFlightCard(
            context: context,
            settings: settings,
            course: course,
            palette: palette,
            sectionHeight: 60,
            opacityScale: 1,
            gridSurface: const Size(52, 132),
            agendaSurface: const Size(300, 120),
            t: 0.5,
          ),
        ),
      ),
    );
    expect(
      find.byType(CourseSurface),
      findsOneWidget,
      reason: '飞行课程卡必须走 CourseSurface（与议程卡同一个材质出口）',
    );
  });
}
