import 'dart:math';

import '../domain/course_domain.dart';
import '../models/course.dart';
import 'course_color_palette.dart';
import 'import_random_course_colors.dart';

/// 重刷配色的分组键：按共享课程名（与课程组编辑页同口径）。
///
/// 「同名同色」是 App 的不变式——addCourse 的共享字段步骤与课程组编辑都会
/// 把同名条目的颜色统一；重刷必须维持它，而不是沿用导入期的 name+teacher 键。
String buildCourseRecolorGroupKey(Course course) =>
    'name\u0000${buildSharedCourseNameKey(course.name)}';

/// 以固定种子对整份课表重刷随机配色（与导入随机配色同一算法与色板）。
///
/// 同一种子 + 同一份课程列表得到逐色一致的配色；课程列表变化后重放同一
/// 种子仍是一次合法的重洗，仅组序变化导致的取色前移/后移。
List<Course> applySeedCourseRecolor(
  List<Course> courses, {
  required int seed,
  required String colorGroupId,
  required bool assignMatchingTextColor,
}) {
  return applyRandomImportCourseColors(
    courses,
    random: Random(seed),
    palette: courseColorGroupPalette(colorGroupId),
    assignMatchingTextColor: assignMatchingTextColor,
    groupKeyBuilder: buildCourseRecolorGroupKey,
  );
}

/// 一组（同名课程）在快照记录里的颜色。
class CourseRecolorSnapshotEntry {
  const CourseRecolorSnapshotEntry({required this.color, this.textColor});

  /// 坏数据（color 缺失/为空/非字符串）返回 null，由调用方丢弃该条，与
  /// [CourseRecolorScheme.fromJson] 的「坏数据丢弃」口径一致。曾兜底默认
  /// 蓝——损坏记录会被渲染成错误颜色；而 color 类型垃圾会抛 TypeError，
  /// 被历史服务整体 catch 后静默清空全部历史。
  static CourseRecolorSnapshotEntry? fromJson(Map<String, dynamic> json) {
    final color = json['color'];
    if (color is! String || color.isEmpty) {
      return null;
    }
    final text = json['text'];
    return CourseRecolorSnapshotEntry(
      color: color,
      textColor: text is String ? text : null,
    );
  }

  final String color;
  final String? textColor;

  Map<String, dynamic> toJson() => {'color': color, 'text': textColor};

  @override
  bool operator ==(Object other) {
    return other is CourseRecolorSnapshotEntry &&
        other.color == color &&
        other.textColor == textColor;
  }

  @override
  int get hashCode => Object.hash(color, textColor);
}

/// 一套已应用的配色方案，供「上一套 / 下一套」往返切换。
///
/// 两类记录：
/// - 种子批次（[seed] 非空）：记录随机种子与当时的颜色组/文字色开关，
///   同一课程列表下重放即逐色还原；
/// - 快照记录（[snapshotEntries] 非空）：逐组保存刷色前的颜色与文字色，
///   用于回到导入/刷色前的原样（含手工挑过的颜色）。
class CourseRecolorScheme {
  const CourseRecolorScheme.seed({
    required this.seed,
    required this.colorGroupId,
    required this.assignMatchingTextColor,
    required this.createdAt,
  }) : snapshotEntries = null;

  /// 非 const：初始化列表里做了 [Map.unmodifiable] 包裹。
  CourseRecolorScheme.snapshot({
    required Map<String, CourseRecolorSnapshotEntry> entries,
    required this.createdAt,
  }) : seed = null,
       colorGroupId = kCourseColorGroupAllId,
       assignMatchingTextColor = false,
       snapshotEntries = Map.unmodifiable(entries);

  final int? seed;
  final String colorGroupId;
  final bool assignMatchingTextColor;
  final Map<String, CourseRecolorSnapshotEntry>? snapshotEntries;
  final DateTime createdAt;

  bool get isSnapshot => snapshotEntries != null;

  Map<String, dynamic> toJson() {
    return {
      'createdAt': createdAt.toIso8601String(),
      if (isSnapshot)
        'snapshot': {
          for (final entry in snapshotEntries!.entries)
            entry.key: entry.value.toJson(),
        }
      else ...{
        'seed': seed,
        'colorGroupId': colorGroupId,
        'assignMatchingTextColor': assignMatchingTextColor,
      },
    };
  }

  /// 坏数据（缺字段/类型不符）返回 null，由调用方丢弃该条。
  static CourseRecolorScheme? fromJson(Map<String, dynamic> json) {
    final createdAt = DateTime.tryParse(json['createdAt'] as String? ?? '');
    if (createdAt == null) {
      return null;
    }
    final snapshotJson = json['snapshot'];
    if (snapshotJson is Map) {
      final entries = <String, CourseRecolorSnapshotEntry>{};
      snapshotJson.forEach((key, value) {
        if (key is String && value is Map) {
          final entry = CourseRecolorSnapshotEntry.fromJson(
            Map<String, dynamic>.from(value),
          );
          if (entry != null) {
            entries[key] = entry;
          }
        }
      });
      return CourseRecolorScheme.snapshot(
        entries: entries,
        createdAt: createdAt,
      );
    }
    final seed = json['seed'];
    if (seed is! int) {
      return null;
    }
    return CourseRecolorScheme.seed(
      seed: seed,
      colorGroupId: json['colorGroupId'] as String? ?? kCourseColorGroupAllId,
      assignMatchingTextColor: json['assignMatchingTextColor'] as bool? ?? false,
      createdAt: createdAt,
    );
  }
}

/// 捕获当前整份课表的颜色快照（逐组 color/textColor，同名组以首条为准）。
CourseRecolorScheme captureCourseRecolorSnapshot(
  List<Course> courses, {
  DateTime? now,
}) {
  final entries = <String, CourseRecolorSnapshotEntry>{};
  for (final course in courses) {
    entries.putIfAbsent(
      buildCourseRecolorGroupKey(course),
      () => CourseRecolorSnapshotEntry(
        color: course.color,
        textColor: course.textColor,
      ),
    );
  }
  return CourseRecolorScheme.snapshot(
    entries: entries,
    createdAt: now ?? DateTime.now(),
  );
}

/// 把 [scheme] 应用到当前课程列表，返回重刷后的课程副本（按 id 对位）。
///
/// 快照记录里没有的组（刷色后才加的课程）保持原色不动。
List<Course> applyCourseRecolorScheme(
  List<Course> courses,
  CourseRecolorScheme scheme,
) {
  final snapshotEntries = scheme.snapshotEntries;
  if (snapshotEntries != null) {
    final recolored = <Course>[];
    for (final course in courses) {
      final entry = snapshotEntries[buildCourseRecolorGroupKey(course)];
      recolored.add(
        entry == null
            ? course
            : course.copyWith(color: entry.color, textColor: entry.textColor),
      );
    }
    return recolored;
  }
  return applySeedCourseRecolor(
    courses,
    seed: scheme.seed!,
    colorGroupId: scheme.colorGroupId,
    assignMatchingTextColor: scheme.assignMatchingTextColor,
  );
}
