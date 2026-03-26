import 'package:flutter/material.dart';

import '../models/course.dart';
import '../models/timetable_settings.dart';

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
  final String? overrideColorHex;
  final String? compactOverlineText;
  final String? topRightBadgeText;

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
    this.overrideColorHex,
    this.compactOverlineText,
    this.topRightBadgeText,
  });

  Color _parseColor(String colorString) {
    final hexColor = colorString.replaceFirst('#', '');
    return Color(int.parse('FF$hexColor', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final color = _parseColor(overrideColorHex ?? course.color);

    if (isCompact) {
      return _buildCompactCard(color);
    }

    return _buildFullCard(color);
  }

  Widget _buildFullCard(Color color) {
    final detailLines = _buildDetailLines();
    final titleAlignment = _contentAlignment;
    final titleTextAlign = _textAlign;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
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
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
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
                                  '第${course.startSection}-${course.endSection}节',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.white,
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
              if (topRightBadgeText != null)
                Positioned(
                  top: 8,
                  right: 8,
                  child: _buildBadge(topRightBadgeText!),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactCard(Color color) {
    final textLines = _buildCompactTextLines();
    final crossAxisAlignment = _crossAxisAlignment;
    final textAlign = _textAlign;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
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
            if (topRightBadgeText != null)
              Positioned(
                top: 6,
                right: 6,
                child: _buildBadge(topRightBadgeText!),
              ),
          ],
        ),
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

  List<Widget> _buildDetailLines() {
    final lines = <Widget>[];
    if (showTeacher && course.teacher.trim().isNotEmpty) {
      lines.add(_buildDetailRow(Icons.person, course.teacher));
    }
    if (showLocation && course.location.trim().isNotEmpty) {
      if (lines.isNotEmpty) lines.add(const SizedBox(height: 4));
      lines.add(_buildDetailRow(Icons.location_on, course.location));
    }
    if (showTime) {
      if (lines.isNotEmpty) lines.add(const SizedBox(height: 4));
      lines.add(
        _buildDetailRow(
          Icons.access_time,
          _buildTimeText(isCompact: false),
        ),
      );
    }
    if (showWeeks) {
      if (lines.isNotEmpty) lines.add(const SizedBox(height: 4));
      lines.add(
        _buildDetailRow(
          Icons.date_range_rounded,
          _buildWeekText(),
        ),
      );
    }
    if (showDescription && (course.description?.trim().isNotEmpty ?? false)) {
      if (lines.isNotEmpty) lines.add(const SizedBox(height: 4));
      lines.add(
          _buildDetailRow(Icons.notes_rounded, course.description!.trim()));
    }
    return lines;
  }

  Widget _buildDetailRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.white70),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.white70,
              height: 1.15,
            ),
            softWrap: true,
          ),
        ),
      ],
    );
  }

  List<_CompactTextLine> _buildCompactTextLines() {
    final lines = <_CompactTextLine>[];
    if (compactOverlineText?.trim().isNotEmpty ?? false) {
      lines.add(
        _CompactTextLine(
          text: compactOverlineText!.trim(),
          flex: 1,
          style: TextStyle(
            fontSize: (compactSubtitleFontSize - 1).clamp(6.0, 12.0),
            color: Colors.white.withValues(alpha: 0.78),
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
            color: Colors.white,
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
            color: Colors.white70,
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
            color: Colors.white70,
            height: 1.1,
          ),
        ),
      );
    }
    if (showTime) {
      lines.addAll([
        _CompactTextLine(
          text: showTimeLabels ? '上课 ${course.startTime}' : course.startTime,
          flex: 2,
          style: TextStyle(
            fontSize: compactSubtitleFontSize,
            color: Colors.white70,
            height: 1.1,
          ),
        ),
        _CompactTextLine(
          text: showTimeLabels ? '下课 ${course.endTime}' : course.endTime,
          flex: 2,
          style: TextStyle(
            fontSize: compactSubtitleFontSize,
            color: Colors.white70,
            height: 1.1,
          ),
        ),
      ]);
    }
    if (showWeeks) {
      lines.add(
        _CompactTextLine(
          text: _buildWeekText(),
          flex: 2,
          style: TextStyle(
            fontSize: compactSubtitleFontSize,
            color: Colors.white70,
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
            color: Colors.white70,
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
                color: Colors.white,
                height: 1.15,
              ),
            ),
          ]
        : lines;
  }

  String _buildWeekText() {
    final mode = course.isOddWeek
        ? ' 单周'
        : course.isEvenWeek
            ? ' 双周'
            : '';
    return '第${course.startWeek}-${course.endWeek}周$mode';
  }

  String _buildTimeText({required bool isCompact}) {
    final start = showTimeLabels ? '上课 ${course.startTime}' : course.startTime;
    final end = showTimeLabels ? '下课 ${course.endTime}' : course.endTime;
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
