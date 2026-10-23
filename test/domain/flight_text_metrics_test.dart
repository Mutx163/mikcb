import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/domain/day_course_display_logic.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/widgets/course_card.dart';
import 'package:university_timetable/widgets/course_surface.dart';
import 'package:university_timetable/widgets/timetable/day_view/day_view_course_agenda_card_variants.dart';
import 'package:university_timetable/widgets/timetable/flight_text_metrics.dart';
import 'package:university_timetable/widgets/timetable/timetable_day_agenda_models.dart';

/// 「卡片对卡片」转场：两端文字锚点必须**对着真实卡片**成立（2026-10-23）。
///
/// 这是 `flight_text_metrics.dart` 的验收测试，不是它的抄写：
///
/// * 期望值来自**真实卡片**——测试真的泵起 `CourseCard(isCompact: true)` 与
///   `TimetableCourseAgendaDefaultCard`，用 `tester.getRect(find.text(...))` 取
///   屏幕上那一行的矩形。
/// * 被测的是纯函数 `measureCompactCardText` / `measureAgendaCardText`。
/// * 两边一比，容差 1.5dp。
///
/// 为什么必须有这条：用户三次反馈的第三条是「卡片里面的字不是平移过去的，
/// 而是开始的、动画上的、最终的，是三个位置」。病根就是飞行卡用了手写近似值。
/// 只要这条测试绿，「近似值」这条路就被钉死了；谁再改公式，这里立刻红。
TextStyle _lastBaseStyle = const TextStyle();
TextStyle _lastTitleStyle = const TextStyle();
TextStyle _lastInfoStyle = const TextStyle();

void main() {
  const zhLocale = Locale('zh');

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

  Future<void> pumpApp(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        locale: zhLocale,
        home: Scaffold(body: Center(child: child)),
      ),
    );
    await tester.pump();
  }

  group('周网格紧凑卡：复算的文字位置 == 真实卡片', () {
    /// 卡片表面尺寸 52×132（56 宽减去两侧 inset 2，136 高减去上下 2）。
    Future<Map<String, Rect>> realRects(
      WidgetTester tester, {
      required Size surfaceSize,
      required double verticalPadding,
      required double titleSize,
      required double subtitleSize,
    }) async {
      await pumpApp(
        tester,
        SizedBox(
          width: surfaceSize.width + 4,
          height: surfaceSize.height + 4,
          child: CourseCard(
            course: course,
            isCompact: true,
            compactTitleFontSize: titleSize,
            compactSubtitleFontSize: subtitleSize,
            compactVerticalPadding: verticalPadding,
          ),
        ),
      );
      final surfaceFinder = find
          .descendant(
            of: find.byType(CourseCard),
            matching: find.byType(CourseSurface),
          )
          .first;
      final surface = tester.getRect(surfaceFinder);
      _lastBaseStyle = DefaultTextStyle.of(
        tester.element(surfaceFinder),
      ).style;
      Rect rel(Rect r) => r.shift(-surface.topLeft);
      return {
        'name': rel(tester.getRect(find.text('高等数学'))),
        'teacher': rel(tester.getRect(find.text('张老师'))),
        'location': rel(tester.getRect(find.text('教三-201'))),
      };
    }

    List<CompactLineSpec> specs(double titleSize, double subtitleSize) => [
      CompactLineSpec(
        id: 'name',
        text: '高等数学',
        fontSize: titleSize,
        height: 1.15,
        weight: FontWeight.w700,
      ),
      CompactLineSpec(
        id: 'teacher',
        text: '张老师',
        fontSize: subtitleSize,
        height: 1.1,
      ),
      CompactLineSpec(
        id: 'location',
        text: '教三-201',
        fontSize: subtitleSize,
        height: 1.1,
      ),
    ];

    testWidgets('默认字号（9 / 8）、垂直居中', (tester) async {
      const surfaceSize = Size(52, 132);
      final real = await realRects(
        tester,
        surfaceSize: surfaceSize,
        verticalPadding: 6,
        titleSize: 9,
        subtitleSize: 8,
      );
      final computed = measureCompactCardText(
        surfaceSize: surfaceSize,
        verticalPadding: 6,
        baseStyle: _lastBaseStyle,
        lines: specs(9, 8),
      );
      for (final id in ['name', 'teacher', 'location']) {
        final want = real[id]!;
        final got = computed[id]!.rect;
        expect(
          got.top,
          closeTo(want.top, 1.5),
          reason: '$id 顶边对不上：真实 ${want.top} / 复算 ${got.top}',
        );
        expect(
          got.left,
          closeTo(want.left, 1.5),
          reason: '$id 左边对不上：真实 ${want.left} / 复算 ${got.left}',
        );
      }
    });

    test('矮格里 BoxFit.scaleDown 按同一系数缩（字与位置一起缩）', () {
      // 内高 = 40 - 12 = 28；内容高由折行决定（窄格里会多折几行），
      // 所以不写死系数，改断言两条必须成立的关系：
      //   ① 缩放真的发生（内容放不下）；
      //   ② 每一行的字号都是「设计字号 × 同一系数」——只缩位置不缩字号，
      //      读起来就是「字被裁掉」。
      final computed = measureCompactCardText(
        surfaceSize: const Size(52, 40),
        verticalPadding: 6,
        lines: specs(12, 11),
      );
      expect(computed.scale, lessThan(1));
      expect(computed.scale, greaterThan(0));
      expect(computed['name']!.fontSize, closeTo(12 * computed.scale, 1e-6));
      expect(
        computed['teacher']!.fontSize,
        closeTo(11 * computed.scale, 1e-6),
      );
      // 整块文字必须落在内高之内（否则就是被 `ClipRect` 裁掉一截）。
      final blockTop = computed.anchors.anchors.first.rect.top - 6;
      final blockBottom =
          computed.anchors.anchors.last.rect.bottom - 6;
      expect(blockBottom - blockTop, lessThanOrEqualTo(28 + 0.5));
    });

    testWidgets('放大字号（12 / 11）时仍对得上（同一份基底样式）', (tester) async {
      const surfaceSize = Size(52, 132);
      final real = await realRects(
        tester,
        surfaceSize: surfaceSize,
        verticalPadding: 6,
        titleSize: 12,
        subtitleSize: 11,
      );
      final computed = measureCompactCardText(
        surfaceSize: surfaceSize,
        verticalPadding: 6,
        baseStyle: _lastBaseStyle,
        lines: specs(12, 11),
      );
      for (final id in ['name', 'teacher', 'location']) {
        final want = real[id]!;
        final got = computed[id]!.rect;
        expect(
          got.top,
          closeTo(want.top, 1.5),
          reason: '$id 顶边对不上：真实 ${want.top} / 复算 ${got.top}',
        );
      }
      // 这一格高度够（内容 68 < 内高 120），`scaleDown` 不该触发；
      // 真要缩放的情形另有一条用例（矮格里必须按同一系数缩）。
      expect(computed.scale, 1.0);
    });
  });

  group('日视图议程卡：复算的文字位置 == 真实卡片', () {
    Future<Map<String, Rect>> realRects(
      WidgetTester tester, {
      required Size surfaceSize,
    }) async {
      const settings = TimetableSettings(sections: <SectionTime>[]);
      const palette = TimetableDayAgendaPalette(
        baseColor: Color(0xFFEF4444),
        fillColor: Color(0xFFEF4444),
        foregroundColor: Color(0xFF1A1A1A),
      );
      final item = DayCourseDisplayItem(
        course: course,
        isCurrentWeekCourse: true,
      );
      await pumpApp(
        tester,
        SizedBox(
          width: surfaceSize.width,
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
      final surfaceFinder = find
          .descendant(
            of: find.byType(TimetableCourseAgendaDefaultCard),
            matching: find.byType(CourseSurface),
          )
          .first;
      final surface = tester.getRect(surfaceFinder);
      final ctx = tester.element(surfaceFinder);
      _lastBaseStyle = DefaultTextStyle.of(ctx).style;
      _lastTitleStyle = Theme.of(ctx).textTheme.titleMedium ?? const TextStyle();
      _lastInfoStyle =
          Theme.of(ctx).textTheme.bodySmall ?? const TextStyle();
      Rect rel(Rect r) => r.shift(-surface.topLeft);
      final titleSize =
          tester
              .widget<Text>(find.text('高等数学'))
              .style
              ?.fontSize ??
          16;
      expect(titleSize, greaterThan(0));
      return {
        'name': rel(tester.getRect(find.text('高等数学'))),
        'time': rel(tester.getRect(find.text('08:00 - 09:40'))),
        'teacher': rel(tester.getRect(find.textContaining('教师'))),
        'location': rel(tester.getRect(find.textContaining('地点'))),
        'icon-teacher': rel(
          tester.getRect(find.byIcon(Icons.person_outline_rounded)),
        ),
        'icon-location': rel(
          tester.getRect(find.byIcon(Icons.location_on_outlined)),
        ),
        'icon-time': rel(tester.getRect(find.byIcon(Icons.schedule_rounded))),
      };
    }

    testWidgets('课名 / 时间 / 教师 / 地点 / 三个图标逐项对齐', (tester) async {
      const surfaceSize = Size(364, 180);
      final real = await realRects(tester, surfaceSize: surfaceSize);
      final l10n = await _pumpL10n(tester);
      final computed = measureAgendaCardText(
        surfaceSize: surfaceSize,
        name: '高等数学',
        teacherLine: '${l10n.teacherPrefix('张老师')} · ${l10n.sectionRangeLabel(1, 2)}',
        locationLine: l10n.locationPrefix('教三-201'),
        titleFontSize: _lastTitleStyle.fontSize ?? 16,
        baseStyle: _lastTitleStyle,
        infoBaseStyle: _lastInfoStyle,
        timeText: '08:00 - 09:40',
      );
      for (final id in real.keys) {
        final want = real[id]!;
        final got = computed[id];
        expect(got, isNotNull, reason: '复算里缺少 $id');
        expect(
          got!.rect.top,
          closeTo(want.top, 1.5),
          reason: '$id 顶边：真实 ${want.top} / 复算 ${got.rect.top}',
        );
        expect(
          got.rect.left,
          closeTo(want.left, 1.5),
          reason: '$id 左边：真实 ${want.left} / 复算 ${got.rect.left}',
        );
      }
    });

    testWidgets('长课名折成两行时，教师行跟着下移（锚点不是常数）', (tester) async {
      // 窄卡里长课名会折成 2 行：教师行的位置必须跟着变，否则飞行卡落点会压住课名。
      final computed = measureAgendaCardText(
        surfaceSize: const Size(180, 240),
        name: '高等数学与工程应用基础理论课程设计实践',
        teacherLine: '张老师 · 第1-2节',
        locationLine: '教三-201教室（东区）',
        titleFontSize: 16,
      );
      final single = measureAgendaCardText(
        surfaceSize: const Size(180, 240),
        name: '高数',
        teacherLine: '张老师 · 第1-2节',
        locationLine: '教三-201教室（东区）',
        titleFontSize: 16,
      );
      expect(
        computed['name']!.rect.height,
        greaterThan(single['name']!.rect.height),
        reason: '长课名应该折成两行',
      );
      expect(
        computed['teacher']!.rect.top,
        greaterThan(single['teacher']!.rect.top),
        reason: '课名变高后教师行必须下移',
      );
    });
  });

  group('两端插值：全程连续，没有断点', () {
    final compact = measureCompactCardText(
      surfaceSize: const Size(52, 132),
      verticalPadding: 6,
      lines: [
        const CompactLineSpec(
          id: 'name',
          text: '高等数学',
          fontSize: 9,
          height: 1.15,
          weight: FontWeight.w700,
        ),
        const CompactLineSpec(
          id: 'teacher',
          text: '张老师',
          fontSize: 8,
          height: 1.1,
        ),
      ],
    );
    final from = compact.anchors;
    final to = measureAgendaCardText(
      surfaceSize: const Size(364, 180),
      name: '高等数学',
      teacherLine: '教师：张老师 · 第1-2节',
      locationLine: '地点：教三-201',
      titleFontSize: 16,
      timeText: '08:00 - 09:40',
    );

    test('课名位置与字号全程单调（不回头）', () {
      // 方向由两端决定（网格卡文字偏下、议程卡偏上，实测 45.5 → 50.0 是向上），
      // 所以这里只断言「单调」：任何一次回头都读作「卡片抖了一下」。
      final tops = <double>[];
      final sizes = <double>[];
      for (var i = 0; i <= 20; i++) {
        final layout = lerpFlightLayout(
          from: from,
          to: to,
          surfaceSize: const Size(364, 180),
          t: i / 20,
        );
        final name = layout.items.firstWhere((item) => item.id == 'name');
        tops.add(name.rect.top);
        sizes.add(name.fontSize);
      }
      final topAscending = tops.first <= tops.last;
      for (var i = 1; i < tops.length; i++) {
        if (topAscending) {
          expect(
            tops[i],
            greaterThanOrEqualTo(tops[i - 1]),
            reason: '第 $i 帧课名顶边回退：${tops[i - 1]} → ${tops[i]}',
          );
        } else {
          expect(
            tops[i],
            lessThanOrEqualTo(tops[i - 1]),
            reason: '第 $i 帧课名顶边回退：${tops[i - 1]} → ${tops[i]}',
          );
        }
        expect(
          sizes[i],
          greaterThan(sizes[i - 1]),
          reason: '第 $i 帧课名字号没有递增：${sizes[i - 1]} → ${sizes[i]}',
        );
      }
    });

    test('两端都有字幕：透明度恒为 1（不闪）', () {
      for (var i = 0; i <= 20; i++) {
        final layout = lerpFlightLayout(
          from: from,
          to: to,
          surfaceSize: const Size(364, 180),
          t: i / 20,
        );
        for (final id in ['name', 'teacher']) {
          final item = layout.items.firstWhere((x) => x.id == id);
          expect(item.opacity, 1, reason: 't=${i / 20} 时 $id 被淡出了');
        }
      }
    });

    test('只有终点有的行：起点不可见、终点完全可见', () {
      final at0 = lerpFlightLayout(
        from: from,
        to: to,
        surfaceSize: const Size(364, 180),
        t: 0,
      );
      final at1 = lerpFlightLayout(
        from: from,
        to: to,
        surfaceSize: const Size(364, 180),
        t: 1,
      );
      expect(
        at0.items.firstWhere((x) => x.id == 'time').opacity,
        0,
        reason: '时间胶囊在起点必须完全不可见',
      );
      expect(
        at1.items.firstWhere((x) => x.id == 'time').opacity,
        1,
        reason: '时间胶囊在终点必须完全可见',
      );
    });

    test('端点逐值还原两端（t=0 与 t=1 各自贴合真实卡片）', () {
      final at0 = lerpFlightLayout(
        from: from,
        to: to,
        surfaceSize: const Size(52, 132),
        t: 0,
      );
      final at1 = lerpFlightLayout(
        from: from,
        to: to,
        surfaceSize: const Size(364, 180),
        t: 1,
      );
      final startName = from['name']!.rect;
      final endName = to['name']!.rect;
      expect(
        at0.items.firstWhere((x) => x.id == 'name').rect.top,
        closeTo(startName.top, 1e-9),
      );
      expect(
        at1.items.firstWhere((x) => x.id == 'name').rect.top,
        closeTo(endName.top, 1e-9),
      );
    });
  });
}

Future<AppLocalizations> _pumpL10n(WidgetTester tester) async {
  final ctx = tester.element(find.byType(Scaffold).last);
  return AppLocalizations.of(ctx)!;
}
