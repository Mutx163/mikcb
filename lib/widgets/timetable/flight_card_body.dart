import 'package:flutter/material.dart';

import '../../models/course.dart';
import '../../models/timetable_settings.dart';
import '../../domain/day_course_display_logic.dart';
import '../../providers/timetable_provider.dart';
import '../../utils/hex_color.dart';
import 'day_view/day_view_agenda_surface.dart';

/// 转场中「正在飞的那张卡」的渲染（2026-10-21）。
///
/// ## 它要看起来像什么
///
/// 用户口径：「1、3、5 节有课，就应该是那几张课程的卡片，直接卡片对卡片，
/// 放大过去」。所以飞行卡是**同一张卡在两种排版之间连续变化**：
///
/// - 起点（`t=0`）：接近周网格里那张紧凑小卡（小字号、单行、几乎贴边）；
/// - 终点（`t=1`）：接近日视图议程卡（大字号、课名 + 地点）。
///
/// 外部矩形由 `MorphFlightCard` 的 `Rect.lerp` 驱动，这里只负责**内部排版**
///（字号、内边距、行数）。两者一起变，才读作「卡片自己长大」；只缩外框会让
/// 文字像被拉扁。
///
/// ## 材质
///
/// 用 [DayViewAgendaSurface]（日视图议程卡的同一套表面）并 `forceSolid: true`：
///
/// - 终点就是议程卡，用同一套材质才能无缝交接；
/// - 为什么强制实体：飞行卡在转场中每帧都在动，玻璃档会每帧重采样身后壁纸
///   （`CourseSurface` 的 `BackdropFilter` 代价），而实体档是一次渐变填充。
///   落地瞬间换成真议程卡（它按用户设置决定材质），此时卡片已静止，重新采样
///   只发生一帧。
class FlightCardBody extends StatelessWidget {
  const FlightCardBody({
    super.key,
    required this.course,
    required this.settings,
    required this.progress,
    required this.color,
  });

  final Course course;
  final TimetableSettings settings;

  /// 飞行进度 0..1（已过曲线）。
  final double progress;

  /// 卡片主色（已按主题/课程色解析）。
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = progress.clamp(0.0, 1.0);
    // 圆角跟着长大：小卡 8dp → 议程卡 12dp 档（实际值由外层 radius 的二段式
    // 决定，这里只做内部视觉）。
    final radius = 8 + (4 * t);
    // 内边距：紧凑卡 3~4dp → 议程卡 10dp 左右。
    final pad = 3 + (7 * t);
    // 字号：紧凑卡约 9sp（网格单行）→ 议程卡 14sp。
    final titleSize = 9 + (5 * t);
    final subSize = 7.5 + (3.5 * t);

    return DayViewAgendaSurface(
      settings: settings,
      color: color,
      radius: radius,
      forceSolid: true,
      child: Padding(
        padding: EdgeInsets.all(pad),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              course.name,
              // 早期一行（小卡放不下两行），长大了才允许折行。
              maxLines: t > 0.45 ? 2 : 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: titleSize,
                fontWeight: FontWeight.w600,
                height: 1.15,
              ),
            ),
            if (t > 0.3) ...[
              SizedBox(height: 1 + 2 * t),
              Opacity(
                // 只在卡片已经有空间时淡入副信息。这里用 Opacity 是安全的：
                // 它包的是纯文本，**不是** CourseSurface 玻璃本体
                //（玻璃进半透明层的禁忌针对的是卡片表面，见 CourseSurface 注释）。
                opacity: ((t - 0.3) / 0.7).clamp(0.0, 1.0),
                child: Text(
                  course.location,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: subSize, height: 1.2),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 按课程 id 从当天课程里造一张飞行卡（找不到就返回空）。
///
/// 抽成顶层函数而不是 State 方法：`timetable_screen.dart` 有行数棘（只减不增），
/// 而这段是纯渲染、不碰 State 私有状态。
Widget buildFlightCardFor({
  required String courseId,
  required List<Course> dayCourses,
  required TimetableSettings settings,
  required TimetableProvider provider,
  required Color fallbackColor,
  required double progress,
}) {
  final course = dayCourses.where((c) => c.id == courseId).firstOrNull;
  if (course == null) {
    return const SizedBox.shrink();
  }
  final hex = resolveDisplayCourseColor(
        DayCourseDisplayItem(course: course),
        settings: settings,
        coupleColorForKind: provider.coupleColorForKind,
      ) ??
      course.color;
  return FlightCardBody(
    course: course,
    settings: settings,
    progress: progress,
    color: parseHexColorOrFallback(hex, fallback: fallbackColor),
  );
}
