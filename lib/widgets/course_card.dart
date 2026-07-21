import 'package:flutter/material.dart';
import 'package:university_timetable/l10n/app_localizations.dart';

import '../models/course.dart';
import '../models/timetable_settings.dart';
import '../utils/hex_color.dart';

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
  final CourseCardVerticalAlign verticalAlign;
  final CourseCardHorizontalAlign horizontalAlign;
  final double compactTitleFontSize;
  final double compactSubtitleFontSize;
  final double compactVerticalPadding;
  final double compactOuterInset;
  final String? overrideColorHex;
  final String? titleColorHex;
  final String? detailColorHex;
  final String? compactOverlineText;
  final String? topRightBadgeText;

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
    this.verticalAlign = CourseCardVerticalAlign.center,
    this.horizontalAlign = CourseCardHorizontalAlign.center,
    this.compactTitleFontSize = 9,
    this.compactSubtitleFontSize = 8,
    this.compactVerticalPadding = 6,
    this.compactOuterInset = 2,
    this.overrideColorHex,
    this.titleColorHex,
    this.detailColorHex,
    this.compactOverlineText,
    this.topRightBadgeText,
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
    final titleColor = titleColorHex != null
        ? _parseColor(titleColorHex!)
        : Colors.white;
    final detailColor = detailColorHex != null
        ? _parseColor(detailColorHex!).withValues(alpha: 0.7)
        : Colors.white70;

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

    final card = Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      elevation: isHighlighted ? 6 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isHighlighted
            ? BorderSide(
                color: Colors.white.withValues(alpha: 0.92),
                width: 1.6,
              )
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withValues(alpha: 0.9),
                color.withValues(alpha: 0.7),
              ],
            ),
            boxShadow: isHighlighted
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.28),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Stack(
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
                                fontWeight: FontWeight.bold,
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
                                    color: titleColor,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    if (showName && detailLines.isNotEmpty)
                      const SizedBox(height: 8),
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
              if (topRightBadgeText != null)
                Positioned(
                  top: 8,
                  right: 8,
                  child: _buildBadgeRow(
                    context,
                    customBadgeText: topRightBadgeText,
                  ),
                ),
              if (isHoliday && topRightBadgeText == null)
                Positioned(
                  top: 8,
                  right: 8,
                  child: _buildBadgeRow(context, showHoliday: true),
                ),
              if (isSuspended && topRightBadgeText == null && !isHoliday)
                Positioned(
                  top: 8,
                  right: 8,
                  child: _buildBadgeRow(context, showSuspended: true),
                ),
            ],
          ),
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
            Container(
              margin: EdgeInsets.all(compactOuterInset),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color.withValues(alpha: 0.9),
                    color.withValues(alpha: 0.7),
                  ],
                ),
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
              ),
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
                              for (var i = 0; i < textLines.length; i++) ...[
                                if (i > 0) const SizedBox(height: 2),
                                Text(
                                  textLines[i].text,
                                  style: textLines[i].style,
                                  textAlign: textAlign,
                                  softWrap: true,
                                ),
                              ],
                            ],
                          );

                          if (verticalAlign ==
                              CourseCardVerticalAlign.spaceEvenly) {
                            return FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.center,
                              child: SizedBox(
                                width: constraints.maxWidth,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  crossAxisAlignment: crossAxisAlignment,
                                  children: [
                                    for (final line in textLines)
                                      Text(
                                        line.text,
                                        style: line.style,
                                        textAlign: textAlign,
                                        softWrap: true,
                                      ),
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
            if (showHomeworkIndicator)
              Positioned(
                top: 4,
                left: 4,
                child: _buildHomeworkIndicator(size: 15, iconSize: 9),
              ),
            if (topRightBadgeText != null)
              Positioned(
                top: 6,
                right: 6,
                child: _buildBadgeRow(
                  context,
                  customBadgeText: topRightBadgeText,
                ),
              ),
            if (isHoliday && topRightBadgeText == null)
              Positioned(
                top: 6,
                right: 6,
                child: _buildBadgeRow(context, showHoliday: true),
              ),
            if (isSuspended && topRightBadgeText == null && !isHoliday)
              Positioned(
                top: 6,
                right: 6,
                child: _buildBadgeRow(context, showSuspended: true),
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
        color: const Color(0xFFE05D44),
      ),
    );
  }

  Widget _buildBadge(String text, {Color? color}) {
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
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
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
  }) {
    final l10n = AppLocalizations.of(context);
    final badges = <Widget>[];
    if (showHoliday && l10n != null) {
      badges.add(
        _buildBadge(l10n.holidayBadgeLabel, color: Colors.orange.shade700),
      );
    }
    if (showSuspended && l10n != null) {
      badges.add(
        _buildBadge(l10n.suspendedBadgeLabel, color: Colors.red.shade700),
      );
    }
    if (customBadgeText != null) {
      badges.add(_buildBadge(customBadgeText));
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
      lines.add(_buildDetailRow(Icons.person, course.teacher, detailColor));
    }
    if (showLocation && course.location.trim().isNotEmpty) {
      if (lines.isNotEmpty) lines.add(const SizedBox(height: 4));
      lines.add(
        _buildDetailRow(Icons.location_on, course.location, detailColor),
      );
    }
    if (showTime) {
      if (lines.isNotEmpty) lines.add(const SizedBox(height: 4));
      lines.add(
        _buildDetailRow(
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
          Icons.notes_rounded,
          course.description!.trim(),
          detailColor,
        ),
      );
    }
    return lines;
  }

  Widget _buildDetailRow(IconData icon, String text, Color detailColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: detailColor),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 13, color: detailColor, height: 1.15),
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
    final lines = <_CompactTextLine>[];
    if (compactOverlineText?.trim().isNotEmpty ?? false) {
      lines.add(
        _CompactTextLine(
          text: compactOverlineText!.trim(),
          flex: 1,
          style: TextStyle(
            fontSize: (compactSubtitleFontSize - 1).clamp(6.0, 12.0),
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
            fontWeight: FontWeight.bold,
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
            color: detailColor,
            height: 1.1,
          ),
        ),
      );
    }
    return lines.isEmpty
        ? [
            _CompactTextLine(
              text: course.name,
              flex: 1,
              style: TextStyle(
                fontSize: compactTitleFontSize,
                fontWeight: FontWeight.bold,
                color: titleColor,
                height: 1.15,
              ),
            ),
          ]
        : lines;
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

  const _CompactTextLine({
    required this.text,
    required this.flex,
    required this.style,
  });
}
