import 'package:flutter/material.dart';

import '../models/timetable_settings.dart';

/// Provides the shared backdrop group required by gaussian course cards.
///
/// Opaque and translucent cards do not need an ancestor host. Keeping the
/// gaussian group at the whole-grid level lets every visible card share one
/// backdrop capture instead of creating a separate capture for each card.
class CourseGridSurfaceHost extends StatelessWidget {
  const CourseGridSurfaceHost({
    required this.settings,
    required this.child,
    super.key,
  });

  final TimetableSettings settings;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return settings.courseCardSurfaceStyle == CourseCardSurfaceStyle.gaussian
        ? BackdropGroup(child: child)
        : child;
  }
}
