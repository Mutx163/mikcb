import 'package:flutter/material.dart';

import '../models/course.dart';

class CourseCard extends StatelessWidget {
  final Course course;
  final VoidCallback? onTap;
  final bool isCompact;
  final double compactTitleFontSize;
  final double compactSubtitleFontSize;
  final double compactVerticalPadding;
  final String? overrideColorHex;
  final String? topRightBadgeText;

  const CourseCard({
    super.key,
    required this.course,
    this.onTap,
    this.isCompact = false,
    this.compactTitleFontSize = 9,
    this.compactSubtitleFontSize = 8,
    this.compactVerticalPadding = 6,
    this.overrideColorHex,
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
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            course.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
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
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.location_on,
                            size: 16, color: Colors.white70),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            course.location,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.person, size: 16, color: Colors.white70),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            course.teacher,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.access_time,
                            size: 16, color: Colors.white70),
                        const SizedBox(width: 4),
                        Text(
                          '${course.startTime} - ${course.endTime}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
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
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    course.name,
                    style: TextStyle(
                      fontSize: compactTitleFontSize,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1.15,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    course.location,
                    style: TextStyle(
                      fontSize: compactSubtitleFontSize,
                      color: Colors.white70,
                      height: 1.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
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

  Widget _buildBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.red.shade600,
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
}
