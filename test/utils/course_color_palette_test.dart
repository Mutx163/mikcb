import 'package:flutter/material.dart';
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

  group('kCourseColorGroups', () {
    test('组 id 唯一且不占用「全部颜色」保留 id', () {
      final ids = kCourseColorGroups.map((group) => group.id).toSet();
      expect(ids, hasLength(kCourseColorGroups.length));
      expect(ids, isNot(contains(kCourseColorGroupAllId)));
    });

    test('每组色数足够随机取色、组内不重复、且全部 ⊆ 全量色板', () {
      final fullPalette = kPresetCourseColorHexes
          .map((hex) => hex.toUpperCase())
          .toSet();
      for (final group in kCourseColorGroups) {
        expect(group.hexes.length, greaterThanOrEqualTo(15),
            reason: '${group.id} 色数过少');
        final seenInGroup = <String>{};
        for (final hex in group.hexes) {
          final key = hex.toUpperCase();
          expect(fullPalette, contains(key),
              reason: '${group.id} 的 $hex 不在全量色板中');
          expect(seenInGroup.add(key), isTrue,
              reason: '${group.id} 组内重复: $hex');
        }
      }
    });

    test('courseColorGroupPalette：all 与未知 id 兜底回全量，预设组原样返回', () {
      expect(
        courseColorGroupPalette(kCourseColorGroupAllId),
        same(kPresetCourseColorHexes),
      );
      expect(courseColorGroupPalette('nonexistent'), same(kPresetCourseColorHexes));
      for (final group in kCourseColorGroups) {
        expect(courseColorGroupPalette(group.id), same(group.hexes));
      }
    });
  });

  group('bestContrastCourseCardInk', () {
    test('浅色底回落近黑墨，深色底回落白墨（预览与实心卡隐身线回落同款）', () {
      expect(
        bestContrastCourseCardInk(const Color(0xFFFDE047)), // yellow-300
        const Color(0xFF1A1A1A),
      );
      expect(
        bestContrastCourseCardInk(const Color(0xFF1D4ED8)), // blue-700
        const Color(0xFFFFFFFF),
      );
    });
  });
}
