import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/domain/day_course_display_logic.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/widgets/course_surface.dart';
import 'package:university_timetable/widgets/timetable/day_view/day_view_course_agenda_card_variants.dart';
import 'package:university_timetable/widgets/timetable/flight_card_body.dart';
import 'package:university_timetable/widgets/timetable/flight_card_factory.dart';
import 'package:university_timetable/widgets/timetable/timetable_day_agenda_models.dart';

/// 飞行卡的**落地一致性**：`t = 1` 那一帧必须与真实议程卡逐项吻合（2026-10-23）。
///
/// ## 为什么要单独测「渲染出来的位置」
///
/// `flight_text_metrics_test.dart` 已经证明「锚点算得对」，但那只是**数据**。
/// 数据对、渲染错的情况真实存在：把锚点放进 `Positioned` 时少减一层内边距、
/// 或者 `Stack` 不在卡片表面坐标里，都会让字整体偏一截 —— 而这条正是用户
/// 反复说的「落地那一下跳」。
///
/// 所以这里量的是**屏幕上那一行字的矩形**：分别泵真实议程卡与 `t = 1` 的飞行卡，
/// 逐项比对顶边 / 左边（容差 2dp），并额外验证 `t = 0` 时飞行卡的位置回落到
/// 周网格卡的锚点（而不是议程卡的）。
void main() {
  final course = Course(
    id: 'c1',
    name: '高等数学',
    teacher: '张老师',
    location: '教三-201',
    dayOfWeek: 3,
    startSection: 1,
    endSection: 2,
    startTime: '08:00',
    endTime: '09:40',
    color: '#ef4444',
  );

  const settings = TimetableSettings(sections: <SectionTime>[]);
  const palette = TimetableDayAgendaPalette(
    baseColor: Color(0xFFEF4444),
    fillColor: Color(0xFFEF4444),
    foregroundColor: Color(0xFF1A1A1A),
  );

  Future<void> pumpApp(WidgetTester tester, Widget child) async {
    await tester.binding.setSurfaceSize(const Size(400, 700));
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
        home: Scaffold(
          body: Align(alignment: Alignment.topLeft, child: child),
        ),
      ),
    );
    await tester.pump();
  }

  /// 卡片表面矩形（相对屏幕）。
  Rect surfaceRect(WidgetTester tester, Finder host) {
    final surface = find
        .descendant(of: host, matching: find.byType(CourseSurface))
        .first;
    return tester.getRect(surface);
  }

  Future<Map<String, Rect>> agendaTextRects(WidgetTester tester) async {
    final item = DayCourseDisplayItem(
      course: course,
      isCurrentWeekCourse: true,
    );
    await pumpApp(
      tester,
      SizedBox(
        width: 364,
        child: TimetableCourseAgendaDefaultCard(
          item: item,
          week: 1,
          settings: settings,
          radius: 20,
          palette: palette,
          statusBadges: const <Widget>[],
          cardDecoration: const BoxDecoration(),
          onTap: () {},
          onOpenNotes: () {},
          onOpenTask: () {},
          opacityScale: 1,
          courseDate: null,
        ),
      ),
    );
    final host = find.byType(TimetableCourseAgendaDefaultCard);
    final surface = surfaceRect(tester, host);
    Rect rel(Rect r) => r.shift(-surface.topLeft);
    return {
      'name': rel(tester.getRect(find.text('高等数学'))),
      'teacher': rel(tester.getRect(find.textContaining('教师'))),
      'location': rel(tester.getRect(find.textContaining('地点'))),
    };
  }

  Future<Map<String, Rect>> flightTextRects(
    WidgetTester tester, {
    required double t,
    required Size surfaceSize,
  }) async {
    late BuildContext context;
    await pumpApp(
      tester,
      Builder(
        builder: (ctx) {
          context = ctx;
          return SizedBox(
            width: surfaceSize.width,
            height: surfaceSize.height,
            child: buildFlightCard(
              context: ctx,
              settings: settings,
              course: course,
              palette: palette,
              sectionHeight: 60,
              opacityScale: 1,
              gridSurface: const Size(52, 132),
              agendaSurface: const Size(364, 180),
              t: t,
            ),
          );
        },
      ),
    );
    expect(context.mounted, isTrue);
    final host = find.byType(FlightCardBody);
    final surface = surfaceRect(tester, host);
    Rect rel(Rect r) => r.shift(-surface.topLeft);
    final result = <String, Rect>{};
    for (final entry in {
      'name': '高等数学',
      'teacher': AppLocalizations.of(context)!.teacherPrefix('张老师'),
      'location': AppLocalizations.of(context)!.locationPrefix('教三-201'),
    }.entries) {
      final finder = find.textContaining(entry.value);
      if (finder.evaluate().isEmpty) {
        continue;
      }
      result[entry.key] = rel(tester.getRect(finder.first));
    }
    return result;
  }

  group('t = 1：飞行卡落地那一帧与真实议程卡逐项吻合', () {
    testWidgets('课名 / 教师 /地点 的位置差 ≤ 2dp', (tester) async {
      final real = await agendaTextRects(tester);
      // 用同一个宽高再泵飞行卡（t=1）。
      final flight = await flightTextRects(
        tester,
        t: 1,
        surfaceSize: const Size(364, 180),
      );

      for (final key in ['name', 'teacher', 'location']) {
        expect(flight[key], isNotNull, reason: '飞行卡 t=1 缺少 $key 这一行');
        expect(
          flight[key]!.top,
          closeTo(real[key]!.top, 2.0),
          reason:
              '$key 顶边：真卡 ${real[key]!.top} / 飞行卡 ${flight[key]!.top}'
              ' —— 落地会跳一下',
        );
        expect(
          flight[key]!.left,
          closeTo(real[key]!.left, 2.0),
          reason:
              '$key 左边：真卡 ${real[key]!.left} / 飞行卡 ${flight[key]!.left}',
        );
      }
    });
  });

  group('t = 0：飞行卡起点回落到周网格卡的锚点', () {
    testWidgets('课名位置接近网格卡（不是议程卡的位置）', (tester) async {
      final flight = await flightTextRects(
        tester,
        t: 0,
        surfaceSize: const Size(52, 132),
      );
      final name = flight['name'];
      expect(name, isNotNull, reason: '起点必须有课名');
      // 网格卡（52×132、9sp）实测课名在 45.5 左右；议程卡是 50.0。
      // 断言「更接近 45.5 而不是 50」，即起点确实用了网格卡的排版。
      expect(
        (name!.top - 45.5).abs(),
        lessThan((name.top - 50.0).abs()),
        reason: '起点课名 top=${name.top}，看起来用的是议程卡的位置',
      );
      // 起点不该出现只有议程卡才有的时间胶囊。
      expect(
        find.textContaining('08:00 - 09:40'),
        findsNothing,
        reason: 't=0 时不该已经有时间胶囊（它在终点才淡入）',
      );
    });
  });

  group('材质与形状：圆角与投影跟着进度长出来', () {
    testWidgets('圆角 8 → 20，投影 0 → 0.18', (tester) async {
      await pumpApp(
        tester,
        Builder(
          builder: (ctx) => SizedBox(
            width: 200,
            height: 120,
            child: buildFlightCard(
              context: ctx,
              settings: settings,
              course: course,
              palette: palette,
              sectionHeight: 60,
              opacityScale: 1,
              gridSurface: const Size(52, 132),
              agendaSurface: const Size(364, 180),
              t: 0,
            ),
          ),
        ),
      );
      final start = tester.widget<FlightCardBody>(find.byType(FlightCardBody));
      expect(start.radius, closeTo(8, 1e-9));
      expect(start.shadowOpacity, closeTo(0, 1e-9));

      await pumpApp(
        tester,
        Builder(
          builder: (ctx) => SizedBox(
            width: 200,
            height: 120,
            child: buildFlightCard(
              context: ctx,
              settings: settings,
              course: course,
              palette: palette,
              sectionHeight: 60,
              opacityScale: 1,
              gridSurface: const Size(52, 132),
              agendaSurface: const Size(364, 180),
              t: 1,
            ),
          ),
        ),
      );
      final end = tester.widget<FlightCardBody>(find.byType(FlightCardBody));
      expect(end.radius, closeTo(20, 1e-9), reason: '落定圆角必须是真议程卡的 20');
      expect(
        end.shadowOpacity,
        closeTo(0.18, 1e-9),
        reason: '落定投影必须与议程卡的 0.18 同值（否则会「忽然长出投影」）',
      );
    });
  });
}
