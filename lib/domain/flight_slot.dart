import '../../models/course.dart';

/// 「卡片对卡片」转场的**起点数据**（2026-10-21）。
///
/// 转场时每张课要从它**在周网格里占的那一格**飞出去，长成日视图议程里的那张卡。
/// 起点矩形由 [startSection]/[endSection] 决定，而矩形本身由转场壳按
/// `weekCardRect` + 共用节高公式算——这里只提供数据，不提供几何。
///
/// 为什么只取**有课**的节次：用户口径是「1、3、5 节有课，那三张卡飞过去」。
/// 空节次没有卡片，硬凑一个起点会让某个不存在的格子「凭空冒出一张卡」。
class FlightSlot {
  const FlightSlot({
    required this.courseId,
    required this.startSection,
    required this.endSection,
  });

  /// 课程 id：两端靠它配对同一张卡。
  final String courseId;

  /// 起始节次（1 起）。
  final int startSection;

  /// 结束节次（含）。
  final int endSection;

  @override
  String toString() =>
      'FlightSlot($courseId, $startSection..$endSection)';
}

/// 从某一天的课程列表提炼飞行起点。
///
/// 过滤掉节次非法的（`startSection <= 0`）：这类课在网格里本来就不落格，
/// 给它算一个起点会让卡片从屏幕外飞进来。
List<FlightSlot> flightSlotsFromCourses(Iterable<Course> courses) {
  final result = <FlightSlot>[];
  for (final course in courses) {
    if (course.startSection <= 0) {
      continue;
    }
    result.add(
      FlightSlot(
        courseId: course.id,
        startSection: course.startSection,
        endSection: course.endSection < course.startSection
            ? course.startSection
            : course.endSection,
      ),
    );
  }
  return result;
}
