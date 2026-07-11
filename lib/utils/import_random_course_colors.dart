import 'dart:math';

import '../models/course.dart';
import 'course_color_palette.dart';

/// Assigns preset colors to imported courses, grouping by name + teacher.
///
/// Same name+teacher share one color. Distinct groups cycle a shuffled palette.
List<Course> applyRandomImportCourseColors(
  List<Course> courses, {
  Random? random,
  List<String> palette = kPresetCourseColorHexes,
}) {
  if (courses.isEmpty || palette.isEmpty) {
    return List<Course>.from(courses);
  }

  final randomSource = random ?? Random();
  final shuffledPalette = List<String>.from(palette)..shuffle(randomSource);

  final groupColorByKey = <String, String>{};
  var nextGroupIndex = 0;

  return courses
      .map((course) {
        final groupKey = buildImportCourseColorGroupKey(
          name: course.name,
          teacher: course.teacher,
        );
        final assignedColor = groupColorByKey.putIfAbsent(groupKey, () {
          final colorHex =
              shuffledPalette[nextGroupIndex % shuffledPalette.length];
          nextGroupIndex += 1;
          return colorHex;
        });
        return course.copyWith(color: assignedColor);
      })
      .toList(growable: false);
}

String buildImportCourseColorGroupKey({
  required String name,
  required String teacher,
}) {
  return '${_normalizeImportColorKeyPart(name)}\u0000${_normalizeImportColorKeyPart(teacher)}';
}

String _normalizeImportColorKeyPart(String value) {
  return value.trim().replaceAll(RegExp(r'\s+'), ' ');
}
