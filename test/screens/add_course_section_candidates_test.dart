import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/screens/add_course_screen.dart';

/// 编辑/添加课程页的「节次」候选范围（第 32 轮）。
///
/// 缺陷：`add_course_screen.dart` 原先用**全局** `settings.sectionCount` 生成候选，
/// 而「结束节次」的 `minValue` 取的是课程现存的 `startSection`。课程钉着一份比全局
/// 更长的作息模板时（全局 10 节、模板 12 节、课在 11-12 节 ——
/// `TimeSchemeLogic.syncCourseWithEffectiveTimeScheme` 对这种越界节次原样保留不改写），
/// `minValue(11) > maxValue(10)`，`showMiuixNumberPickerSheet` 开头的
/// `currentValue.clamp(minValue, maxValue)`（`miuix_number_picker_sheet.dart:20`）
/// 直接抛 ArgumentError：点那一行 release 里毫无反应、debug 里断言崩，
/// 那门课的节次再也改不动。改课弹层在更早的审查里已经修过同一处
/// （`course_followup_sheets.dart:306-333`），加课/编辑课页是漏网的入口。
void main() {
  group('editableSectionNumbers 跟着这门课自己的节次表', () {
    test('模板比全局长时，多出来的节次选得到', () {
      final numbers = editableSectionNumbers(
        globalSectionCount: 10,
        courseSchemeSectionCount: 12,
        currentStartSection: 11,
        currentEndSection: 12,
      );

      expect(numbers, contains(11));
      expect(numbers, contains(12));
      expect(numbers.last, 12);
      // 起止都落在候选里，选择器的 min<=max 才成立。
      expect(numbers.first, 1);
    });

    test('课程现存的越界节次一定并进候选（不让 clamp 抛）', () {
      // 模板解析不出来（null / 空表）时退回全局节数，但课程现存值仍必须在集合里，
      // 否则 minValue=startSection 又会大于 maxValue。
      final numbers = editableSectionNumbers(
        globalSectionCount: 10,
        courseSchemeSectionCount: null,
        currentStartSection: 11,
        currentEndSection: 12,
      );

      expect(numbers, contains(11));
      expect(numbers, contains(12));
      expect(numbers.last, greaterThanOrEqualTo(12));
    });

    test('模板比全局短时以模板为准（与改课弹层同口径）', () {
      final numbers = editableSectionNumbers(
        globalSectionCount: 12,
        courseSchemeSectionCount: 8,
        currentStartSection: 3,
        currentEndSection: 4,
      );

      expect(numbers, List<int>.generate(8, (i) => i + 1));
    });

    test('空模板（异常状态）退回全局节数，选择器不空掉', () {
      final numbers = editableSectionNumbers(
        globalSectionCount: 9,
        courseSchemeSectionCount: 0,
        currentStartSection: 1,
        currentEndSection: 1,
      );

      expect(numbers.length, 9);
    });
  });

  test('接线棘：候选必须出自 editableSectionNumbers，不许退回全局节数', () {
    final source = _readSource('lib/screens/add_course_screen.dart');

    expect(
      source,
      isNot(contains('List.generate(settings.sectionCount, (i) => i + 1)')),
      reason: '又用全局节数当候选了 —— 课程钉着更长模板时 min>max 会抛',
    );
    expect(
      RegExp('editableSectionNumbers\\s*\\(').hasMatch(source),
      isTrue,
      reason: 'helper 写了但没接线，等价于没修',
    );
    expect(
      RegExp('courseSchemeSectionCount:').hasMatch(source),
      isTrue,
      reason: '接线必须把"这门课解析出的模板节数"传进去',
    );
  });
}

String _readSource(String relativePath) {
  final file = File(relativePath);
  expect(file.existsSync(), isTrue, reason: '需在仓库根运行');
  return file.readAsLinesSync().join('\n');
}
