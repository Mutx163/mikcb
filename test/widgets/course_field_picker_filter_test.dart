import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/widgets/course_field_picker_sheet.dart';

/// 回归钉（第 27 轮，改课/加课的历史建议搜索按大小写敏感匹配）。
///
/// 原先 `course_field_picker_sheet.dart` 的过滤是 `suggestions.where((s) =>
/// s.contains(query))`（原 :96-98），而同仓其它「输入框过滤列表」都先把两侧归一：
/// `open_source_licenses_screen.dart:116`、`settings_glass_dock_icon_editor.dart:82`、
/// `warehouse_repository_models.dart:277-278 / 327-330`。
///
/// 教室与老师名恰恰是中英混排的高发地（教务系统里 `A101`、`实验楼B-302`、拼音教师名
/// 很常见），命中空表时弹层显示 `l10n.noHistoryRecords`（「无历史记录」，原 :150-158），
/// 用户读到的是「我的记录没了」，于是手打一个小写版本存进去 —— 同一个教室从此裂成
/// 两条，并继续污染楼栋聚类与场所统计。
void main() {
  const suggestions = ['A101', '实验楼B-302', '张伟', 'Zhang Wei'];

  test('小写输入命中大写教室（修复前这里是空表）', () {
    expect(filterFieldSuggestions(suggestions, 'a101'), ['A101']);
    expect(filterFieldSuggestions(suggestions, 'b-302'), ['实验楼B-302']);
    expect(filterFieldSuggestions(suggestions, 'zhang wei'), ['Zhang Wei']);
  });

  test('大写输入同样命中小写记录', () {
    expect(filterFieldSuggestions(['a101'], 'A101'), ['a101']);
  });

  test('空查询与纯空白返回整份列表，顺序不变', () {
    expect(filterFieldSuggestions(suggestions, ''), suggestions);
    expect(filterFieldSuggestions(suggestions, '   '), suggestions);
  });

  test('中文过滤仍按子串，未命中时为空', () {
    expect(filterFieldSuggestions(suggestions, '实验'), ['实验楼B-302']);
    expect(filterFieldSuggestions(suggestions, '图书馆'), isEmpty);
  });

  test('弹层必须用这条归一后的过滤，不再写一份大小写敏感的副本', () {
    final source = File('lib/widgets/course_field_picker_sheet.dart')
      .readAsStringSync();
    expect(source, contains('filterFieldSuggestions(suggestions, query)'));
    expect(
      RegExp(r'\.contains\(\s*query\s*\)').hasMatch(source),
      isFalse,
      reason: '再次出现 `contains(query)` 就是绕过了大小写归一',
    );
  });
}
