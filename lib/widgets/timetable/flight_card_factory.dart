import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../ui/app_fonts.dart';
import '../../models/course.dart';
import '../../models/timetable_settings.dart';
import 'flight_card_body.dart';
import 'flight_grid_metrics.dart';
import 'flight_text_metrics.dart';
import 'timetable_day_agenda_models.dart';

/// 组装「转场中那一张飞行卡」（2026-10-23 从 `timetable_day_view_part.dart` 搬出）。
///
/// ## 为什么单独成文件
///
/// 课表页主文件 + 日视图分片共用一条行数棘轮（只减不增，见
/// `test/architecture/god_file_unit_guard_test.dart`）。而这段代码**没有一处**
/// 依赖 `_TimetableScreenState` 的私有字段：调色板由调用方算好传进来，其余全是
/// 「按两端真实卡片的口径复算」。放在这里既能过棘轮，也能单独读。
///
/// ## 它保证什么
///
/// 用户三次反馈的第三条是「卡片里面的字是三个位置，圆角也是三个环节」。
/// 本文件把「两端各自长什么样」翻译成 `flight_text_metrics.dart` 的输入：
///
/// * **位置与字号**：两端每行字都按真实排版复算（不是手写近似值）；
/// * **圆角**：8 → 20 线性；
/// * **材质**：底色 / 渐变 / 投影 / 字色都与议程卡同源；
/// * **判定口径**：显示哪几行，逐个照抄两端真实卡片的开关（见
///   `buildFlightCardPlan` 的表格），任何一处不同都会让那一行中途消失或凭空出现。
FlightCardBody buildFlightCard({
  required BuildContext context,
  required TimetableSettings settings,
  required Course course,
  required TimetableDayAgendaPalette palette,
  required double sectionHeight,
  required double opacityScale,
  required Size gridSurface,
  required Size agendaSurface,
  required double t,
}) {
  final theme = Theme.of(context);
  final l10n = AppLocalizations.of(context)!;
  final teacherText = course.teacher.trim().isNotEmpty
      ? course.teacher.trim()
      : l10n.unknownTeacher;
  final locationText = course.location.trim().isNotEmpty
      ? course.location.trim()
      : l10n.unknownLocation;
  final sectionLabel = l10n.sectionRangeLabel(
    course.startSection,
    course.endSection,
  );

  final plan = buildFlightCardPlan(
    name: course.name,
    teacher: course.teacher,
    location: course.location,
    settings: settings,
    gridSurfaceSize: gridSurface,
    // 议程卡的锚点只依赖**宽度**（每行按顺序往下堆，高度只影响外框），
    // 而调用方量到的是整卡矩形 —— 直接用，宽高都真实。
    agendaSurfaceSize: agendaSurface,
    startTime: course.startTime,
    endTime: course.endTime,
    teacherLine: '${l10n.teacherPrefix(teacherText)} · $sectionLabel',
    locationLine: l10n.locationPrefix(locationText),
    gridVerticalPadding: sectionHeight < 64 ? 4 : 6,
    gridTitleFontSize: settings.courseCardFontSize,
    agendaTitleFontSize:
        theme.textTheme.titleMedium?.fontSize ?? flightEndTitleSize(context),
    gridBaseStyle: DefaultTextStyle.of(context).style,
    agendaBaseStyle: theme.textTheme.titleMedium ?? const TextStyle(),
    agendaInfoBaseStyle: theme.textTheme.bodySmall ?? const TextStyle(),
    gridAlignTop: settings.courseCardVerticalAlign == CourseCardVerticalAlign.top,
    gridCrossAxisAlignment: switch (settings.courseCardHorizontalAlign) {
      CourseCardHorizontalAlign.left => CrossAxisAlignment.start,
      CourseCardHorizontalAlign.right => CrossAxisAlignment.end,
      CourseCardHorizontalAlign.center => CrossAxisAlignment.center,
    },
    titleWeight: (fontSize) => _resolveWeight(context, 700, fontSize),
    detailWeight: (fontSize) => _resolveWeight(context, 400, fontSize),
    // 天气不传给飞行卡：网格卡上是「图标 + 短文案」、议程卡上是它自己那一行，
    // 两端文案口径不同。硬凑一行会在中途换字，比少一行更显眼（默认即 null）。
  );

  final k = t.clamp(0.0, 1.0);
  final surfaceRadius = flightStartCardRadius +
      (flightEndCardRadius - flightStartCardRadius) * k;
  final layout = lerpFlightLayout(
    from: plan.start,
    to: plan.end,
    surfaceSize: Size(
      gridSurface.width + (agendaSurface.width - gridSurface.width) * k,
      gridSurface.height + (agendaSurface.height - gridSurface.height) * k,
    ),
    t: t,
  );

  return FlightCardBody(
    settings: settings,
    progress: t,
    layout: layout,
    color: palette.fillColor,
    // 议程卡实体档的渐变（`baseColor → fillColor`）。网格卡实体档也是同色两段，
    // 两端都不会在落定那一帧「忽然多一层渐变」。
    gradientColors: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [palette.baseColor, palette.fillColor],
    ),
    radius: surfaceRadius,
    // 网格卡默认无投影（只有高亮课才有），议程卡恒定 16px / alpha 0.18。
    shadowOpacity: 0.18 * k,
    opacityScale: opacityScale,
    onCardColor: palette.foregroundColor,
  );
}

/// 把设计字重解析成运行时字重。
///
/// 必须走 `AppFontScope.resolveShiftedWeight`（与 `course_card.dart` 同一个入口）：
/// 用户把全局字重调粗时，网格卡的课名是 700、详情是 400，两者**各自平移**；
/// 飞行卡若写死 700/400，落地那一帧就会与真卡差一档。
FontWeight _resolveWeight(BuildContext context, int design, double fontSize) {
  // 与 `course_card.dart` 的 `_courseCardWeight` 同一个入口：无 scope 时原样返回。
  final resolved =
      AppFontScope.maybeOf(context)?.resolveShiftedWeight(design) ?? design;
  return FontWeight(resolved);
}
