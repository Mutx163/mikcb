import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/utils/course_color_palette.dart';
import 'package:university_timetable/utils/hex_color.dart';

void main() {
  group('kPresetCourseColorHexes', () {
    test('数量达到 100，随机导入取色范围足够大', () {
      expect(kPresetCourseColorHexes.length, greaterThanOrEqualTo(100));
    });

    test('全部是合法 6 位大写 hex 且可解析', () {
      final pattern = RegExp(r'^#[0-9A-F]{6}$');
      for (final hex in kPresetCourseColorHexes) {
        expect(pattern.hasMatch(hex), isTrue, reason: '非法色值: $hex');
        expect(tryParseHexColor(hex), isNotNull, reason: '解析失败: $hex');
      }
    });

    test('无重复色值（大小写不敏感）', () {
      final seen = <String>{};
      for (final hex in kPresetCourseColorHexes) {
        final key = hex.toUpperCase();
        expect(seen.add(key), isTrue, reason: '重复色值: $hex');
      }
    });

    test('新建课程默认色 #2196F3 仍在预设内', () {
      expect(kPresetCourseColorHexes, contains('#2196F3'));
    });
  });

  group('kCourseColorQuickPickHexes', () {
    test('非空且都是全量色板的子集', () {
      expect(kCourseColorQuickPickHexes, isNotEmpty);
      for (final hex in kCourseColorQuickPickHexes) {
        expect(
          kPresetCourseColorHexes,
          contains(hex),
          reason: '快捷色 $hex 不在全量色板中',
        );
      }
    });

    test('快捷行首色是默认色 #2196F3（新建课程初值显示为预设而非自定义）', () {
      expect(kCourseColorQuickPickHexes.first, '#2196F3');
    });

    test('无重复色值', () {
      expect(
        kCourseColorQuickPickHexes.map((hex) => hex.toUpperCase()).toSet(),
        hasLength(kCourseColorQuickPickHexes.length),
      );
    });
  });
}
