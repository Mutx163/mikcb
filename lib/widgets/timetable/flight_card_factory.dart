import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../l10n/course_week_localizations.dart';
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
/// 计划缓存（2026-10-24 加）。
///
/// ## 为什么可以缓存
///
/// `buildFlightCardPlan` 的结果**只取决于输入，与进度 `t` 无关** —— 而转场期间
/// 每帧每张卡都会调它一次。实测单次约 **273µs**（内部 ~11 次 `TextPainter.layout`），
/// 8 张卡一帧就是 **2.2ms**，正好吃掉 60fps 预算的 13%。而它算出来的东西整场
/// 转场一个字节都没变。
///
/// 键包含**全部**输入（含字号、对齐、文字缩放、文案），所以命中必然是同一个答案；
/// 用户改设置 / 换主题时键跟着变，不会拿到旧计划。
///
/// 容量上限 64：一屏最多几十张卡，满了整体清空（比 LRU 简单，且这里的重建代价
/// 只是「下一帧各算一次」）。
final Map<Object, FlightCardPlan> _planCache = <Object, FlightCardPlan>{};

/// 命中缓存的 `buildFlightCardPlan`（见 [_planCache]）。
FlightCardPlan flightCardPlanFor({
  required String name,
  required String teacher,
  required String location,
  required TimetableSettings settings,
  required Size gridSurfaceSize,
  required Size agendaSurfaceSize,
  required String startTime,
  required String endTime,
  required String teacherLine,
  required String locationLine,
  String? weeksText,
  String? descriptionText,
  required double gridVerticalPadding,
  required double gridTitleFontSize,
  required double agendaTitleFontSize,
  required TextStyle gridBaseStyle,
  required TextStyle agendaBaseStyle,
  required TextStyle agendaInfoBaseStyle,
  required bool gridAlignTop,
  required CrossAxisAlignment gridCrossAxisAlignment,
  required TitleWeightResolver titleWeight,
  required TitleWeightResolver detailWeight,
}) {
  // 字重解析器是闭包（不可比较），用它的两个设计值参与键即可 —— 同一个调用点
  // 传进来的解析器行为只由那两件事决定（见 `_resolveWeight`）。
  final key = (
    name,
    teacher,
    location,
    settings.courseCardFontSize,
    settings.courseCardVerticalAlign,
    settings.courseCardHorizontalAlign,
    gridSurfaceSize,
    agendaSurfaceSize,
    startTime,
    endTime,
    teacherLine,
    locationLine,
    weeksText,
    descriptionText,
    gridVerticalPadding,
    gridTitleFontSize,
    agendaTitleFontSize,
    gridBaseStyle,
    agendaBaseStyle,
    agendaInfoBaseStyle,
    gridAlignTop,
    gridCrossAxisAlignment,
  );
  final hit = _planCache[key];
  if (hit != null) {
    return hit;
  }
  if (_planCache.length > 64) {
    _planCache.clear();
  }
  final plan = buildFlightCardPlan(
    name: name,
    teacher: teacher,
    location: location,
    settings: settings,
    gridSurfaceSize: gridSurfaceSize,
    agendaSurfaceSize: agendaSurfaceSize,
    startTime: startTime,
    endTime: endTime,
    teacherLine: teacherLine,
    locationLine: locationLine,
    weeksText: weeksText,
    descriptionText: descriptionText,
    gridVerticalPadding: gridVerticalPadding,
    gridTitleFontSize: gridTitleFontSize,
    agendaTitleFontSize: agendaTitleFontSize,
    gridBaseStyle: gridBaseStyle,
    agendaBaseStyle: agendaBaseStyle,
    agendaInfoBaseStyle: agendaInfoBaseStyle,
    gridAlignTop: gridAlignTop,
    gridCrossAxisAlignment: gridCrossAxisAlignment,
    titleWeight: titleWeight,
    detailWeight: detailWeight,
  );
  _planCache[key] = plan;
  return plan;
}

/// 测试用：清掉计划缓存（静态状态会跨用例残留）。
@visibleForTesting
void resetFlightCardPlanCacheForTest() => _planCache.clear();

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
  // ── 网格卡上「只有起点才有」的那几行（2026-10-24 补）──────────────
  //
  // 旧实现一个都没传，于是：①用户开了「显示周数 / 简介」时，真网格卡上有那几行、
  // 飞行卡没有 —— 接管那一帧它们消失；②更要命的是 `measureCompactCardText` 按
  // 「没有这几行」把整块文字居中，于是**每一行都偏**（实测开周数+简介+天气后
  // 课名从 45.5 变成 19.5，偏 26dp）。
  //
  // 文案口径照抄 `course_card.dart`：周数走 `course.weekDescription`，
  // 时间在 `courseCardShowTimeLabels` 开着时带「开始/结束」前缀（真卡那两行是
  // 分开画的，所以这里也分成 time / time-end）。
  final showTimeLabels = settings.courseCardShowTimeLabels;
  final startTimeText = showTimeLabels
      ? l10n.classStartsAtLabel(course.startTime)
      : course.startTime;
  final endTimeText = showTimeLabels
      ? l10n.classEndsAtLabel(course.endTime)
      : course.endTime;
  final weeksText = settings.courseCardShowWeeks
      ? course.weekDescription(l10n)
      : null;
  final descriptionText = settings.courseCardShowDescription
      ? course.description?.trim()
      : null;

  final plan = flightCardPlanFor(
    name: course.name,
    teacher: course.teacher,
    location: course.location,
    settings: settings,
    gridSurfaceSize: gridSurface,
    // 议程卡的锚点只依赖**宽度**（每行按顺序往下堆，高度只影响外框），
    // 而调用方量到的是整卡矩形 —— 直接用，宽高都真实。
    agendaSurfaceSize: agendaSurface,
    teacherLine: '${l10n.teacherPrefix(teacherText)} · $sectionLabel',
    locationLine: l10n.locationPrefix(locationText),
    startTime: startTimeText,
    endTime: endTimeText,
    weeksText: weeksText,
    descriptionText: descriptionText,
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
