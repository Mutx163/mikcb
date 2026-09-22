import 'package:flutter/material.dart';
import 'package:university_timetable/l10n/app_localizations.dart';

import '../models/course.dart';
import '../models/timetable_settings.dart';
import '../utils/course_color_palette.dart';
import '../utils/hex_color.dart';
import '../ui/app_fonts.dart';
import '../ui/hyperos/hyperos_theme.dart';
import 'course_surface.dart';
import 'course_weather_display.dart';

/// 课卡文本的设计字重。
///
/// 课卡的主次完全靠字重表达（标题粗、详情常规），因此不能像
/// [HyperosTypography] 那样被全局字重绝对覆盖——那会把标题和详情压成同一
/// 档，卡片失去层级。改用 [AppFontScope.resolveShiftedWeight] 整体平移：
/// 用户调粗时两者同步变粗，差值保留。
const int _kCourseCardTitleWeight = 700;
const int _kCourseCardDetailWeight = 400;

/// 把课卡的设计字重解析成运行时字重；无 scope（单测/预览）时原样返回。
int _courseCardWeight(BuildContext context, int designWeight) =>
    AppFontScope.maybeOf(
      context,
    )?.resolveShiftedWeight(designWeight) ??
    designWeight;

class CourseCard extends StatelessWidget {
  final Course course;
  final VoidCallback? onTap;
  final bool isCompact;
  final bool showName;
  final bool showTeacher;
  final bool showLocation;
  final bool showTime;
  final bool showTimeLabels;
  final bool showWeeks;
  final bool showDescription;

  /// 这节课时段内的天气（图标 + 已本地化文案）；null = 不显示这一行。
  ///
  /// 由调用方算好传进来而不是在这里查 `WeatherProvider`：本部件同时被首页周网格、
  /// 设置页预览与**导出分享图**的离屏树使用，后者不能出现天气（用户明确选了
  /// 分享图不带天气），显式传 null 比「靠环境里有没有 provider」可靠得多。
  final CourseWeatherDisplay? weather;

  final CourseCardVerticalAlign verticalAlign;
  final CourseCardHorizontalAlign horizontalAlign;
  final double compactTitleFontSize;
  final double compactSubtitleFontSize;
  final double compactVerticalPadding;
  final double compactOuterInset;
  final String? overrideColorHex;
  final String? titleColorHex;
  final String? detailColorHex;

  /// Surface material style behind the card content (solid / translucent /
  /// gaussian).
  final CourseCardSurfaceStyle surfaceStyle;

  /// 壁纸带亮度（0–1），仅玻璃（高斯模糊）档使用：与课程 tint 各 50% 混合
  /// 判定自动黑白（彩色墨回落、中性墨对比度门槛）。实体卡忽略；为 null
  /// （无壁纸 / 采样未完成）时玻璃档维持旧行为保留用户墨色。
  final double? wallpaperLuminance;

  /// Dim factor for conflict / holiday / suspended states (0–1); scales the
  /// surface fill and tint alphas.
  final double surfaceOpacity;
  final String? compactOverlineText;
  final String? topRightBadgeText;

  /// Shows a circular reminder bell on the top-right badge row（日课表：
  /// 这节课已设置单节课提醒）。与备注角标并排展示。
  final bool hasReminder;

  /// Shows a circular homework indicator on the card (typically week view).
  final bool showHomeworkIndicator;
  final bool isHighlighted;
  final bool isHoliday;
  final bool isSuspended;

  const CourseCard({
    super.key,
    required this.course,
    this.onTap,
    this.isCompact = false,
    this.showName = true,
    this.showTeacher = true,
    this.showLocation = true,
    this.showTime = false,
    this.showTimeLabels = true,
    this.showWeeks = false,
    this.showDescription = false,
    this.weather,
    this.verticalAlign = CourseCardVerticalAlign.center,
    this.horizontalAlign = CourseCardHorizontalAlign.center,
    this.compactTitleFontSize = 9,
    this.compactSubtitleFontSize = 8,
    this.compactVerticalPadding = 6,
    this.compactOuterInset = 2,
    this.overrideColorHex,
    this.titleColorHex,
    this.detailColorHex,
    this.surfaceStyle = CourseCardSurfaceStyle.solid,
    this.wallpaperLuminance,
    this.surfaceOpacity = 1.0,
    this.compactOverlineText,
    this.topRightBadgeText,
    this.hasReminder = false,
    this.showHomeworkIndicator = false,
    this.isHighlighted = false,
    this.isHoliday = false,
    this.isSuspended = false,
  });

  Color _parseColor(String colorString) {
    return parseHexColorOrFallback(
      colorString,
      fallback: const Color(0xFF2196F3),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = _parseColor(overrideColorHex ?? course.color);
    // 可读性兜底：实心卡面上自定义字色与卡色同色系时（如蓝字配蓝卡）替换
    // 为黑白最优墨；玻璃卡面上按壁纸亮度做玻璃规则（彩色墨回落自动黑白、
    // 中性墨对比度门槛），壁纸亮度未知时保留用户选择。
    final surfaceShowsWallpaper = courseCardSurfaceShowsWallpaper(
      surfaceStyle,
    );
    final titleColor = resolveReadableCourseCardTitleColor(
      preferred: titleColorHex != null
          ? _parseColor(titleColorHex!)
          : Colors.white,
      cardColor: color,
      surfaceShowsWallpaper: surfaceShowsWallpaper,
      wallpaperLuminance: wallpaperLuminance,
    );
    // 详情墨：实心卡面与标题墨同极性（白标题不再配黑简介）；玻璃卡面在
    // 壁纸亮度已知时一律跟随标题墨软化。
    final detailColor = resolveReadableCourseCardDetailColor(
      preferred: detailColorHex != null
          ? _parseColor(detailColorHex!)
          : Colors.white,
      resolvedTitleInk: titleColor,
      cardColor: color,
      surfaceShowsWallpaper: surfaceShowsWallpaper,
      wallpaperLuminance: wallpaperLuminance,
    );

    if (isCompact) {
      return _buildCompactCard(context, color, titleColor, detailColor);
    }

    return _buildFullCard(context, color, titleColor, detailColor);
  }

  Widget _buildFullCard(
    BuildContext context,
    Color color,
    Color titleColor,
    Color detailColor,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final detailLines = _buildDetailLines(context, detailColor);
    final titleAlignment = _contentAlignment;
    final titleTextAlign = _textAlign;

    // Content layout (shared between full and compact paths).
    final content = Stack(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showName)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        course.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight(
                            _courseCardWeight(
                              context,
                              _kCourseCardTitleWeight,
                            ),
                          ),
                          color: titleColor,
                        ),
                        textAlign: titleTextAlign,
                        softWrap: true,
                      ),
                    ),
                    if (showName)
                      Align(
                        alignment: titleAlignment,
                        child: Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            l10n.sectionRangeLabel(
                              course.startSection,
                              course.endSection,
                            ),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight(
                                _courseCardWeight(
                                  context,
                                  _kCourseCardDetailWeight,
                                ),
                              ),
                              color: titleColor,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              if (showName && detailLines.isNotEmpty) const SizedBox(height: 8),
              ...detailLines,
            ],
          ),
        ),
        if (showHomeworkIndicator)
          Positioned(
            top: 8,
            left: 8,
            child: _buildHomeworkIndicator(size: 18, iconSize: 11),
          ),
        if (topRightBadgeText != null || hasReminder)
          Positioned(
            top: 8,
            right: 8,
            child: _buildBadgeRow(
              context,
              customBadgeText: topRightBadgeText,
              showReminderBell: hasReminder,
            ),
          ),
        if (isHoliday && topRightBadgeText == null && !hasReminder)
          Positioned(
            top: 8,
            right: 8,
            child: _buildBadgeRow(
              context,
              showHoliday: true,
              showReminderBell: hasReminder,
            ),
          ),
        if (isSuspended &&
            topRightBadgeText == null &&
            !isHoliday &&
            !hasReminder)
          Positioned(
            top: 8,
            right: 8,
            child: _buildBadgeRow(
              context,
              showSuspended: true,
              showReminderBell: hasReminder,
            ),
          ),
      ],
    );

    // Tap target with ink ripple, identical to the day-view approach.
    final tapTarget = onTap != null
        ? Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: content,
            ),
          )
        : content;

    // Use CourseSurface (same as _buildCompactCard) instead of Material Card +
    // inner Container gradient. The old Card wrapper added its own default
    // background color (surfaceContainerLow), creating a "card within a card"
    // look around the inner gradient's rounded corners. CourseSurface paints
    // the surface in one pass and supports the solid, translucent, and
    // gaussian styles.
    final card = Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: CourseSurface(
        style: surfaceStyle,
        color: color,
        borderRadius: 12,
        opacityScale: surfaceOpacity,
        solidGradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withValues(alpha: 0.9), color.withValues(alpha: 0.7)],
        ),
        outerShadow: isHighlighted
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.28),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
        border: isHighlighted
            ? Border.all(
                color: Colors.white.withValues(alpha: 0.92),
                width: 1.6,
              )
            : null,
        child: tapTarget,
      ),
    );

    if (isHoliday) {
      return Opacity(opacity: 0.3, child: card);
    }
    if (isSuspended) {
      return Opacity(opacity: 0.4, child: card);
    }
    return card;
  }

  Widget _buildCompactCard(
    BuildContext context,
    Color color,
    Color titleColor,
    Color detailColor,
  ) {
    final textLines = _buildCompactTextLines(context, titleColor, detailColor);
    final crossAxisAlignment = _crossAxisAlignment;
    final textAlign = _textAlign;

    final card = GestureDetector(
      onTap: onTap,
      child: SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Colors.transparent),
            Padding(
              padding: EdgeInsets.all(compactOuterInset),
              child: CourseSurface(
                style: surfaceStyle,
                color: color,
                borderRadius: 8,
                opacityScale: surfaceOpacity,
                border: isHighlighted
                    ? Border.all(
                        color: Colors.white.withValues(alpha: 0.9),
                        width: 1.2,
                      )
                    : null,
                boxShadow: isHighlighted
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.24),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ]
                    : null,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: compactVerticalPadding,
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        child: ClipRect(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final content = Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: crossAxisAlignment,
                                children: [
                                  for (
                                    var i = 0;
                                    i < textLines.length;
                                    i++
                                  ) ...[
                                    if (i > 0) const SizedBox(height: 2),
                                    _compactLineWidget(textLines[i], textAlign),
                                  ],
                                ],
                              );

                              if (verticalAlign ==
                                  CourseCardVerticalAlign.spaceEvenly) {
                                return FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: SizedBox(
                                    width: constraints.maxWidth,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceEvenly,
                                      crossAxisAlignment: crossAxisAlignment,
                                      children: [
                                        for (final line in textLines)
                                          _compactLineWidget(line, textAlign),
                                      ],
                                    ),
                                  ),
                                );
                              }

                              return Align(
                                alignment: _verticalContentAlignment,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: _verticalContentAlignment,
                                  child: SizedBox(
                                    width: constraints.maxWidth,
                                    child: content,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (showHomeworkIndicator)
              Positioned(
                top: 4,
                left: 4,
                child: _buildHomeworkIndicator(size: 15, iconSize: 9),
              ),
            if (topRightBadgeText != null || hasReminder)
              Positioned(
                top: 6,
                right: 6,
                child: _buildBadgeRow(
                  context,
                  customBadgeText: topRightBadgeText,
                  showReminderBell: hasReminder,
                ),
              ),
            if (isHoliday && topRightBadgeText == null && !hasReminder)
              Positioned(
                top: 6,
                right: 6,
                child: _buildBadgeRow(
                  context,
                  showHoliday: true,
                  showReminderBell: hasReminder,
                ),
              ),
            if (isSuspended &&
                topRightBadgeText == null &&
                !isHoliday &&
                !hasReminder)
              Positioned(
                top: 6,
                right: 6,
                child: _buildBadgeRow(
                  context,
                  showSuspended: true,
                  showReminderBell: hasReminder,
                ),
              ),
          ],
        ),
      ),
    );

    if (isHoliday) {
      return Opacity(opacity: 0.3, child: card);
    }
    if (isSuspended) {
      return Opacity(opacity: 0.4, child: card);
    }
    return card;
  }

  /// 一行紧凑卡文本；带图标时是「图标 + 文字」，否则就是纯文字。
  ///
  /// 图标尺寸按同行字号推导（而不是写死 dp）：整块内容会被外层
  /// `FittedBox(scaleDown)` 等比缩放，写死的尺寸会让图标在字号调大调小时
  /// 与文字比例失衡。颜色跟随该行的文字色，深色卡面自动可读。
  Widget _compactLineWidget(_CompactTextLine line, TextAlign textAlign) {
    final icon = line.icon;
    // 带图标的行（目前只有天气行）**锁死单行**，超出用省略号。
    //
    // 它与其他行的性质不同：课名/教师/地点折行只是多占一行，而这一行是
    // 「图标 + 一项内容」，一旦折行，掉到第二行的那半截既没有图标顶着、
    // 又把整块内容撑高——外层 `FittedBox` 随即把整张卡（含课名）等比缩小，
    // 同一屏里就会出现「有天气的卡字小、没天气的卡字大」。窄格里省掉那几个字
    // 比这个代价小得多。
    final text = Text(
      line.text,
      style: line.style,
      textAlign: textAlign,
      softWrap: icon == null,
      maxLines: icon == null ? null : 1,
      overflow: icon == null ? null : TextOverflow.ellipsis,
    );
    if (icon == null) {
      return text;
    }
    final fontSize = line.style.fontSize ?? 9;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: fontSize * 1.25, color: line.style.color),
        SizedBox(width: fontSize * 0.5),
        // Flexible 而不是 Expanded：文字按自身宽度收紧，短文案不会把整行撑满，
        // 横向对齐（左/中/右）仍由外层 Column 的 crossAxisAlignment 决定。
        Flexible(child: text),
      ],
    );
  }

  /// Circular outlined badge used for per-session homework marks.
  Widget _buildHomeworkIndicator({
    required double size,
    required double iconSize,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.95),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.assignment_outlined,
        size: iconSize,
        color: HyperosColors.destructive,
      ),
    );
  }

  /// 圆形提醒铃铛角标：样式与作业角标一致，颜色用主题蓝以示区分。
  Widget _buildReminderIndicator() {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.95),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: const Icon(
        Icons.alarm_on_rounded,
        size: 10,
        color: Color(0xFF2563EB),
      ),
    );
  }

  Widget _buildBadge(BuildContext context, String text, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color ?? Colors.red.shade600,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight(
            _courseCardWeight(context, _kCourseCardTitleWeight),
          ),
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildBadgeRow(
    BuildContext context, {
    String? customBadgeText,
    bool showHoliday = false,
    bool showSuspended = false,
    bool showReminderBell = false,
  }) {
    final l10n = AppLocalizations.of(context);
    final badges = <Widget>[];
    if (showReminderBell) {
      badges.add(_buildReminderIndicator());
    }
    if (showHoliday && l10n != null) {
      badges.add(
        _buildBadge(
          context,
          l10n.holidayBadgeLabel,
          color: Colors.orange.shade700,
        ),
      );
    }
    if (showSuspended && l10n != null) {
      badges.add(
        _buildBadge(
          context,
          l10n.suspendedBadgeLabel,
          color: Colors.red.shade700,
        ),
      );
    }
    if (customBadgeText != null) {
      badges.add(_buildBadge(context, customBadgeText));
    }
    if (badges.isEmpty) return const SizedBox.shrink();
    if (badges.length == 1) return badges.first;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < badges.length; i++) ...[
          if (i > 0) const SizedBox(width: 3),
          badges[i],
        ],
      ],
    );
  }

  List<Widget> _buildDetailLines(BuildContext context, Color detailColor) {
    final lines = <Widget>[];
    if (showTeacher && course.teacher.trim().isNotEmpty) {
      lines.add(
        _buildDetailRow(context, Icons.person, course.teacher, detailColor),
      );
    }
    if (showLocation && course.location.trim().isNotEmpty) {
      if (lines.isNotEmpty) lines.add(const SizedBox(height: 4));
      lines.add(
        _buildDetailRow(
          context,
          Icons.location_on,
          course.location,
          detailColor,
        ),
      );
    }
    if (showTime) {
      if (lines.isNotEmpty) lines.add(const SizedBox(height: 4));
      lines.add(
        _buildDetailRow(
          context,
          Icons.access_time,
          _buildTimeText(context, isCompact: false),
          detailColor,
        ),
      );
    }
    if (showWeeks) {
      if (lines.isNotEmpty) lines.add(const SizedBox(height: 4));
      lines.add(
        _buildDetailRow(
          context,
          Icons.date_range_rounded,
          _buildWeekText(context),
          detailColor,
        ),
      );
    }
    if (showDescription && (course.description?.trim().isNotEmpty ?? false)) {
      if (lines.isNotEmpty) lines.add(const SizedBox(height: 4));
      lines.add(
        _buildDetailRow(
          context,
          Icons.notes_rounded,
          course.description!.trim(),
          detailColor,
        ),
      );
    }
    return lines;
  }

  Widget _buildDetailRow(
    BuildContext context,
    IconData icon,
    String text,
    Color detailColor,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: detailColor),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight(
                _courseCardWeight(context, _kCourseCardDetailWeight),
              ),
              color: detailColor,
              height: 1.15,
            ),
            softWrap: true,
          ),
        ),
      ],
    );
  }

  List<_CompactTextLine> _buildCompactTextLines(
    BuildContext context,
    Color titleColor,
    Color detailColor,
  ) {
    final l10n = AppLocalizations.of(context)!;
    // 网格卡的字号小、行距紧，层级只能靠字重区分：标题与详情各自按角色
    // 平移用户全局字重，不能压成同一档。
    final titleWeight = FontWeight(
      _courseCardWeight(context, _kCourseCardTitleWeight),
    );
    final detailWeight = FontWeight(
      _courseCardWeight(context, _kCourseCardDetailWeight),
    );
    final lines = <_CompactTextLine>[];
    if (compactOverlineText?.trim().isNotEmpty ?? false) {
      lines.add(
        _CompactTextLine(
          text: compactOverlineText!.trim(),
          flex: 1,
          style: TextStyle(
            fontSize: (compactSubtitleFontSize - 1).clamp(6.0, 12.0),
            fontWeight: detailWeight,
            color: detailColor,
            height: 1.05,
          ),
        ),
      );
    }
    if (showName) {
      lines.add(
        _CompactTextLine(
          text: course.name,
          flex: 4,
          style: TextStyle(
            fontSize: compactTitleFontSize,
            fontWeight: titleWeight,
            color: titleColor,
            height: 1.15,
          ),
        ),
      );
    }
    if (showTeacher && course.teacher.trim().isNotEmpty) {
      lines.add(
        _CompactTextLine(
          text: course.teacher.trim(),
          flex: 2,
          style: TextStyle(
            fontSize: compactSubtitleFontSize,
            fontWeight: detailWeight,
            color: detailColor,
            height: 1.1,
          ),
        ),
      );
    }
    if (showLocation && course.location.trim().isNotEmpty) {
      lines.add(
        _CompactTextLine(
          text: course.location.trim(),
          flex: 2,
          style: TextStyle(
            fontSize: compactSubtitleFontSize,
            fontWeight: detailWeight,
            color: detailColor,
            height: 1.1,
          ),
        ),
      );
    }
    if (showTime) {
      lines.addAll([
        _CompactTextLine(
          text: showTimeLabels
              ? l10n.classStartsAtLabel(course.startTime)
              : course.startTime,
          flex: 2,
          style: TextStyle(
            fontSize: compactSubtitleFontSize,
            fontWeight: detailWeight,
            color: detailColor,
            height: 1.1,
          ),
        ),
        _CompactTextLine(
          text: showTimeLabels
              ? l10n.classEndsAtLabel(course.endTime)
              : course.endTime,
          flex: 2,
          style: TextStyle(
            fontSize: compactSubtitleFontSize,
            fontWeight: detailWeight,
            color: detailColor,
            height: 1.1,
          ),
        ),
      ]);
    }
    if (showWeeks) {
      lines.add(
        _CompactTextLine(
          text: _buildWeekText(context),
          flex: 2,
          style: TextStyle(
            fontSize: compactSubtitleFontSize,
            fontWeight: detailWeight,
            color: detailColor,
            height: 1.1,
          ),
        ),
      );
    }
    if (showDescription && (course.description?.trim().isNotEmpty ?? false)) {
      lines.add(
        _CompactTextLine(
          text: course.description!.trim(),
          flex: 3,
          style: TextStyle(
            fontSize: compactSubtitleFontSize,
            fontWeight: detailWeight,
            color: detailColor,
            height: 1.1,
          ),
        ),
      );
    }
    if (lines.isEmpty) {
      // 一个字段都没开时也要有课名，否则卡片上只剩天气/空白。
      lines.add(
        _CompactTextLine(
          text: course.name,
          flex: 1,
          style: TextStyle(
            fontSize: compactTitleFontSize,
            fontWeight: titleWeight,
            color: titleColor,
            height: 1.15,
          ),
        ),
      );
    }
    // 天气排在最后：上面那些是「这门课是什么」的自身字段，天气是外部环境信息。
    // 也刻意放在课名兜底之后——兜底判的是「课卡自身字段是不是全关了」，
    // 天气不算课卡字段，不该把兜底顶掉。
    final weather = this.weather;
    if (weather != null) {
      lines.add(
        _CompactTextLine(
          text: weather.text,
          flex: 2,
          icon: weather.icon,
          style: TextStyle(
            fontSize: compactSubtitleFontSize,
            fontWeight: detailWeight,
            color: detailColor,
            height: 1.1,
          ),
        ),
      );
    }
    return lines;
  }

  String _buildWeekText(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return course.weekDescription(l10n);
  }

  String _buildTimeText(BuildContext context, {required bool isCompact}) {
    final l10n = AppLocalizations.of(context)!;
    final start = showTimeLabels
        ? l10n.classStartsAtLabel(course.startTime)
        : course.startTime;
    final end = showTimeLabels
        ? l10n.classEndsAtLabel(course.endTime)
        : course.endTime;
    return isCompact ? '$start\n$end' : '$start\n$end';
  }

  Alignment get _verticalContentAlignment => switch (verticalAlign) {
    CourseCardVerticalAlign.top => Alignment.topCenter,
    CourseCardVerticalAlign.center => Alignment.center,
    CourseCardVerticalAlign.bottom => Alignment.bottomCenter,
    CourseCardVerticalAlign.spaceEvenly => Alignment.center,
  };

  CrossAxisAlignment get _crossAxisAlignment => switch (horizontalAlign) {
    CourseCardHorizontalAlign.left => CrossAxisAlignment.start,
    CourseCardHorizontalAlign.center => CrossAxisAlignment.center,
    CourseCardHorizontalAlign.right => CrossAxisAlignment.end,
  };

  Alignment get _contentAlignment => switch (horizontalAlign) {
    CourseCardHorizontalAlign.left => Alignment.centerLeft,
    CourseCardHorizontalAlign.center => Alignment.center,
    CourseCardHorizontalAlign.right => Alignment.centerRight,
  };

  TextAlign get _textAlign => switch (horizontalAlign) {
    CourseCardHorizontalAlign.left => TextAlign.left,
    CourseCardHorizontalAlign.center => TextAlign.center,
    CourseCardHorizontalAlign.right => TextAlign.right,
  };
}

class _CompactTextLine {
  final String text;
  final int flex;
  final TextStyle style;

  /// 行首图标；null = 纯文字行（绝大多数字段）。目前只有天气行会带。
  final IconData? icon;

  const _CompactTextLine({
    required this.text,
    required this.flex,
    required this.style,
    this.icon,
  });
}
