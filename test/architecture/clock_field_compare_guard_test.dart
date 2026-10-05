import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 架构棘（第二十四轮）：**钟点串一律按分钟数比**，不许再出现字段级字典序比较。
///
/// 正源是 `lib/domain/clock_order.dart` 的 `compareClockText`，它自己的注释
/// （:5-11）写明了为什么：`Course.fromJson`（models/course.dart:298）与
/// `ScheduleItem.fromJson`（models/schedule_item.dart:226）都是
/// `json['startTime'] as String` 原样收下，而"备份 JSON、局域网传输包、别的工具
/// 导出的课表里 `9:00` 很常见" —— 字典序下 `'10:00' < '9:00'`，同一天两条就排反。
///
/// 这条规则本仓已经**修过三次、每次只改当时找到的那几处**（第七轮两处、
/// 第二十二轮统计一处、第二十四轮三处），所以用一个棘把它钉死：以后谁再写
/// `xxx.startTime.compareTo(yyy.startTime)`，这个测试就红，而不是等下一轮审查。
///
/// 允许清单里只有一处，且**已逐行核过安全**：
/// `timetable_screen.dart` 的当日考试排序排的是 `Exam.startTime`，
/// 而 `Exam.fromJson`（models/exam.dart:168）走 `normalizeTimeOfDay(...)`，
/// 恒为补零的 `HH:mm`，字典序与分钟序同序。
void main() {
  final libDir = Directory('lib');

  final forbidden = RegExp(
    r'\.\s*(?:startTime|endTime)\s*\.\s*compareTo\s*\(',
  );
  const allowedLine =
      '..sort((a, b) => a.startTime.compareTo(b.startTime));';
  const allowedNote =
      '只允许排 Exam.startTime（Exam.fromJson 走 normalizeTimeOfDay 恒补零）；'
      '若这里开始混排 Course/ScheduleItem 的钟点，必须改成 compareClockText';

  test('lib/ 里不再有对钟点字段做字典序比较的新位置', () {
    expect(libDir.existsSync(), isTrue, reason: '请在仓库根目录运行本测试');

    final hits = <String>[];
    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }
      final lines = entity.readAsLinesSync();
      final normalizedPath = entity.path.replaceAll(r'\', '/');
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (!forbidden.hasMatch(line)) {
          continue;
        }
        // 注释里出现规则名不算违规（本棘自己的说明也会提到）。
        final trimmed = line.trim();
        if (trimmed.startsWith('//') || trimmed.startsWith('///')) {
          continue;
        }
        // 允许清单按**整行内容**匹配，不按文件放行：否则同一个文件里新加的
        // 课程/日程排序会被一起放过（第一版就犯了这个错）。
        if (normalizedPath.endsWith('screens/timetable_screen.dart') &&
            trimmed == allowedLine) {
          continue;
        }
        hits.add('$normalizedPath:${i + 1}: $trimmed');
      }
    }

    expect(
      hits,
      isEmpty,
      reason:
          '钟点字段不能按字典序比较（\'10:00\' < \'9:00\' 会把同一天排反），'
          '请改用 domain/clock_order.dart 的 compareClockText。命中：\n'
          '${hits.join('\n')}',
    );
  });

  test('允许清单里的那一处仍然是考试排序，没有变成课程或日程', () {
    final file = File('lib/screens/timetable_screen.dart');
    expect(file.existsSync(), isTrue);
    expect(allowedNote, isNotEmpty);
    final offending = file.readAsLinesSync().where((line) {
      final trimmed = line.trim();
      return forbidden.hasMatch(trimmed) &&
          !trimmed.startsWith('//') &&
          !trimmed.startsWith('///');
    }).toList();

    // 今天只允许一行：`..sort((a, b) => a.startTime.compareTo(b.startTime))`
    // 且它排序的对象是 dayExams（Exam）。多出一行就说明有人把课程或日程
    // 也塞进了同一个排序，那时本棘必须被更新而不是放过。
    expect(
      offending.map((line) => line.trim()).toList(),
      [allowedLine],
      reason: offending.join('\n'),
    );
  });
}
