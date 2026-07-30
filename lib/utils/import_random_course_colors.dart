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
  bool assignMatchingTextColor = false,
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
        return course.copyWith(
          color: assignedColor,
          textColor: assignMatchingTextColor
              ? matchingCourseTextColorHex(assignedColor)
              : null,
        );
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

/// Picks a legible text color hex (near-black or white) for [backgroundHex]
/// based on its perceived luminance (ITU-R BT.601).
String matchingCourseTextColorHex(String backgroundHex) {
  final hex = backgroundHex.replaceAll('#', '').trim();
  if (hex.length < 6) {
    return '#FFFFFF';
  }
  final r = int.tryParse(hex.substring(0, 2), radix: 16) ?? 0;
  final g = int.tryParse(hex.substring(2, 4), radix: 16) ?? 0;
  final b = int.tryParse(hex.substring(4, 6), radix: 16) ?? 0;
  final luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255;
  return luminance > 0.6 ? '#1F1F1F' : '#FFFFFF';
}
