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

  group('议程卡的天气行 / 本节备注行（2026-10-27 补）', () {
    // 病根：旧实现只量到「地点」就返回，而真实议程卡在 location 之后还会挂
    // `DayCourseWeatherRow` 与本节备注行。于是开着「日卡显示天气」的人，飞行卡
    // 比真卡少 1~2 行 —— 卡片落地那一帧底部突然多出内容（用户口径的「开始的、
    // 动画上的、最终的，是三个位置」的尾巴）。
    //
    // 这里钉的是**两件事**：
    // 1. 传了天气/备注，测出来的锚点里就必须有这两行；
    // 2. 备注行必须排在天气行**下面**（不是和它重叠）—— 顺序错了等于少一行。

    FlightCardAnchors measure({
      String? weather,
      String? note,
      IconData? icon,
    }) =>
        measureAgendaCardText(
          surfaceSize: const Size(364, 260),
          name: '高等数学',
          teacherLine: '教师：张老师 · 第1-2节',
          locationLine: '地点：教三-201',
          titleFontSize: 16,
          timeText: '08:00 - 09:40',
          weatherText: weather,
          weatherIcon: icon,
          noteText: note,
        );

    test('不传天气/备注时不产生这两行（锚点集合与旧行为一致）', () {
      final anchors = measure();
      expect(anchors['weather'], isNull);
      expect(anchors['note'], isNull);
      expect(anchors['icon-weather'], isNull);
      expect(anchors['icon-note'], isNull);
      // 旧的四行必须原样都在，不能因为加功能把它们挤掉。
      for (final id in ['name', 'teacher', 'location', 'time']) {
        expect(anchors[id], isNotNull, reason: '缺少 $id');
      }
    });

    test('传了天气行：紧接地点行之下，且不与该行重叠', () {
      final anchors = measure(weather: '晴 23°');
      final location = anchors['location']!;
      final weather = anchors['weather']!;
      expect(
        weather.rect.top,
        greaterThan(location.rect.top),
        reason: '天气行必须在地点行之下',
      );
      expect(
        weather.rect.top,
        greaterThan(location.rect.bottom),
        reason: '天气行不能压在地点行上（真实卡有 5.5 的间距）',
      );
      expect(anchors['icon-weather']!.isIcon, isTrue);
    });

    test('天气图标跟随传入的现象图标，不是写死太阳', () {
      final sunny = measure(weather: '晴 23°', icon: Icons.wb_sunny_outlined);
      final rainy = measure(weather: '雨 18°', icon: Icons.umbrella_outlined);
      expect(sunny['icon-weather']!.icon, Icons.wb_sunny_outlined);
      expect(rainy['icon-weather']!.icon, Icons.umbrella_outlined);
    });

    test('备注行排在天气行下面（传了天气时备注重心必须下移一整行）', () {
      const note = '下次课带计算器';
      final withoutWeather = measure(note: note);
      final withWeather = measure(weather: '晴 23°', note: note);
      expect(
        withWeather['note']!.rect.top,
        greaterThan(withoutWeather['note']!.rect.top),
        reason: '天气行占位后，备注行必须往下让，否则两行会叠在一起',
      );
      expect(
        withWeather['note']!.rect.top,
        greaterThan(withWeather['weather']!.rect.bottom),
        reason: '备注行必须在天气行之下',
      );
    });

    test('空白字符串等于没传（不会占用一行高度）', () {
      // ⚠️ 天气这条必须传**纯空白**，不能传空串。
      // 第一版这里传的是 `''`，于是「有没有 trim」判据改坏也照样绿 ——
      // `isNotEmpty` 对 `''` 同样为 false，探针抓不到（2026-10-27 实测到）。
      // 真卡的风险点是 `'   '` 这种「看着空、字节非空」的值。
      final blank = measure(weather: '   ', note: '   ');
      expect(blank['weather'], isNull, reason: '纯空白天气不该占一行');
      expect(blank['note'], isNull, reason: '纯空白备注不该占一行');
      final empty = measure(weather: '', note: '');
      expect(empty['weather'], isNull, reason: '空串不该占一行');
      expect(empty['note'], isNull, reason: '空串不该占一行');
    });

    test('纯空白与有内容之间：只有后者的锚点比地点行低', () {
      // 把「有/无」的分界钉在**渲染结果**上，而不是只钉 `isNull`：
      // 传 `'   '` 时天气行必须完全不存在，传 `'晴 23°'` 时它必须比地点行低。
      final location = measure()['location']!;
      expect(measure(weather: '   ')['weather'], isNull);
      expect(
        measure(weather: '晴 23°')['weather']!.rect.top,
        greaterThan(location.rect.bottom),
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
