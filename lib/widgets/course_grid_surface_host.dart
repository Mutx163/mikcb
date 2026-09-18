import 'package:flutter/material.dart';

import '../models/timetable_settings.dart';
import '../ui/hyperos/hyperos_blurred_header.dart';
import '../utils/home_page_background.dart';

/// Provides the shared backdrop group required by glass course cards.
///
/// Opaque cards do not need an ancestor host. Keeping the group at the
/// whole-grid level lets every visible card share one backdrop capture instead
/// of creating a separate capture for each card.
///
/// 高斯档常态就要这个组；折射档常态走共享预模糊位图、用不到它，但**位图到位
/// 之前**它会退化成实时 `BackdropFilter.grouped` 过渡几帧，那几帧同样要靠这个
/// 组才只捕获一次。所以判据用 [CourseCardSurfaceStyleX.isGlass] 而不是
/// `== gaussian`。
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
    // No wallpaper or no blur pipeline (global solid / degraded) -> no glass
    // cards, hence no shared backdrop capture (mirrors
    // effectiveCourseCardSurfaceStyle used by the cards themselves).
    return effectiveCourseCardSurfaceStyle(
          settings,
          gaussianBlurAvailable: HyperosBlurredHeader.backdropBlurEnabled(
            context,
          ),
        ).isGlass
        ? BackdropGroup(child: child)
        : child;
  }
}
